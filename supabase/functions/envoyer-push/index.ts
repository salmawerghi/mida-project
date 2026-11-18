// =====================================================================
// US23 — Edge Function « envoyer-push »
// ---------------------------------------------------------------------
// Appelée par la base (déclencheur private.envoyer_push, via pg_net) à
// chaque nouvelle ligne de public.notifications. Elle relit la
// notification, puis l'envoie par Firebase Cloud Messaging (API HTTP v1)
// à tous les téléphones du destinataire (table device_tokens).
//
// Secrets de la fonction (supabase secrets set) :
//   PUSH_SECRET               mot de passe partagé avec la base (Vault « push_secret »)
//   FIREBASE_SERVICE_ACCOUNT  clé du compte de service Firebase (JSON, ou JSON en base64)
// Fournis automatiquement par Supabase : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
//
// Déployée SANS vérification de JWT (--no-verify-jwt) : c'est l'en-tête
// x-mida-secret qui protège l'appel.
// =====================================================================
import { createClient } from 'jsr:@supabase/supabase-js@2';

/** Canal Android créé par les applis (MainActivity) : notification en haut de l'écran. */
const CANAL_ANDROID = 'commandes_mida';

type CompteService = { project_id: string; client_email: string; private_key: string; token_uri?: string };

const json = (corps: unknown, status = 200) =>
  new Response(JSON.stringify(corps), { status, headers: { 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ erreur: 'Méthode non autorisée' }, 405);

  const secret = Deno.env.get('PUSH_SECRET');
  if (!secret || !egalSur(req.headers.get('x-mida-secret') ?? '', secret)) {
    return json({ erreur: 'Accès refusé' }, 401);
  }

  let notificationId: string | undefined;
  try {
    notificationId = (await req.json())?.notification_id;
  } catch {
    // corps illisible : traité juste en dessous
  }
  if (typeof notificationId !== 'string') return json({ erreur: 'notification_id manquant' }, 400);

  const base = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: { persistSession: false },
  });

  const { data: notif, error: errNotif } = await base
    .from('notifications')
    .select('id, destinataire_id, titre, message, type, commande_id')
    .eq('id', notificationId)
    .maybeSingle();
  if (errNotif) return json({ erreur: errNotif.message }, 500);
  if (!notif) return json({ erreur: 'Notification introuvable' }, 404);

  const { data: appareils, error: errJetons } = await base
    .from('device_tokens')
    .select('token')
    .eq('user_id', notif.destinataire_id);
  if (errJetons) return json({ erreur: errJetons.message }, 500);
  if (!appareils?.length) return json({ envoyees: 0, raison: 'aucun téléphone enregistré' });

  let compte: CompteService;
  try {
    compte = lireCompteService(Deno.env.get('FIREBASE_SERVICE_ACCOUNT'));
  } catch (e) {
    return json({ erreur: `FIREBASE_SERVICE_ACCOUNT : ${(e as Error).message}` }, 500);
  }
  const acces = await jetonGoogle(compte);

  let envoyees = 0;
  const perimes: string[] = [];
  const erreurs: string[] = [];
  for (const { token } of appareils) {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${compte.project_id}/messages:send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${acces}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: notif.titre, body: notif.message },
          // Lu par l'appli quand on touche la notification
          data: { notification_id: notif.id, commande_id: notif.commande_id ?? '', type: notif.type },
          android: { priority: 'HIGH', notification: { channel_id: CANAL_ANDROID } },
        },
      }),
    });
    if (r.ok) {
      envoyees++;
      continue;
    }
    const detail = await r.text();
    // Appli désinstallée ou jeton remplacé : on l'oublie.
    if (r.status === 404 || detail.includes('UNREGISTERED')) perimes.push(token);
    else erreurs.push(`${r.status} ${detail.slice(0, 300)}`);
  }
  if (perimes.length) await base.from('device_tokens').delete().in('token', perimes);
  if (erreurs.length) console.error('Envoi FCM en échec :', erreurs);

  return json({ envoyees, jetons_supprimes: perimes.length, erreurs: erreurs.length });
});

/** Comparaison en temps constant (ne révèle pas le secret par la durée de réponse). */
function egalSur(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

/** Accepte le fichier JSON tel quel ou encodé en base64 (plus simple à passer en ligne de commande). */
function lireCompteService(valeur: string | undefined): CompteService {
  if (!valeur) throw new Error('secret absent');
  const texte = valeur.trim().startsWith('{') ? valeur : new TextDecoder().decode(base64VersOctets(valeur.trim()));
  const c = JSON.parse(texte);
  if (!c.project_id || !c.client_email || !c.private_key) throw new Error('champs manquants');
  return c;
}

// ---------------------------------------------------------------------
// Jeton d'accès Google (OAuth 2.0, compte de service), gardé ~1 h
// ---------------------------------------------------------------------
let cache: { jeton: string; expire: number } | null = null;

async function jetonGoogle(compte: CompteService): Promise<string> {
  if (cache && cache.expire > Date.now() + 60_000) return cache.jeton;

  const maintenant = Math.floor(Date.now() / 1000);
  const adresse = compte.token_uri ?? 'https://oauth2.googleapis.com/token';
  const entete = { alg: 'RS256', typ: 'JWT' };
  const contenu = {
    iss: compte.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: adresse,
    iat: maintenant,
    exp: maintenant + 3600,
  };
  const aSigner = `${base64Url(JSON.stringify(entete))}.${base64Url(JSON.stringify(contenu))}`;
  const cle = await crypto.subtle.importKey(
    'pkcs8',
    base64VersOctets(compte.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cle, new TextEncoder().encode(aSigner)),
  );

  const r = await fetch(adresse, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${aSigner}.${base64Url(signature)}`,
    }),
  });
  if (!r.ok) throw new Error(`Jeton Google refusé : ${r.status} ${await r.text()}`);
  const { access_token, expires_in } = await r.json();
  cache = { jeton: access_token, expire: Date.now() + (expires_in ?? 3600) * 1000 };
  return access_token;
}

function base64Url(donnees: string | Uint8Array): string {
  const octets = typeof donnees === 'string' ? new TextEncoder().encode(donnees) : donnees;
  let bin = '';
  for (const o of octets) bin += String.fromCharCode(o);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64VersOctets(b64: string): Uint8Array {
  const bin = atob(b64);
  const octets = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) octets[i] = bin.charCodeAt(i);
  return octets;
}
