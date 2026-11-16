-- =====================================================================
-- Mida — US11 : rendre un plat momentanément indisponible
-- =====================================================================
-- • Le responsable coche ou décoche `plats.disponible` depuis son menu
--   (droit déjà donné par la règle « plat : modification » d'US02).
-- • Les clients voient toujours le plat (grisé, « Indisponible »), mais
--   il ne peut pas être commandé, quelle que soit la façon dont la
--   commande est créée (future fonction « passer commande », etc.).
-- =====================================================================

-- Une ligne naît avec sa commande, à l'état « en_attente » : c'est à ce
-- moment que le plat doit être disponible. L'historique n'est pas
-- concerné (un plat déjà commandé peut devenir indisponible ensuite).
-- « security definer » : la vérification ne dépend pas des droits de
-- lecture de celui qui crée la commande.
create function private.verifier_plat_disponible()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nom text;
begin
  select p.nom into v_nom
  from public.plats p
  join public.commandes c on c.id = new.commande_id
  where p.id = new.plat_id
    and not p.disponible
    and c.etat = 'en_attente';

  if found then
    raise exception 'Le plat « % » est indisponible pour le moment : il ne peut pas être commandé', v_nom
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger plat_disponible before insert on public.lignes_commande
  for each row when (new.plat_id is not null)
  execute function private.verifier_plat_disponible();
