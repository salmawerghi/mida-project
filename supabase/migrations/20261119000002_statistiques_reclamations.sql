-- =====================================================================
-- Mida — US44, US45, US49
-- ---------------------------------------------------------------------
-- US44  statistiques de ventes d'un restaurant : public.statistiques_restaurant
-- US45  statistiques globales de la plateforme : public.statistiques_plateforme
-- US49  réclamations : le client signale un problème sur une commande
--       livrée ; l'administrateur la traite (résolue / rejetée, réponse,
--       remboursement éventuel) et le client est prévenu.
--
-- Les fonctions de statistiques sont « security invoker » : elles ne
-- calculent que sur les lignes que l'appelant a le droit de lire (règles
-- d'US02). Les jours sont comptés à l'heure de Tunis.
-- =====================================================================

-- ---------------------------------------------------------------------
-- US44 — statistiques d'un restaurant
-- ---------------------------------------------------------------------
create function public.statistiques_restaurant(p_restaurant uuid, p_jours integer default 30)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_debut date := (now() at time zone 'Africa/Tunis')::date - (p_jours - 1);
  v_pct numeric := coalesce((select commission_pct from public.parametres where id = 1), 0);
  v_resultat jsonb;
begin
  if p_jours is null or p_jours not between 1 and 365 then
    raise exception 'Période invalide : de 1 à 365 jours.' using errcode = '22023';
  end if;

  with periode as (
    select c.*, (c.created_at at time zone 'Africa/Tunis')::date as jour
    from public.commandes c
    where c.restaurant_id = p_restaurant
      and (c.created_at at time zone 'Africa/Tunis')::date >= v_debut
  ),
  livrees as (select * from periode where etat = 'livree'),
  jours as (
    select d::date as jour from generate_series(v_debut, (now() at time zone 'Africa/Tunis')::date, interval '1 day') d
  ),
  par_jour as (
    select j.jour,
           count(p.id)::int as commandes,
           coalesce(sum(p.sous_total) filter (where p.etat = 'livree'), 0) as ventes
    from jours j left join periode p on p.jour = j.jour
    group by j.jour order by j.jour
  ),
  plats as (
    select l.nom_plat as nom, sum(l.quantite)::int as quantite, sum(l.quantite * l.prix_unitaire) as ventes
    from livrees c join public.lignes_commande l on l.commande_id = c.id
    group by l.nom_plat
    order by quantite desc, ventes desc, nom
    limit 5
  ),
  notes as (
    select round(avg(note)::numeric, 2) as moyenne, count(*)::int as nb from public.avis where restaurant_id = p_restaurant
  )
  select jsonb_build_object(
    'jours', p_jours,
    'commandes', (select count(*) from periode),
    'livrees', (select count(*) from livrees),
    'refusees', (select count(*) from periode where etat = 'refusee'),
    'annulees', (select count(*) from periode where etat = 'annulee'),
    'ventes', (select coalesce(sum(sous_total), 0) from livrees),
    'panier_moyen', (select coalesce(round(avg(sous_total), 3), 0) from livrees),
    'commission_pct', v_pct,
    'commission', (select coalesce(round(sum(sous_total) * v_pct / 100, 3), 0) from livrees),
    'par_jour', (select coalesce(jsonb_agg(jsonb_build_object('jour', jour, 'commandes', commandes, 'ventes', ventes)), '[]') from par_jour),
    'top_plats', (select coalesce(jsonb_agg(jsonb_build_object('nom', nom, 'quantite', quantite, 'ventes', ventes)), '[]') from plats),
    'note_moyenne', (select moyenne from notes),
    'nb_avis', (select nb from notes)
  ) into v_resultat;
  return v_resultat;
end;
$$;
revoke execute on function public.statistiques_restaurant(uuid, integer) from public, anon;
grant execute on function public.statistiques_restaurant(uuid, integer) to authenticated, service_role;

