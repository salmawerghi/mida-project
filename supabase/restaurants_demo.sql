-- =====================================================================
-- Mida — 8 restaurants de démonstration (comptes, horaires, menus)
-- ---------------------------------------------------------------------
-- Ajoutés à la demande de l'utilisateur le 18/11/2026 pour remplir le
-- catalogue, SANS le reste de seed.sql (pas de clients, commandes ni
-- changement des paramètres de la plateforme).
--
-- * Responsables : <compte>@mida.test, mot de passe commun Mida2026!
-- * Les 4 restaurants des maquettes reprennent les identifiants de
--   seed.sql (comptes e0…01-04, restaurants 10…01-04, menus et plats) :
--   lancer seed.sql plus tard ne crée pas de doublon.
-- * Catégories : celles créées dans le tableau de bord admin (« Salé »,
--   « Sucré »), retrouvées par leur nom (créées si absentes).
-- * Comptes et restaurants déjà validés (actif), comme après une
--   décision de l'administrateur.
-- * Les images (logos, plats) sont envoyées ensuite dans le stockage
--   par le script supabase/images_demo/ (voir le README).
-- Peut être relancé sans erreur ni doublon.
-- =====================================================================

-- 1. Comptes des responsables -----------------------------------------
-- Le déclencheur d'inscription crée le profil (rôle responsable, en attente).
with comptes (id, email, meta) as (
  values
    ('e0000000-0000-4000-8000-000000000001'::uuid, 'zitouna@mida.test',    '{"role": "responsable", "nom": "Mehdi Ben Salem",  "telephone": "+216 71 742 100"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000002'::uuid, 'kanoun@mida.test',     '{"role": "responsable", "nom": "Sonia Gharbi",     "telephone": "+216 71 911 230"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000003'::uuid, 'babsouika@mida.test',  '{"role": "responsable", "nom": "Hichem Trabelsi",  "telephone": "+216 71 560 884"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000004'::uuid, 'lellabeya@mida.test',  '{"role": "responsable", "nom": "Béya Ayari",       "telephone": "+216 71 740 552"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000005'::uuid, 'ennakhla@mida.test',   '{"role": "responsable", "nom": "Rim Haddad",       "telephone": "+216 70 855 214"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000006'::uuid, 'chapati@mida.test',    '{"role": "responsable", "nom": "Walid Jebali",     "telephone": "+216 71 820 337"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000007'::uuid, 'koffa@mida.test',      '{"role": "responsable", "nom": "Najet Ben Amor",   "telephone": "+216 71 588 902"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000008'::uuid, 'sidimahrez@mida.test', '{"role": "responsable", "nom": "Fethi Zouari",     "telephone": "+216 71 563 418"}'::jsonb)
),
nouveaux as (
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  )
  select
    '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email,
    extensions.crypt('Mida2026!', extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}'::jsonb, meta, now(), now(),
    '', '', '', ''
  from comptes
  where not exists (select 1 from auth.users u where u.email = comptes.email)
  on conflict (id) do nothing
  returning id, email
)
insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), id, id::text,
       jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true),
       'email', now(), now(), now()
from nouveaux;

-- 2. Restaurants, horaires, menus --------------------------------------
do $$
declare
  u uuid[] := array(
    select u.id from unnest(array['zitouna', 'kanoun', 'babsouika', 'lellabeya',
                                  'ennakhla', 'chapati', 'koffa', 'sidimahrez']) with ordinality as c(nom, rang)
    join auth.users u on u.email = c.nom || '@mida.test'
    order by c.rang);
  k_sale  uuid;
  k_sucre uuid;
  r uuid[] := array[
    '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000008']::uuid[];
