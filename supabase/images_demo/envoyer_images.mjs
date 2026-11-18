// Logos et photos des 8 restaurants de démonstration (supabase/restaurants_demo.sql)
// à partir des illustrations Mida : image générée (WebP), envoyée dans le
// bucket « restaurants » EN SE CONNECTANT avec le compte de chaque
// responsable (les règles d'accès du stockage s'appliquent comme dans
// l'appli web), puis logo_url / image_url mis à jour par l'API.
// Lancement : cd supabase/images_demo && npm install && npm run envoyer
import sharp from 'sharp';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ici = dirname(fileURLToPath(import.meta.url));
const URL_SUPABASE = 'https://tpfpuwlgnxhwhezicuto.supabase.co';
const CLE = 'sb_publishable_xxD9ZnF7RkGUTpX1tT1flA_iO0fa0pk'; // clé publique (celle des applis)
const MOT_DE_PASSE = 'Mida2026!';

const restaurants = [
  { compte: 'zitouna',    id: '10000000-0000-4000-8000-000000000001', couleur: '#1554C0', logo: 'couscous' },
  { compte: 'kanoun',     id: '10000000-0000-4000-8000-000000000002', couleur: '#C93A22', logo: 'ojja' },
  { compte: 'babsouika',  id: '10000000-0000-4000-8000-000000000003', couleur: '#F2B233', logo: 'brik' },
  { compte: 'lellabeya',  id: '10000000-0000-4000-8000-000000000004', couleur: '#0E7C86', logo: 'tajine' },
  { compte: 'ennakhla',   id: '10000000-0000-4000-8000-000000000005', couleur: '#D9577A', logo: 'bambalouni' },
  { compte: 'chapati',    id: '10000000-0000-4000-8000-000000000006', couleur: '#E07B1F', logo: 'brik' },
  { compte: 'koffa',      id: '10000000-0000-4000-8000-000000000007', couleur: '#5E7F2A', logo: 'koffa' },
  { compte: 'sidimahrez', id: '10000000-0000-4000-8000-000000000008', couleur: '#0F1B33', logo: 'the' },
];

/** Illustration qui correspond le mieux au nom du plat. */
function illustration(nom) {
  const n = nom.toLowerCase();
  const regles = [
    [/couscous/, 'couscous'], [/tajine/, 'tajine'], [/ojja/, 'ojja'],
    [/brik|fricass|chapati|mlawi|makloub/, 'brik'],
    [/thé|citronnade/, 'the'],
    [/bambalouni|makroudh|baklawa|assida/, 'bambalouni'],
  ];
  return regles.find(([re]) => re.test(n))?.[1] ?? 'mida';
}

const svg = (nom) => {
  const local = join(ici, `${nom}.svg`);
  try { return readFileSync(local); } catch { return readFileSync(join(ici, '../../apps/client/assets/illustrations', `${nom}.svg`)); }
};

/** Teinte claire de la couleur du restaurant (fond des photos de plats). */
function teinte(hex, part = 0.86) {
  const v = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
  return '#' + v.map((c) => Math.round(c + (255 - c) * part).toString(16).padStart(2, '0')).join('');
}

async function dessin(nom, taille) {
  return sharp(svg(nom), { density: 300 }).resize(taille, taille, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } }).png().toBuffer();
}

async function imagePlat(nom, couleur) {
  return sharp({ create: { width: 600, height: 600, channels: 4, background: teinte(couleur) } })
    .composite([{ input: await dessin(illustration(nom), 470), gravity: 'center' }])
    .webp({ quality: 86 }).toBuffer();
}

async function imageLogo(nomIllustration, couleur) {
  const rond = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><circle cx="256" cy="256" r="210" fill="#ffffff"/></svg>`);
  return sharp({ create: { width: 512, height: 512, channels: 4, background: couleur } })
    .composite([{ input: rond }, { input: await dessin(nomIllustration, 300), gravity: 'center' }])
    .webp({ quality: 88 }).toBuffer();
}

async function api(chemin, options = {}, jeton) {
  const r = await fetch(URL_SUPABASE + chemin, {
    ...options,
    headers: { apikey: CLE, ...(jeton ? { Authorization: `Bearer ${jeton}` } : {}), ...options.headers },
  });
  if (!r.ok) throw new Error(`${options.method ?? 'GET'} ${chemin} → ${r.status} ${await r.text()}`);
  return r.status === 204 ? null : r.json().catch(() => null);
}

async function envoyer(jeton, chemin, octets) {
  await api(`/storage/v1/object/restaurants/${chemin}`, {
    method: 'POST', body: octets, headers: { 'Content-Type': 'image/webp', 'x-upsert': 'true' },
  }, jeton);
  return `${URL_SUPABASE}/storage/v1/object/public/restaurants/${chemin}?v=${Date.now()}`;
}

// --apercu : quelques images dans un dossier, sans rien envoyer
if (process.argv[2] === '--apercu') {
  const { writeFileSync, mkdirSync } = await import('node:fs');
  const dossier = process.argv[3] ?? join(ici, 'apercu');
  mkdirSync(dossier, { recursive: true });
  for (const r of restaurants) writeFileSync(join(dossier, `logo-${r.compte}.webp`), await imageLogo(r.logo, r.couleur));
  for (const [nom, couleur] of [['Couscous à l\x27agneau', '#1554C0'], ['Ojja merguez', '#C93A22'], ['Makroudh', '#D9577A'], ['Grillade mixte', '#C93A22']])
    writeFileSync(join(dossier, `plat-${illustration(nom)}.webp`), await imagePlat(nom, couleur));
  process.exit(0);
}

for (const r of restaurants) {
  const { access_token: jeton } = await api('/auth/v1/token?grant_type=password', {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: `${r.compte}@mida.test`, password: MOT_DE_PASSE }),
  });
  const logo = await envoyer(jeton, `${r.id}/logo.webp`, await imageLogo(r.logo, r.couleur));
  await api(`/rest/v1/restaurants?id=eq.${r.id}`, {
    method: 'PATCH', headers: { 'Content-Type': 'application/json', Prefer: 'return=minimal' }, body: JSON.stringify({ logo_url: logo }),
  }, jeton);
  const plats = await api(`/rest/v1/plats?restaurant_id=eq.${r.id}&select=id,nom`, {}, jeton);
  for (const p of plats) {
    const url = await envoyer(jeton, `${r.id}/plats/${p.id}.webp`, await imagePlat(p.nom, r.couleur));
    await api(`/rest/v1/plats?id=eq.${p.id}`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json', Prefer: 'return=minimal' }, body: JSON.stringify({ image_url: url }),
    }, jeton);
  }
  await api('/auth/v1/logout', { method: 'POST' }, jeton);
  console.log(`${r.compte} : logo + ${plats.length} plats`);
}
