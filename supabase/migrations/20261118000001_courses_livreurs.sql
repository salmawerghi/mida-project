-- =====================================================================
-- Mida — US26 à US28 : disponibilité des livreurs et courses
-- =====================================================================
-- Cycle d'une course (table `livraisons`) :
--
--   commande acceptée par le restaurant
--        → course « proposee » (sans livreur), visible des livreurs
--          validés ET disponibles (US26, US27)
--   accepter_course    → « acceptee » : un seul livreur (verrou de la ligne)
--   recuperer_course   → « recuperee », commande « en_livraison »
--                        (seulement si la commande est « prete », US28)
--   livrer_course      → « livree », commande « livree » ; un paiement en
--                        espèces passe à « paye » (encaissé à la remise)
--
-- Le client est prévenu à chaque étape (table `notifications`). Les
-- applications ne modifient ni les commandes ni les livraisons directement
-- (US02) : tout passe par ces fonctions.
-- =====================================================================

-- ---------------------------------------------------------------------
-- US26 — disponible / indisponible
-- ---------------------------------------------------------------------
-- Livreur validé ET disponible : lui seul voit les courses proposées.
create function private.est_livreur_disponible()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.est_livreur_actif()
     and exists (select 1 from public.livreurs where id = (select auth.uid()) and disponible);
$$;
grant execute on function private.est_livreur_disponible() to authenticated, service_role;

-- Un livreur pas encore validé (ou bloqué) ne peut pas se mettre disponible.
-- Bloquer un compte le rend indisponible (voir proteger_profil plus bas).
create function private.proteger_livreur()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if private.requete_application() and not private.est_admin()
     and new.disponible and not old.disponible and not private.est_livreur_actif() then
    raise exception 'Votre compte doit être validé par Mida avant de recevoir des courses'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger proteger_livreur before update on public.livreurs
  for each row execute function private.proteger_livreur();

create function private.livreur_bloque_indisponible()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.etat_compte <> 'actif' and old.etat_compte = 'actif' then
    update public.livreurs set disponible = false where id = new.id;
  end if;
  return new;
end;
$$;
create trigger livreur_bloque_indisponible after update of etat_compte on public.profiles
  for each row when (new.role = 'livreur') execute function private.livreur_bloque_indisponible();

-- Les courses proposées ne sont visibles que des livreurs disponibles
-- (avant : tout livreur actif). Le reste de la règle ne change pas.
create or replace function private.peut_voir_commande(p_commande uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.est_admin()
      or exists (
        select 1 from public.commandes c
        where c.id = p_commande
          and (c.client_id = (select auth.uid()) or private.est_responsable_de(c.restaurant_id))
      )
      or exists (
        select 1 from public.livraisons l
        where l.commande_id = p_commande
          and (
            l.livreur_id = (select auth.uid())
            or (l.livreur_id is null and l.etat = 'proposee' and private.est_livreur_disponible())
          )
      );
$$;

-- ---------------------------------------------------------------------
-- US27 — la course est proposée dès que le restaurant accepte la commande
-- ---------------------------------------------------------------------
create function private.proposer_course()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.livraisons (commande_id, gain_livreur)
  select new.id, p.gain_livreur from public.parametres p where p.id = 1
  on conflict (commande_id) do nothing;
  return new;
end;
$$;
create trigger proposer_course after update of etat on public.commandes
  for each row when (old.etat = 'en_attente' and new.etat = 'acceptee')
  execute function private.proposer_course();

-- Commandes déjà acceptées avant cette migration : leur course est proposée.
insert into public.livraisons (commande_id, gain_livreur)
select c.id, (select gain_livreur from public.parametres where id = 1)
from public.commandes c
where c.etat in ('acceptee', 'en_preparation', 'prete')
  and not exists (select 1 from public.livraisons l where l.commande_id = c.id);

-- Les livreurs voient arriver les courses en temps réel.
alter publication supabase_realtime add table public.livraisons;

-- Course du livreur connecté, verrouillée jusqu'à la fin de la transaction.
create function private.course_du_livreur(p_livraison uuid)
returns public.livraisons
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.livraisons;
begin
  select * into v from public.livraisons where id = p_livraison for update;
  if not found or v.livreur_id is distinct from (select auth.uid()) then
    raise exception 'Course introuvable, ou elle ne vous est pas attribuée' using errcode = '42501';
  end if;
  return v;
end;
$$;

create function public.accepter_course(p_livraison uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.livraisons;
  v_commande public.commandes;
  v_nom text;
begin
  if not private.est_livreur_actif() then
    raise exception 'Votre compte doit être validé par Mida avant de recevoir des courses' using errcode = '42501';
  end if;
  if not private.est_livreur_disponible() then
    raise exception 'Mettez-vous disponible pour accepter une course' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.livraisons
             where livreur_id = (select auth.uid()) and etat in ('acceptee', 'recuperee')) then
    raise exception 'Terminez d''abord votre course en cours' using errcode = 'P0001';
  end if;

  -- Verrou : si deux livreurs acceptent en même temps, le second attend,
  -- puis voit que la course a déjà un livreur.
  select * into v from public.livraisons where id = p_livraison for update;
  if not found then
    raise exception 'Course introuvable' using errcode = 'P0001';
  end if;
  if v.livreur_id is not null or v.etat <> 'proposee' then
    raise exception 'Cette course a déjà été acceptée par un autre livreur' using errcode = 'P0001';
  end if;
  select * into v_commande from public.commandes where id = v.commande_id;
  if v_commande.etat not in ('acceptee', 'en_preparation', 'prete') then
    raise exception 'Cette course n''est plus disponible' using errcode = 'P0001';
  end if;

  update public.livraisons
     set livreur_id = (select auth.uid()), etat = 'acceptee', acceptee_le = now()
   where id = v.id;

  select nom into v_nom from public.profiles where id = (select auth.uid());
  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v_commande.client_id, 'Livreur en route',
          format('%s livrera votre commande n° %s.', v_nom, v_commande.numero), 'commande', v_commande.id);
