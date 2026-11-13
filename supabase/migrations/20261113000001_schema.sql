-- =====================================================================
-- Mida — US01 : modèle de données (cahier des charges §9)
-- Toutes les tables partagées par les 4 applications, avec leurs
-- relations et contraintes. Les règles d'accès (RLS) sont dans la
-- migration suivante (US02).
-- Montants en dinars tunisiens : numeric(10,3) (le dinar a 1000 millimes).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Types énumérés
-- ---------------------------------------------------------------------
create type public.role_utilisateur as enum ('client', 'livreur', 'responsable', 'admin');
create type public.etat_compte     as enum ('en_attente', 'actif', 'rejete', 'bloque');
-- §6.1 — états de la commande
create type public.etat_commande   as enum ('en_attente', 'acceptee', 'en_preparation', 'prete',
                                            'en_livraison', 'livree', 'refusee', 'annulee');
-- §6.2 — paiement
create type public.mode_paiement   as enum ('carte', 'especes');
create type public.etat_paiement   as enum ('en_attente', 'paye', 'echoue', 'rembourse');
create type public.etat_livraison  as enum ('proposee', 'acceptee', 'recuperee', 'livree', 'annulee');
create type public.type_vehicule   as enum ('moto', 'velo', 'voiture');
create type public.etat_document   as enum ('en_attente', 'valide', 'refuse');
create type public.etat_reclamation as enum ('ouverte', 'en_cours', 'resolue', 'rejetee');

-- ---------------------------------------------------------------------
-- Mise à jour automatique de updated_at
-- ---------------------------------------------------------------------
create function public.maj_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Utilisateurs
-- ---------------------------------------------------------------------
-- Un profil par compte d'authentification (auth.users). Il est créé
-- automatiquement à l'inscription (voir migration RLS).
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  nom          text not null check (length(trim(nom)) > 0),
  email        text not null,
  telephone    text,
  role         public.role_utilisateur not null default 'client',
  etat_compte  public.etat_compte not null default 'actif',
  avatar_url   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
comment on table public.profiles is 'Utilisateur : client, livreur, responsable de restaurant ou administrateur.';