-- ---------------------------------------------------------------------
-- US45 — statistiques globales (administrateur)
-- ---------------------------------------------------------------------
create function public.statistiques_plateforme(p_jours integer default 30)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_debut date := (now() at time zone 'Africa/Tunis')::date - (p_jours - 1);
  v_pct numeric := coalesce((select commission_pct from public.parametres where id = 1), 0);
  v_resultat jsonb;
begin
  perform private.exiger_admin();
  if p_jours is null or p_jours not between 1 and 365 then
    raise exception 'Période invalide : de 1 à 365 jours.' using errcode = '22023';
  end if;

  with periode as (
    select c.*, (c.created_at at time zone 'Africa/Tunis')::date as jour
    from public.commandes c
    where (c.created_at at time zone 'Africa/Tunis')::date >= v_debut
  ),
  livrees as (select * from periode where etat = 'livree'),
  jours as (
    select d::date as jour from generate_series(v_debut, (now() at time zone 'Africa/Tunis')::date, interval '1 day') d
  ),
  par_jour as (
    select j.jour,
           count(p.id)::int as commandes,
           coalesce(sum(p.total) filter (where p.etat = 'livree'), 0) as chiffre_affaires
    from jours j left join periode p on p.jour = j.jour
    group by j.jour order by j.jour
  ),
  restos as (
    select r.nom, count(*)::int as commandes, sum(c.sous_total) as ventes
    from livrees c join public.restaurants r on r.id = c.restaurant_id
    group by r.nom
    order by ventes desc, commandes desc, r.nom
    limit 5
  ),
  inscrits as (
    select role, count(*)::int as nb from public.profiles
    where (created_at at time zone 'Africa/Tunis')::date >= v_debut
    group by role
  )
  select jsonb_build_object(
    'jours', p_jours,
    'commandes', (select count(*) from periode),
    'livrees', (select count(*) from livrees),
    'refusees', (select count(*) from periode where etat = 'refusee'),
    'annulees', (select count(*) from periode where etat = 'annulee'),
    'chiffre_affaires', (select coalesce(sum(total), 0) from livrees),
    'ventes_restaurants', (select coalesce(sum(sous_total), 0) from livrees),
    'frais_livraison', (select coalesce(sum(frais_livraison), 0) from livrees),
    'commission_pct', v_pct,
    'commissions', (select coalesce(round(sum(sous_total) * v_pct / 100, 3), 0) from livrees),
    'gains_livreurs', (select coalesce(sum(l.gain_livreur), 0) from public.livraisons l join livrees c on c.id = l.commande_id),
    'panier_moyen', (select coalesce(round(avg(total), 3), 0) from livrees),
    'par_jour', (select coalesce(jsonb_agg(jsonb_build_object('jour', jour, 'commandes', commandes, 'chiffre_affaires', chiffre_affaires)), '[]') from par_jour),
    'top_restaurants', (select coalesce(jsonb_agg(jsonb_build_object('nom', nom, 'commandes', commandes, 'ventes', ventes)), '[]') from restos),
    'nouveaux_clients', coalesce((select nb from inscrits where role = 'client'), 0),
    'nouveaux_livreurs', coalesce((select nb from inscrits where role = 'livreur'), 0),
    'nouveaux_restaurants', coalesce((select nb from inscrits where role = 'responsable'), 0),
    'note_moyenne', (select round(avg(note)::numeric, 2) from public.avis where restaurant_id is not null),
    'reclamations_ouvertes', (select count(*) from public.reclamations where etat in ('ouverte', 'en_cours'))
  ) into v_resultat;
  return v_resultat;
end;
$$;
revoke execute on function public.statistiques_plateforme(integer) from public, anon;
grant execute on function public.statistiques_plateforme(integer) to authenticated, service_role;

-- ---------------------------------------------------------------------
-- US49 — réclamations
-- ---------------------------------------------------------------------
alter table public.reclamations
  add constraint reclamations_motif_longueur check (char_length(btrim(motif)) between 2 and 80),
  add constraint reclamations_description_longueur check (description is null or char_length(description) <= 1000),
  add constraint reclamations_reponse_longueur check (reponse is null or char_length(reponse) <= 1000);

