-- =====================================================================
-- Mida — US02 : rôles et règles de sécurité
-- • 4 rôles : client, livreur, responsable (de restaurant), admin
-- • RLS sur toutes les tables : chacun ne voit que ce qui le concerne
-- • Les opérations sensibles (créer une commande, changer son état,
--   payer, attribuer une course) passeront par des fonctions serveur
--   (stories suivantes) : aucune application ne peut écrire directement
--   dans commandes / lignes_commande / paiements / livraisons.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Création automatique du profil à l'inscription
-- ---------------------------------------------------------------------
-- Le rôle vient des métadonnées d'inscription (signUp(..., data: {role, nom, telephone})).
-- Seuls client / livreur / responsable sont acceptés : un compte admin ne
-- peut jamais être créé depuis une application.
-- Client : actif tout de suite. Livreur et responsable : en attente de
-- validation par l'administrateur (cahier des charges §3).
create function public.creer_profil_nouvel_utilisateur()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role public.role_utilisateur;
begin
  v_role := case new.raw_user_meta_data ->> 'role'
              when 'livreur'     then 'livreur'::public.role_utilisateur
              when 'responsable' then 'responsable'::public.role_utilisateur
              else 'client'::public.role_utilisateur
            end;

  insert into public.profiles (id, nom, email, telephone, role, etat_compte)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nom'), ''), split_part(new.email, '@', 1)),
    new.email,
    new.raw_user_meta_data ->> 'telephone',
    v_role,
    case when v_role = 'client' then 'actif'::public.etat_compte else 'en_attente'::public.etat_compte end
  );

  if v_role = 'livreur' then
    insert into public.livreurs (id) values (new.id);
  end if;

  return new;
end;
$$;

create trigger creer_profil_apres_inscription
  after insert on auth.users
  for each row execute function public.creer_profil_nouvel_utilisateur();

-- ---------------------------------------------------------------------
-- 2. Fonctions d'aide utilisées par les règles
-- ---------------------------------------------------------------------
-- Placées dans un schéma « private » non exposé par l'API REST.
-- « security definer » : elles lisent les tables sans repasser par la RLS,
-- ce qui évite les boucles (une règle sur profiles qui lit profiles).
create schema if not exists private;
grant usage on schema private to anon, authenticated, service_role;

create function private.role_actuel()
returns public.role_utilisateur
language sql stable security definer set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

create function private.est_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin' and etat_compte = 'actif'
  );
$$;

-- L'utilisateur connecté est-il le responsable de ce restaurant ?
create function private.est_responsable_de(p_restaurant uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.restaurants r
    join public.profiles p on p.id = r.responsable_id
    where r.id = p_restaurant
      and r.responsable_id = (select auth.uid())
      and p.etat_compte <> 'bloque'
  );
$$;

-- Restaurant visible publiquement (validé par l'administrateur)
create function private.restaurant_public(p_restaurant uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.restaurants where id = p_restaurant and etat = 'actif');
$$;

-- Livreur validé (compte actif) ?
create function private.est_livreur_actif()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'livreur' and etat_compte = 'actif'
  );
$$;

-- L'utilisateur connecté peut-il voir cette commande ?
--  • le client qui l'a passée
--  • le responsable du restaurant concerné
--  • le livreur à qui la course est attribuée
--  • tout livreur actif tant que la course est proposée et sans livreur (L3)
--  • l'administrateur
create function private.peut_voir_commande(p_commande uuid)
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
            or (l.livreur_id is null and l.etat = 'proposee' and private.est_livreur_actif())
          )
      );
$$;

-- Peut-on voir le profil d'un autre utilisateur ? Seulement s'il existe une
-- commande qui vous relie (nom et téléphone du client pour le restaurant et
-- le livreur, nom du livreur et du responsable pour le client).
create function private.peut_voir_profil(p_profil uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.commandes c
    join public.restaurants r on r.id = c.restaurant_id
    left join public.livraisons l on l.commande_id = c.id
    where
      -- je suis le restaurant ou le livreur de la commande, et p_profil en est le client
      (c.client_id = p_profil and (r.responsable_id = (select auth.uid()) or l.livreur_id = (select auth.uid())))
      -- je suis le client, et p_profil est le livreur ou le responsable du restaurant
      or (c.client_id = (select auth.uid()) and (l.livreur_id = p_profil or r.responsable_id = p_profil))
      -- je suis le restaurant, et p_profil est le livreur de ma commande
      or (r.responsable_id = (select auth.uid()) and l.livreur_id = p_profil)
  );
