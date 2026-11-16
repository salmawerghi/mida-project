-- =====================================================================
-- Mida — US12 : nouvelles commandes en temps réel dans l'espace restaurant
-- =====================================================================
-- Supabase Realtime diffuse les changements des tables de la publication
-- `supabase_realtime`. Chaque abonné ne reçoit que les lignes qu'il a le
-- droit de lire (règle « commande : lecture » d'US02) : un restaurant ne
-- reçoit que ses propres commandes.
-- Le détail (plats, paiement, nom du client) est relu par l'appli à
-- chaque événement : seule la table `commandes` est diffusée.
-- =====================================================================

alter publication supabase_realtime add table public.commandes;
