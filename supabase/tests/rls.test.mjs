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

/** Exécute fn en tant qu'utilisateur (ou visiteur si email = null), puis annule tout. */
async function en(utilisateur, fn) {
  await debut();

  try {
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