-- Une seule réclamation en cours de traitement par commande.
create unique index reclamations_une_ouverte on public.reclamations (commande_id)
  where etat in ('ouverte', 'en_cours');
create index if not exists reclamations_etat_idx on public.reclamations (etat, created_at desc);

-- Le client ne signale qu'une commande livrée, dans les 7 jours, et ne
-- remplit que le motif et la description (le reste est pour l'admin).
create function private.controler_reclamation()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_commande public.commandes;
begin
  if not private.requete_application() or private.est_admin() then
    return new;
  end if;
  -- (lecture soumise aux règles d'accès : seulement ses propres commandes)
  select * into v_commande from public.commandes where id = new.commande_id and client_id = (select auth.uid());
  if not found then
    raise exception 'Commande introuvable.' using errcode = '42501';
  end if;
  if v_commande.etat <> 'livree' then
    raise exception 'Vous pouvez signaler un problème une fois la commande livrée.' using errcode = 'P0001';
  end if;
  if v_commande.livree_le < now() - interval '7 days' then
    raise exception 'Le délai de 7 jours après la livraison est dépassé : contactez Mida.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.reclamations
             where commande_id = new.commande_id and etat in ('ouverte', 'en_cours')) then
    raise exception 'Une réclamation est déjà en cours pour cette commande.' using errcode = 'P0001';
  end if;
  new.motif := btrim(new.motif);
  new.description := nullif(btrim(coalesce(new.description, '')), '');
  new.etat := 'ouverte';
  new.reponse := null;
  new.montant_rembourse := null;
  new.traitee_par := null;
  new.traitee_le := null;
  return new;
end;
$$;
create trigger controler_reclamation before insert on public.reclamations
  for each row execute function private.controler_reclamation();

-- Traitement par l'administrateur : résolue (avec remboursement éventuel,
-- au plus le total de la commande) ou rejetée ; réponse obligatoire ; le
-- client est prévenu.
create function public.traiter_reclamation(
  p_reclamation uuid,
  p_resolue     boolean,
  p_reponse     text,
  p_montant     numeric default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v public.reclamations;
  v_commande public.commandes;
  v_reponse text := nullif(btrim(coalesce(p_reponse, '')), '');
  v_montant numeric := case when p_resolue then nullif(coalesce(p_montant, 0), 0) end;
begin
  perform private.exiger_admin();
  select * into v from public.reclamations where id = p_reclamation for update;
  if not found then
    raise exception 'Réclamation introuvable' using errcode = 'P0001';
  end if;
  if v.etat not in ('ouverte', 'en_cours') then
    raise exception 'Cette réclamation a déjà été traitée' using errcode = 'P0001';
  end if;
  if v_reponse is null then
    raise exception 'Écrivez une réponse : elle est envoyée au client' using errcode = 'P0001';
  end if;
  if char_length(v_reponse) > 1000 then
    raise exception 'La réponse fait 1000 caractères au plus' using errcode = 'P0001';
  end if;
  select * into v_commande from public.commandes where id = v.commande_id;
  if v_montant is not null and (v_montant < 0 or v_montant > v_commande.total) then
    raise exception 'Le remboursement va de 0 au total de la commande (%)', private.montant_dt(v_commande.total)
      using errcode = 'P0001';
  end if;

  update public.reclamations
     set etat = case when p_resolue then 'resolue' else 'rejetee' end::public.etat_reclamation,
         reponse = v_reponse,
         montant_rembourse = v_montant,
         traitee_par = (select auth.uid()),
         traitee_le = now()
   where id = v.id;

  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v.client_id,
          case when p_resolue then 'Réclamation résolue' else 'Réclamation examinée' end,
          format('Commande n° %s : %s%s', v_commande.numero, v_reponse,
                 case when v_montant is not null
                      then format(' Mida vous rembourse %s.', private.montant_dt(v_montant)) else '' end),
          'reclamation', v.commande_id);
end;
$$;
revoke execute on function public.traiter_reclamation(uuid, boolean, text, numeric) from public, anon;
grant execute on function public.traiter_reclamation(uuid, boolean, text, numeric) to authenticated, service_role;