end;
$$;

-- ---------------------------------------------------------------------
-- US28 — récupération au restaurant, puis remise au client
-- ---------------------------------------------------------------------
create function public.recuperer_course(p_livraison uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.livraisons;
  v_commande public.commandes;
begin
  v := private.course_du_livreur(p_livraison);
  if v.etat <> 'acceptee' then
    raise exception 'Cette course a déjà été récupérée' using errcode = 'P0001', hint = v.etat::text;
  end if;
  select * into v_commande from public.commandes where id = v.commande_id for update;
  if v_commande.etat <> 'prete' then
    raise exception 'La commande n° % n''est pas encore prête : attendez que le restaurant la marque « prête »',
      v_commande.numero using errcode = 'P0001', hint = v_commande.etat::text;
  end if;

  update public.livraisons set etat = 'recuperee', recuperee_le = now() where id = v.id;
  update public.commandes set etat = 'en_livraison' where id = v_commande.id;

  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v_commande.client_id, 'Commande en route',
          format('Votre commande n° %s a quitté le restaurant : elle arrive bientôt.', v_commande.numero),
          'commande', v_commande.id);
end;
$$;

create function public.livrer_course(p_livraison uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.livraisons;
  v_commande public.commandes;
begin
  v := private.course_du_livreur(p_livraison);
  if v.etat <> 'recuperee' then
    raise exception 'Confirmez d''abord la récupération de la commande au restaurant'
      using errcode = 'P0001', hint = v.etat::text;
  end if;
  select * into v_commande from public.commandes where id = v.commande_id for update;

  update public.livraisons set etat = 'livree', livree_le = now() where id = v.id;
  update public.commandes set etat = 'livree', livree_le = now() where id = v_commande.id;
  -- espèces : le livreur a encaissé le montant à la remise
  update public.paiements set etat = 'paye', paye_le = now()
   where commande_id = v_commande.id and mode = 'especes' and etat = 'en_attente';

  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v_commande.client_id, 'Commande livrée',
          format('Votre commande n° %s a été livrée. Bon appétit !', v_commande.numero),
          'commande', v_commande.id);
end;
$$;

revoke execute on function public.accepter_course(uuid), public.recuperer_course(uuid), public.livrer_course(uuid)
  from public, anon;
grant execute on function public.accepter_course(uuid), public.recuperer_course(uuid), public.livrer_course(uuid)
  to authenticated, service_role;
revoke execute on function private.course_du_livreur(uuid), private.proposer_course(),
  private.livreur_bloque_indisponible() from public, anon, authenticated;
