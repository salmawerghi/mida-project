// Tests des migrations Mida (US01 + US02) sur un vrai moteur PostgreSQL
// embarqué (PGlite), sans Docker ni projet Supabase.
// Lancement : cd supabase/tests && npm install && npm test
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';

const ici = dirname(fileURLToPath(import.meta.url));
const racine = join(ici, '..');
const db = new PGlite({ extensions: { pgcrypto } });

// --- mise en place : environnement Supabase simulé + migrations + données
await db.exec(readFileSync(join(ici, 'supabase-stub.sql'), 'utf8'));
for (const f of readdirSync(join(racine, 'migrations')).sort()) {
  await db.exec(readFileSync(join(racine, 'migrations', f), 'utf8'));
}
await db.exec(readFileSync(join(racine, 'seed.sql'), 'utf8'));
// Le seed doit pouvoir être relancé sans erreur ni doublon
await db.exec(readFileSync(join(racine, 'seed.sql'), 'utf8'));

const ids = Object.fromEntries(
  (await db.query('select email, id from auth.users')).rows.map((r) => [r.email.split('@')[0], r.id]),
);

// Dans une transaction, chaque requête est isolée par un point de sauvegarde :
// une erreur attendue (accès refusé) ne bloque pas les requêtes suivantes.
let enTransaction = false;
async function requete(sql, params) {
  if (!enTransaction) return db.query(sql, params);
  await db.exec('savepoint q');
  try {
    const r = await db.query(sql, params);
    await db.exec('release savepoint q');
    return r;
  } catch (e) {
    await db.exec('rollback to savepoint q');
    throw e;
  }
}

/**
 * Exécute fn en tant qu'utilisateur (ou visiteur si email = null), puis annule tout.
 * `preparation` (SQL facultatif) est exécuté avant, avec tous les droits.
 */
async function en(utilisateur, fn, preparation) {
  await debut();

  try {
    if (preparation) await db.exec(preparation);
    if (utilisateur === null) {
      await db.exec('set local role anon');
    } else {
      await db.query("select set_config('request.jwt.claim.sub', $1, true)", [ids[utilisateur]]);
      await db.exec('set local role authenticated');
    }
    return await fn();
  } finally {
    await fin();
  }
}
async function debut() { await db.exec('begin'); enTransaction = true; }
async function fin() { enTransaction = false; await db.exec('rollback'); }
const lignes = async (sql, params = []) => (await requete(sql, params)).rows;
const numeros = async () => (await lignes('select numero from public.commandes order by numero')).map((r) => Number(r.numero));
const nbModifiees = async (sql, params = []) => (await requete(sql, params)).affectedRows;

// =====================================================================
// US01 — modèle de données
// =====================================================================
test('US01 · toutes les tables du modèle existent', async () => {
  const tables = (await lignes(`select tablename from pg_tables where schemaname = 'public' order by 1`)).map((r) => r.tablename);
  for (const t of ['profiles', 'adresses', 'restaurants', 'categories_menu', 'plats', 'commandes',
                   'lignes_commande', 'paiements', 'livraisons', 'avis', 'livreurs', 'documents_livreur',
                   'categories_restaurant', 'horaires', 'parametres', 'reclamations', 'notifications', 'device_tokens']) {
    assert.ok(tables.includes(t), `table manquante : ${t}`);
  }
});

test('US01 · le jeu de données de test est chargé (et relançable sans doublon)', async () => {
  const [c] = await lignes(`select
      (select count(*) from public.profiles)::int     as profils,
      (select count(*) from public.restaurants)::int  as restaurants,
      (select count(*) from public.plats)::int        as plats,
      (select count(*) from public.commandes)::int    as commandes,
      (select count(*) from public.lignes_commande)::int as lignes,
      (select count(*) from public.avis)::int         as avis`);
  assert.deepEqual(c, { profils: 11, restaurants: 4, plats: 13, commandes: 6, lignes: 9, avis: 2 });
});

test('US01 · contraintes : total cohérent, prix positif, catégorie du même restaurant', async () => {
  await assert.rejects(lignes(`update public.commandes set total = 1 where numero = 1042`), /check/i);
  await assert.rejects(lignes(`update public.plats set prix = -2 where nom = 'Fricassé'`), /check/i);
  // un plat d'El Kanoun ne peut pas être rangé dans une catégorie de Dar Zitouna
  await assert.rejects(lignes(`update public.plats set categorie_id = '30000000-0000-4000-8000-000000000001'
                               where id = '40000000-0000-4000-8000-000000000008'`), /foreign key/i);
  // impossible de supprimer une catégorie qui contient des plats
  await assert.rejects(lignes(`delete from public.categories_menu where id = '30000000-0000-4000-8000-000000000001'`), /foreign key/i);
});

test('US01 · la numérotation des commandes continue après le jeu de test', async () => {
  const [{ v }] = await lignes(`select nextval(pg_get_serial_sequence('public.commandes', 'numero')) as v`);
  assert.equal(Number(v), 1047);
});

