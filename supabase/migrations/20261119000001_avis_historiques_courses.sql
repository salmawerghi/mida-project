-- =====================================================================
-- Mida — US38, US48, US39, US42, US43
-- ---------------------------------------------------------------------
-- US38  le client note le restaurant (et le livreur) après la livraison :
--       public.noter_commande(), « security invoker » : les avis passent
--       par la règle d'accès « avis : ajout par le client » d'US02
--       (commande livrée, à lui, restaurant / livreur de la commande).
-- US48  le restaurant (et le livreur) est prévenu de chaque nouvel avis ;
--       la lecture des avis est publique depuis US02.
-- US39  historique des commandes du restaurant : index pour lire ses
--       commandes de la plus récente à la plus ancienne.
-- US42  historique des courses du livreur : lecture seule, règles US27.
-- US43  chaque nouvelle course proposée est annoncée par une notification
--       (donc par un push, US23) à tous les livreurs validés et disponibles.
-- =====================================================================

-- ---------------------------------------------------------------------
-- US38 — noter une commande livrée
-- ---------------------------------------------------------------------
alter table public.avis
  add constraint avis_commentaire_longueur check (commentaire is null or char_length(commentaire) <= 500);

create function public.noter_commande(
  p_commande               uuid,
  p_note_restaurant        integer,
  p_commentaire_restaurant text    default null,
  p_note_livreur           integer default null,
  p_commentaire_livreur    text    default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_client  uuid := (select auth.uid());
  v_commande public.commandes;
  v_livreur uuid;
  v_com_resto text := nullif(btrim(coalesce(p_commentaire_restaurant, '')), '');
  v_com_livreur text := nullif(btrim(coalesce(p_commentaire_livreur, '')), '');
begin
  if v_client is null then
    raise exception 'Connectez-vous pour donner votre avis.' using errcode = '42501';
  end if;

  select * into v_commande from public.commandes where id = p_commande and client_id = v_client;
  if not found then
    raise exception 'Commande introuvable.' using errcode = '42501';
  end if;
  if v_commande.etat <> 'livree' then
    raise exception 'Vous pourrez donner votre avis une fois la commande livrée.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.avis where commande_id = p_commande and client_id = v_client) then
    raise exception 'Vous avez déjà donné votre avis sur cette commande.' using errcode = 'P0001';
  end if;

  if p_note_restaurant is null or p_note_restaurant not between 1 and 5 then
    raise exception 'Choisissez une note de 1 à 5 étoiles pour le restaurant.' using errcode = 'P0001';
  end if;
  if p_note_livreur is not null and p_note_livreur not between 1 and 5 then
    raise exception 'La note du livreur va de 1 à 5 étoiles.' using errcode = 'P0001';
  end if;
  if char_length(coalesce(v_com_resto, '')) > 500 or char_length(coalesce(v_com_livreur, '')) > 500 then
    raise exception 'Un commentaire fait 500 caractères au plus.' using errcode = 'P0001';
  end if;

  insert into public.avis (commande_id, client_id, restaurant_id, note, commentaire)
  values (p_commande, v_client, v_commande.restaurant_id, p_note_restaurant, v_com_resto);

  if p_note_livreur is not null then
    select livreur_id into v_livreur from public.livraisons where commande_id = p_commande;
    if v_livreur is null then
      raise exception 'Aucun livreur à noter pour cette commande.' using errcode = 'P0001';
    end if;
    insert into public.avis (commande_id, client_id, livreur_id, note, commentaire)
    values (p_commande, v_client, v_livreur, p_note_livreur, v_com_livreur);
  end if;
end;
$$;
revoke execute on function public.noter_commande(uuid, integer, text, integer, text) from public, anon;
grant execute on function public.noter_commande(uuid, integer, text, integer, text) to authenticated, service_role;

-- ---------------------------------------------------------------------
-- US48 — le restaurant (ou le livreur) est prévenu d'un nouvel avis
-- ---------------------------------------------------------------------
-- Le client n'a pas le droit d'écrire dans les notifications des autres :
-- le déclencheur s'en charge (security definer, non appelable par l'API).
create function private.prevenir_avis()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_numero bigint;
  v_destinataire uuid;
  v_etoiles text := repeat('★', new.note) || repeat('☆', 5 - new.note);
begin
  select numero into v_numero from public.commandes where id = new.commande_id;
  if new.restaurant_id is not null then
    select responsable_id into v_destinataire from public.restaurants where id = new.restaurant_id;
  else
    v_destinataire := new.livreur_id;
  end if;
  if v_destinataire is null then
    return new;
  end if;

  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v_destinataire, 'Nouvel avis ' || v_etoiles,
          case when new.commentaire is null
               then format('Un client a noté la commande n° %s : %s/5.', v_numero, new.note)
               else format('Commande n° %s, %s/5 : « %s »', v_numero, new.note, left(new.commentaire, 140))
          end,
          'avis', new.commande_id);
  return new;
end;
$$;
revoke execute on function private.prevenir_avis() from public, anon, authenticated;

create trigger prevenir_avis after insert on public.avis
  for each row execute function private.prevenir_avis();

-- ---------------------------------------------------------------------
-- US39 — historique des commandes du restaurant (plus récentes d'abord)
-- ---------------------------------------------------------------------
create index if not exists commandes_restaurant_date_idx
  on public.commandes (restaurant_id, created_at desc);

-- ---------------------------------------------------------------------
-- US43 — chaque nouvelle course est annoncée aux livreurs disponibles
-- ---------------------------------------------------------------------
create function private.annoncer_course()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_numero bigint;
  v_adresse text;
  v_restaurant text;
  v_ville text;
begin
  select c.numero, c.adresse_livraison, r.nom, r.ville
    into v_numero, v_adresse, v_restaurant, v_ville
  from public.commandes c join public.restaurants r on r.id = c.restaurant_id
  where c.id = new.commande_id;

  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  select l.id, 'Nouvelle course',
         format('%s%s → %s · gain %s',
                v_restaurant,
                coalesce(' (' || nullif(btrim(v_ville), '') || ')', ''),
                left(v_adresse, 80),
                private.montant_dt(new.gain_livreur)),
         'course', new.commande_id
  from public.livreurs l
  join public.profiles p on p.id = l.id
  where l.disponible and p.role = 'livreur' and p.etat_compte = 'actif'
    -- un livreur déjà occupé par une course ne peut pas en accepter d'autre
    and not exists (select 1 from public.livraisons x
                    where x.livreur_id = l.id and x.etat in ('acceptee', 'recuperee'));
  return new;
end;
$$;
revoke execute on function private.annoncer_course() from public, anon, authenticated;

create trigger annoncer_course after insert on public.livraisons
  for each row when (new.etat = 'proposee' and new.livreur_id is null)
  execute function private.annoncer_course();