$$;


-- ---------------------------------------------------------------------
-- 3. Champs que seul l'administrateur peut modifier
-- ---------------------------------------------------------------------
-- Les règles RLS filtrent les LIGNES ; ces déclencheurs protègent des
-- COLONNES (un client ne doit pas pouvoir se donner le rôle admin, un
-- restaurant ne doit pas pouvoir se valider lui-même).
-- Ils ne s'appliquent qu'aux requêtes venant des applications
-- (rôles anon / authenticated), pas aux fonctions serveur ni au tableau
-- de bord Supabase.
create function private.requete_application()
returns boolean
language sql stable
set search_path = ''
as $$
  select current_user in ('anon', 'authenticated');
$$;

create function private.proteger_profil()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if private.requete_application() and not private.est_admin() then
    if new.role is distinct from old.role
       or new.etat_compte is distinct from old.etat_compte
       or new.email is distinct from old.email
       or new.id is distinct from old.id then
      raise exception 'Seul un administrateur peut modifier le rôle, l''état ou l''e-mail d''un compte'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
create trigger proteger_profil before update on public.profiles
  for each row execute function private.proteger_profil();

create function private.proteger_restaurant()
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
    end if;
  end if;
  return new;
end;
$$;
create trigger proteger_restaurant before insert or update on public.restaurants
  for each row execute function private.proteger_restaurant();

create function private.proteger_document_livreur()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if private.requete_application() and not private.est_admin() then
    if tg_op = 'INSERT' then
      new.etat := 'en_attente';
    elsif new.etat is distinct from old.etat then
      raise exception 'Seul un administrateur peut valider un document' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
create trigger proteger_document_livreur before insert or update on public.documents_livreur
  for each row execute function private.proteger_document_livreur();

-- Un utilisateur ne peut changer que l'état « lue » de ses notifications
create function private.proteger_notification()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if private.requete_application() and not private.est_admin() then
    if (to_jsonb(new) - 'lue') is distinct from (to_jsonb(old) - 'lue') then
      raise exception 'Seul le champ « lue » d''une notification peut être modifié' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
create trigger proteger_notification before update on public.notifications
  for each row execute function private.proteger_notification();

-- ---------------------------------------------------------------------
-- 4. Activation de la RLS sur toutes les tables
-- ---------------------------------------------------------------------
alter table public.profiles              enable row level security;
alter table public.livreurs              enable row level security;
alter table public.documents_livreur     enable row level security;
alter table public.adresses              enable row level security;
alter table public.categories_restaurant enable row level security;
alter table public.restaurants           enable row level security;
alter table public.horaires              enable row level security;
alter table public.categories_menu       enable row level security;
alter table public.plats                 enable row level security;
alter table public.parametres            enable row level security;
alter table public.commandes             enable row level security;
alter table public.lignes_commande       enable row level security;
alter table public.paiements             enable row level security;
alter table public.livraisons            enable row level security;
alter table public.avis                  enable row level security;
alter table public.reclamations          enable row level security;
alter table public.notifications         enable row level security;
alter table public.device_tokens         enable row level security;

-- ---------------------------------------------------------------------
-- 5. Règles d'accès
-- ---------------------------------------------------------------------
-- Profils -------------------------------------------------------------
create policy "profil : lecture" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.est_admin() or private.peut_voir_profil(id));
create policy "profil : modification de son propre profil" on public.profiles for update to authenticated
  using (id = (select auth.uid()) or private.est_admin())
  with check (id = (select auth.uid()) or private.est_admin());
create policy "profil : suppression par l'admin" on public.profiles for delete to authenticated
  using (private.est_admin());

-- Livreurs ------------------------------------------------------------
create policy "livreur : lecture" on public.livreurs for select to authenticated
  using (id = (select auth.uid()) or private.est_admin() or private.peut_voir_profil(id));
create policy "livreur : modification de sa fiche" on public.livreurs for update to authenticated
  using (id = (select auth.uid()) or private.est_admin())
  with check (id = (select auth.uid()) or private.est_admin());

create policy "document : lecture" on public.documents_livreur for select to authenticated
  using (livreur_id = (select auth.uid()) or private.est_admin());