// =====================================================================
// US02 — rôles et règles de sécurité
// =====================================================================
test('US02 · la RLS est activée sur toutes les tables', async () => {
  const sans = await lignes(`select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
                             where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity`);
  assert.deepEqual(sans, []);
});

test('US02 · les 4 rôles existent', async () => {
  const roles = (await lignes(`select distinct role::text from public.profiles order by 1`)).map((r) => r.role);
  assert.deepEqual(roles, ['admin', 'client', 'livreur', 'responsable']);
});

test('US02 · un client ne lit que ses propres commandes', async () => {
  assert.deepEqual(await en('amine', numeros), [1040, 1042, 1046]);
  assert.deepEqual(await en('leila', numeros), [1043, 1044]);
  assert.deepEqual(await en('youssef', numeros), [1045]);
  // ni les lignes, ni les paiements des autres
  const lignesVues = await en('amine', () => lignes(`select distinct commande_id from public.lignes_commande`));
  assert.equal(lignesVues.length, 3);
  const paiements = await en('youssef', () => lignes(`select montant from public.paiements`));
  assert.deepEqual(paiements.map((p) => p.montant), ['25.500']);
});

test('US02 · un restaurant ne voit que ses commandes', async () => {
  assert.deepEqual(await en('zitouna', numeros), [1042, 1044, 1045]);
  assert.deepEqual(await en('kanoun', numeros), [1043, 1046]);
});

test('US02 · un restaurant ne peut modifier que son propre menu', async () => {
  await en('zitouna', async () => {
    // son plat : OK
    assert.equal(await nbModifiees(`update public.plats set prix = 19 where id = '40000000-0000-4000-8000-000000000001'`), 1);
    // le plat d'El Kanoun : aucune ligne touchée
    assert.equal(await nbModifiees(`update public.plats set prix = 1 where id = '40000000-0000-4000-8000-000000000008'`), 0);
    assert.equal(await nbModifiees(`delete from public.plats where id = '40000000-0000-4000-8000-000000000008'`), 0);
    // ajouter un plat chez El Kanoun : refusé
    await assert.rejects(lignes(`insert into public.plats (restaurant_id, categorie_id, nom, prix)
      values ('10000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000005', 'Intrus', 5)`), /row-level security/);
    // ajouter une catégorie à son propre menu : OK
    assert.equal(await nbModifiees(`insert into public.categories_menu (restaurant_id, nom)
      values ('10000000-0000-4000-8000-000000000001', 'Desserts')`), 1);
  });
});

test('US02 · visiteur (mode sans compte) : restaurants validés et menus seulement', async () => {
  await en(null, async () => {
    const restos = (await lignes(`select nom from public.restaurants order by nom`)).map((r) => r.nom);
    assert.deepEqual(restos, ['Brik Bab Souika', 'Dar Zitouna', 'El Kanoun']);   // pas Lella Béya (en attente)
    assert.equal((await lignes(`select id from public.plats`)).length, 13);
    assert.equal((await lignes(`select id from public.profiles`)).length, 0);
    assert.equal((await lignes(`select id from public.commandes`)).length, 0);
    assert.equal((await lignes(`select id from public.adresses`)).length, 0);
  });
});

test('US02 · personne ne peut se donner un rôle ou se valider soi-même', async () => {
  await en('amine', async () => {
    await assert.rejects(lignes(`update public.profiles set role = 'admin' where id = auth.uid()`), /administrateur/);
    // modifier son nom reste possible
    assert.equal(await nbModifiees(`update public.profiles set nom = 'Amine B.' where id = auth.uid()`), 1);
    // et le profil d'un autre est invisible donc non modifiable
    assert.equal(await nbModifiees(`update public.profiles set nom = 'X' where email = 'leila@mida.test'`), 0);
  });
  await en('lellabeya', async () => {
    const [r] = await lignes(`select etat from public.restaurants where responsable_id = auth.uid()`);
    assert.equal(r.etat, 'en_attente');   // il voit son restaurant en attente…
    await assert.rejects(lignes(`update public.restaurants set etat = 'actif' where responsable_id = auth.uid()`), /administrateur/);
  });
  await en('yassine', async () => {
    await assert.rejects(lignes(`update public.profiles set etat_compte = 'actif' where id = auth.uid()`), /administrateur/);
  });
});

