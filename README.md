# Mida — plateforme de livraison de repas

Projet de fin d'année : 4 applications (client et livreur en Flutter, restaurant et admin en React + TypeScript) autour d'un backend Supabase commun.

## Organisation

```
supabase/
  migrations/
    20261113000001_schema.sql          US01 : tables, relations, contraintes
    20261113000002_roles_securite.sql  US02 : rôles, règles d'accès (RLS), rôle dans le jeton
    20261113000003_stockage_images.sql US03 : stockage des images (buckets + règles d'accès)
    20261115000001_ouverture_restaurant.sql US08 : ouvert / fermé, pas de commande pour un restaurant fermé
    20261115000002_suppression_categorie_menu.sql US09 : suppression d'une catégorie avec ses plats
    …
    20261118000001_courses_livreurs.sql US26-US28 : disponibilité, courses proposées / acceptées / récupérées / livrées
    20261118000002_administration.sql  US32-US37 : décisions de l'administrateur (valider, rejeter, bloquer), bornes des paramètres
    20261118000003_notifications_push.sql US23 : jetons des téléphones, chaque notification part en push (pg_net)
  functions/
    envoyer-push/                      US23 : Edge Function qui envoie les notifications par Firebase (FCM HTTP v1)
  seed.sql                             jeu de données de test (données des maquettes)
  tests/                               tests automatiques des migrations (PGlite, sans Docker)
apps/
  client/                              application mobile client (Flutter)
  restaurant/                          espace web du responsable restaurant (React + TypeScript)
  livreur/                             application mobile livreur (Flutter)
  admin/                               tableau de bord d'administration (React + TypeScript)
```

## Avancement du backlog