create policy "document : envoi par le livreur" on public.documents_livreur for insert to authenticated
  with check (livreur_id = (select auth.uid()));
create policy "document : validation par l'admin" on public.documents_livreur for update to authenticated
  using (private.est_admin()) with check (private.est_admin());
create policy "document : suppression avant validation" on public.documents_livreur for delete to authenticated
  using ((livreur_id = (select auth.uid()) and etat = 'en_attente') or private.est_admin());

-- Adresses : uniquement le client propriétaire -------------------------
create policy "adresse : lecture" on public.adresses for select to authenticated
  using (client_id = (select auth.uid()) or private.est_admin());
create policy "adresse : ajout" on public.adresses for insert to authenticated
  with check (client_id = (select auth.uid()));
create policy "adresse : modification" on public.adresses for update to authenticated
  using (client_id = (select auth.uid())) with check (client_id = (select auth.uid()));
create policy "adresse : suppression" on public.adresses for delete to authenticated
  using (client_id = (select auth.uid()));

-- Catégories de restaurants : publiques, gérées par l'admin ------------
create policy "categorie restaurant : lecture publique" on public.categories_restaurant for select to anon, authenticated
  using (true);
create policy "categorie restaurant : gestion admin" on public.categories_restaurant for all to authenticated
  using (private.est_admin()) with check (private.est_admin());

-- Restaurants ---------------------------------------------------------
-- Visiteurs et clients : seulement les restaurants validés (mode visiteur inclus)
create policy "restaurant : lecture" on public.restaurants for select to anon, authenticated
  using (etat = 'actif' or responsable_id = (select auth.uid()) or private.est_admin());
create policy "restaurant : inscription par son responsable" on public.restaurants for insert to authenticated
  with check (responsable_id = (select auth.uid()) and private.role_actuel() = 'responsable');
create policy "restaurant : modification par son responsable" on public.restaurants for update to authenticated
  using (private.est_responsable_de(id) or private.est_admin())
  with check (private.est_responsable_de(id) or private.est_admin());
create policy "restaurant : suppression par l'admin" on public.restaurants for delete to authenticated
  using (private.est_admin());