test('US02 · inscription : rôle pris des métadonnées, jamais admin', async () => {
  await debut();
  try {
    await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
      ('f0000000-0000-4000-8000-000000000001', 'pirate@mida.test',  '{"role": "admin", "nom": "Pirate"}'),
      ('f0000000-0000-4000-8000-000000000002', 'nouveau@mida.test', '{"role": "responsable", "nom": "Nouveau resto"}'),
      ('f0000000-0000-4000-8000-000000000003', 'velo@mida.test',    '{"role": "livreur", "nom": "Livreur vélo"}')`);
    const p = await lignes(`select email, role::text, etat_compte::text from public.profiles
                            where id::text like 'f0000000%' order by email`);
    assert.deepEqual(p, [
      { email: 'nouveau@mida.test', role: 'responsable', etat_compte: 'en_attente' },
      { email: 'pirate@mida.test',  role: 'client',      etat_compte: 'actif' },
      { email: 'velo@mida.test',    role: 'livreur',     etat_compte: 'en_attente' },
    ]);
    const [l] = await lignes(`select count(*)::int as n from public.livreurs where id = 'f0000000-0000-4000-8000-000000000003'`);
    assert.equal(l.n, 1);
  } finally {
    await fin();
  }
});

test('US02 · un responsable inscrit son restaurant, toujours « en attente »', async () => {
  await debut();
  try {
    await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
      ('f0000000-0000-4000-8000-000000000009', 'resto9@mida.test', '{"role": "responsable", "nom": "R9"}')`);
    await db.query("select set_config('request.jwt.claim.sub', 'f0000000-0000-4000-8000-000000000009', true)");
    await db.exec('set local role authenticated');
    await db.exec(`insert into public.restaurants (responsable_id, nom, adresse, ville, etat)
                   values (auth.uid(), 'Chez R9', '1 rue', 'Tunis', 'actif')`);   // tente de s'auto-valider
    const [r] = await lignes(`select etat::text from public.restaurants where responsable_id = auth.uid()`);
    assert.equal(r.etat, 'en_attente');
    // un client ne peut pas créer de restaurant
    await db.query("select set_config('request.jwt.claim.sub', $1, true)", [ids.amine]);
    await assert.rejects(lignes(`insert into public.restaurants (responsable_id, nom, adresse, ville)
                                 values (auth.uid(), 'Faux', '1 rue', 'Tunis')`), /row-level security/);
  } finally {
    await fin();
  }
});

