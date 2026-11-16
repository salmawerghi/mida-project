-- =====================================================================
-- Mida — US14 : faire passer une commande à « En préparation » puis « Prête »
-- =====================================================================
-- Le responsable fait avancer sa commande, une étape à la fois :
--     acceptee  →  en_preparation  →  prete
-- Pas de saut d'étape, pas de retour en arrière. L'appli indique l'état
-- visé (et pas seulement « suivant ») : un double clic ou un onglet resté
-- ouvert ne peut donc pas faire avancer la commande de deux étapes.
-- Le client est prévenu à chaque étape ; le changement est diffusé en
-- temps réel (US12). La suite (en_livraison, livree) appartient au livreur.
-- =====================================================================

create function public.avancer_commande(p_commande uuid, p_etat public.etat_commande)
returns void
language plpgsql
security definer                     -- les applications n'ont pas le droit de modifier une commande
set search_path = ''
as $$
declare
  v public.commandes;
  v_precedent public.etat_commande;
  v_restaurant text;
begin
  v_precedent := case p_etat
                   when 'en_preparation' then 'acceptee'
                   when 'prete' then 'en_preparation'
                 end;
  if v_precedent is null then
    raise exception 'Le restaurant ne peut faire passer une commande qu''à « en préparation » ou « prête »'
      using errcode = 'P0001';
  end if;

  select * into v from public.commandes where id = p_commande for update;
  if not found or not (private.est_responsable_de(v.restaurant_id) or private.est_admin()) then
    raise exception 'Commande introuvable, ou elle ne concerne pas votre restaurant'
      using errcode = '42501';
  end if;
  if v.etat = p_etat then
    raise exception 'La commande n° % est déjà %', v.numero,
      case p_etat when 'prete' then 'prête' else 'en préparation' end
      using errcode = 'P0001';
  end if;
  if v.etat <> v_precedent then
    raise exception 'La commande n° % ne peut pas passer à « % » depuis son état actuel', v.numero,
      case p_etat when 'prete' then 'prête' else 'en préparation' end
      using errcode = 'P0001', hint = v.etat::text;
  end if;

  update public.commandes
     set etat = p_etat,
         prete_le = case when p_etat = 'prete' then now() else prete_le end
   where id = v.id;

  select nom into v_restaurant from public.restaurants where id = v.restaurant_id;
  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v.client_id,
          case p_etat when 'prete' then 'Commande prête' else 'Commande en préparation' end,
          case p_etat
            when 'prete' then format('Votre commande n° %s est prête chez %s : elle va bientôt partir en livraison.', v.numero, v_restaurant)
            else format('%s prépare votre commande n° %s.', v_restaurant, v.numero)
          end,
          'commande', v.id);
end;
$$;

revoke execute on function public.avancer_commande(uuid, public.etat_commande) from public, anon;
grant execute on function public.avancer_commande(uuid, public.etat_commande) to authenticated, service_role;
