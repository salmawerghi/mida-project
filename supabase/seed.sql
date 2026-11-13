-- =====================================================================
-- Mida — jeu de données de test (US01)
-- Reprend les données des maquettes : Dar Zitouna, El Kanoun,
-- commande n° 1042 d'Amine Belhadj, livreur Sami…
--
-- ⚠ Comptes de démonstration uniquement. Mot de passe commun : Mida2026!
--   Ne jamais exécuter ce fichier sur une base de production.
--
-- Exécution : automatiquement par `supabase db reset` (CLI), ou en
-- collant ce fichier dans le SQL Editor du tableau de bord Supabase
-- APRÈS les deux migrations. Il peut être relancé sans erreur.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Comptes d'authentification
-- ---------------------------------------------------------------------
-- Le déclencheur creer_profil_apres_inscription crée le profil (et la
-- fiche livreur) à partir de raw_user_meta_data, comme pour une vraie
-- inscription depuis une application.
with comptes (id, email, meta) as (
  values
    ('a0000000-0000-4000-8000-000000000001'::uuid, 'admin@mida.test',      '{"nom": "Administrateur Mida", "telephone": "+216 71 000 000"}'::jsonb),
    ('c0000000-0000-4000-8000-000000000001'::uuid, 'amine@mida.test',      '{"role": "client", "nom": "Amine Belhadj",  "telephone": "+216 22 145 870"}'::jsonb),
    ('c0000000-0000-4000-8000-000000000002'::uuid, 'leila@mida.test',      '{"role": "client", "nom": "Leïla Mansour",  "telephone": "+216 98 220 431"}'::jsonb),
    ('c0000000-0000-4000-8000-000000000003'::uuid, 'youssef@mida.test',    '{"role": "client", "nom": "Youssef Karray", "telephone": "+216 50 774 019"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000001'::uuid, 'zitouna@mida.test',    '{"role": "responsable", "nom": "Mehdi Ben Salem",  "telephone": "+216 71 742 100"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000002'::uuid, 'kanoun@mida.test',     '{"role": "responsable", "nom": "Sonia Gharbi",     "telephone": "+216 71 911 230"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000003'::uuid, 'babsouika@mida.test',  '{"role": "responsable", "nom": "Hichem Trabelsi",  "telephone": "+216 71 560 884"}'::jsonb),
    ('e0000000-0000-4000-8000-000000000004'::uuid, 'lellabeya@mida.test',  '{"role": "responsable", "nom": "Béya Ayari",       "telephone": "+216 71 740 552"}'::jsonb),
    ('d0000000-0000-4000-8000-000000000001'::uuid, 'sami@mida.test',       '{"role": "livreur", "nom": "Sami Ben Salah", "telephone": "+216 55 310 204"}'::jsonb),
    ('d0000000-0000-4000-8000-000000000002'::uuid, 'karim@mida.test',      '{"role": "livreur", "nom": "Karim Dridi",    "telephone": "+216 24 880 615"}'::jsonb),
    ('d0000000-0000-4000-8000-000000000003'::uuid, 'yassine@mida.test',    '{"role": "livreur", "nom": "Yassine Mejri",  "telephone": "+216 29 117 930"}'::jsonb)
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
  on conflict (id) do nothing
  returning id, email
)
insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select gen_random_uuid(), id, id::text,
       jsonb_build_object('sub', id::text, 'email', email, 'email_verified', true),
       'email', now(), now(), now()
from nouveaux;

