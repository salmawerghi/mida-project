-- =====================================================================
-- Mida — US13 : accepter ou refuser une commande (avec un motif)
-- =====================================================================
-- Les applications ne modifient pas les commandes directement (US02) :
-- le responsable passe par ces deux fonctions, qui vérifient
--   • que la commande est bien celle de son restaurant,
--   • qu'elle est encore « en attente » (une seule décision possible),
--   • qu'un refus a un motif,
-- puis préviennent le client par une notification (table `notifications`,
-- que l'appli client affichera). Le changement d'état est aussi diffusé
-- en temps réel (US12).
-- =====================================================================

-- « 22.5 » → « 22,500 DT »
create function private.montant_dt(p_montant numeric)
returns text
language sql immutable set search_path = ''
as $$
  select replace(to_char(p_montant, 'FM999999990.000'), '.', ',') || ' DT';
$$;

-- Commande à traiter par le responsable connecté, verrouillée jusqu'à la
-- fin de la transaction (deux clics simultanés ne font qu'une décision).
create function private.commande_a_traiter(p_commande uuid)
returns public.commandes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.commandes;
begin
  select * into v from public.commandes where id = p_commande for update;
  if not found or not (private.est_responsable_de(v.restaurant_id) or private.est_admin()) then
    raise exception 'Commande introuvable, ou elle ne concerne pas votre restaurant'
      using errcode = '42501';
  end if;
  if v.etat <> 'en_attente' then
    raise exception 'La commande n° % a déjà été traitée', v.numero
      using errcode = 'P0001', hint = v.etat::text;
  end if;
  return v;
end;
$$;

-- Accepter ------------------------------------------------------------
create function public.accepter_commande(p_commande uuid)
returns void
language plpgsql
security definer                     -- les applications n'ont pas le droit de modifier une commande
set search_path = ''
as $$
declare
  v public.commandes := private.commande_a_traiter(p_commande);
  v_restaurant text;
begin
  update public.commandes
     set etat = 'acceptee', acceptee_le = now()
   where id = v.id;

  select nom into v_restaurant from public.restaurants where id = v.restaurant_id;
  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v.client_id, 'Commande acceptée',
          format('%s a accepté votre commande n° %s. Elle va être préparée.', v_restaurant, v.numero),
          'commande', v.id);
end;
$$;

-- Refuser (motif obligatoire) ----------------------------------------------
create function public.refuser_commande(p_commande uuid, p_motif text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_motif text := trim(coalesce(p_motif, ''));
  v public.commandes;
  v_restaurant text;
  v_rembourse numeric;
begin
  if v_motif = '' then
    raise exception 'Le motif du refus est obligatoire' using errcode = 'P0001';
  end if;
  if length(v_motif) > 500 then
    raise exception 'Le motif du refus est trop long (500 caractères au plus)' using errcode = 'P0001';
  end if;
  v := private.commande_a_traiter(p_commande);

  update public.commandes
     set etat = 'refusee', motif_refus = v_motif
   where id = v.id;

  -- Paiement par carte déjà encaissé : il est remboursé (le remboursement
  -- auprès de la passerelle de paiement viendra avec la story du paiement).
  update public.paiements
     set etat = 'rembourse'
   where commande_id = v.id and mode = 'carte' and etat = 'paye'
  returning montant into v_rembourse;

  select nom into v_restaurant from public.restaurants where id = v.restaurant_id;
  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v.client_id, 'Commande refusée',
          format('%s ne peut pas préparer votre commande n° %s. Motif : %s', v_restaurant, v.numero, v_motif)
            || case when v_motif ~ '[.!?…]$' then '' else '.' end
            || case when v_rembourse is not null
                    then format(' Vous allez être remboursé de %s.', private.montant_dt(v_rembourse))
                    else '' end,
          'commande', v.id);
end;
$$;

revoke execute on function public.accepter_commande(uuid) from public, anon;
revoke execute on function public.refuser_commande(uuid, text) from public, anon;
grant execute on function public.accepter_commande(uuid) to authenticated, service_role;
grant execute on function public.refuser_commande(uuid, text) to authenticated, service_role;