test('US05 · restaurant en attente : visible de son responsable seulement, un seul par compte', async () => {
  await debut();
  try {
    await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values
      ('f0000000-0000-4000-8000-000000000010', 'resto10@mida.test', '{"role": "responsable", "nom": "R10"}')`);
    await db.query("select set_config('request.jwt.claim.sub', 'f0000000-0000-4000-8000-000000000010', true)");
    await db.exec('set local role authenticated');
    await requete(`insert into public.restaurants (responsable_id, nom, adresse, ville)
                   values (auth.uid(), 'Chez R10', '2 rue', 'Sousse')`);
    // le responsable relit son restaurant en attente (écran « En attente de validation »)
    assert.deepEqual(await lignes(`select nom, etat::text from public.restaurants where responsable_id = auth.uid()`),
                     [{ nom: 'Chez R10', etat: 'en_attente' }]);
    // un seul restaurant par compte responsable
    await assert.rejects(lignes(`insert into public.restaurants (responsable_id, nom, adresse, ville)
                                 values (auth.uid(), 'Deuxième', '3 rue', 'Sousse')`), /unique|duplicate/i);
    // ni les visiteurs ni les clients ne le voient avant validation
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', '', true)"); // un visiteur n'a pas d'identifiant
    await db.exec('set local role anon');
    assert.deepEqual(await lignes(`select id from public.restaurants where nom = 'Chez R10'`), []);
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', $1, true)", [ids.amine]);
    await db.exec('set local role authenticated');
    assert.deepEqual(await lignes(`select id from public.restaurants where nom = 'Chez R10'`), []);
  } finally {
    await fin();
  }
});

test('US02 · livreurs : courses proposées visibles seulement par les livreurs validés', async () => {
  assert.deepEqual(await en('sami', numeros), [1040, 1042, 1044]);    // ses courses + la course proposée
  assert.deepEqual(await en('karim', numeros), [1044, 1046]);
  assert.deepEqual(await en('yassine', numeros), []);                 // compte pas encore validé
});

test('US02 · les commandes ne s\'écrivent pas directement depuis une application', async () => {
  await en('amine', async () => {
    await assert.rejects(lignes(`insert into public.commandes (client_id, restaurant_id, adresse_livraison, sous_total, frais_livraison, total)
      values (auth.uid(), '10000000-0000-4000-8000-000000000001', 'x', 1, 0, 1)`), /row-level security/);
    assert.equal(await nbModifiees(`update public.commandes set etat = 'livree' where numero = 1046`), 0);
    assert.equal(await nbModifiees(`update public.paiements set etat = 'paye'`), 0);
  });
  await en('zitouna', async () => {
    assert.equal(await nbModifiees(`update public.commandes set etat = 'acceptee' where numero = 1045`), 0);
  });
});

test('US02 · profils visibles seulement entre personnes liées par une commande', async () => {
  const vus = async (u) => (await en(u, () => lignes(`select email from public.profiles order by email`))).map((r) => r.email);
  assert.deepEqual(await vus('amine'), ['amine@mida.test', 'babsouika@mida.test', 'kanoun@mida.test', 'karim@mida.test', 'sami@mida.test', 'zitouna@mida.test']);
  assert.deepEqual(await vus('zitouna'), ['amine@mida.test', 'leila@mida.test', 'sami@mida.test', 'youssef@mida.test', 'zitouna@mida.test']);
  assert.deepEqual(await vus('yassine'), ['yassine@mida.test']);
});

test('US02 · adresses et notifications privées', async () => {
  await en('amine', async () => {
    assert.equal((await lignes(`select id from public.adresses`)).length, 2);
    assert.equal(await nbModifiees(`update public.notifications set lue = true`), 1);
    await assert.rejects(lignes(`update public.notifications set message = 'modifié'`), /lue/);
  });
  await en('leila', async () => {
    assert.equal((await lignes(`select id from public.adresses`)).length, 1);
  });
});

test('US02 · avis : seulement sur sa propre commande livrée', async () => {
  await en('amine', async () => {
    // commande 1046 pas encore livrée
    await assert.rejects(lignes(`insert into public.avis (commande_id, client_id, restaurant_id, note)
      values ('60000000-0000-4000-8000-000000001046', auth.uid(), '10000000-0000-4000-8000-000000000002', 5)`), /row-level security/);
    // commande 1040 livrée : OK
    assert.equal(await nbModifiees(`insert into public.avis (commande_id, client_id, restaurant_id, note)
      values ('60000000-0000-4000-8000-000000001040', auth.uid(), '10000000-0000-4000-8000-000000000003', 4)`), 1);
  });
  await en('leila', async () => {
    await assert.rejects(lignes(`insert into public.avis (commande_id, client_id, restaurant_id, note)
      values ('60000000-0000-4000-8000-000000001042', auth.uid(), '10000000-0000-4000-8000-000000000001', 1)`), /row-level security/);
  });
});

test('US02 · l\'administrateur voit tout et valide les comptes', async () => {
  await en('admin', async () => {
    assert.deepEqual(await numeros(), [1040, 1042, 1043, 1044, 1045, 1046]);
    assert.equal(await nbModifiees(`update public.restaurants set etat = 'actif' where nom = 'Lella Béya'`), 1);
    assert.equal(await nbModifiees(`update public.profiles set etat_compte = 'actif' where email = 'yassine@mida.test'`), 1);
    assert.equal(await nbModifiees(`update public.parametres set frais_livraison = 3`), 1);
  });
  // un non-admin ne change pas les paramètres
  await en('zitouna', async () => {
    assert.equal(await nbModifiees(`update public.parametres set frais_livraison = 0`), 0);
  });
});

test('US02 · le jeton de connexion contient le rôle', async () => {
  const [{ r }] = await lignes(`select public.custom_access_token_hook(
      jsonb_build_object('user_id', $1::text, 'claims', '{"sub": "x"}'::jsonb)) as r`, [ids.zitouna]);
  assert.equal(r.claims.user_role, 'responsable');
  assert.equal(r.claims.etat_compte, 'actif');
  // les applications ne peuvent pas l'appeler elles-mêmes
  await en('amine', async () => {
    await assert.rejects(lignes(`select public.custom_access_token_hook('{}'::jsonb)`), /permission denied/);
  });
});

test('US02 · les fonctions serveur (service_role) peuvent modifier les champs protégés', async () => {
  await debut();
  try {
    await db.exec('set local role service_role');
    assert.equal(await nbModifiees(`update public.profiles set etat_compte = 'actif' where email = 'yassine@mida.test'`), 1);
    assert.equal(await nbModifiees(`update public.restaurants set etat = 'actif' where nom = 'Lella Béya'`), 1);
    assert.equal(await nbModifiees(`update public.documents_livreur set etat = 'valide' where etat = 'en_attente'`), 3);
    assert.equal(await nbModifiees(`update public.notifications set message = 'texte serveur'`), 3);
  } finally {
    await fin();
  }
});

// =====================================================================
// US03 — stockage des images
// =====================================================================
const R_ZITOUNA = '10000000-0000-4000-8000-000000000001';
const R_KANOUN = '10000000-0000-4000-8000-000000000002';
const envoyer = (bucket, nom) =>
  requete(`insert into storage.objects (bucket_id, name, owner) values ($1, $2, auth.uid())`, [bucket, nom]);
const remplacer = (bucket, nom) =>
  nbModifiees(`update storage.objects set metadata = '{"v": 2}', updated_at = now()
               where bucket_id = $1 and name = $2`, [bucket, nom]);
const supprimer = (bucket, nom) =>
  nbModifiees(`delete from storage.objects where bucket_id = $1 and name = $2`, [bucket, nom]);
const RLS = /row-level security/;
// fichiers déjà présents avant chaque scénario
const FICHIERS_EXISTANTS = `insert into storage.objects (bucket_id, name) values
  ('restaurants', '${R_KANOUN}/logo.webp'),
  ('restaurants', '${R_ZITOUNA}/logo.webp')`;

test('US03 · les trois espaces de stockage sont configurés', async () => {
  const b = await lignes(`select id, public, file_size_limit::int as taille, allowed_mime_types as formats
                          from storage.buckets order by id`);
  assert.deepEqual(b.map((x) => [x.id, x.public, x.taille]), [
    ['avatars', true, 2097152],
    ['documents-livreurs', false, 10485760],
    ['restaurants', true, 5242880],
  ]);
  assert.ok(b.every((x) => x.formats.includes('image/webp')));
  assert.ok(b.find((x) => x.id === 'documents-livreurs').formats.includes('application/pdf'));
});

test('US03 · un restaurant envoie et remplace ses propres images', async () => {
  await en('zitouna', async () => {
    await envoyer('restaurants', `${R_ZITOUNA}/couverture.webp`);
    await envoyer('restaurants', `${R_ZITOUNA}/plats/40000000-0000-4000-8000-000000000001.webp`);
    assert.equal(await remplacer('restaurants', `${R_ZITOUNA}/logo.webp`), 1);
    // il retrouve ses fichiers (nécessaire pour remplacer un fichier existant)
    const [{ n }] = await lignes(`select count(*)::int as n from storage.objects where bucket_id = 'restaurants'`);
    assert.equal(n, 3);
  }, FICHIERS_EXISTANTS);
});

test('US03 · seul le propriétaire peut remplacer une image de restaurant', async () => {
  await en('zitouna', async () => {
    // pas d'envoi dans le dossier d'El Kanoun
    await assert.rejects(envoyer('restaurants', `${R_KANOUN}/logo2.webp`), RLS);
    // ni remplacement, ni suppression de son logo (aucune ligne touchée)
    assert.equal(await remplacer('restaurants', `${R_KANOUN}/logo.webp`), 0);
    assert.equal(await supprimer('restaurants', `${R_KANOUN}/logo.webp`), 0);
    // un chemin sans dossier de restaurant est refusé
    await assert.rejects(envoyer('restaurants', 'logo.webp'), RLS);
    await assert.rejects(envoyer('restaurants', 'pas-un-id/logo.webp'), RLS);
  }, FICHIERS_EXISTANTS);
  // un client et un visiteur ne peuvent rien envoyer
  await en('amine', async () => {
    await assert.rejects(envoyer('restaurants', `${R_ZITOUNA}/pirate.webp`), RLS);
    assert.equal(await remplacer('restaurants', `${R_ZITOUNA}/logo.webp`), 0);
  }, FICHIERS_EXISTANTS);
  await en(null, async () => {
    await assert.rejects(envoyer('restaurants', `${R_ZITOUNA}/pirate.webp`), RLS);
  });
  // l'administrateur peut intervenir sur toutes les images
  await en('admin', async () => {
    assert.equal(await remplacer('restaurants', `${R_KANOUN}/logo.webp`), 1);
  }, FICHIERS_EXISTANTS);
});

test('US03 · un restaurant bloqué ne gère plus ses images', async () => {
  await en('zitouna', async () => {
    await assert.rejects(envoyer('restaurants', `${R_ZITOUNA}/couverture.webp`), RLS);
  }, `update public.profiles set etat_compte = 'bloque' where email = 'zitouna@mida.test'`);
});

test('US03 · chacun gère uniquement sa photo de profil', async () => {
  await en('amine', async () => {
    await envoyer('avatars', `${ids.amine}/avatar.webp`);
    assert.equal(await remplacer('avatars', `${ids.amine}/avatar.webp`), 1);
    await assert.rejects(envoyer('avatars', `${ids.leila}/avatar.webp`), RLS);
  });
  await en('amine', async () => {
    assert.equal(await remplacer('avatars', `${ids.leila}/avatar.webp`), 0);
    assert.equal(await supprimer('avatars', `${ids.leila}/avatar.webp`), 0);
  }, `insert into storage.objects (bucket_id, name) values ('avatars', '${ids.leila}/avatar.webp')`);
});

test('US03 · documents des livreurs : privés et figés une fois validés', async () => {
  const docs = `insert into storage.objects (bucket_id, name) values
    ('documents-livreurs', '${ids.sami}/cin.pdf'),
    ('documents-livreurs', '${ids.yassine}/cin.pdf')`;
  // Yassine (en attente) remplace sa CIN encore en attente de validation
  await en('yassine', async () => {
    assert.equal(await remplacer('documents-livreurs', `${ids.yassine}/cin.pdf`), 1);
    await envoyer('documents-livreurs', `${ids.yassine}/photo.jpg`);
  }, docs);
  // Sami ne peut plus remplacer ni supprimer sa CIN validée, mais peut ajouter un document manquant
  await en('sami', async () => {
    assert.equal(await remplacer('documents-livreurs', `${ids.sami}/cin.pdf`), 0);
    assert.equal(await supprimer('documents-livreurs', `${ids.sami}/cin.pdf`), 0);
    await assert.rejects(envoyer('documents-livreurs', `${ids.sami}/cin.png`), RLS);
    // pas de contournement par un sous-dossier
    await assert.rejects(envoyer('documents-livreurs', `${ids.sami}/x/cin.pdf`), RLS);
    await envoyer('documents-livreurs', `${ids.sami}/carte_grise.pdf`);
  }, docs);
  // un autre livreur ne les voit pas, un client ne peut pas en envoyer
  await en('karim', async () => {
    const vus = await lignes(`select name from storage.objects where bucket_id = 'documents-livreurs'`);
    assert.deepEqual(vus, []);
  }, docs);
  await en('amine', async () => {
    await assert.rejects(envoyer('documents-livreurs', `${ids.amine}/cin.pdf`), RLS);
  });
  // l'administrateur les consulte tous
  await en('admin', async () => {
    const [{ n }] = await lignes(`select count(*)::int as n from storage.objects where bucket_id = 'documents-livreurs'`);
    assert.equal(n, 2);
  }, docs);
});

// =====================================================================
// US07 — profil du restaurant (informations, logo, horaires)
// =====================================================================
// Ce que fait l'espace restaurant : remplacer les 7 jours d'un coup.
const HORAIRES_7_JOURS = (restaurant) => `
  insert into public.horaires (restaurant_id, jour, ouverture, fermeture, ferme)
  select '${restaurant}', j, case when j = 1 then null else time '12:00' end,
         case when j = 1 then null else time '23:30' end, j = 1
  from generate_series(1, 7) as j
  on conflict (restaurant_id, jour) do update
    set ouverture = excluded.ouverture, fermeture = excluded.fermeture, ferme = excluded.ferme`;

test('US07 · un responsable modifie le profil et les horaires de son restaurant', async () => {
  await en('zitouna', async () => {
    assert.equal(await nbModifiees(
      `update public.restaurants
       set nom = 'Dar Zitouna Marsa', adresse = '12 rue du Pacha, Tunis', telephone = '+216 71 555 010',
           description = 'Nouvelle carte', logo_url = 'https://exemple.test/logo.webp?v=2'
       where id = $1`, [R_ZITOUNA]), 1);
    await requete(HORAIRES_7_JOURS(R_ZITOUNA));
    const h = await lignes(`select jour, ferme, ouverture::text from public.horaires
                            where restaurant_id = $1 order by jour`, [R_ZITOUNA]);
    assert.equal(h.length, 7);                       // remplacés, pas doublés
    assert.deepEqual(h[0], { jour: 1, ferme: true, ouverture: null });
    assert.deepEqual(h[6], { jour: 7, ferme: false, ouverture: '12:00:00' });
    // l'état reste réservé à l'administrateur
    await assert.rejects(lignes(`update public.restaurants set etat = 'bloque' where id = $1`, [R_ZITOUNA]),
                         /Seul un administrateur/);
  });
});

test('US07 · les modifications sont visibles tout de suite par les visiteurs et les clients', async () => {
  const modification = `
    update public.restaurants set nom = 'Dar Zitouna Marsa' where id = '${R_ZITOUNA}';
    ${HORAIRES_7_JOURS(R_ZITOUNA)};`;
  for (const lecteur of [null, 'amine']) {
    await en(lecteur, async () => {
      assert.deepEqual(await lignes(`select nom from public.restaurants where id = $1`, [R_ZITOUNA]),
                       [{ nom: 'Dar Zitouna Marsa' }]);
      const [{ n }] = await lignes(`select count(*)::int as n from public.horaires
                                    where restaurant_id = $1 and (ferme or ouverture = '12:00')`, [R_ZITOUNA]);
      assert.equal(n, 7);
    }, modification);
  }
});

test('US07 · personne ne modifie le profil ou les horaires d\'un autre restaurant', async () => {
  for (const intrus of ['zitouna', 'amine']) {
    await en(intrus, async () => {
      assert.equal(await nbModifiees(`update public.restaurants set nom = 'Piraté' where id = $1`, [R_KANOUN]), 0);
      assert.equal(await nbModifiees(`update public.horaires set ferme = true where restaurant_id = $1`, [R_KANOUN]), 0);
      assert.equal(await nbModifiees(`delete from public.horaires where restaurant_id = $1`, [R_KANOUN]), 0);
      await assert.rejects(requete(HORAIRES_7_JOURS(R_KANOUN)), RLS);
    });
  }
  await en(null, async () => {
    assert.equal(await nbModifiees(`update public.restaurants set nom = 'Piraté' where id = $1`, [R_KANOUN]), 0);
    assert.equal(await nbModifiees(`update public.horaires set ferme = true where restaurant_id = $1`, [R_KANOUN]), 0);
  });
});

test('US07 · restaurant en attente : profil déjà modifiable, invisible des clients', async () => {
  let restaurant;
  await en('lellabeya', async () => {
    [{ id: restaurant }] = await lignes(`select id from public.restaurants where responsable_id = auth.uid()`);
    assert.equal(await nbModifiees(`update public.restaurants set description = 'Bientôt ouvert' where id = $1`, [restaurant]), 1);
    await requete(HORAIRES_7_JOURS(restaurant));
    const [{ n }] = await lignes(`select count(*)::int as n from public.horaires where restaurant_id = $1`, [restaurant]);
    assert.equal(n, 7);
  });
  await en(null, async () => {
    assert.deepEqual(await lignes(`select id from public.horaires where restaurant_id = $1`, [restaurant]), []);
  }, HORAIRES_7_JOURS(restaurant));
});

test('US07 · un responsable bloqué ne modifie plus son restaurant', async () => {
  await en('zitouna', async () => {
    assert.equal(await nbModifiees(`update public.restaurants set nom = 'X' where id = $1`, [R_ZITOUNA]), 0);
    await assert.rejects(requete(HORAIRES_7_JOURS(R_ZITOUNA)), RLS);
  }, `update public.profiles set etat_compte = 'bloque' where email = 'zitouna@mida.test'`);
});

// =====================================================================
// US08 — ouvrir ou fermer son restaurant en un clic
// =====================================================================
const NOUVELLE_COMMANDE = (restaurant, etat = 'en_attente') => [
  `insert into public.commandes (client_id, restaurant_id, adresse_livraison, etat, sous_total, frais_livraison, total)
   values ($1, $2, '12, rue du Jasmin, La Marsa', '${etat}', 10, 2.5, 12.5)`, [ids.amine, restaurant]];

test('US08 · un responsable ferme et rouvre son restaurant, les clients le voient', async () => {
  await en('zitouna', async () => {
    assert.equal(await nbModifiees(`update public.restaurants set ouvert = false where id = $1`, [R_ZITOUNA]), 1);
    assert.equal(await nbModifiees(`update public.restaurants set ouvert = true where id = $1`, [R_ZITOUNA]), 1);
    // pas l'interrupteur d'un autre restaurant
    assert.equal(await nbModifiees(`update public.restaurants set ouvert = false where id = $1`, [R_KANOUN]), 0);
  });
  for (const lecteur of [null, 'amine']) {
    await en(lecteur, async () => {
      assert.deepEqual(await lignes(`select ouvert from public.restaurants where id = $1`, [R_ZITOUNA]), [{ ouvert: false }]);
    }, `update public.restaurants set ouvert = false where id = '${R_ZITOUNA}'`);
  }
});

test('US08 · seul un restaurant validé peut être ouvert', async () => {
  await en('lellabeya', async () => {
    await assert.rejects(lignes(`update public.restaurants set ouvert = true where responsable_id = auth.uid()`),
                         /validé par Mida/);
    // ses autres informations restent modifiables
    assert.equal(await nbModifiees(`update public.restaurants set description = 'x' where responsable_id = auth.uid()`), 1);
  });
  // même une fonction serveur ne peut pas ouvrir un restaurant non validé : il reste fermé
  await debut();
  try {
    await db.exec('set local role service_role');
    await requete(`update public.restaurants set ouvert = true where nom = 'Lella Béya'`);
    assert.deepEqual(await lignes(`select ouvert from public.restaurants where nom = 'Lella Béya'`), [{ ouvert: false }]);
  } finally {
    await fin();
  }
});

test('US08 · bloquer un restaurant le ferme automatiquement', async () => {
  await en('admin', async () => {
    assert.equal(await nbModifiees(`update public.restaurants set etat = 'bloque' where id = $1`, [R_ZITOUNA]), 1);
    assert.deepEqual(await lignes(`select etat::text, ouvert from public.restaurants where id = $1`, [R_ZITOUNA]),
                     [{ etat: 'bloque', ouvert: false }]);
  });
});

test('US08 · un restaurant fermé n\'accepte plus de nouvelle commande', async () => {
  await debut();
  try {
    await db.exec('set local role service_role');           // comme la future fonction « passer commande »
    await requete(...NOUVELLE_COMMANDE(R_ZITOUNA));           // ouvert : acceptée
    await requete(`update public.restaurants set ouvert = false where id = $1`, [R_ZITOUNA]);
    await assert.rejects(requete(...NOUVELLE_COMMANDE(R_ZITOUNA)), /restaurant est fermé/);
    // un restaurant non validé non plus
    const [{ id: beya }] = await lignes(`select id from public.restaurants where nom = 'Lella Béya'`);
    await assert.rejects(requete(...NOUVELLE_COMMANDE(beya)), /restaurant est fermé/);
    // les commandes déjà passées continuent leur vie après la fermeture
    assert.equal(await nbModifiees(`update public.commandes set etat = 'acceptee', acceptee_le = now() where numero = 1045`), 1);
  } finally {
    await fin();
  }
});

// =====================================================================
// US09 — catégories du menu
// =====================================================================
const M_Z_COUSCOUS = '30000000-0000-4000-8000-000000000001';   // Dar Zitouna, contient des plats
const M_K_OJJA = '30000000-0000-4000-8000-000000000005';       // El Kanoun
const categoriesDe = async (restaurant) =>
  (await lignes(`select nom from public.categories_menu where restaurant_id = $1 order by ordre, nom`, [restaurant])).map((c) => c.nom);

test('US09 · un responsable crée, renomme et ordonne les catégories de son menu', async () => {
  await en('zitouna', async () => {
    const avant = await categoriesDe(R_ZITOUNA);
    await requete(`insert into public.categories_menu (restaurant_id, nom, ordre) values ($1, 'Boissons', 99)`, [R_ZITOUNA]);
    assert.deepEqual(await categoriesDe(R_ZITOUNA), [...avant, 'Boissons']);
    // deux catégories du même menu ne portent pas le même nom
    await assert.rejects(requete(`insert into public.categories_menu (restaurant_id, nom) values ($1, 'Boissons')`, [R_ZITOUNA]),
                         /unique|duplicate/i);
    assert.equal(await nbModifiees(`update public.categories_menu set nom = 'Boissons fraîches'
                                    where restaurant_id = $1 and nom = 'Boissons'`, [R_ZITOUNA]), 1);
    // nouvel ordre enregistré d'un coup (ce que fait l'espace restaurant) : « Boissons fraîches » en premier
    await requete(`insert into public.categories_menu (id, restaurant_id, nom, ordre)
                   select id, restaurant_id, nom, case when nom = 'Boissons fraîches' then 0 else ordre end
                   from public.categories_menu where restaurant_id = $1
                   on conflict (id) do update set ordre = excluded.ordre`, [R_ZITOUNA]);
    assert.deepEqual(await categoriesDe(R_ZITOUNA), ['Boissons fraîches', ...avant]);
  });
});

test('US09 · supprimer une catégorie : vide directement, avec ses plats par la fonction dédiée', async () => {
  await en('zitouna', async () => {
    // catégorie vide : suppression simple
    await requete(`insert into public.categories_menu (restaurant_id, nom) values ($1, 'Vide')`, [R_ZITOUNA]);
    assert.equal(await nbModifiees(`delete from public.categories_menu where restaurant_id = $1 and nom = 'Vide'`, [R_ZITOUNA]), 1);
    // catégorie avec des plats : la suppression simple est refusée…
    const [{ n: plats }] = await lignes(`select count(*)::int as n from public.plats where categorie_id = $1`, [M_Z_COUSCOUS]);
    assert.ok(plats > 0);
    await assert.rejects(lignes(`delete from public.categories_menu where id = $1`, [M_Z_COUSCOUS]), /foreign key/i);
    // … la fonction (appelée après confirmation) supprime les plats puis la catégorie
    const [{ supprimes }] = await lignes(`select public.supprimer_categorie_menu($1) as supprimes`, [M_Z_COUSCOUS]);
    assert.equal(supprimes, plats);
    assert.deepEqual(await lignes(`select id from public.categories_menu where id = $1`, [M_Z_COUSCOUS]), []);
    assert.deepEqual(await lignes(`select id from public.plats where categorie_id = $1`, [M_Z_COUSCOUS]), []);
  });
  // les commandes déjà passées gardent le nom et le prix des plats supprimés
  await debut();
  try {
    const [{ n: avant }] = await lignes(`select count(*)::int as n from public.lignes_commande`);
    await db.query("select set_config('request.jwt.claim.sub', $1, true)", [ids.zitouna]);
    await db.exec('set local role authenticated');
    await requete(`select public.supprimer_categorie_menu($1)`, [M_Z_COUSCOUS]);
    await db.exec('reset role');
    const [{ n: apres, sans_plat }] = await lignes(`select count(*)::int as n, count(*) filter (where plat_id is null)::int as sans_plat
                                                    from public.lignes_commande`);
    assert.equal(apres, avant);
    assert.ok(sans_plat > 0);
  } finally {
    await fin();
  }
});

test('US09 · personne ne touche aux catégories d\'un autre restaurant', async () => {
  for (const intrus of ['zitouna', 'amine']) {
    await en(intrus, async () => {
      await assert.rejects(requete(`insert into public.categories_menu (restaurant_id, nom) values ($1, 'Pirate')`, [R_KANOUN]), RLS);
      assert.equal(await nbModifiees(`update public.categories_menu set nom = 'Pirate' where id = $1`, [M_K_OJJA]), 0);
      assert.equal(await nbModifiees(`delete from public.categories_menu where id = $1`, [M_K_OJJA]), 0);
      await assert.rejects(lignes(`select public.supprimer_categorie_menu($1)`, [M_K_OJJA]), /pas le droit/);
    });
  }
  // un visiteur ne peut pas appeler la fonction
  await en(null, async () => {
    await assert.rejects(lignes(`select public.supprimer_categorie_menu($1)`, [M_K_OJJA]), /permission denied/);
  });
  // rien n'a été supprimé
  const [{ n }] = await lignes(`select count(*)::int as n from public.categories_menu where id = $1`, [M_K_OJJA]);
  assert.equal(n, 1);
});

test('US09 · le menu est lu dans l\'ordre choisi ; celui d\'un restaurant en attente reste privé', async () => {
  for (const lecteur of [null, 'amine']) {
    await en(lecteur, async () => {
      assert.deepEqual((await categoriesDe(R_ZITOUNA))[0], 'Nouveautés');
      assert.deepEqual(await lignes(`select c.id from public.categories_menu c
                                     join public.restaurants r on r.id = c.restaurant_id where r.nom = 'Lella Béya'`), []);
    }, `insert into public.categories_menu (restaurant_id, nom, ordre) values ('${R_ZITOUNA}', 'Nouveautés', -1);
        insert into public.categories_menu (restaurant_id, nom)
        select id, 'En préparation' from public.restaurants where nom = 'Lella Béya';`);
  }
  // le responsable en attente prépare déjà son menu
  await en('lellabeya', async () => {
    await requete(`insert into public.categories_menu (restaurant_id, nom)
                   select id, 'Poissons du jour' from public.restaurants where responsable_id = auth.uid()`);
    const [{ n }] = await lignes(`select count(*)::int as n from public.categories_menu c
                                  join public.restaurants r on r.id = c.restaurant_id where r.responsable_id = auth.uid()`);
    assert.ok(n >= 1);
  });
});