| Story | Contenu | État |
|-------|---------|------|
| US01 | Base de données : 18 tables du §9 (+ livreurs, documents, horaires, paramètres, réclamations, notifications, jetons d'appareil), relations et contraintes, jeu de test | fait, testé en local |
| US02 | 4 rôles (client, livreur, responsable, admin), RLS sur toutes les tables, protection des champs réservés à l'admin, rôle dans le JWT | fait, testé en local |
| US03 | Stockage des images : 3 buckets (restaurants, avatars, documents-livreurs), seul le propriétaire envoie/remplace ses fichiers | fait, testé en local |
| US04 | Appli client : inscription (nom, e-mail, téléphone +216, mot de passe), connexion, session conservée, déconnexion ; comptes non clients ou bloqués refusés | fait : 24 tests OK, essayé sur émulateur avec le vrai projet Supabase, puis installé sur un vrai téléphone (APK release) |
| US05 | Espace restaurant web : inscription en 2 étapes (responsable puis restaurant), compte et restaurant « en attente » de validation, connexion, écran d'attente ou de refus (avec motif), pages réservées aux responsables connectés | fait : 27 tests Vitest + test PGlite, essayé avec le vrai projet Supabase |
| US06 | Mot de passe oublié (appli client) : e-mail → code reçu par e-mail → nouveau mot de passe, puis session ouverte | codé, 13 tests OK ; **lien masqué** dans l'appli et essai réel en attente du réglage e-mail de Supabase (voir plus bas) |
| US07 | Profil du restaurant (espace web) : nom, catégorie, adresse, ville, téléphone, description, logo et horaires des 7 jours ; ouvert dès l'inscription, même avant la validation | fait : 21 tests Vitest + 5 tests PGlite ; essayé avec le vrai projet Supabase (infos, horaires, logo) |
| US08 | Ouvrir ou fermer son restaurant en un clic (interrupteur du menu de l'espace web) ; un restaurant fermé ou non validé ne reçoit plus de nouvelle commande | fait : 4 tests Vitest + 4 tests PGlite, migration appliquée sur Supabase, essayé avec un vrai restaurant validé ; affichage côté client avec le catalogue |
| US09 | Catégories du menu (espace web, page « Menu ») : créer, renommer, ordonner ; suppression avec confirmation, qui annonce et supprime les plats de la catégorie | fait : 16 tests Vitest + 4 tests PGlite, fonction appliquée sur Supabase, essayé avec le vrai projet |
| US10 | Plats (espace web) : ajouter, modifier, supprimer un plat avec nom, description, prix positif, photo et catégorie ; aperçu côté client dans le formulaire | fait : 15 tests Vitest + 5 tests PGlite, essayé avec le vrai projet (plats avec photo) ; affichage dans l'appli client avec le catalogue |
| US11 | Plat momentanément indisponible (espace web) : case « Disponible » sur chaque plat du menu, un clic pour le retirer de la commande ou le réactiver ; un plat indisponible ne peut pas être commandé | fait : 4 tests Vitest + 2 tests PGlite, migration appliquée sur Supabase, essayé avec le vrai projet ; affichage grisé dans l'appli client avec le catalogue |
| US12 | Commandes en cours (espace web, page « Commandes ») : 4 colonnes (en attente, en préparation, prête, en livraison), nouvelles commandes en temps réel avec alerte sonore et visuelle, détail (plats, quantités, remarques, paiement) | fait : 15 tests Vitest + 2 tests PGlite, migration appliquée sur Supabase ; essayé avec deux commandes de test créées par SQL (n° 1001 en espèces, n° 1003 par carte) : arrivée en temps réel, son, bandeaux et pastille OK |
| US13 | Accepter ou refuser une commande (espace web) : boutons sur les commandes en attente, fenêtre de refus avec motif obligatoire (4 motifs proposés + message au client), client prévenu par une notification, paiement par carte remboursé | fait : 8 tests Vitest + 4 tests PGlite, fonctions appliquées sur Supabase ; essayé avec le vrai projet (n° 1001 acceptée, n° 1003 refusée et remboursée, notifications créées) ; affichage des notifications dans l'appli client à venir |
| US14 | Faire avancer une commande (espace web) : « Commencer la préparation » (acceptée → en préparation) puis « Marquer comme prête », une étape par clic, sans saut ni retour en arrière ; client prévenu à chaque étape | fait : 4 tests Vitest + 3 tests PGlite, fonction appliquée sur Supabase ; essayé avec le vrai projet (n° 1004 et 1005 : acceptée → en préparation → prête, notifications créées) |
| US15 | Catalogue de l'appli client : restaurants validés (ouverts d'abord), avec logo, catégorie, ville, note moyenne et nombre d'avis, état ouvert / fermé, délai ; aussi pour les visiteurs | fait : 6 tests Flutter + 1 test PGlite, vue appliquée sur Supabase ; essayé sur un vrai téléphone (APK release) |
| US16 | Recherche d'un restaurant par nom (sans tenir compte des majuscules ni des accents) et filtre par catégorie ; message et « Effacer les filtres » s'il n'y a aucun résultat | fait : 5 tests Flutter ; essayé sur un vrai téléphone |
| US17 | Menu d'un restaurant (appli client) : rubriques dans l'ordre du restaurant, plats avec photo, description et prix, plats indisponibles signalés, note, délai et horaire du jour ; restaurant fermé consultable avec un bandeau | fait : 7 tests Flutter ; essayé sur un vrai téléphone (plat décoché sur le web → « Indisponible ») |
| US18 | Panier (appli client) : ajouter des plats depuis le menu, modifier les quantités (1 à 20), retirer, vider ; total à jour ; un seul restaurant par panier (proposition de vider sinon) ; conservé en quittant l'écran | fait : 7 tests Flutter ; essayé sur un vrai téléphone |
| US19 | Valider la commande (appli client) : adresse de livraison obligatoire, remarque, paiement en espèces, récapitulatif sous-total / frais / total ; total calculé par le serveur ; la commande arrive au restaurant « en attente » ; un visiteur se connecte d'abord, panier gardé | fait : 7 tests Flutter + 3 tests PGlite, fonction appliquée sur Supabase ; essayé sur un vrai téléphone (n° 1004 à 1006, adresse vide refusée, parcours visiteur) |
| US20 | Suivi de la commande en temps réel (appli client) : étapes franchies avec leur heure, mise à jour sans action du client, motif affiché si la commande est refusée (et remboursement) ; accès depuis l'accueil | fait : 8 tests Flutter ; essayé sur un vrai téléphone avec l'espace restaurant (acceptation, préparation, prête, refus avec motif n° 1006) |
| US21 | Annuler sa commande (appli client) tant qu'elle est « en attente », avec confirmation ; le restaurant voit l'annulation (alerte avec le numéro, la commande quitte la liste) et reçoit une notification | codé : 3 tests Flutter + 2 tests Vitest + 3 tests PGlite, fonction appliquée sur Supabase ; **annulation réelle pas encore vérifiée** (à refaire avec US40) |
| US22 | Historique des commandes (appli client, icône « Mes commandes » de l'accueil) : commandes en cours puis passées, de la plus récente à la plus ancienne, avec date, nombre d'articles, total et état ; un toucher ouvre le détail | fait : 7 tests Flutter ; essayé sur un vrai téléphone |
| US23 | Notifications push (applis client et livreur) : chaque notification de la base (commande acceptée, en préparation, prête, livreur en route, livrée…) arrive aussi sur le téléphone, appli fermée ; appli ouverte, un bandeau s'affiche | codé : 5 tests PGlite, migration et Edge Function en ligne sur Supabase ; essai réel à faire |
| US24 | Profil du client (icône « Mon profil » de l'accueil) : nom et téléphone modifiables (mêmes règles qu'à l'inscription), e-mail affiché, déconnexion | codé : 6 tests Flutter ; essai réel à faire |
| US25 | Appli livreur : candidature en 2 étapes (compte, puis « Avez-vous une moto ? » et « Avez-vous un permis de conduire ? » : moto → immatriculation, permis et carte grise, une moto sans permis est refusée ; sans moto → vélo, carte d'identité seule, plus le permis s'il en a un) ; compte « en attente de validation », écran d'attente avec l'état des documents ; connexion réservée aux livreurs | fait : tests Flutter (appli livreur) + 1 test PGlite ; essayé sur un vrai téléphone le 18/11 (compte testlivreur@gmail.com : moto, 3 photos dans le stockage privé, compte « en attente » ; validé ensuite par SQL faute d'appli admin) |
| US26 | Disponible / indisponible (interrupteur de l'accueil livreur), enregistré dans la base ; un livreur indisponible, pas encore validé ou bloqué ne reçoit aucune course | fait : tests Flutter + 2 tests PGlite, migration appliquée sur Supabase ; essayé (disponible / indisponible, état conservé) |
| US27 | Courses proposées dès que le restaurant accepte la commande : restaurant, adresse du client, gain, paiement (« Payée en ligne » / « À encaisser ») ; « Accepter la course » : un seul livreur (verrou), une course à la fois, elle disparaît chez les autres (temps réel + relecture toutes les 20 s) | fait : tests Flutter + 2 tests PGlite, fonction appliquée sur Supabase ; essayé (courses 1001, 1004, 1005 proposées, n° 1001 acceptée) |
| US28 | Course acceptée : « J'ai récupéré la commande » (actif seulement quand la commande est « Prête », en temps réel) → commande « En cours de livraison » ; « Confirmer la livraison » (après « J'ai bien reçu … DT » pour les espèces) → « Livrée », paiement en espèces encaissé ; client prévenu à chaque étape | fait : tests Flutter + 2 tests PGlite, fonctions appliquées sur Supabase ; essayé (n° 1001 récupérée puis livrée, espèces payées, 3 notifications au client) |
| US29 | Paiement à la livraison (appli livreur) : « Payée en ligne » ou « À encaisser · montant » sur chaque course ; « J'ai bien reçu … DT » puis la remise font passer le paiement à « payé » | fait avec US28 ; essayé (n° 1001, espèces payées) |
| US30-US31 | Paiement par carte en ligne | **annulées** le 19/11/2026 (Konnect n'a pas fonctionné) : paiement en espèces à la livraison uniquement, option « Carte en ligne » retirée de l'appli client. La base garde le mode `carte` (avec le remboursement en cas de refus ou d'annulation), mais aucune commande ne l'utilise |
| US30-US31 | Paiement par carte en ligne | **annulées** le 19/11/2026 (Konnect n'a pas fonctionné) : paiement en espèces à la livraison seulement ; l'option « Carte en ligne » est retirée de l'appli client. La base garde le mode `carte` (remboursement à l'annulation / au refus) sans quaucune
| US32 | Tableau de bord admin (`apps/admin`) : connexion réservée aux administrateurs, tout autre compte refusé (« Ce compte n'a pas le rôle administrateur… ») ; vue d'ensemble (commandes du jour, chiffre d'affaires 7 j, utilisateurs, taux de refus, demandes à traiter) | codé : tests Vitest ; essai réel à faire (compte admin à créer) |
| US33 | Restaurants : demandes en attente, page « Examiner » (responsable, téléphone, e-mail, catégorie, adresse), « Valider le restaurant » ou « Rejeter » avec motif obligatoire ; responsable prévenu ; validé → visible des clients | codé : tests Vitest + 2 tests PGlite, fonction appliquée sur Supabase ; essai réel à faire |
| US34 | Livreurs : candidatures avec leurs documents (aperçu et ouverture par adresse temporaire du stockage privé), valider ou rejeter avec motif ; livreur prévenu, validé → peut se mettre disponible | codé : tests Vitest + 2 tests PGlite, fonction appliquée sur Supabase ; essai réel à faire |
| US35 | Bloquer / réactiver (avec confirmation) un client, un livreur ou un restaurant (son responsable) ; un compte bloqué ne peut plus se connecter ni agir ; restaurant bloqué fermé, livreur bloqué indisponible | codé : tests Vitest + 1 test PGlite, fonction appliquée sur Supabase ; essai réel à faire |
| US36 | Commandes : filtres par état, restaurant et date ; détail avec plats, total, mode, état, montant et référence du paiement, livreur | codé : tests Vitest + 1 test PGlite ; essai réel à faire |
| US37 | Paramètres : frais de livraison, commission, gain du livreur (pour les commandes suivantes) ; catégories de restaurants (ajouter, renommer, supprimer), utilisées par le filtre du catalogue client | codé : tests Vitest + 1 test PGlite ; essai réel à faire |

US01 à US03, US08, US09, US11 à US15, US19 et US21 sont appliquées sur le projet Supabase de Mida (`tpfpuwlgnxhwhezicuto`) ; le jeu de test n'y est pas encore chargé.

## Appliquer sur un projet Supabase

**Projet dédié obligatoire** : ne pas utiliser le projet de DarImmo (même `auth.users`, même table `profiles`).

Méthode simple, depuis le tableau de bord Supabase (**SQL Editor**), dans cet ordre :

1. `supabase/migrations/20261113000001_schema.sql`
2. `supabase/migrations/20261113000002_roles_securite.sql`
3. `supabase/migrations/20261113000003_stockage_images.sql`
4. `supabase/migrations/20261115000001_ouverture_restaurant.sql`
5. `supabase/migrations/20261115000002_suppression_categorie_menu.sql`
6. `supabase/seed.sql` (données de test, facultatif)

Puis activer le rôle dans le jeton : **Authentication → Hooks → Custom Access Token** → `public.custom_access_token_hook`.

Avec la CLI Supabase : `supabase link --project-ref <ref>` puis `supabase db push` (et `supabase db reset` en local pour rejouer le seed).

### Comptes de test (mot de passe : `Mida2026!`)

| Rôle | E-mail | Remarque |
|------|--------|----------|
| admin | admin@mida.test | |
| client | amine@mida.test, leila@mida.test, youssef@mida.test | Amine a la commande n° 1042 des maquettes |
| responsable | zitouna@mida.test, kanoun@mida.test, babsouika@mida.test | restaurants validés |
| responsable | lellabeya@mida.test | restaurant **en attente** de validation |
| livreur | sami@mida.test, karim@mida.test | validés et disponibles |
| livreur | yassine@mida.test | **en attente** de validation |

Comptes de démonstration uniquement : ne jamais exécuter `seed.sql` en production.

### Restaurants de démonstration (en ligne depuis le 18/11)

Pour remplir le catalogue sans le reste du seed (ni clients, ni commandes, ni changement des paramètres), `supabase/restaurants_demo.sql` a été exécuté sur le projet Supabase : **8 restaurants validés** avec leur responsable (mot de passe `Mida2026!`), leurs horaires et leur menu (37 plats), rangés dans les catégories « Salé » / « Sucré » créées dans l'admin. Les 4 restaurants des maquettes reprennent les identifiants de `seed.sql` (pas de doublon s'il est lancé plus tard ; le seed laisserait alors Lella Béya validée).

| Restaurant | Ville | Catégorie | Compte responsable |
|---|---|---|---|
| Dar Zitouna | La Marsa | Salé | zitouna@mida.test |
| El Kanoun (fermé le lundi) | Gammarth | Salé | kanoun@mida.test |
| Brik Bab Souika (**fermé** en ce moment) | Tunis | Salé | babsouika@mida.test |
| Lella Béya | Sidi Bou Saïd | Salé | lellabeya@mida.test |
| Pâtisserie Ennakhla | Ariana | Sucré | ennakhla@mida.test |
| Chapati Ennasr | Ennasr | Salé | chapati@mida.test |
| Koffa du Bardo | Le Bardo | Salé | koffa@mida.test |
| Café Sidi Mahrez | Tunis | Sucré | sidimahrez@mida.test |

Logos et photos des plats : illustrations Mida générées en WebP et envoyées dans le bucket `restaurants` par `supabase/images_demo` (`npm install && npm run envoyer` ; `node envoyer_images.mjs --apercu <dossier>` pour les voir sans rien envoyer). Le script se connecte avec le compte de chaque responsable : les règles d'accès du stockage s'appliquent comme dans l'appli web.

## Règles de sécurité (résumé)

- **Visiteur** (sans compte) : restaurants validés, leurs menus, horaires et avis.
- **Client** : ses commandes, ses adresses, ses notifications ; avis seulement sur ses commandes livrées.
- **Responsable** : son restaurant (même en attente), son menu (écriture), les commandes de son restaurant.
- **Livreur** : ses courses, et les courses proposées s'il est validé.
- **Admin** : tout ; seul à pouvoir changer un rôle, valider ou bloquer un compte ou un restaurant, modifier les paramètres.
- Les commandes, lignes, paiements et livraisons sont **en lecture seule** pour les applications : leur création et leurs changements d'état passeront par des fonctions serveur (stories des sprints 2 à 5), comme le prévoit le cahier des charges (§5.1).
- Un compte créé depuis une application ne peut jamais être admin ; livreurs et responsables démarrent « en attente ».

## Stockage des images (US03)

| Bucket | Accès | Taille max | Formats | Chemin du fichier |
|--------|-------|-----------|---------|-------------------|
| `restaurants` | public (URL publique) | 5 Mo | jpeg, png, webp | `<restaurant_id>/logo.webp`, `<restaurant_id>/couverture.webp`, `<restaurant_id>/plats/<plat_id>.webp` |
| `avatars` | public | 2 Mo | jpeg, png, webp | `<user_id>/avatar.webp` |
| `documents-livreurs` | **privé** (URL signée) | 10 Mo | jpeg, png, webp, pdf | `<livreur_id>/<type>.<ext>` (type : `cin`, `permis`, `carte_grise`, `photo`) |

- Le **premier dossier** du chemin désigne le propriétaire : c'est lui que les règles vérifient. Un fichier hors de son propre dossier est refusé.
- Restaurants : seul le responsable du restaurant (compte non bloqué) ou l'admin envoie, remplace ou supprime.
- Avatars : chacun le sien.
- Documents : visibles seulement par le livreur et l'admin ; plus remplaçables une fois validés.
- En base : `restaurants.logo_url`, `restaurants.couverture_url`, `plats.image_url` et `profiles.avatar_url` contiennent l'**URL publique** (`getPublicUrl`) ; `documents_livreur.fichier_url` contient le **chemin** dans `documents-livreurs` (l'admin l'affiche avec `createSignedUrl`).
- Pour remplacer une image, envoyer au même chemin avec `upsert: true` (ajouter `?v=<date>` à l'URL affichée pour éviter le cache).

## Tests

```bash
cd supabase/tests
npm install
npm test
```

Les tests chargent les migrations et le seed dans un PostgreSQL embarqué (PGlite) avec une imitation minimale de l'authentification Supabase (`tests/supabase-stub.sql`), puis vérifient chaque règle en se connectant avec chaque rôle. Ils ne remplacent pas un essai sur un vrai projet Supabase (connexion réelle, JWT).

## Application client (US04)

```bash
cd apps/client
flutter pub get
flutter test        # règles de saisie, messages d'erreur, rôle du jeton, écran d'inscription
flutter run         # se connecte au projet Supabase de Mida (lib/config.dart)
```

- `google_fonts` est fixé en **^8.0.0** : la version 9 utilise le paquet séparé `material_ui`, dont la classe `TextTheme` est différente de celle de `package:flutter/material.dart` (erreur de type dans `lib/theme.dart`).
- L'inscription crée un compte de rôle `client` ; le profil (`profiles`) est rempli par le déclencheur de la migration US02.
- Côté Supabase (Authentication → Sign In / Providers) : si « Confirm email » est activé, l'appli affiche « lien de confirmation envoyé » et il faut cliquer le lien avant de se connecter. Pour les essais, le désactiver, ou régler la Site URL.
- Les comptes livreur, responsable, admin ou bloqués sont déconnectés aussitôt avec un message qui indique la bonne application.
- « Confirm email » est **désactivé** sur le projet Mida (essais) : l'inscription ouvre directement la session. À réactiver avant une vraie mise en service.
- Essai du 14/11/2026 sur émulateur Android (Pixel 7) : inscription, ligne `profiles` créée (rôle `client`, téléphone `+216 22 145 870`), session conservée après fermeture de l'appli, déconnexion, mauvais mot de passe, connexion. Compte d'essai : `test.us04@mida.test` / `Us04Mida7k2q`. Pas encore essayé : le refus d'un compte livreur/responsable (aucun compte de ce type en ligne tant que `seed.sql` n'est pas chargé).
### Catalogue des restaurants (US15)

- L'accueil (`lib/pages/accueil_page.dart`) est le catalogue, pour les clients connectés comme pour les visiteurs. Chaque carte (`lib/widgets/catalogue.dart`) montre le logo (ou une illustration Mida si le restaurant n'en a pas), le nom, la catégorie et la ville, la pastille **Ouvert / Fermé** (un restaurant fermé reste visible mais grisé), la note moyenne « ★ 4,8 (12 avis) » ou « Nouveau », et le délai estimé (temps de préparation + 10 min).
- Ordre : ouverts d'abord, puis les mieux notés, puis par nom. Tirer vers le bas recharge la liste.
- Données (`lib/donnees/service_mida.dart`) : `restaurants` filtrés sur `etat = actif` (la RLS ne montre déjà que ceux-là) avec `categories_restaurant(nom)`, et la vue **`notes_restaurants`** (migration `20261116000005`, `security_invoker`) : note moyenne arrondie à 0,1 et nombre d'avis par restaurant.
- **Recherche et filtre (US16)** : champ « Rechercher un restaurant » (filtre au fil de la saisie, par mots, sans majuscules ni accents ; il cherche dans le nom et la catégorie) et puces de catégorie (« Tous » + seulement les catégories qui ont au moins un restaurant). S'il n'y a aucun résultat : « Aucun restaurant ne correspond à « … » » et un bouton « Effacer les filtres ». Si les catégories ne se chargent pas, le catalogue reste utilisable sans le filtre. Le filtrage se fait dans l'appli (`filtrerRestaurants`, `lib/donnees/modeles.dart`) : le catalogue est petit et déjà chargé.

### Menu d'un restaurant (US17)

- Toucher un restaurant du catalogue ouvre `RestaurantPage` (maquette « Client · Restaurant ») : en-tête bleu avec le logo, puis note (« ★ 4,8 », « 12 avis »), délai, et ouverture du jour (« Ouvert, jusqu'à 23:00 », d'après la table `horaires`, 1 = lundi comme `DateTime.weekday`).
- Le menu est classé par rubriques (`categories_menu`, dans l'ordre choisi par le restaurant ; les rubriques vides sont masquées). Des puces en haut font défiler jusqu'à une rubrique. Chaque plat montre sa photo (ou une illustration Mida), sa description et son prix ; un plat **indisponible** (US11) est grisé avec l'étiquette « Indisponible ».
- Un restaurant **fermé** reste consultable, avec un bandeau « Ce restaurant est fermé pour le moment : vous pouvez consulter son menu, mais pas commander. »

### Panier (US18)

- `Panier` (`lib/panier/panier.dart`, un `ChangeNotifier`) est créé une seule fois dans `main.dart` et fourni par `Dependances` : il est **conservé** quand on change d'écran, et aussi pendant qu'un visiteur se connecte. Il n'est pas enregistré sur le téléphone : il se vide si l'appli est fermée.
- Dans le menu, un plat disponible d'un restaurant ouvert a un bouton « + » ; une fois au panier, il devient « − 2 + » (la corbeille remplace « − » au dernier exemplaire). Quantité maximale : 20 par plat. La barre du bas « Voir le panier » affiche le nombre d'articles et le sous-total ; l'icône du panier, en haut de l'accueil, affiche le nombre d'articles.
- **Un seul restaurant par panier** : ajouter un plat d'un autre restaurant ouvre « Commencer un nouveau panier ? » (« Garder mon panier » / « Vider et ajouter »).
- Page panier : chaque ligne avec son montant et « − / + », sous-total mis à jour à chaque modification, bouton « Vider » (avec confirmation), et un écran « Votre panier est vide ».

### Valider la commande (US19)

- Sous les plats du panier : **adresse de livraison** (obligatoire), remarque pour le restaurant (facultative), mode de paiement **Espèces** (« À payer au livreur, à la livraison » ; seul mode proposé, le paiement par carte US30-US31 ayant été abandonné), puis le récapitulatif : sous-total, frais de livraison (lus dans `parametres`), total. Le bouton « Commander · 25,500 DT » envoie la commande. L'adresse et la remarque sont gardées dans le panier si l'on quitte l'écran.
- **Visiteur** : « Commander » ouvre « Connectez-vous pour commander » (maquette « Client · Connexion requise » : « Votre panier est gardé », rappel du panier). « J'ai déjà un compte » ou « Créer un compte » ramènent ensuite **au panier** (paramètre `retourApresConnexion` de `ConnexionPage` et `InscriptionPage`), où le client n'a plus qu'à toucher « Commander ». « Continuer à explorer » revient au panier sans rien envoyer.
- **Serveur** (migration `20261116000006`) : `passer_commande(p_restaurant, p_lignes, p_adresse, p_remarque)`, où `p_lignes` = `[{"plat_id", "quantite", "remarque"}]`. L'appli n'envoie **aucun prix** : la fonction relit le prix de chaque plat dans le menu et les frais dans `parametres`, et calcule `sous_total`, `frais_livraison` et `total`. Elle vérifie : compte **client** non bloqué, adresse non vide (300 caractères au plus), panier non vide (30 plats différents au plus, pas de doublon), quantités de 1 à 20, plats **du restaurant choisi** et **disponibles** ; le déclencheur d'US08 refuse un restaurant fermé. Elle crée la commande `en_attente`, ses lignes (nom et prix copiés), le paiement `especes` / `en_attente`, et une notification « Nouvelle commande » pour le restaurant. Elle renvoie `{id, numero, sous_total, frais_livraison, total}`. Les refus s'affichent tels quels dans l'appli (« Ce restaurant est fermé… », « Le plat « … » est indisponible pour le moment »).
- Après l'envoi : panier vidé, retour à l'accueil, puis ouverture du suivi de la commande (US20).

### Suivi de la commande (US20)

- `SuiviPage` (maquettes « Client · Suivi » et « Client · Commande refusée ») : titre de l'état (« En attente du restaurant », « Acceptée par le restaurant », « En préparation », « Prête », « En cours de livraison », « Livrée »), étapes franchies (pastille verte et heure : envoi `created_at`, acceptation `acceptee_le`, prête `prete_le`, livraison `livree_le` ; l'étape « En préparation » n'a pas d'heure, la base ne la garde pas), étape actuelle en rouge, étapes à venir. Puis le détail : plats, sous-total, frais, total, adresse, mode de paiement, remarque.
- **Temps réel** : abonnement Supabase Realtime à la commande (`onPostgresChanges` sur `commandes`, filtre `id = …` ; la table est dans la publication depuis US12, et la RLS ne laisse passer que les commandes du client). Chaque événement relit la commande (300 ms après le dernier), ainsi qu'à chaque (re)connexion ; l'abonnement est retiré en quittant l'écran. Tirer vers le bas relit aussi.
- **Refusée** : « Dar Zitouna n'a pas pu accepter votre commande », le motif indiqué par le restaurant entre guillemets, et « … remboursés » si le paiement par carte a été remboursé (sinon « Vous n'avez rien payé »). Bouton « Trouver un autre restaurant ».
- L'accueil d'un client connecté affiche ses **commandes en cours** (« Commande n° 1047 · Dar Zitouna — En préparation ») : un toucher ouvre le suivi, même après avoir fermé l'appli.

### Annuler sa commande (US21)

- Sur le suivi d'une commande **en attente**, le bouton « Annuler la commande » (« Possible tant que le restaurant n'a pas accepté votre commande ») demande confirmation (« Garder ma commande » / « Annuler la commande »). La commande passe à « Commande annulée » (« Vous avez annulé cette commande à 19:03. Le restaurant a été prévenu. »). Le bouton disparaît dès que le restaurant accepte (temps réel). Si le restaurant a accepté entre-temps, le refus du serveur s'affiche.
- **Serveur** (migration `20261116000007`) : `annuler_commande(p_commande)` — seulement le **client** de la commande (sinon « Commande introuvable »), seulement à l'état `en_attente` (verrou de la ligne : une acceptation et une annulation simultanées ne passent pas toutes les deux). Elle met `etat = annulee` et `annulee_le`, rembourse un paiement par carte déjà encaissé, et crée la notification « Commande annulée » pour le restaurant.
- **Espace restaurant** : l'événement temps réel « annulée » affiche, sur toutes les pages, « La commande n° 1045 a été annulée par le client. » (bouton « Compris ») ; la carte quitte la page Commandes et la pastille du menu se met à jour.

### Historique des commandes (US22)

- `HistoriquePage` (maquette « Client · Mes commandes »), ouverte par l'icône « Mes commandes » de l'accueil (clients connectés seulement) : section **En cours** puis **Commandes passées**, chacune de la plus récente à la plus ancienne. Chaque carte : restaurant, « n° 1047 · 16 nov. · 3 articles », total et pastille d'état (Livrée en vert, Refusée / Refusée · remboursée en rouge, Annulée en gris, En attente en doré, les autres en bleu).
- Un toucher ouvre le **détail** : c'est l'écran de suivi (US20), qui montre aussi les commandes terminées (plats, montants, adresse, paiement, motif de refus) et la date « Passée le 16 nov. à 19:00 ». Au retour, la liste est relue ; tirer vers le bas la relit aussi.
- Lecture : `mesCommandes()` = `commandes` du client, triées par `created_at` décroissant, 100 au plus (même sélection que le suivi). Aucune commande : « Vous n'avez pas encore passé de commande. » et « Découvrir les restaurants ».

### Profil du client (US24)

- `ProfilPage` (maquette « Client · Profil »), ouverte par l'icône « Mon profil » de l'accueil (elle remplace l'ancienne icône de déconnexion) : initiales, nom et e-mail, puis le formulaire **Nom et prénom** et **Téléphone** (+216, 8 chiffres, mêmes contrôles qu'à l'inscription). L'e-mail est affiché sans être modifiable (il sert d'identifiant). « Enregistrer » → « Vos informations sont enregistrées. » ; « Se déconnecter » referme les écrans et revient à la page de bienvenue.
- Enregistrement : mise à jour de `profiles` (nom, téléphone ; la règle « modification de son propre profil » d'US02 le permet, le rôle, l'état et l'e-mail restent protégés) puis des métadonnées du compte (`updateUser`), d'où vient le « Bonjour, … » de l'accueil. Pas de migration.

- Les services sont fournis à tous les écrans par `Dependances.of(context)` (`lib/dependances.dart`) ; les tests utilisent `test/faux_service_mida.dart`.

- Si la compilation Android échoue sur le cache Kotlin (« Could not close incremental caches ») : c'est le projet sur `D:` et le cache pub sur `C:` ; `kotlin.incremental=false` est déjà dans `android/gradle.properties`.

## Application livreur (US25 à US28)

```bash
cd apps/livreur
flutter pub get
flutter test        # candidature, disponibilité, courses, récupération et remise (faux services)
flutter run         # même projet Supabase que l'appli client (lib/config.dart)
```

- Paquet Android `tn.mida.mida_livreur`, nom affiché « Mida Livreur ». Thème, composants, règles de saisie et messages d'erreur copiés de l'appli client ; `image_picker` pour les photos des documents (galerie, JPEG 2000 px au plus).
- **Écran racine** (`EspaceLivreur`) selon le compte : candidature incomplète → « Vos documents » (étape 2) ; en attente ou refusée → écran d'attente (« Actualiser », « Se déconnecter ») ; validée → courses. Les comptes client, responsable, admin ou bloqués sont refusés à la connexion.
- **Candidature (US25)** : `signUp` avec le rôle `livreur` (le déclencheur d'US02 crée le profil « en attente » et la fiche `livreurs`), puis mise à jour de `livreurs` (véhicule, immatriculation), envoi des photos dans `documents-livreurs/<id>/<type>.jpg` et une ligne `documents_livreur` par document (état forcé à « en attente » par la base). La validation se fera dans le tableau de bord admin (US34) ; d'ici là, par SQL.
- **Questions de la candidature** (demande du 18/11) : « Avez-vous une moto ? » (Oui = moto, Non = vélo ; le choix « Voiture » n'est pas proposé) et « Avez-vous un permis de conduire ? ». Une moto sans permis est refusée dans l'appli (« Un permis de conduire est obligatoire pour livrer en moto. Sans permis, vous pouvez livrer à vélo. »). Documents : carte d'identité toujours ; permis si « Oui » ; carte grise et immatriculation pour une moto.
- **Disponibilité (US26)** : `livreurs.disponible`, conservé d'une ouverture à l'autre. La base refuse « disponible » à un compte non validé ; bloquer un livreur le rend indisponible.
- **Courses (US27, US28)**, migration `20261118000001` : la course (`livraisons`, état `proposee`, gain = `parametres.gain_livreur`) est créée quand le restaurant **accepte** la commande ; les commandes déjà acceptées avant la migration ont reçu la leur. Seuls les livreurs **validés et disponibles** la voient (règle `peut_voir_commande`). Fonctions : `accepter_course` (verrou de la ligne : un seul livreur ; refus si le livreur a déjà une course en cours), `recuperer_course` (seulement si la commande est `prete` → commande `en_livraison`), `livrer_course` (commande `livree`, `livree_le` ; paiement en espèces → `paye`). Le client reçoit « Livreur en route », « Commande en route », « Commande livrée ». `livraisons` est diffusée en temps réel.
- Une course prise par un autre livreur cesse d'être visible pour les autres : la base n'envoie donc pas d'événement temps réel aux autres livreurs → l'accueil relit la liste toutes les 20 s, et « Accepter » sur une course déjà prise affiche « Cette course a déjà été acceptée par un autre livreur ».
- Pas encore fait : historique et gains (US42), itinéraire (US41), notification de nouvelle course appli fermée (US43).

## Notifications push (US23)

Chemin d'une notification : une fonction serveur ajoute une ligne dans `notifications` → le déclencheur `envoyer_push` (migration `20261118000003`) appelle, **après** la validation de la transaction (pg_net), l'Edge Function `envoyer-push` en ne lui donnant que l'identifiant → la fonction relit la notification et l'envoie par **Firebase Cloud Messaging** (API HTTP v1) à chaque téléphone du destinataire (`device_tokens`). Les jetons refusés par Firebase (appli désinstallée) sont supprimés. Une panne du push ne bloque jamais une commande.

- **Applis** (`lib/push/notifications_push.dart`, identique dans les deux) : à la connexion, demande l'autorisation (Android 13+), puis enregistre le jeton avec `enregistrer_jeton` (un téléphone qui change de compte change de propriétaire) ; à la déconnexion, le jeton est supprimé. Canal Android « Commandes » en importance haute (`MainActivity.kt`), icône étoile `ic_notification`.
- **Projet Firebase** : `midaproject`, deux applis Android (`tn.mida.mida_client`, `tn.mida.mida_livreur`).
- **Fichiers secrets (jamais dans git, dossier `secrets/`)** : `google-services.json` (à copier dans `apps/client/android/app/` et `apps/livreur/android/app/` avant de compiler : sans lui, la compilation échoue), `firebase-service-account.json` (clé du compte de service), `push.env`.
- **Réglages en ligne** (déjà faits) :
  - secrets de l'Edge Function : `PUSH_SECRET` et `FIREBASE_SERVICE_ACCOUNT` (le JSON en base64) — `npx supabase secrets set --env-file secrets/push.env` ;
  - déploiement : `npx supabase functions deploy envoyer-push --no-verify-jwt --use-api` (pas de JWT : c'est l'en-tête `x-mida-secret` qui protège l'appel) ;
  - Vault : secrets `push_url` (adresse de la fonction) et `push_secret` (même valeur que `PUSH_SECRET`), lus par le déclencheur. Sans eux, rien n'est envoyé.
- **Limites** : pas de push vers l'espace web restaurant ni l'admin (ils ont déjà le temps réel) ; toucher la notification ouvre l'appli sans aller directement à la commande. `getToken()` est marqué obsolète dans firebase_messaging 17 (au profit de `register()`), on le garde car c'est le jeton qu'attend l'API HTTP v1.

## Tableau de bord d'administration (US32 à US37)

```bash
cd apps/admin
npm install
npm test            # Vitest : connexion, restaurants, livreurs, clients, commandes, paramètres
npm run dev -- --port 5174
```

- Même base technique et même style que l'espace restaurant (Vite + React + TypeScript + react-router + supabase-js ; `index.css` repris, compléments dans `admin.css`). Session gardée dans l'onglet (`sessionStorage`) : elle se ferme avec le navigateur.
- **Accès** : seul un compte `admin` non bloqué entre ; tout autre compte est déconnecté avec « Ce compte n'a pas le rôle administrateur… ». Un compte admin ne se crée pas par inscription : on passe un compte existant en `role = 'admin'` par SQL.
- **Décisions** (migration `20261118000002`) : `admin_decider_restaurant(id, valider, motif)` (restaurant et compte du responsable, motif obligatoire pour un rejet, notification), `admin_decider_livreur(id, valider, motif)` (documents et compte, carte d'identité exigée pour valider, notification), `admin_bloquer_compte(id, bloquer)` (un responsable bloqué bloque son restaurant, qui se ferme ; la réactivation le rouvre aux commandes ; un compte admin ne peut pas être bloqué). Fonctions **security invoker** : elles s'exécutent avec les droits de l'appelant (les règles d'accès s'appliquent) et vérifient en plus qu'il est administrateur.
- **Documents des livreurs** : lus dans le stockage privé par une adresse signée valable 10 minutes (`createSignedUrl`).
- **Paramètres** : `parametres` (frais ≤ 50 DT, gain ≤ 50 DT, commission 0-100 %) ; `passer_commande` copie les frais au moment de la commande, donc un changement ne touche que les commandes suivantes.

## Espace restaurant web (US05)

```bash
cd apps/restaurant
npm install
npm run dev         # http://localhost:5173 — se connecte au projet Supabase de Mida (src/config.ts)
npm test            # 83 tests (Vitest)
npm run build       # vérification TypeScript + version de production dans dist/
```

- Inscription en 2 étapes : compte du responsable (rôle `responsable`, état `en_attente`), puis restaurant (ligne `restaurants`, la base force l'état `en_attente`). Aucune migration ajoutée.
- Après connexion, la page dépend de l'état du restaurant : pas encore inscrit → fin de l'inscription ; `en_attente` ou `rejete` → écran d'attente (avec le motif du refus) ; `actif` → tableau de bord (provisoire, rempli par les stories suivantes).
- Les comptes client, livreur, admin ou bloqués sont refusés avec un message qui indique la bonne application.
- Reportés à US07 (profil du restaurant) : matricule fiscal et logo.
- Essai du 15/11/2026 dans le navigateur avec le vrai projet Supabase : inscription d'un responsable et de son restaurant (Ariana), profil `responsable` / `en_attente`, restaurant `en_attente`, rôle présent dans le jeton (hook). « Confirm email » doit rester désactivé pendant les essais (sinon Supabase refuse les adresses `@mida.test`).

### Profil du restaurant (US07)

Page `/profil` (`src/pages/Profil.tsx`), dans le cadre à menu latéral (`src/Cadre.tsx`) partagé avec le tableau de bord.

- **Informations** : nom, catégorie, adresse, ville, téléphone, description → `update` de la ligne `restaurants`. L'état et le motif de refus ne sont jamais envoyés (réservés à l'admin).
- **Logo** : JPEG, PNG ou WebP, 5 Mo maximum ; l'image est réduite à 512 px et convertie en WebP dans le navigateur, puis envoyée à `restaurants/<restaurant_id>/logo.webp` (`upsert`) ; `restaurants.logo_url` reçoit l'URL publique suivie de `?v=<date>`.
- **Horaires** : les 7 jours sont enregistrés d'un coup (`upsert` sur `restaurant_id, jour`). Un jour décoché est « fermé ». Une fermeture avant l'ouverture (18:00 → 02:00) veut dire « ferme après minuit ». Tant que rien n'est enregistré, la page propose 11:00 – 23:00.
- **Accès** : dès que le restaurant est inscrit, même en attente ou refusé (lien sur la page d'attente). Les clients ne voient le restaurant et ses horaires qu'une fois validé (règles US02) ; pour un restaurant validé, la modification est visible tout de suite, sans autre étape.
- Pas de migration : les règles d'accès des US02 et US03 suffisent (vérifié par les tests « US07 » de `supabase/tests`).
- Reportés : photo de couverture, position sur la carte, matricule fiscal ; l'interrupteur ouvert / fermé est la story US08.

### Ouvert / fermé en un clic (US08)

- Dans le menu latéral (`src/Cadre.tsx`), sous le nom du restaurant : un interrupteur vert « Restaurant ouvert » / rouge « Restaurant fermé », visible sur toutes les pages. Il n'apparaît que pour un restaurant validé ; un nouveau restaurant validé démarre **fermé** (le tableau de bord le rappelle).
- L'interrupteur modifie `restaurants.ouvert`. Cette colonne est lisible par les visiteurs et les clients pour tout restaurant validé : l'appli client l'affichera avec le catalogue des restaurants (pas encore développé).
- Garanties de la base (migration `20261115000001`) :
  - un restaurant ouvert est forcément validé (contrainte) ; le responsable d'un restaurant en attente reçoit un refus, et bloquer ou refuser un restaurant le ferme automatiquement ;
  - **aucune nouvelle commande** (état `en_attente`) ne peut être créée pour un restaurant fermé ou non validé, même par une fonction serveur (déclencheur `restaurant_ouvert` sur `commandes`). Les commandes déjà passées continuent leur vie après la fermeture. La future fonction « passer commande » devra afficher ce refus au client.
- L'interrupteur est manuel : il ne suit pas les horaires d'ouverture (US07).

### Catégories du menu (US09)

- Page `/menu` (`src/pages/Menu.tsx`, lien « Menu » du menu latéral), ouverte dès l'inscription du restaurant : le menu se prépare pendant la validation, mais reste invisible des clients jusque-là.
- Une catégorie a un **nom** (40 caractères au plus, unique dans le menu, sans tenir compte des majuscules) et un **ordre d'affichage**. Une nouvelle catégorie va à la fin ; les flèches la montent ou la descendent, et l'ordre complet est enregistré en une seule requête (`upsert`, `ordre` = 1, 2, 3…).
- **Suppression** : toujours confirmée. Si la catégorie contient des plats, la confirmation l'annonce (« contient 3 plats… ces plats seront supprimés ») et le bouton le répète. La base refuse de supprimer directement une catégorie qui contient des plats ; l'espace restaurant appelle donc la fonction `supprimer_categorie_menu` (migration `20261115000002`), qui supprime les plats puis la catégorie dans la même transaction, avec les droits de l'appelant. Les commandes déjà passées gardent le nom et le prix des plats supprimés.
- Les plats eux-mêmes (nom, prix, photo) : US10.

### Plats (US10)

- Sur la page `/menu`, chaque catégorie liste ses plats (photo, nom, description, prix) avec « Modifier » et « Supprimer » (confirmation). Le formulaire est sur `/menu/plats/nouveau` (`?categorie=<id>` pour présélectionner la catégorie) et `/menu/plats/<id>` (`src/pages/PlatForm.tsx`).
- **Prix** en dinars avec 3 décimales : « 16 », « 16,5 », « 16.500 » ou « 16,000 DT » sont acceptés ; il doit être positif (la base le refuse aussi : `prix > 0`) et au plus 1 000 DT. Affichage tunisien : « 16,500 DT ».
- **Photo** (facultative) : JPEG, PNG ou WebP, 5 Mo au plus, réduite à 800 px et convertie en WebP, envoyée à `restaurants/<restaurant_id>/plats/<plat_id>.webp`. L'identifiant du plat est choisi par l'appli (`crypto.randomUUID()`) pour nommer la photo. Le plat est enregistré d'abord : si la photo échoue, il reste au menu sans photo et un avertissement invite à réessayer. Supprimer un plat retire aussi sa photo du stockage (pas encore pour les plats supprimés avec leur catégorie).
- **Catégorie** : obligatoire, et forcément une catégorie du même restaurant (clé étrangère composée de la migration US01).
- **Côté client** : les plats d'un restaurant validé sont lisibles par les visiteurs et les clients (vérifié par les tests « US10 » de `supabase/tests`) ; l'appli client les affichera avec l'écran du restaurant (pas encore développé).
- La case « disponible » (plat épuisé) : voir US11 ci-dessous. Modifier un plat ne change pas sa disponibilité.

### Plat indisponible (US11)

- Sur la page `/menu`, chaque plat a une case **« Disponible »**, comme dans la maquette « Restaurant · Menu ». Un clic la décoche : le plat est grisé, marqué « Indisponible », et le sous-titre compte les plats indisponibles (« 3 catégories · 8 plats · 1 plat indisponible »). Un second clic le réactive. Pas de confirmation, car l'action se défait aussi vite. Si la base refuse, la case revient comme avant et un message s'affiche.
- **Côté client** : le plat reste visible (les clients savent qu'il existe), mais il ne peut pas être commandé. La base le garantit, quelle que soit l'appli : le déclencheur `plat_disponible` sur `lignes_commande` (migration `20261116000001`, fonction `private.verifier_plat_disponible`) refuse une ligne d'une commande `en_attente` dont le plat est indisponible (« Le plat « … » est indisponible pour le moment »). La future fonction « passer commande » et le panier de l'appli client devront afficher ce refus ; le panier devra aussi griser le bouton « Ajouter ».
- Les commandes déjà passées ne sont pas concernées si le plat devient indisponible ensuite.

### Commandes en cours en temps réel (US12)

- Page `/commandes` (`src/pages/Commandes.tsx`, maquette « Restaurant · Commandes en cours »), réservée aux restaurants validés. Quatre colonnes : **En attente**, **En préparation** (acceptée ou en préparation), **Prête**, **En cours de livraison**. Chaque carte montre le numéro, le client (prénom et initiale), l'heure, les plats avec leur quantité et leur remarque, la remarque du client, le mode de paiement (« Espèces à la livraison », « Carte · payée ») et le total. Les boutons Accepter / Refuser viendront avec US13, « Marquer comme prête » avec US14, le nom du livreur avec les stories du livreur.
- **Temps réel** : Supabase Realtime, migration `20261116000002` (table `commandes` ajoutée à la publication `supabase_realtime`). L'abonnement (`surCommandes`) filtre sur le restaurant, et Realtime applique la RLS : un restaurant ne reçoit que ses commandes. À chaque événement, l'appli relit la liste complète avec son détail (une requête, 300 ms après le dernier événement), et aussi à chaque reconnexion.
- **Alerte** (`src/commandes/suivi.tsx`, active sur toutes les pages de l'espace restaurant) :
  - visuelle : pastille rouge sur « Commandes » dans le menu (nombre de commandes en attente), bandeau « N nouvelles commandes à traiter », nombre dans le titre de l'onglet (« (2) Mida… »), carte mise en avant 15 secondes ; sur les autres pages, un bandeau « Nouvelle commande reçue ! » avec un lien vers les commandes ;
  - sonore : deux notes jouées avec Web Audio (`src/commandes/son.ts`, pas de fichier son). Le bouton « Alerte sonore activée / désactivée » garde le choix dans le navigateur. Les navigateurs bloquent le son tant que la page n'a reçu aucun clic : après un F5, le premier clic dans la page le débloque, et un message invite à cliquer si besoin.
- **Essai réel sans appli client** : une commande peut être créée à la main dans l'éditeur SQL de Supabase (commande `en_attente` + ses `lignes_commande` + son `paiements`, dans une seule transaction). Les déclencheurs `restaurant_ouvert` (US08) et `plat_disponible` (US11) s'appliquent. Attention : un paiement `paye` doit avoir sa date `paye_le` (contrainte de la table `paiements`).

### Accepter ou refuser une commande (US13)

- Sur la page `/commandes`, chaque commande **en attente** a deux boutons. **Accepter** : un clic, la commande passe à « acceptée » (colonne « En préparation »). **Refuser** : fenêtre « Refuser la commande n° … » (maquette « Restaurant · Refus ») avec un **motif obligatoire** (« Un plat est épuisé », « Trop de commandes en cours », « Le restaurant ferme bientôt », « Autre motif ») et un message facultatif au client, obligatoire pour « Autre motif ». Le motif enregistré est « Motif — message ». La fenêtre indique si le client sera remboursé (carte payée) ou non (espèces). Échap ou « Annuler » la ferme.
- **Base** (migration `20261116000003`) : les applications n'ont toujours pas le droit de modifier une commande directement. Le responsable appelle `accepter_commande(p_commande)` ou `refuser_commande(p_commande, p_motif)`. Ces fonctions verrouillent la commande, vérifient qu'elle appartient au restaurant du responsable connecté (`private.est_responsable_de`) et qu'elle est encore `en_attente` (une seule décision : « La commande n° … a déjà été traitée »), puis :
  - accepter : `etat = acceptee`, `acceptee_le = now()` ;
  - refuser : `etat = refusee`, `motif_refus` ; un paiement par **carte déjà payé** passe à `rembourse` (le vrai remboursement auprès de la passerelle viendra avec la story du paiement) ;
  - dans les deux cas, une **notification** est créée pour le client (« Commande acceptée » / « Commande refusée », avec le motif et le montant remboursé). L'appli client les affichera ; le changement d'état est aussi diffusé en temps réel (US12).
- Les fonctions sont `security definer` (elles écrivent dans `commandes`, interdite aux applications) et réservées aux comptes connectés (`anon` n'y a pas accès). L'outil de sécurité de Supabase les signale (« Signed-In Users Can Execute SECURITY DEFINER Function ») : c'est voulu, car ce sont les seules portes d'entrée, et elles contrôlent elles-mêmes le restaurant et l'état.

### En préparation, puis prête (US14)

- Dans la colonne « En préparation », une commande **acceptée** porte l'étiquette « Acceptée · à préparer » et le bouton **« Commencer la préparation »** ; une commande **en préparation** porte « En cuisine » et le bouton **« Marquer comme prête »**. Une fois prête, elle passe dans la colonne « Prête », sans bouton : la suite (récupération, livraison) appartient au livreur.
- **Base** (migration `20261116000004`) : `avancer_commande(p_commande, p_etat)`, où `p_etat` est l'état **visé** (`en_preparation` ou `prete`). La fonction n'accepte que `acceptee → en_preparation` et `en_preparation → prete` : pas de saut d'étape, pas de retour en arrière, aucun autre état (« Le restaurant ne peut faire passer une commande qu'à « en préparation » ou « prête » »). Comme l'état visé est indiqué, un double clic ou un onglet resté ouvert ne fait jamais avancer la commande de deux étapes (« La commande n° … est déjà prête »). `prete_le` est enregistrée, et le client reçoit une notification à chaque étape (« Commande en préparation », « Commande prête »). Mêmes contrôles qu'US13 (commande du restaurant du responsable connecté, verrou).
- Pas encore fait : proposer la course aux livreurs quand la commande est prête (stories du livreur).

## Mot de passe oublié (US06) — en attente du réglage e-mail

Dans l'appli client : `lib/pages/mot_de_passe_oublie_page.dart` (`resetPasswordForEmail` → `verifyOTP` de type `recovery` → `updateUser`). Un code plutôt qu'un lien, pour ne pas dépendre de l'ouverture de l'appli depuis le navigateur.

Le lien « Mot de passe oublié ? » de l'écran de connexion est **masqué** (`motDePasseOublieActif` dans `lib/config.dart`) tant que le projet Supabase n'envoie pas le code. À faire avant de l'activer :

1. **SMTP personnalisé** (Authentication → Emails → Set up SMTP). Sans lui, l'offre gratuite ne permet pas de modifier les modèles d'e-mail, n'envoie qu'environ 2 e-mails par heure, et pas à toutes les adresses. Avec Gmail : hôte `smtp.gmail.com`, port `587`, identifiant = l'adresse Gmail, mot de passe = un « mot de passe d'application » Google (validation en deux étapes requise).
2. **Modèle « Reset password »** (onglet Source) : y mettre le code `{{ .Token }}` à la place du lien.
3. Lancer ou compiler avec `--dart-define=MOT_DE_PASSE_OUBLIE=true`, puis essayer avec une vraie adresse e-mail.

La même fonction reste à faire dans l'espace restaurant web.
