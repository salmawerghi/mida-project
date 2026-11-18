-- =====================================================================
-- Mida — US32 à US37 : tableau de bord d'administration
-- =====================================================================
-- L'administrateur a déjà tous les droits de lecture et d'écriture par les
-- règles d'accès d'US02 (private.est_admin()). Ces fonctions regroupent
-- chaque décision en une seule opération cohérente (restaurant + compte du
-- responsable, documents + compte du livreur…) et préviennent la personne
-- concernée. Elles sont « security invoker » : elles s'exécutent avec les
-- droits de l'appelant, donc les règles d'accès s'appliquent ; elles
-- vérifient en plus que l'appelant est administrateur.
-- =====================================================================

-- L'administrateur peut écrire une notification (décisions ci-dessous).
create policy "notification : envoi par l'admin" on public.notifications for insert to authenticated
  with check (private.est_admin());

create function private.exiger_admin()
returns void
language plpgsql stable
set search_path = ''
as $$
begin
  if not private.est_admin() then
    raise exception 'Action réservée aux administrateurs de Mida' using errcode = '42501';
  end if;
end;
$$;
grant execute on function private.exiger_admin() to authenticated, service_role;

-- ---------------------------------------------------------------------
-- US33 — valider ou rejeter un restaurant
-- ---------------------------------------------------------------------
create function public.admin_decider_restaurant(p_restaurant uuid, p_valider boolean, p_motif text default null)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v public.restaurants;
  v_motif text := nullif(trim(coalesce(p_motif, '')), '');
begin
  perform private.exiger_admin();
  select * into v from public.restaurants where id = p_restaurant for update;
  if not found then
    raise exception 'Restaurant introuvable' using errcode = 'P0001';
  end if;
  if v.etat <> 'en_attente' then
    raise exception 'La demande de « % » a déjà été traitée', v.nom using errcode = 'P0001', hint = v.etat::text;
  end if;
  if not p_valider and v_motif is null then
    raise exception 'Indiquez le motif du rejet : il est communiqué au responsable' using errcode = 'P0001';
  end if;

  update public.restaurants
     set etat = case when p_valider then 'actif' else 'rejete' end::public.etat_compte,
         motif_rejet = case when p_valider then null else v_motif end
   where id = v.id;
  update public.profiles
     set etat_compte = case when p_valider then 'actif' else 'rejete' end::public.etat_compte
   where id = v.responsable_id and etat_compte = 'en_attente';

  insert into public.notifications (destinataire_id, titre, message, type)
  values (v.responsable_id,
          case when p_valider then 'Restaurant validé' else 'Demande refusée' end,
          case when p_valider
            then format('« %s » est validé : ouvrez-le pour recevoir vos premières commandes.', v.nom)
            else format('La demande d''inscription de « %s » n''a pas été acceptée. Motif : %s', v.nom, v_motif)
          end,
          'compte');
end;
$$;

-- ---------------------------------------------------------------------
-- US34 — valider ou rejeter un livreur (après vérification des documents)
-- ---------------------------------------------------------------------
create function public.admin_decider_livreur(p_livreur uuid, p_valider boolean, p_motif text default null)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v public.profiles;
  v_motif text := nullif(trim(coalesce(p_motif, '')), '');
begin
  perform private.exiger_admin();
  select * into v from public.profiles where id = p_livreur and role = 'livreur' for update;
  if not found then
    raise exception 'Livreur introuvable' using errcode = 'P0001';
  end if;
  if v.etat_compte <> 'en_attente' then
    raise exception 'La candidature de % a déjà été traitée', v.nom using errcode = 'P0001', hint = v.etat_compte::text;
  end if;
  if p_valider and not exists (select 1 from public.documents_livreur where livreur_id = v.id and type = 'cin') then
    raise exception 'Impossible de valider : la carte d''identité n''a pas été déposée' using errcode = 'P0001';
  end if;
  if not p_valider and v_motif is null then
    raise exception 'Indiquez le motif du rejet : il est communiqué au livreur' using errcode = 'P0001';
  end if;

  update public.documents_livreur
     set etat = case when p_valider then 'valide' else 'refuse' end::public.etat_document
   where livreur_id = v.id and etat = 'en_attente';
  update public.profiles
     set etat_compte = case when p_valider then 'actif' else 'rejete' end::public.etat_compte
   where id = v.id;

  insert into public.notifications (destinataire_id, titre, message, type)
  values (v.id,
          case when p_valider then 'Compte livreur activé' else 'Candidature refusée' end,
          case when p_valider
            then 'Vos documents sont validés : mettez-vous disponible pour recevoir vos premières courses.'
            else format('Votre candidature n''a pas été acceptée. Motif : %s', v_motif)
          end,
          'compte');
end;
$$;

-- ---------------------------------------------------------------------
-- US35 — bloquer ou réactiver un compte
-- ---------------------------------------------------------------------
-- Un compte bloqué ne peut plus se connecter (les applications le refusent)
-- ni agir (règles d'accès et fonctions). Bloquer un responsable bloque aussi
-- son restaurant (qui se ferme, US08) ; bloquer un livreur le rend
-- indisponible. La réactivation remet le compte (et son restaurant) actifs.
create function public.admin_bloquer_compte(p_compte uuid, p_bloquer boolean)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v public.profiles;
begin
  perform private.exiger_admin();
  select * into v from public.profiles where id = p_compte for update;
  if not found then
    raise exception 'Compte introuvable' using errcode = 'P0001';
  end if;
  if v.role = 'admin' then
    raise exception 'Un compte administrateur ne peut pas être bloqué ici' using errcode = 'P0001';
  end if;
  if p_bloquer and v.etat_compte = 'bloque' then
    raise exception 'Ce compte est déjà bloqué' using errcode = 'P0001';
  end if;
  if not p_bloquer and v.etat_compte <> 'bloque' then
    raise exception 'Ce compte n''est pas bloqué' using errcode = 'P0001';
  end if;

  update public.profiles
     set etat_compte = case when p_bloquer then 'bloque' else 'actif' end::public.etat_compte
   where id = v.id;
  if v.role = 'responsable' then
    update public.restaurants
       set etat = case when p_bloquer then 'bloque' else 'actif' end::public.etat_compte
     where responsable_id = v.id and etat = case when p_bloquer then 'actif' else 'bloque' end::public.etat_compte;
  end if;
end;
$$;

revoke execute on function public.admin_decider_restaurant(uuid, boolean, text),
                           public.admin_decider_livreur(uuid, boolean, text),
                           public.admin_bloquer_compte(uuid, boolean) from public, anon;
grant execute on function public.admin_decider_restaurant(uuid, boolean, text),
                          public.admin_decider_livreur(uuid, boolean, text),
                          public.admin_bloquer_compte(uuid, boolean) to authenticated, service_role;

-- ---------------------------------------------------------------------
-- US37 — paramètres : bornes raisonnables
-- ---------------------------------------------------------------------
-- Les frais de la commande sont copiés au moment où elle est passée
-- (passer_commande, US19) : un changement ne touche que les suivantes.
alter table public.parametres
  add constraint parametres_frais_raisonnables check (frais_livraison <= 50),
  add constraint parametres_gain_raisonnable check (gain_livreur <= 50);
alter table public.categories_restaurant
  add constraint categories_restaurant_nom_non_vide check (length(trim(nom)) > 0);
