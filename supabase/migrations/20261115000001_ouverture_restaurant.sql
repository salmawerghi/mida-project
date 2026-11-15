-- =====================================================================
-- Mida — US08 : ouvrir ou fermer son restaurant en un clic
-- =====================================================================
-- • Le responsable change lui-même `restaurants.ouvert` (interrupteur de
--   l'espace restaurant) ; les clients lisent cette colonne.
-- • Seul un restaurant validé peut être ouvert.
-- • Un restaurant fermé (ou non validé) n'accepte plus de nouvelle
--   commande, quelle que soit la façon dont la commande est créée.
-- =====================================================================

-- 1. Un restaurant ouvert est forcément un restaurant validé -------------
alter table public.restaurants
  add constraint restaurant_ouvert_si_valide check (not ouvert or etat = 'actif');

-- 2. Protection des colonnes du restaurant (remplace la version US02) ----
create or replace function private.proteger_restaurant()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if private.requete_application() and not private.est_admin() then
    if tg_op = 'INSERT' then
      -- un nouveau restaurant attend toujours la validation (US05)
      new.etat := 'en_attente';
      new.motif_rejet := null;
    elsif new.etat is distinct from old.etat
       or new.motif_rejet is distinct from old.motif_rejet
       or new.responsable_id is distinct from old.responsable_id then
      raise exception 'Seul un administrateur peut valider, bloquer ou transférer un restaurant'
        using errcode = '42501';
    elsif new.ouvert and not old.ouvert and new.etat <> 'actif' then
      raise exception 'Un restaurant doit être validé par Mida avant de pouvoir ouvrir'
        using errcode = '42501';
    end if;
  end if;
  -- Un restaurant qui n'est pas (ou plus) validé est toujours fermé :
  -- le bloquer ou le refuser le ferme automatiquement.
  if new.etat <> 'actif' then
    new.ouvert := false;
  end if;
  return new;
end;
$$;

-- 3. Pas de nouvelle commande pour un restaurant fermé -------------------
-- Une commande naît toujours « en_attente » : c'est à ce moment que le
-- restaurant doit être validé et ouvert. (Les commandes déjà passées ne
-- sont pas concernées : le restaurant peut fermer ensuite.)
-- « security definer » : la vérification ne dépend pas des droits de
-- lecture de celui qui crée la commande.
create function private.verifier_restaurant_ouvert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.restaurants r
    where r.id = new.restaurant_id and r.etat = 'actif' and r.ouvert
  ) then
    raise exception 'Ce restaurant est fermé : il n''accepte pas de commande pour le moment'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger restaurant_ouvert before insert on public.commandes
  for each row when (new.etat = 'en_attente')
  execute function private.verifier_restaurant_ouvert();
