-- =====================================================================
-- US23 — Notifications push (Firebase Cloud Messaging)
-- ---------------------------------------------------------------------
-- 1. Les applis mobiles (client, livreur) enregistrent le jeton FCM du
--    téléphone avec public.enregistrer_jeton().
-- 2. Chaque ligne ajoutée dans public.notifications (commande acceptée,
--    prête, course proposée…) déclenche un appel HTTP asynchrone (pg_net)
--    vers l'Edge Function « envoyer-push », qui relit la notification et
--    l'envoie à tous les téléphones du destinataire.
--
-- Réglages faits HORS migration (valeurs secrètes, voir le README) :
--   * Vault : secrets « push_url » (adresse de la fonction) et
--     « push_secret » (mot de passe partagé avec la fonction) ;
--   * secrets de l'Edge Function : PUSH_SECRET et FIREBASE_SERVICE_ACCOUNT.
-- Tant que ces secrets n'existent pas, aucune notification push n'est
-- envoyée, et rien d'autre ne change.
-- =====================================================================

-- pg_net : requêtes HTTP envoyées APRÈS la validation de la transaction
-- (une commande annulée par une erreur n'envoie donc rien).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
end
$$;

-- ---------------------------------------------------------------------
-- 1. Enregistrer le jeton du téléphone
-- ---------------------------------------------------------------------
-- Un même téléphone peut changer de compte (déconnexion puis connexion
-- avec un autre compte) : le jeton change alors de propriétaire. La règle
-- d'accès de device_tokens ne laisse pas voir le jeton d'un autre compte,
-- d'où cette fonction « security definer » dans le schéma private.
create function private.enregistrer_jeton(p_token text, p_plateforme text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'Connectez-vous pour recevoir les notifications.' using errcode = '42501';
  end if;
  if p_token is null or length(btrim(p_token)) < 20 or length(p_token) > 4096 then
    raise exception 'Jeton d''appareil invalide.' using errcode = '22023';
  end if;
  insert into public.device_tokens (user_id, token, plateforme)
  values (v_user, btrim(p_token), coalesce(p_plateforme, 'android'))
  on conflict (token) do update
    set user_id = excluded.user_id, plateforme = excluded.plateforme, created_at = now();
end;
$$;
revoke execute on function private.enregistrer_jeton(text, text) from public, anon;
grant execute on function private.enregistrer_jeton(text, text) to authenticated, service_role;

-- Porte d'entrée exposée à l'API : « security invoker », elle ne fait
-- qu'appeler la fonction privée.
create function public.enregistrer_jeton(p_token text, p_plateforme text default 'android')
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.enregistrer_jeton(p_token, p_plateforme);
$$;
revoke execute on function public.enregistrer_jeton(text, text) from public, anon;
grant execute on function public.enregistrer_jeton(text, text) to authenticated, service_role;

-- La suppression (à la déconnexion) passe par la règle d'accès existante
-- « jeton : suppression » : chacun supprime les siens.

-- ---------------------------------------------------------------------
-- 2. Chaque notification part aussi en push
-- ---------------------------------------------------------------------
create function private.envoyer_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url    text;
  v_secret text;
begin
  -- Personne à prévenir sur un téléphone (restaurant, admin, client
  -- jamais connecté à l'appli) : pas d'appel inutile.
  if not exists (select 1 from public.device_tokens where user_id = new.destinataire_id) then
    return new;
  end if;

  select decrypted_secret into v_url    from vault.decrypted_secrets where name = 'push_url';
  select decrypted_secret into v_secret from vault.decrypted_secrets where name = 'push_secret';
  if v_url is null or v_secret is null then
    return new;  -- notifications push pas encore configurées
  end if;

  -- Seul l'identifiant part : la fonction relit la notification en base,
  -- un appel imité ne peut donc rien envoyer d'inventé.
  perform net.http_post(
    url                  := v_url,
    body                 := jsonb_build_object('notification_id', new.id),
    headers              := jsonb_build_object('Content-Type', 'application/json', 'x-mida-secret', v_secret),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  -- Une panne du push ne doit jamais bloquer une commande.
  raise warning 'Notification push non envoyée : %', sqlerrm;
  return new;
end;
$$;
revoke execute on function private.envoyer_push() from public, anon, authenticated;

create trigger envoyer_push
  after insert on public.notifications
  for each row execute function private.envoyer_push();