-- Informations propres aux livreurs (1-1 avec profiles)
create table public.livreurs (
  id               uuid primary key references public.profiles (id) on delete cascade,
  type_vehicule    public.type_vehicule,
  immatriculation  text,
  disponible       boolean not null default false,
  latitude         double precision check (latitude between -90 and 90),
  longitude        double precision check (longitude between -180 and 180),
  position_maj_le  timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Pièces justificatives envoyées à l'inscription du livreur (L1, A3)
create table public.documents_livreur (
  id          uuid primary key default gen_random_uuid(),
  livreur_id  uuid not null references public.livreurs (id) on delete cascade,
  type        text not null check (type in ('cin', 'permis', 'carte_grise', 'photo')),
  fichier_url text not null,
  etat        public.etat_document not null default 'en_attente',
  created_at  timestamptz not null default now(),
  unique (livreur_id, type)
);

-- Adresses de livraison d'un client (C4, C14)
create table public.adresses (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references public.profiles (id) on delete cascade,
  libelle     text not null,                       -- « Maison », « Travail »…
  rue         text not null,
  ville       text not null,
  complement  text,
  latitude    double precision check (latitude between -90 and 90),
  longitude   double precision check (longitude between -180 and 180),
  par_defaut  boolean not null default false,
  created_at  timestamptz not null default now()
);
-- Une seule adresse par défaut par client
create unique index adresses_une_par_defaut on public.adresses (client_id) where par_defaut;

-- ---------------------------------------------------------------------
-- Restaurants et menus
-- ---------------------------------------------------------------------
-- Catégories de restaurants gérées par l'administrateur (A8)
create table public.categories_restaurant (
  id     uuid primary key default gen_random_uuid(),
  nom    text not null unique,
  ordre  integer not null default 0
);

create table public.restaurants (
  id                     uuid primary key default gen_random_uuid(),
  responsable_id         uuid not null unique references public.profiles (id) on delete restrict,
  categorie_id           uuid references public.categories_restaurant (id) on delete set null,
  nom                    text not null check (length(trim(nom)) > 0),
  description            text,
  telephone              text,
  adresse                text not null,
  ville                  text not null,
  latitude               double precision check (latitude between -90 and 90),
  longitude              double precision check (longitude between -180 and 180),
  logo_url               text,
  couverture_url         text,
  -- validation par l'administrateur (A2) : en_attente → actif / rejete, ou bloque
  etat                   public.etat_compte not null default 'en_attente',
  motif_rejet            text,
  ouvert                 boolean not null default false,   -- ouvert / fermé en un clic (R2)
  temps_preparation_min  integer not null default 25 check (temps_preparation_min > 0),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
comment on column public.restaurants.etat is 'Validation par l''administrateur ; seul un restaurant « actif » est visible des clients.';

-- Horaires d'ouverture (1 = lundi … 7 = dimanche)
create table public.horaires (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references public.restaurants (id) on delete cascade,
  jour           smallint not null check (jour between 1 and 7),
  ouverture      time,
  fermeture      time,
  ferme          boolean not null default false,
  unique (restaurant_id, jour),
  check (ferme or (ouverture is not null and fermeture is not null))
);

-- Catégories du menu d'un restaurant (US09)
create table public.categories_menu (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references public.restaurants (id) on delete cascade,
  nom            text not null check (length(trim(nom)) > 0),
  ordre          integer not null default 0,
  unique (restaurant_id, nom),
  unique (id, restaurant_id)          -- cible de la clé étrangère composée des plats
);

-- Plats (US10). La clé étrangère composée garantit que la catégorie
-- appartient bien au même restaurant que le plat. « on delete restrict » :
-- impossible de supprimer une catégorie qui contient encore des plats.
create table public.plats (
  id             uuid primary key default gen_random_uuid(),
  restaurant_id  uuid not null references public.restaurants (id) on delete cascade,
  categorie_id   uuid not null,
  nom            text not null check (length(trim(nom)) > 0),
  description    text,
  prix           numeric(10, 3) not null check (prix > 0),
  image_url      text,
  disponible     boolean not null default true,      -- R7
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  foreign key (categorie_id, restaurant_id)
    references public.categories_menu (id, restaurant_id) on delete restrict
);

-- ---------------------------------------------------------------------
-- Paramètres de la plateforme (A7) — une seule ligne
-- ---------------------------------------------------------------------
create table public.parametres (
  id               smallint primary key default 1 check (id = 1),
  frais_livraison  numeric(10, 3) not null default 2.500 check (frais_livraison >= 0),
  commission_pct   numeric(5, 2)  not null default 10.00 check (commission_pct between 0 and 100),
  gain_livreur     numeric(10, 3) not null default 2.000 check (gain_livreur >= 0),
  updated_at       timestamptz not null default now()
);
insert into public.parametres (id) values (1);

-- ---------------------------------------------------------------------
-- Commandes
-- ---------------------------------------------------------------------
create table public.commandes (
  id                 uuid primary key default gen_random_uuid(),
  numero             bigint generated by default as identity (start with 1001) unique,  -- « n° 1042 »
  client_id          uuid not null references public.profiles (id) on delete restrict,
  restaurant_id      uuid not null references public.restaurants (id) on delete restrict,
  adresse_id         uuid references public.adresses (id) on delete set null,
  -- copie de l'adresse au moment de la commande (l'adresse peut être modifiée ensuite)
  adresse_livraison  text not null,
  latitude           double precision check (latitude between -90 and 90),
  longitude          double precision check (longitude between -180 and 180),
  etat               public.etat_commande not null default 'en_attente',
  sous_total         numeric(10, 3) not null check (sous_total >= 0),
  frais_livraison    numeric(10, 3) not null check (frais_livraison >= 0),
  total              numeric(10, 3) not null,
  remarque           text,
  motif_refus        text,
  created_at         timestamptz not null default now(),
  acceptee_le        timestamptz,
  prete_le           timestamptz,
  livree_le          timestamptz,
  annulee_le         timestamptz,
  updated_at         timestamptz not null default now(),
  check (total = sous_total + frais_livraison),
  check (etat <> 'refusee' or motif_refus is not null)
);

-- Lignes de commande : le prix unitaire est figé au moment de la commande
create table public.lignes_commande (
  id             uuid primary key default gen_random_uuid(),
  commande_id    uuid not null references public.commandes (id) on delete cascade,
  plat_id        uuid references public.plats (id) on delete set null,
  nom_plat       text not null,                     -- copie : le plat peut être supprimé plus tard
  quantite       integer not null check (quantite > 0),
  prix_unitaire  numeric(10, 3) not null check (prix_unitaire >= 0),
  remarque       text
);

-- Paiement : son état est séparé de celui de la commande (§6.2)
create table public.paiements (
  id                    uuid primary key default gen_random_uuid(),
  commande_id           uuid not null unique references public.commandes (id) on delete cascade,
  mode                  public.mode_paiement not null,
  montant               numeric(10, 3) not null check (montant >= 0),
  etat                  public.etat_paiement not null default 'en_attente',
  reference_passerelle  text,                        -- aucune donnée de carte n'est stockée
  paye_le               timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  check (etat <> 'paye' or paye_le is not null)
);

-- Livraison : la course est « proposée » aux livreurs puis acceptée par l'un d'eux
create table public.livraisons (
  id            uuid primary key default gen_random_uuid(),
  commande_id   uuid not null unique references public.commandes (id) on delete cascade,
  livreur_id    uuid references public.livreurs (id) on delete set null,
  etat          public.etat_livraison not null default 'proposee',
  acceptee_le   timestamptz,
  recuperee_le  timestamptz,
  livree_le     timestamptz,
  gain_livreur  numeric(10, 3) not null default 0 check (gain_livreur >= 0),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (etat = 'proposee' or etat = 'annulee' or livreur_id is not null)
);

-- ---------------------------------------------------------------------
-- Avis, réclamations, notifications
-- ---------------------------------------------------------------------
-- Avis d'un client sur un restaurant OU sur un livreur, après une commande (C12)
create table public.avis (
  id             uuid primary key default gen_random_uuid(),
  commande_id    uuid not null references public.commandes (id) on delete cascade,
  client_id      uuid not null references public.profiles (id) on delete cascade,
  restaurant_id  uuid references public.restaurants (id) on delete cascade,
  livreur_id     uuid references public.livreurs (id) on delete cascade,
  note           smallint not null check (note between 1 and 5),
  commentaire    text,
  created_at     timestamptz not null default now(),
  check (num_nonnulls(restaurant_id, livreur_id) = 1),
  unique (commande_id, restaurant_id),
  unique (commande_id, livreur_id)
);

-- Réclamations traitées par l'administrateur (A9)
create table public.reclamations (
  id                 uuid primary key default gen_random_uuid(),
  commande_id        uuid not null references public.commandes (id) on delete cascade,
  client_id          uuid not null references public.profiles (id) on delete cascade,
  motif              text not null,
  description        text,
  etat               public.etat_reclamation not null default 'ouverte',
  reponse            text,
  montant_rembourse  numeric(10, 3) check (montant_rembourse >= 0),
  traitee_par        uuid references public.profiles (id) on delete set null,
  traitee_le         timestamptz,
  created_at         timestamptz not null default now()
);

-- Notifications affichées dans les applications (C11, L7)
create table public.notifications (
  id               uuid primary key default gen_random_uuid(),
  destinataire_id  uuid not null references public.profiles (id) on delete cascade,
  titre            text not null,
  message          text not null,
  type             text not null default 'info',
  commande_id      uuid references public.commandes (id) on delete cascade,
  lue              boolean not null default false,
  created_at       timestamptz not null default now()
);

-- Jetons Firebase Cloud Messaging des appareils (notifications push)
create table public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  token       text not null unique,
  plateforme  text not null check (plateforme in ('android', 'ios', 'web')),
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Index sur les clés étrangères et les recherches fréquentes
-- ---------------------------------------------------------------------
create index on public.documents_livreur (livreur_id);
create index on public.adresses (client_id);
create index on public.restaurants (categorie_id);
create index on public.restaurants (etat, ouvert);
create index on public.categories_menu (restaurant_id, ordre);
create index on public.plats (restaurant_id);
create index on public.plats (categorie_id, restaurant_id);
create index on public.commandes (client_id, created_at desc);
create index on public.commandes (restaurant_id, etat);
create index on public.commandes (adresse_id);
create index on public.lignes_commande (commande_id);
create index on public.lignes_commande (plat_id);
create index on public.livraisons (livreur_id);
create index on public.livraisons (etat) where livreur_id is null;
create index on public.avis (client_id);
create index on public.avis (restaurant_id);
create index on public.avis (livreur_id);
create index on public.reclamations (commande_id);
create index on public.reclamations (client_id);
create index on public.reclamations (traitee_par);
create index on public.notifications (destinataire_id, lue);
create index on public.notifications (commande_id);
create index on public.device_tokens (user_id);

-- ---------------------------------------------------------------------
-- Déclencheurs updated_at
-- ---------------------------------------------------------------------
create trigger maj_updated_at before update on public.profiles    for each row execute function public.maj_updated_at();
create trigger maj_updated_at before update on public.livreurs    for each row execute function public.maj_updated_at();
create trigger maj_updated_at before update on public.restaurants for each row execute function public.maj_updated_at();
create trigger maj_updated_at before update on public.plats       for each row execute function public.maj_updated_at();
create trigger maj_updated_at before update on public.parametres  for each row execute function public.maj_updated_at();
create trigger maj_updated_at before update on public.commandes   for each row execute function public.maj_updated_at();
create trigger maj_updated_at before update on public.paiements   for each row execute function public.maj_updated_at();
create trigger maj_updated_at before update on public.livraisons  for each row execute function public.maj_updated_at();