begin
  if array_length(u, 1) is distinct from 8 then
    raise exception 'Comptes des responsables introuvables (partie 1)';
  end if;

  select id into k_sale  from public.categories_restaurant where nom = 'Salé';
  if k_sale is null then
    insert into public.categories_restaurant (nom, ordre) values ('Salé', 1) returning id into k_sale;
  end if;
  select id into k_sucre from public.categories_restaurant where nom = 'Sucré';
  if k_sucre is null then
    insert into public.categories_restaurant (nom, ordre) values ('Sucré', 2) returning id into k_sucre;
  end if;

  -- Comptes validés par l'administrateur
  update public.profiles set etat_compte = 'actif' where id = any (u) and etat_compte <> 'actif';

  insert into public.restaurants (id, responsable_id, categorie_id, nom, description, telephone, adresse, ville,
                                  latitude, longitude, etat, ouvert, temps_preparation_min) values
    (r[1], u[1], k_sale,  'Dar Zitouna', 'Couscous, tajines et cuisine maison comme à la médina.',
     '+216 71 742 100', '8, rue Habib Bourguiba', 'La Marsa', 36.8782, 10.3247, 'actif', true, 25),
    (r[2], u[2], k_sale,  'El Kanoun', 'Ojja, grillades au feu de bois et merguez maison.',
     '+216 71 911 230', '3, avenue de la Corniche', 'Gammarth', 36.9170, 10.2870, 'actif', true, 20),
    (r[3], u[3], k_sale,  'Brik Bab Souika', 'Briks croustillantes et fricassés depuis 1987.',
     '+216 71 560 884', 'Place Bab Souika', 'Tunis', 36.8065, 10.1700, 'actif', false, 15),
    (r[4], u[4], k_sale,  'Lella Béya', 'Cuisine tunisienne et poissons du jour, face à la mer.',
     '+216 71 740 552', '15, rue Sidi Dhrif', 'Sidi Bou Saïd', 36.8687, 10.3416, 'actif', true, 30),
    (r[5], u[5], k_sucre, 'Pâtisserie Ennakhla', 'Bambalouni chaud, makroudh et douceurs tunisiennes faites maison.',
     '+216 70 855 214', '22, avenue Habib Bourguiba', 'Ariana', 36.8601, 10.1934, 'actif', true, 10),
    (r[6], u[6], k_sale,  'Chapati Ennasr', 'Chapati, mlawi et makloub garnis à la minute.',
     '+216 71 820 337', '5, rue Hédi Nouira', 'Ennasr', 36.8566, 10.1631, 'actif', true, 15),
    (r[7], u[7], k_sale,  'Koffa du Bardo', 'Les plats de grand-mère : couscous du vendredi, tajine malsouka, ojja.',
     '+216 71 588 902', '41, avenue Habib Bourguiba', 'Le Bardo', 36.8092, 10.1340, 'actif', true, 25),
    (r[8], u[8], k_sucre, 'Café Sidi Mahrez', 'Thé aux pignons et douceurs de la médina, dans un ancien café maure.',
     '+216 71 563 418', '12, place Sidi Mahrez', 'Tunis', 36.8015, 10.1700, 'actif', true, 10)
  on conflict (id) do nothing;

  -- Horaires (jour 1 = lundi … 7 = dimanche) : 11 h – 23 h ;
  -- pâtisserie et café 8 h – 22 h ; El Kanoun fermé le lundi.
  insert into public.horaires (restaurant_id, jour, ouverture, fermeture, ferme)
  select rid, j.jour,
         case when rid = r[2] and j.jour = 1 then null
              when rid in (r[5], r[8]) then time '08:00' else time '11:00' end,
         case when rid = r[2] and j.jour = 1 then null
              when rid in (r[5], r[8]) then time '22:00' else time '23:00' end,
         (rid = r[2] and j.jour = 1)
  from unnest(r) as rid
  cross join generate_series(1, 7) as j(jour)
  on conflict (restaurant_id, jour) do nothing;

  -- Catégories du menu (identifiants 30…01-08 repris de seed.sql)
  insert into public.categories_menu (id, restaurant_id, nom, ordre) values
    ('30000000-0000-4000-8000-000000000001', r[1], 'Couscous',          1),
    ('30000000-0000-4000-8000-000000000002', r[1], 'Tajines',           2),
    ('30000000-0000-4000-8000-000000000003', r[1], 'Entrées',           3),
    ('30000000-0000-4000-8000-000000000004', r[1], 'Thé',               4),
    ('30000000-0000-4000-8000-000000000005', r[2], 'Ojja',              1),
    ('30000000-0000-4000-8000-000000000006', r[2], 'Grillades',         2),
    ('30000000-0000-4000-8000-000000000007', r[3], 'Briks',             1),
    ('30000000-0000-4000-8000-000000000008', r[3], 'Fricassés',         2),
    ('30000000-0000-4000-8000-000000000009', r[4], 'Poissons',          1),
    ('30000000-0000-4000-8000-000000000010', r[4], 'Boissons',          2),
    ('30000000-0000-4000-8000-000000000011', r[5], 'Beignets',          1),
    ('30000000-0000-4000-8000-000000000012', r[5], 'Gâteaux tunisiens', 2),
    ('30000000-0000-4000-8000-000000000013', r[5], 'Boissons',          3),
    ('30000000-0000-4000-8000-000000000014', r[6], 'Sandwichs',         1),
    ('30000000-0000-4000-8000-000000000015', r[6], 'Boissons',          2),
    ('30000000-0000-4000-8000-000000000016', r[7], 'Plats du jour',     1),
    ('30000000-0000-4000-8000-000000000017', r[7], 'Entrées',           2),
    ('30000000-0000-4000-8000-000000000018', r[8], 'Thés',              1),
    ('30000000-0000-4000-8000-000000000019', r[8], 'Douceurs',          2)
  on conflict (id) do nothing;

  -- Plats (identifiants 40…01-13 repris de seed.sql)
  insert into public.plats (id, restaurant_id, categorie_id, nom, description, prix, disponible) values
    -- Dar Zitouna
    ('40000000-0000-4000-8000-000000000001', r[1], '30000000-0000-4000-8000-000000000001', 'Couscous à l''agneau', 'Semoule fine, agneau, pois chiches, légumes de saison', 18.000, true),
    ('40000000-0000-4000-8000-000000000002', r[1], '30000000-0000-4000-8000-000000000001', 'Couscous aux légumes', 'Carottes, courgettes, navets, potiron, harissa maison', 13.000, true),
    ('40000000-0000-4000-8000-000000000003', r[1], '30000000-0000-4000-8000-000000000001', 'Couscous au poisson', 'Mérou, sauce rouge épicée, piments frits', 22.000, false),
    ('40000000-0000-4000-8000-000000000004', r[1], '30000000-0000-4000-8000-000000000002', 'Tajine de poulet aux olives', 'Œufs, fromage, poulet et persil, cuit au four', 16.000, true),
    ('40000000-0000-4000-8000-000000000005', r[1], '30000000-0000-4000-8000-000000000003', 'Brik à l''œuf', 'Feuille de malsouka, œuf coulant, thon et câpres', 4.500, true),
    ('40000000-0000-4000-8000-000000000006', r[1], '30000000-0000-4000-8000-000000000003', 'Salade méchouia', 'Poivrons et tomates grillés, thon, œuf dur', 6.000, true),
    ('40000000-0000-4000-8000-000000000007', r[1], '30000000-0000-4000-8000-000000000004', 'Thé à la menthe', 'Thé vert à la menthe fraîche et aux pignons', 2.500, true),
    -- El Kanoun
    ('40000000-0000-4000-8000-000000000008', r[2], '30000000-0000-4000-8000-000000000005', 'Ojja merguez', 'Sauce tomate pimentée, œufs, merguez maison', 12.000, true),
    ('40000000-0000-4000-8000-000000000009', r[2], '30000000-0000-4000-8000-000000000005', 'Ojja aux crevettes', 'Crevettes, sauce tomate, harissa, œufs', 16.000, true),
    ('40000000-0000-4000-8000-000000000010', r[2], '30000000-0000-4000-8000-000000000006', 'Grillade mixte', 'Agneau, poulet, merguez, salade et frites', 24.000, true),
    ('40000000-0000-4000-8000-000000000014', r[2], '30000000-0000-4000-8000-000000000006', 'Côtelettes d''agneau', 'Grillées au feu de bois, salade tunisienne', 26.000, true),
    -- Brik Bab Souika
    ('40000000-0000-4000-8000-000000000011', r[3], '30000000-0000-4000-8000-000000000007', 'Brik à l''œuf', 'La brik traditionnelle de Bab Souika', 4.000, true),
    ('40000000-0000-4000-8000-000000000012', r[3], '30000000-0000-4000-8000-000000000007', 'Brik au thon', 'Thon, œuf, persil et câpres', 5.000, true),
    ('40000000-0000-4000-8000-000000000013', r[3], '30000000-0000-4000-8000-000000000008', 'Fricassé', 'Pain frit, thon, olives, harissa et pomme de terre', 2.500, true),
    ('40000000-0000-4000-8000-000000000015', r[3], '30000000-0000-4000-8000-000000000007', 'Brik aux crevettes', 'Crevettes, fromage, persil, œuf', 6.500, true),
    -- Lella Béya
    ('40000000-0000-4000-8000-000000000016', r[4], '30000000-0000-4000-8000-000000000009', 'Couscous au mérou', 'Mérou de Kélibia, sauce rouge, coings et piments', 28.000, true),
    ('40000000-0000-4000-8000-000000000017', r[4], '30000000-0000-4000-8000-000000000009', 'Ojja aux fruits de mer', 'Calamars, crevettes et moules, œufs, harissa douce', 22.000, true),
    ('40000000-0000-4000-8000-000000000018', r[4], '30000000-0000-4000-8000-000000000009', 'Tajine de poisson', 'Daurade, œufs, fromage et persil', 19.000, true),
    ('40000000-0000-4000-8000-000000000019', r[4], '30000000-0000-4000-8000-000000000010', 'Thé aux pignons', 'Thé rouge et pignons de pin grillés', 4.000, true),
    -- Pâtisserie Ennakhla
    ('40000000-0000-4000-8000-000000000020', r[5], '30000000-0000-4000-8000-000000000011', 'Bambalouni', 'Beignet chaud saupoudré de sucre, comme à Sidi Bou Saïd', 1.500, true),
    ('40000000-0000-4000-8000-000000000021', r[5], '30000000-0000-4000-8000-000000000011', 'Bambalouni au miel', 'Arrosé de miel de thym et de sésame grillé', 2.500, true),
    ('40000000-0000-4000-8000-000000000022', r[5], '30000000-0000-4000-8000-000000000012', 'Makroudh (6 pièces)', 'Semoule, pâte de dattes, trempé dans le sirop', 7.000, true),
    ('40000000-0000-4000-8000-000000000023', r[5], '30000000-0000-4000-8000-000000000012', 'Baklawa (6 pièces)', 'Feuilles fines, amandes et pistaches, sirop au géranium', 12.000, true),
    ('40000000-0000-4000-8000-000000000024', r[5], '30000000-0000-4000-8000-000000000013', 'Thé à la menthe', 'Thé vert à la menthe fraîche', 2.000, true),
    -- Chapati Ennasr
    ('40000000-0000-4000-8000-000000000025', r[6], '30000000-0000-4000-8000-000000000014', 'Chapati thon fromage', 'Thon, œuf, fromage fondu, harissa et salade méchouia', 6.500, true),
    ('40000000-0000-4000-8000-000000000026', r[6], '30000000-0000-4000-8000-000000000014', 'Mlawi escalope', 'Galette feuilletée, escalope grillée, frites et sauce', 8.000, true),
    ('40000000-0000-4000-8000-000000000027', r[6], '30000000-0000-4000-8000-000000000014', 'Makloub poulet', 'Pâte à pizza pliée, poulet, fromage, olives', 9.000, true),
    ('40000000-0000-4000-8000-000000000028', r[6], '30000000-0000-4000-8000-000000000015', 'Citronnade maison', 'Citron pressé, menthe et eau de fleur d''oranger', 3.500, true),
    -- Koffa du Bardo
    ('40000000-0000-4000-8000-000000000029', r[7], '30000000-0000-4000-8000-000000000016', 'Couscous au poulet', 'Le couscous du vendredi, poulet fermier et légumes', 15.000, true),
    ('40000000-0000-4000-8000-000000000030', r[7], '30000000-0000-4000-8000-000000000016', 'Tajine malsouka', 'Poulet, œufs et fromage entre deux feuilles croustillantes', 14.000, true),
    ('40000000-0000-4000-8000-000000000031', r[7], '30000000-0000-4000-8000-000000000016', 'Ojja merguez', 'Œufs, merguez, piments et sauce tomate', 11.000, true),
    ('40000000-0000-4000-8000-000000000032', r[7], '30000000-0000-4000-8000-000000000016', 'Mida familiale (4 pers.)', 'Couscous, tajine, briks et salade méchouia à partager', 48.000, true),
    ('40000000-0000-4000-8000-000000000033', r[7], '30000000-0000-4000-8000-000000000017', 'Brik à l''œuf', 'Malsouka, œuf, thon, persil', 4.000, true),
    -- Café Sidi Mahrez
    ('40000000-0000-4000-8000-000000000034', r[8], '30000000-0000-4000-8000-000000000018', 'Thé aux pignons', 'Thé rouge infusé longuement, pignons de pin', 4.500, true),
    ('40000000-0000-4000-8000-000000000035', r[8], '30000000-0000-4000-8000-000000000018', 'Thé à la menthe', 'Menthe fraîche du jardin', 2.500, true),
    ('40000000-0000-4000-8000-000000000036', r[8], '30000000-0000-4000-8000-000000000019', 'Bambalouni', 'Beignet tunisien tout chaud', 1.500, true),
    ('40000000-0000-4000-8000-000000000037', r[8], '30000000-0000-4000-8000-000000000019', 'Assida zgougou', 'Crème de pin d''Alep, amandes et pistaches', 9.000, true)
  on conflict (id) do nothing;
end
$$;
