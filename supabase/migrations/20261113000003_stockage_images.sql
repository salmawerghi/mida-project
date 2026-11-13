-- =====================================================================
-- Mida — US03 : stockage des images (Supabase Storage)
-- Trois espaces de stockage (« buckets ») :
--   • restaurants         public  : logos, couvertures et photos des plats
--   • avatars             public  : photos de profil
--   • documents-livreurs  privé   : pièces justificatives des livreurs
-- Chaque fichier est rangé dans un dossier qui porte l'identifiant de son
-- propriétaire ; les règles ci-dessous lisent ce dossier pour décider qui
-- peut envoyer, remplacer ou supprimer le fichier.
--
-- Chemins à utiliser dans les applications :
--   restaurants/<restaurant_id>/logo.webp
--   restaurants/<restaurant_id>/couverture.webp
--   restaurants/<restaurant_id>/plats/<plat_id>.webp
--   avatars/<user_id>/avatar.webp
--   documents-livreurs/<livreur_id>/<type>.<ext>   (type : cin, permis, carte_grise, photo)
--
-- Les buckets publics servent les images par une URL publique (affichage
-- sans compte, mode visiteur compris) : la lecture n'a donc pas besoin de
-- règle. Les documents des livreurs, eux, ne sont lisibles qu'avec une URL
-- signée demandée par le livreur lui-même ou par l'administrateur.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Les buckets (taille maximale et formats acceptés)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('restaurants',        'restaurants',        true,  5242880,  array['image/jpeg', 'image/png', 'image/webp']),
  ('avatars',            'avatars',            true,  2097152,  array['image/jpeg', 'image/png', 'image/webp']),
  ('documents-livreurs', 'documents-livreurs', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------
-- 2. Fonctions d'aide
-- ---------------------------------------------------------------------
-- Premier dossier du chemin converti en identifiant (null s'il n'en est pas un :
-- un chemin mal formé est simplement refusé, sans provoquer d'erreur).
create function private.dossier_proprietaire(p_nom text)
returns uuid
language sql immutable
set search_path = ''
as $$
  select case
    when split_part(p_nom, '/', 1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
         and position('/' in p_nom) > 0
    then split_part(p_nom, '/', 1)::uuid
  end;
$$;

-- Le fichier appartient-il au restaurant de l'utilisateur connecté ?
create function private.peut_gerer_fichier_restaurant(p_nom text)
returns boolean
language sql stable
set search_path = ''
as $$
  select private.est_admin()
      or coalesce(private.est_responsable_de(private.dossier_proprietaire(p_nom)), false);
$$;

-- Un document de livreur peut-il encore être envoyé, remplacé ou supprimé ?
-- Le chemin doit être exactement <livreur_id>/<type>.<ext> (pas de sous-dossier,
-- qui permettrait de contourner le contrôle), et le document ne doit pas
-- avoir été validé par l'administrateur.
create function private.document_livreur_modifiable(p_nom text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select cardinality(string_to_array(p_nom, '/')) = 2
     and not exists (
    select 1 from public.documents_livreur d
    where d.livreur_id = private.dossier_proprietaire(p_nom)
      and d.type = split_part(split_part(p_nom, '/', 2), '.', 1)
      and d.etat = 'valide'
  );
$$;

grant execute on function private.dossier_proprietaire(text),
                         private.peut_gerer_fichier_restaurant(text),
                         private.document_livreur_modifiable(text)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 3. Règles d'accès aux fichiers (storage.objects)
-- ---------------------------------------------------------------------
-- Remarque : remplacer un fichier (upsert) demande les droits de lecture,
-- d'ajout et de modification ; d'où une règle de lecture réservée au
-- propriétaire, même sur les buckets publics (elle sert aussi à lister
-- ses fichiers, sans permettre de lister ceux des autres).

-- Images des restaurants : le responsable du restaurant (ou l'admin)
create policy "images restaurant : lecture par le propriétaire" on storage.objects
  for select to authenticated
  using (bucket_id = 'restaurants' and private.peut_gerer_fichier_restaurant(name));
create policy "images restaurant : envoi" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'restaurants' and private.peut_gerer_fichier_restaurant(name));
create policy "images restaurant : remplacement" on storage.objects
  for update to authenticated
  using (bucket_id = 'restaurants' and private.peut_gerer_fichier_restaurant(name))
  with check (bucket_id = 'restaurants' and private.peut_gerer_fichier_restaurant(name));
create policy "images restaurant : suppression" on storage.objects
  for delete to authenticated
  using (bucket_id = 'restaurants' and private.peut_gerer_fichier_restaurant(name));

-- Avatars : chacun le sien (l'admin peut aussi retirer une photo)
create policy "avatar : lecture par le propriétaire" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (private.dossier_proprietaire(name) = (select auth.uid()) or private.est_admin()));
create policy "avatar : envoi" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and private.dossier_proprietaire(name) = (select auth.uid()));
create policy "avatar : remplacement" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and private.dossier_proprietaire(name) = (select auth.uid()))
  with check (bucket_id = 'avatars' and private.dossier_proprietaire(name) = (select auth.uid()));
create policy "avatar : suppression" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (private.dossier_proprietaire(name) = (select auth.uid()) or private.est_admin()));

-- Documents des livreurs : privés (le livreur et l'administrateur)
create policy "document livreur : lecture" on storage.objects
  for select to authenticated
  using (bucket_id = 'documents-livreurs'
         and (private.dossier_proprietaire(name) = (select auth.uid()) or private.est_admin()));
create policy "document livreur : envoi" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'documents-livreurs'
              and private.dossier_proprietaire(name) = (select auth.uid())
              and private.role_actuel() = 'livreur'
              and private.document_livreur_modifiable(name));
create policy "document livreur : remplacement avant validation" on storage.objects
  for update to authenticated
  using (bucket_id = 'documents-livreurs'
         and private.dossier_proprietaire(name) = (select auth.uid())
         and private.document_livreur_modifiable(name))
  with check (bucket_id = 'documents-livreurs'
              and private.dossier_proprietaire(name) = (select auth.uid())
              and private.document_livreur_modifiable(name));
create policy "document livreur : suppression" on storage.objects
  for delete to authenticated
  using (bucket_id = 'documents-livreurs'
         and ((private.dossier_proprietaire(name) = (select auth.uid()) and private.document_livreur_modifiable(name))
              or private.est_admin()));