-- ---------------------------------------------------------------------
-- 2. Données métier
-- ---------------------------------------------------------------------
do $$
declare
  -- comptes (retrouvés par e-mail : fonctionne aussi si les comptes ont été
  -- créés à la main dans Authentication → Users avec les mêmes adresses)
  u_admin   uuid := (select id from auth.users where email = 'admin@mida.test');
  u_amine   uuid := (select id from auth.users where email = 'amine@mida.test');
  u_leila   uuid := (select id from auth.users where email = 'leila@mida.test');
  u_youssef uuid := (select id from auth.users where email = 'youssef@mida.test');
  u_zitouna uuid := (select id from auth.users where email = 'zitouna@mida.test');
  u_kanoun  uuid := (select id from auth.users where email = 'kanoun@mida.test');
  u_souika  uuid := (select id from auth.users where email = 'babsouika@mida.test');
  u_beya    uuid := (select id from auth.users where email = 'lellabeya@mida.test');
  u_sami    uuid := (select id from auth.users where email = 'sami@mida.test');
  u_karim   uuid := (select id from auth.users where email = 'karim@mida.test');
  u_yassine uuid := (select id from auth.users where email = 'yassine@mida.test');

  -- restaurants
  r_zitouna uuid := '10000000-0000-4000-8000-000000000001';
  r_kanoun  uuid := '10000000-0000-4000-8000-000000000002';
  r_souika  uuid := '10000000-0000-4000-8000-000000000003';
  r_beya    uuid := '10000000-0000-4000-8000-000000000004';

  -- catégories de restaurants
  k_couscous uuid := '20000000-0000-4000-8000-000000000001';
  k_grill    uuid := '20000000-0000-4000-8000-000000000002';
  k_street   uuid := '20000000-0000-4000-8000-000000000003';
  k_sucre    uuid := '20000000-0000-4000-8000-000000000004';
  k_poisson  uuid := '20000000-0000-4000-8000-000000000005';

  -- catégories de menu
  m_z_couscous uuid := '30000000-0000-4000-8000-000000000001';
  m_z_tajines  uuid := '30000000-0000-4000-8000-000000000002';
  m_z_entrees  uuid := '30000000-0000-4000-8000-000000000003';
  m_z_the      uuid := '30000000-0000-4000-8000-000000000004';
  m_k_ojja     uuid := '30000000-0000-4000-8000-000000000005';
  m_k_grill    uuid := '30000000-0000-4000-8000-000000000006';
  m_s_briks    uuid := '30000000-0000-4000-8000-000000000007';
  m_s_fricasse uuid := '30000000-0000-4000-8000-000000000008';

  -- plats
  p_cous_agneau  uuid := '40000000-0000-4000-8000-000000000001';
  p_cous_legumes uuid := '40000000-0000-4000-8000-000000000002';
  p_cous_poisson uuid := '40000000-0000-4000-8000-000000000003';
  p_tajine       uuid := '40000000-0000-4000-8000-000000000004';
  p_brik_z       uuid := '40000000-0000-4000-8000-000000000005';
  p_mechouia     uuid := '40000000-0000-4000-8000-000000000006';
  p_the          uuid := '40000000-0000-4000-8000-000000000007';
  p_ojja_merguez uuid := '40000000-0000-4000-8000-000000000008';
  p_ojja_crev    uuid := '40000000-0000-4000-8000-000000000009';
  p_grillade     uuid := '40000000-0000-4000-8000-000000000010';
  p_brik_oeuf    uuid := '40000000-0000-4000-8000-000000000011';
  p_brik_thon    uuid := '40000000-0000-4000-8000-000000000012';
  p_fricasse     uuid := '40000000-0000-4000-8000-000000000013';

  -- adresses
  a_amine_maison  uuid := '50000000-0000-4000-8000-000000000001';
  a_amine_travail uuid := '50000000-0000-4000-8000-000000000002';
  a_leila         uuid := '50000000-0000-4000-8000-000000000003';
  a_youssef       uuid := '50000000-0000-4000-8000-000000000004';

  -- commandes
  c_1040 uuid := '60000000-0000-4000-8000-000000001040';
  c_1042 uuid := '60000000-0000-4000-8000-000000001042';
  c_1043 uuid := '60000000-0000-4000-8000-000000001043';
  c_1044 uuid := '60000000-0000-4000-8000-000000001044';
  c_1045 uuid := '60000000-0000-4000-8000-000000001045';
  c_1046 uuid := '60000000-0000-4000-8000-000000001046';
