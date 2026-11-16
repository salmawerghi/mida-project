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
  seed.sql                             jeu de données de test (données des maquettes)
  tests/                               tests automatiques des migrations (PGlite, sans Docker)
apps/
  client/                              application mobile client (Flutter)
  restaurant/                          espace web du responsable restaurant (React + TypeScript)
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
| US14 | Faire avancer une commande (espace web) : « Commencer la préparation » (acceptée → en préparation) puis « Marquer comme prête », une étape par clic, sans saut ni retour en arrière ; client prévenu à chaque étape | codé : 4 tests Vitest + 3 tests PGlite, fonction appliquée sur Supabase ; essai réel à faire (commande de test 1001) |
| US15 | Catalogue de l'appli client : restaurants validés (ouverts d'abord), avec logo, catégorie, ville, note moyenne et nombre d'avis, état ouvert / fermé, délai ; aussi pour les visiteurs | codé : 6 tests Flutter + 1 test PGlite, vue appliquée sur Supabase ; essai réel à faire |
| US16 | Recherche d'un restaurant par nom (sans tenir compte des majuscules ni des accents) et filtre par catégorie ; message et « Effacer les filtres » s'il n'y a aucun résultat | codé : 5 tests Flutter ; essai réel à faire |
| US17 | Menu d'un restaurant (appli client) : rubriques dans l'ordre du restaurant, plats avec photo, description et prix, plats indisponibles signalés, note, délai et horaire du jour ; restaurant fermé consultable avec un bandeau | codé : 7 tests Flutter ; essai réel à faire |
| US18 | Panier (appli client) : ajouter des plats depuis le menu, modifier les quantités (1 à 20), retirer, vider ; total à jour ; un seul restaurant par panier (proposition de vider sinon) ; conservé en quittant l'écran | codé : 7 tests Flutter ; essai réel à faire |
| US19 | Valider la commande (appli client) : adresse de livraison obligatoire, remarque, paiement en espèces, récapitulatif sous-total / frais / total ; total calculé par le serveur ; la commande arrive au restaurant « en attente » ; un visiteur se connecte d'abord, panier gardé | codé : 7 tests Flutter + 3 tests PGlite, fonction appliquée sur Supabase ; essai réel à faire |

US01 à US03, US08, US09, US11 à US15 et US19 sont appliquées sur le projet Supabase de Mida (`tpfpuwlgnxhwhezicuto`) ; le jeu de test n'y est pas encore chargé.

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

- Sous les plats du panier : **adresse de livraison** (obligatoire), remarque pour le restaurant (facultative), mode de paiement **Espèces** (« À payer au livreur, à la livraison » ; « Carte en ligne » est affichée « Bientôt disponible »), puis le récapitulatif : sous-total, frais de livraison (lus dans `parametres`), total. Le bouton « Commander · 25,500 DT » envoie la commande. L'adresse et la remarque sont gardées dans le panier si l'on quitte l'écran.
- **Visiteur** : « Commander » ouvre « Connectez-vous pour commander » (maquette « Client · Connexion requise » : « Votre panier est gardé », rappel du panier). « J'ai déjà un compte » ou « Créer un compte » ramènent ensuite **au panier** (paramètre `retourApresConnexion` de `ConnexionPage` et `InscriptionPage`), où le client n'a plus qu'à toucher « Commander ». « Continuer à explorer » revient au panier sans rien envoyer.
- **Serveur** (migration `20261116000006`) : `passer_commande(p_restaurant, p_lignes, p_adresse, p_remarque)`, où `p_lignes` = `[{"plat_id", "quantite", "remarque"}]`. L'appli n'envoie **aucun prix** : la fonction relit le prix de chaque plat dans le menu et les frais dans `parametres`, et calcule `sous_total`, `frais_livraison` et `total`. Elle vérifie : compte **client** non bloqué, adresse non vide (300 caractères au plus), panier non vide (30 plats différents au plus, pas de doublon), quantités de 1 à 20, plats **du restaurant choisi** et **disponibles** ; le déclencheur d'US08 refuse un restaurant fermé. Elle crée la commande `en_attente`, ses lignes (nom et prix copiés), le paiement `especes` / `en_attente`, et une notification « Nouvelle commande » pour le restaurant. Elle renvoie `{id, numero, sous_total, frais_livraison, total}`. Les refus s'affichent tels quels dans l'appli (« Ce restaurant est fermé… », « Le plat « … » est indisponible pour le moment »).
- Après l'envoi : panier vidé, retour à l'accueil avec « Commande n° … envoyée au restaurant » (le suivi arrive avec US20).

- Les services sont fournis à tous les écrans par `Dependances.of(context)` (`lib/dependances.dart`) ; les tests utilisent `test/faux_service_mida.dart`.

- Si la compilation Android échoue sur le cache Kotlin (« Could not close incremental caches ») : c'est le projet sur `D:` et le cache pub sur `C:` ; `kotlin.incremental=false` est déjà dans `android/gradle.properties`.

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
