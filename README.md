# Mida — plateforme de livraison de repas

Projet de fin d'année : 4 applications (client et livreur en Flutter, restaurant et admin en React + TypeScript) autour d'un backend Supabase commun.

## Organisation

```
supabase/
  migrations/
    20261113000001_schema.sql          US01 : tables, relations, contraintes
    20261113000002_roles_securite.sql  US02 : rôles, règles d'accès (RLS), rôle dans le jeton
  seed.sql                             jeu de données de test (données des maquettes)
  tests/                               tests automatiques des migrations (PGlite, sans Docker)
```

## Avancement du backlog

| Story | Contenu | État |
|-------|---------|------|
| US01 | Base de données : 18 tables du §9 (+ livreurs, documents, horaires, paramètres, réclamations, notifications, jetons d'appareil), relations et contraintes, jeu de test | fait, testé en local |
| US02 | 4 rôles (client, livreur, responsable, admin), RLS sur toutes les tables, protection des champs réservés à l'admin, rôle dans le JWT | fait, testé en local |

## Appliquer sur un projet Supabase

**Projet dédié obligatoire** : ne pas utiliser le projet de DarImmo (même `auth.users`, même table `profiles`).

Méthode simple, depuis le tableau de bord Supabase (**SQL Editor**), dans cet ordre :

1. `supabase/migrations/20261113000001_schema.sql`
2. `supabase/migrations/20261113000002_roles_securite.sql`
3. `supabase/seed.sql` (données de test, facultatif)

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

## Tests

```bash
cd supabase/tests
npm install
npm test
```

Les tests chargent les migrations et le seed dans un PostgreSQL embarqué (PGlite) avec une imitation minimale de l'authentification Supabase (`tests/supabase-stub.sql`), puis vérifient chaque règle en se connectant avec chaque rôle. Ils ne remplacent pas un essai sur un vrai projet Supabase (connexion réelle, JWT).
