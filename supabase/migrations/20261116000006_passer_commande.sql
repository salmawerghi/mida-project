-- =====================================================================
-- Mida — US19 : passer commande (paiement en espèces à la livraison)
-- =====================================================================
-- Les applications ne créent pas de commande directement (US02) : le
-- client appelle cette fonction avec son panier. Le SERVEUR calcule les
-- montants à partir des prix du menu et des frais de livraison des
-- paramètres : l'appli n'envoie que les plats et leurs quantités.
--
--   p_lignes : [{"plat_id": "…", "quantite": 2, "remarque": "sans piment"}, …]
--
-- Vérifié ici : compte client non bloqué, adresse de livraison, panier
-- non vide (30 lignes au plus), quantités de 1 à 20, plats du restaurant
-- choisi et disponibles. Les déclencheurs `restaurant_ouvert` (US08) et
-- `plat_disponible` (US11) s'appliquent aussi.
-- La commande naît « en attente » ; le restaurant est prévenu (temps réel
-- US12 et notification).
-- =====================================================================

create function public.passer_commande(
  p_restaurant uuid,
  p_lignes     jsonb,
  p_adresse    text,
  p_remarque   text default null
)
returns jsonb
language plpgsql
security definer                     -- les applications n'ont pas le droit de créer une commande
set search_path = ''
as $$
declare
  v_client      uuid := (select auth.uid());
  v_adresse     text := trim(coalesce(p_adresse, ''));
  v_remarque    text := nullif(trim(coalesce(p_remarque, '')), '');
  v_ligne       jsonb;
  v_plat        public.plats;
  v_quantite    integer;
  v_sous_total  numeric(10, 3) := 0;
  v_frais       numeric(10, 3);
  v_commande    public.commandes;
  v_responsable uuid;
begin
  if v_client is null or private.role_actuel() is distinct from 'client' then
    raise exception 'Seul un compte client peut passer commande' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles where id = v_client and etat_compte = 'bloque') then
    raise exception 'Votre compte est bloqué : contactez le support Mida' using errcode = '42501';
  end if;
  if v_adresse = '' then
    raise exception 'L''adresse de livraison est obligatoire' using errcode = 'P0001';
  end if;
  if length(v_adresse) > 300 or length(coalesce(v_remarque, '')) > 300 then
    raise exception 'Adresse ou remarque trop longue (300 caractères au plus)' using errcode = 'P0001';
  end if;
  if jsonb_typeof(p_lignes) is distinct from 'array' or jsonb_array_length(p_lignes) = 0 then
    raise exception 'Votre panier est vide' using errcode = 'P0001';
  end if;
  if jsonb_array_length(p_lignes) > 30 then
    raise exception 'Trop de plats différents dans une même commande (30 au plus)' using errcode = 'P0001';
  end if;
  if (select count(distinct x ->> 'plat_id') from jsonb_array_elements(p_lignes) x) <> jsonb_array_length(p_lignes) then
    raise exception 'Un même plat apparaît deux fois dans le panier' using errcode = 'P0001';
  end if;

  -- Chaque plat : du restaurant choisi, disponible, quantité raisonnable ; prix du menu.
  for v_ligne in select * from jsonb_array_elements(p_lignes) loop
    v_quantite := case when (v_ligne ->> 'quantite') ~ '^[0-9]{1,3}$' then (v_ligne ->> 'quantite')::integer end;
    if v_quantite is null or v_quantite not between 1 and 20 then
      raise exception 'Quantité invalide : de 1 à 20 par plat' using errcode = 'P0001';
    end if;
    select p.* into v_plat
    from public.plats p
    where p.id::text = v_ligne ->> 'plat_id' and p.restaurant_id = p_restaurant;
    if not found then
      raise exception 'Un plat de votre panier n''est plus au menu de ce restaurant' using errcode = 'P0001';
    end if;
    if not v_plat.disponible then
      raise exception 'Le plat « % » est indisponible pour le moment', v_plat.nom using errcode = 'P0001';
    end if;
    v_sous_total := v_sous_total + v_plat.prix * v_quantite;
  end loop;

  select frais_livraison into v_frais from public.parametres where id = 1;
  v_frais := coalesce(v_frais, 0);

  -- Le déclencheur restaurant_ouvert refuse ici un restaurant fermé ou non validé.
  insert into public.commandes (client_id, restaurant_id, adresse_livraison, etat,
                                sous_total, frais_livraison, total, remarque)
  values (v_client, p_restaurant, v_adresse, 'en_attente',
          v_sous_total, v_frais, v_sous_total + v_frais, v_remarque)
  returning * into v_commande;

  -- Nom et prix copiés : la commande garde ses montants si le menu change ensuite.
  insert into public.lignes_commande (commande_id, plat_id, nom_plat, quantite, prix_unitaire, remarque)
  select v_commande.id, p.id, p.nom, (x ->> 'quantite')::integer, p.prix,
         nullif(left(trim(coalesce(x ->> 'remarque', '')), 200), '')
  from jsonb_array_elements(p_lignes) x
  join public.plats p on p.id::text = x ->> 'plat_id';

  insert into public.paiements (commande_id, mode, montant, etat)
  values (v_commande.id, 'especes', v_commande.total, 'en_attente');

  select responsable_id into v_responsable from public.restaurants where id = p_restaurant;
  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v_responsable, 'Nouvelle commande',
          format('Commande n° %s à accepter : %s, paiement en espèces.', v_commande.numero, private.montant_dt(v_commande.total)),
          'commande', v_commande.id);

  return jsonb_build_object(
    'id', v_commande.id,
    'numero', v_commande.numero,
    'sous_total', v_commande.sous_total,
    'frais_livraison', v_commande.frais_livraison,
    'total', v_commande.total
  );
end;
$$;

revoke execute on function public.passer_commande(uuid, jsonb, text, text) from public, anon;
grant execute on function public.passer_commande(uuid, jsonb, text, text) to authenticated, service_role;