-- Horaires, catégories du menu et plats : même logique ----------------
-- lecture : tout le monde si le restaurant est validé ; son responsable ; l'admin
-- écriture : uniquement le responsable du restaurant (ou l'admin)
create policy "horaire : lecture" on public.horaires for select to anon, authenticated
  using (private.restaurant_public(restaurant_id) or private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "horaire : ajout" on public.horaires for insert to authenticated
  with check (private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "horaire : modification" on public.horaires for update to authenticated
  using (private.est_responsable_de(restaurant_id) or private.est_admin())
  with check (private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "horaire : suppression" on public.horaires for delete to authenticated
  using (private.est_responsable_de(restaurant_id) or private.est_admin());

create policy "categorie menu : lecture" on public.categories_menu for select to anon, authenticated
  using (private.restaurant_public(restaurant_id) or private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "categorie menu : ajout" on public.categories_menu for insert to authenticated
  with check (private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "categorie menu : modification" on public.categories_menu for update to authenticated
  using (private.est_responsable_de(restaurant_id) or private.est_admin())
  with check (private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "categorie menu : suppression" on public.categories_menu for delete to authenticated
  using (private.est_responsable_de(restaurant_id) or private.est_admin());

create policy "plat : lecture" on public.plats for select to anon, authenticated
  using (private.restaurant_public(restaurant_id) or private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "plat : ajout" on public.plats for insert to authenticated
  with check (private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "plat : modification" on public.plats for update to authenticated
  using (private.est_responsable_de(restaurant_id) or private.est_admin())
  with check (private.est_responsable_de(restaurant_id) or private.est_admin());
create policy "plat : suppression" on public.plats for delete to authenticated
  using (private.est_responsable_de(restaurant_id) or private.est_admin());

-- Paramètres : lisibles par tous (frais affichés au client), modifiables par l'admin
create policy "parametres : lecture" on public.parametres for select to anon, authenticated
  using (true);
create policy "parametres : modification admin" on public.parametres for update to authenticated
  using (private.est_admin()) with check (private.est_admin());

-- Commandes et données liées : lecture seule pour les applications ----
-- (création et changements d'état via les fonctions serveur à venir)
create policy "commande : lecture" on public.commandes for select to authenticated
  using (private.peut_voir_commande(id));
create policy "commande : gestion admin" on public.commandes for update to authenticated
  using (private.est_admin()) with check (private.est_admin());

create policy "ligne : lecture" on public.lignes_commande for select to authenticated
  using (private.peut_voir_commande(commande_id));

create policy "paiement : lecture" on public.paiements for select to authenticated
  using (private.peut_voir_commande(commande_id));

create policy "livraison : lecture" on public.livraisons for select to authenticated
  using (private.peut_voir_commande(commande_id));

-- Avis : publics ; un client note seulement une commande livrée qui est la sienne
create policy "avis : lecture publique" on public.avis for select to anon, authenticated
  using (true);
create policy "avis : ajout par le client" on public.avis for insert to authenticated
  with check (
    client_id = (select auth.uid())
    and exists (
      select 1 from public.commandes c
      left join public.livraisons l on l.commande_id = c.id
      where c.id = avis.commande_id
        and c.client_id = (select auth.uid())
        and c.etat = 'livree'
        and (avis.restaurant_id = c.restaurant_id or avis.livreur_id = l.livreur_id)
    )
  );
create policy "avis : suppression" on public.avis for delete to authenticated
  using (client_id = (select auth.uid()) or private.est_admin());

-- Réclamations : le client sur ses commandes ; traitement par l'admin --
create policy "reclamation : lecture" on public.reclamations for select to authenticated
  using (client_id = (select auth.uid()) or private.est_admin());
create policy "reclamation : ajout par le client" on public.reclamations for insert to authenticated
  with check (
    client_id = (select auth.uid())
    and exists (select 1 from public.commandes c where c.id = reclamations.commande_id and c.client_id = (select auth.uid()))
  );
create policy "reclamation : traitement admin" on public.reclamations for update to authenticated
  using (private.est_admin()) with check (private.est_admin());

-- Notifications : chacun les siennes (créées par le serveur) -----------
create policy "notification : lecture" on public.notifications for select to authenticated
  using (destinataire_id = (select auth.uid()));
create policy "notification : marquer comme lue" on public.notifications for update to authenticated
  using (destinataire_id = (select auth.uid())) with check (destinataire_id = (select auth.uid()));
create policy "notification : suppression" on public.notifications for delete to authenticated
  using (destinataire_id = (select auth.uid()));

-- Jetons d'appareil : chacun les siens --------------------------------
create policy "jeton : lecture" on public.device_tokens for select to authenticated
  using (user_id = (select auth.uid()));
create policy "jeton : ajout" on public.device_tokens for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "jeton : suppression" on public.device_tokens for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 6. Le rôle dans le jeton de connexion (§5.1)
-- ---------------------------------------------------------------------
-- Ajoute « user_role » et « etat_compte » au JWT remis à la connexion,
-- pour que les applications sachent quel espace afficher sans requête
-- supplémentaire. À activer dans le tableau de bord Supabase :
-- Authentication → Hooks → Custom Access Token → public.custom_access_token_hook
-- (la sécurité, elle, ne dépend pas de ce jeton : les règles relisent profiles).
create function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_claims jsonb := coalesce(event -> 'claims', '{}'::jsonb);
  v_role   text;
  v_etat   text;
begin
  select role::text, etat_compte::text into v_role, v_etat
  from public.profiles where id = (event ->> 'user_id')::uuid;

  v_claims := jsonb_set(v_claims, '{user_role}', coalesce(to_jsonb(v_role), 'null'::jsonb));
  v_claims := jsonb_set(v_claims, '{etat_compte}', coalesce(to_jsonb(v_etat), 'null'::jsonb));
  return jsonb_set(event, '{claims}', v_claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook from authenticated, anon, public;
grant select on table public.profiles to supabase_auth_admin;
create policy "profil : lecture par le service d'authentification" on public.profiles
  as permissive for select to supabase_auth_admin using (true);

-- Les fonctions de déclenchement ne doivent pas être appelables par l'API
revoke execute on function public.creer_profil_nouvel_utilisateur() from anon, authenticated, public;
revoke execute on function public.maj_updated_at() from anon, authenticated, public;

-- Les fonctions d'aide et de protection sont appelées par les règles et les
-- déclencheurs : les applications et les fonctions serveur doivent pouvoir
-- les exécuter (placé en fin de fichier, après leur création).
grant execute on all functions in schema private to anon, authenticated, service_role;