begin
  if u_amine is null or u_zitouna is null or u_sami is null then
    raise exception 'Comptes de test introuvables : exécutez d''abord la partie 1 de seed.sql';
  end if;

  -- Rôles et états des comptes (ce que ferait l'administrateur) -------
  update public.profiles set role = 'admin', etat_compte = 'actif' where id = u_admin;
  update public.profiles set etat_compte = 'actif'
    where id in (u_zitouna, u_kanoun, u_souika, u_sami, u_karim);
  -- u_beya et u_yassine restent « en_attente » : demandes à valider dans le dashboard admin

  update public.livreurs set type_vehicule = 'moto', immatriculation = '245 TU 1830', disponible = true,
         latitude = 36.8782, longitude = 10.3247, position_maj_le = now()
    where id = u_sami;
  update public.livreurs set type_vehicule = 'moto', immatriculation = '231 TU 5521', disponible = true,
         latitude = 36.8510, longitude = 10.2730, position_maj_le = now()
    where id = u_karim;
  update public.livreurs set type_vehicule = 'moto', immatriculation = '250 TU 0912'
    where id = u_yassine;

  insert into public.documents_livreur (livreur_id, type, fichier_url, etat) values
    (u_sami,    'cin',         u_sami || '/cin.pdf',         'valide'),
    (u_sami,    'permis',      u_sami || '/permis.jpg',      'valide'),
    (u_yassine, 'cin',         u_yassine || '/cin.pdf',         'en_attente'),
    (u_yassine, 'permis',      u_yassine || '/permis.jpg',      'en_attente'),
    (u_yassine, 'carte_grise', u_yassine || '/carte_grise.pdf', 'en_attente')
  on conflict (livreur_id, type) do nothing;

  -- Paramètres de la plateforme ---------------------------------------
  update public.parametres set frais_livraison = 2.500, commission_pct = 10, gain_livreur = 2.000 where id = 1;

  -- Catégories de restaurants -----------------------------------------
  insert into public.categories_restaurant (id, nom, ordre) values
    (k_couscous, 'Couscous et tajines', 1),
    (k_grill,    'Ojja et grillades',   2),
    (k_street,   'Brik et street food', 3),
    (k_sucre,    'Pâtisseries',         4),
    (k_poisson,  'Poissons',            5)
  on conflict (id) do nothing;

  -- Restaurants -------------------------------------------------------
  insert into public.restaurants (id, responsable_id, categorie_id, nom, description, telephone, adresse, ville,
                                  latitude, longitude, etat, ouvert, temps_preparation_min) values
    (r_zitouna, u_zitouna, k_couscous, 'Dar Zitouna', 'Couscous, tajines et cuisine maison comme à la médina.',
     '+216 71 742 100', '8, rue Habib Bourguiba', 'La Marsa', 36.8782, 10.3247, 'actif', true, 25),
    (r_kanoun,  u_kanoun,  k_grill,    'El Kanoun', 'Ojja, grillades au feu de bois et merguez maison.',
     '+216 71 911 230', '3, avenue de la Corniche', 'Gammarth', 36.9170, 10.2870, 'actif', true, 20),
    (r_souika,  u_souika,  k_street,   'Brik Bab Souika', 'Briks croustillantes et fricassés depuis 1987.',
     '+216 71 560 884', 'Place Bab Souika', 'Tunis', 36.8065, 10.1700, 'actif', false, 15),
    (r_beya,    u_beya,    k_poisson,  'Lella Béya', 'Cuisine tunisienne et poissons du jour.',
     '+216 71 740 552', '15, rue Sidi Dhrif', 'Sidi Bou Saïd', 36.8687, 10.3416, 'en_attente', false, 30)
  on conflict (id) do nothing;

  -- Horaires : 11h–23h, fermé le lundi pour El Kanoun
  insert into public.horaires (restaurant_id, jour, ouverture, fermeture, ferme)
  select r.id, j.jour,
         case when r.id = r_kanoun and j.jour = 1 then null else time '11:00' end,
         case when r.id = r_kanoun and j.jour = 1 then null else time '23:00' end,
         (r.id = r_kanoun and j.jour = 1)
  from (values (r_zitouna), (r_kanoun), (r_souika), (r_beya)) as r(id)
  cross join generate_series(1, 7) as j(jour)
  on conflict (restaurant_id, jour) do nothing;

  -- Menus -------------------------------------------------------------
  insert into public.categories_menu (id, restaurant_id, nom, ordre) values
    (m_z_couscous, r_zitouna, 'Couscous',    1),
    (m_z_tajines,  r_zitouna, 'Tajines',     2),
    (m_z_entrees,  r_zitouna, 'Entrées',     3),
    (m_z_the,      r_zitouna, 'Thé',         4),
    (m_k_ojja,     r_kanoun,  'Ojja',        1),
    (m_k_grill,    r_kanoun,  'Grillades',   2),
    (m_s_briks,    r_souika,  'Briks',       1),
    (m_s_fricasse, r_souika,  'Fricassés',   2)
  on conflict (id) do nothing;

  insert into public.plats (id, restaurant_id, categorie_id, nom, description, prix, disponible) values
    (p_cous_agneau,  r_zitouna, m_z_couscous, 'Couscous à l''agneau', 'Semoule fine, agneau, pois chiches, légumes de saison', 18.000, true),
    (p_cous_legumes, r_zitouna, m_z_couscous, 'Couscous aux légumes', 'Carottes, courgettes, navets, potiron, harissa maison', 13.000, true),
    (p_cous_poisson, r_zitouna, m_z_couscous, 'Couscous au poisson', 'Mérou, sauce rouge épicée, piments frits',               22.000, false),
    (p_tajine,       r_zitouna, m_z_tajines,  'Tajine de poulet aux olives', 'Œufs, fromage, poulet et persil, cuit au four',  16.000, true),
    (p_brik_z,       r_zitouna, m_z_entrees,  'Brik à l''œuf', 'Feuille de malsouka, œuf coulant, thon et câpres',           4.500, true),
    (p_mechouia,     r_zitouna, m_z_entrees,  'Salade méchouia', 'Poivrons et tomates grillés, thon, œuf dur',                6.000, true),
    (p_the,          r_zitouna, m_z_the,      'Thé à la menthe', 'Thé vert à la menthe fraîche et aux pignons',               2.500, true),
    (p_ojja_merguez, r_kanoun,  m_k_ojja,     'Ojja merguez', 'Sauce tomate pimentée, œufs, merguez maison',                 12.000, true),
    (p_ojja_crev,    r_kanoun,  m_k_ojja,     'Ojja aux crevettes', 'Crevettes, sauce tomate, harissa, œufs',                16.000, true),
    (p_grillade,     r_kanoun,  m_k_grill,    'Grillade mixte', 'Agneau, poulet, merguez, salade et frites',                 24.000, true),
    (p_brik_oeuf,    r_souika,  m_s_briks,    'Brik à l''œuf', 'La brik traditionnelle de Bab Souika',                         4.000, true),
    (p_brik_thon,    r_souika,  m_s_briks,    'Brik au thon', 'Thon, œuf, persil et câpres',                                   5.000, true),
    (p_fricasse,     r_souika,  m_s_fricasse, 'Fricassé', 'Pain frit, thon, olives, harissa et pomme de terre',               2.500, true)
  on conflict (id) do nothing;

  -- Adresses ----------------------------------------------------------
  insert into public.adresses (id, client_id, libelle, rue, ville, latitude, longitude, par_defaut) values
    (a_amine_maison,  u_amine,   'Maison',  '12, rue du Jasmin',                     'La Marsa', 36.8790, 10.3180, true),
    (a_amine_travail, u_amine,   'Travail', 'Immeuble Lac Palace, Les Berges du Lac', 'Tunis',    36.8380, 10.2400, false),
    (a_leila,         u_leila,   'Maison',  '4, rue des Orangers',                   'Ariana',   36.8625, 10.1956, true),
    (a_youssef,       u_youssef, 'Maison',  '27, avenue de Paris',                   'Tunis',    36.8008, 10.1815, true)
  on conflict (id) do nothing;

  -- Commandes (une par état représentatif) ----------------------------
  insert into public.commandes (id, numero, client_id, restaurant_id, adresse_id, adresse_livraison, latitude, longitude,
                                etat, sous_total, frais_livraison, total, remarque, motif_refus,
                                created_at, acceptee_le, prete_le, livree_le) values
    -- livrée (historique, payée en espèces)
    (c_1040, 1040, u_amine, r_souika, a_amine_maison, '12, rue du Jasmin, La Marsa', 36.8790, 10.3180,
     'livree', 13.000, 2.500, 15.500, null, null,
     now() - interval '6 days', now() - interval '6 days' + interval '3 min', now() - interval '6 days' + interval '18 min', now() - interval '6 days' + interval '41 min'),
    -- la commande n° 1042 des maquettes : livrée, payée par carte, notée
    (c_1042, 1042, u_amine, r_zitouna, a_amine_maison, '12, rue du Jasmin, La Marsa', 36.8790, 10.3180,
     'livree', 31.000, 2.500, 33.500, 'Sans pois chiches dans le couscous aux légumes', null,
     now() - interval '5 days', now() - interval '5 days' + interval '2 min', now() - interval '5 days' + interval '24 min', now() - interval '5 days' + interval '47 min'),
    -- refusée par le restaurant, paiement remboursé
    (c_1043, 1043, u_leila, r_kanoun, a_leila, '4, rue des Orangers, Ariana', 36.8625, 10.1956,
     'refusee', 24.000, 2.500, 26.500, null, 'Désolés, nous n''avons plus de merguez ce soir.',
     now() - interval '2 hours', null, null, null),
    -- en préparation : la course est proposée aux livreurs
    (c_1044, 1044, u_leila, r_zitouna, a_leila, '4, rue des Orangers, Ariana', 36.8625, 10.1956,
     'en_preparation', 48.000, 2.500, 50.500, null, null,
     now() - interval '12 min', now() - interval '9 min', null, null),
    -- en attente de réponse du restaurant, en espèces
    (c_1045, 1045, u_youssef, r_zitouna, a_youssef, '27, avenue de Paris, Tunis', 36.8008, 10.1815,
     'en_attente', 23.000, 2.500, 25.500, null, null,
     now() - interval '3 min', null, null, null),
    -- en cours de livraison par Karim, en espèces
    (c_1046, 1046, u_amine, r_kanoun, a_amine_travail, 'Immeuble Lac Palace, Les Berges du Lac, Tunis', 36.8380, 10.2400,
     'en_livraison', 12.000, 2.500, 14.500, null, null,
     now() - interval '35 min', now() - interval '33 min', now() - interval '15 min', null)
  on conflict (id) do nothing;

  -- les numéros suivants continuent après 1046
  perform setval(pg_get_serial_sequence('public.commandes', 'numero'),
                 greatest((select max(numero) from public.commandes), 1001));

  insert into public.lignes_commande (commande_id, plat_id, nom_plat, quantite, prix_unitaire, remarque)
  select * from (values
    (c_1040, p_brik_oeuf,    'Brik à l''œuf',               2, 4.000,  null::text),
    (c_1040, p_fricasse,     'Fricassé',                    2, 2.500,  null),
    (c_1042, p_cous_agneau,  'Couscous à l''agneau',        1, 18.000, null),
    (c_1042, p_cous_legumes, 'Couscous aux légumes',        1, 13.000, 'Sans pois chiches'),
    (c_1043, p_ojja_merguez, 'Ojja merguez',                2, 12.000, null),
    (c_1044, p_tajine,       'Tajine de poulet aux olives', 3, 16.000, null),
    (c_1045, p_cous_agneau,  'Couscous à l''agneau',        1, 18.000, 'Piquant : moyen'),
    (c_1045, p_the,          'Thé à la menthe',             2, 2.500,  null),
    (c_1046, p_ojja_merguez, 'Ojja merguez',                1, 12.000, null)
  ) as l(commande_id, plat_id, nom_plat, quantite, prix_unitaire, remarque)
  where not exists (select 1 from public.lignes_commande x where x.commande_id = l.commande_id);

  insert into public.paiements (commande_id, mode, montant, etat, reference_passerelle, paye_le) values
    (c_1040, 'especes', 15.500, 'paye',       null,              now() - interval '6 days' + interval '41 min'),
    (c_1042, 'carte',   33.500, 'paye',       'pi_test_1042',    now() - interval '5 days'),
    (c_1043, 'carte',   26.500, 'rembourse',  'pi_test_1043',    now() - interval '2 hours'),
    (c_1044, 'carte',   50.500, 'paye',       'pi_test_1044',    now() - interval '12 min'),
    (c_1045, 'especes', 25.500, 'en_attente', null,              null),
    (c_1046, 'especes', 14.500, 'en_attente', null,              null)
  on conflict (commande_id) do nothing;

  insert into public.livraisons (commande_id, livreur_id, etat, acceptee_le, recuperee_le, livree_le, gain_livreur) values
    (c_1040, u_sami,  'livree',    now() - interval '6 days' + interval '5 min', now() - interval '6 days' + interval '20 min', now() - interval '6 days' + interval '41 min', 2.000),
    (c_1042, u_sami,  'livree',    now() - interval '5 days' + interval '4 min', now() - interval '5 days' + interval '26 min', now() - interval '5 days' + interval '47 min', 2.000),
    (c_1044, null,    'proposee',  null, null, null, 2.000),
    (c_1046, u_karim, 'recuperee', now() - interval '30 min', now() - interval '14 min', null, 2.000)
  on conflict (commande_id) do nothing;

  -- Avis sur la commande n° 1042 --------------------------------------
  insert into public.avis (commande_id, client_id, restaurant_id, livreur_id, note, commentaire) values
    (c_1042, u_amine, r_zitouna, null,   5, 'Couscous généreux, comme chez ma grand-mère. Merci !'),
    (c_1042, u_amine, null,      u_sami, 4, null)
  on conflict do nothing;

  -- Réclamation ouverte -----------------------------------------------
  insert into public.reclamations (commande_id, client_id, motif, description, etat)
  select c_1040, u_amine, 'Plat manquant', 'Il manquait un fricassé dans ma commande.', 'ouverte'
  where not exists (select 1 from public.reclamations where commande_id = c_1040);

  -- Notifications -----------------------------------------------------
  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  select * from (values
    (u_amine,   'Votre livreur arrive', 'Karim est à 12 min de chez vous avec la commande n° 1046.', 'commande', c_1046),
    (u_leila,   'Commande refusée',     'El Kanoun n''a pas pu accepter votre commande n° 1043. Le remboursement est lancé.', 'commande', c_1043),
    (u_zitouna, 'Nouvelle commande',    'Commande n° 1045 de Youssef K. : 25,500 DT en espèces.', 'commande', c_1045)
  ) as n(destinataire_id, titre, message, type, commande_id)
  where not exists (select 1 from public.notifications x where x.commande_id = n.commande_id and x.destinataire_id = n.destinataire_id);
end;
$$;
