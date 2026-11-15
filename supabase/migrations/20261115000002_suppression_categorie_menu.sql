-- =====================================================================
-- Mida — US09 : catégories du menu
-- =====================================================================
-- Créer, renommer et ordonner une catégorie se fait directement sur la
-- table `categories_menu` (règles d'accès de la migration US02).
--
-- Supprimer une catégorie qui contient des plats est impossible en une
-- seule requête (clé étrangère « on delete restrict », pour éviter une
-- suppression par accident). L'espace restaurant demande donc une
-- confirmation, puis appelle cette fonction, qui supprime les plats et
-- la catégorie dans la même transaction : tout, ou rien.
-- =====================================================================

create function public.supprimer_categorie_menu(p_categorie uuid)
returns integer                      -- nombre de plats supprimés avec la catégorie
language plpgsql
security invoker                     -- les règles d'accès de l'appelant s'appliquent
set search_path = ''
as $$
declare
  v_plats integer;
begin
  if not exists (
    select 1 from public.categories_menu c
    where c.id = p_categorie
      and (private.est_responsable_de(c.restaurant_id) or private.est_admin())
  ) then
    raise exception 'Catégorie introuvable, ou vous n''avez pas le droit de la supprimer'
      using errcode = '42501';
  end if;

  -- Les lignes des commandes déjà passées gardent le nom et le prix du plat
  -- (lignes_commande.plat_id passe à null).
  delete from public.plats where categorie_id = p_categorie;
  get diagnostics v_plats = row_count;
  delete from public.categories_menu where id = p_categorie;
  return v_plats;
end;
$$;

revoke execute on function public.supprimer_categorie_menu(uuid) from public, anon;
grant execute on function public.supprimer_categorie_menu(uuid) to authenticated, service_role;
