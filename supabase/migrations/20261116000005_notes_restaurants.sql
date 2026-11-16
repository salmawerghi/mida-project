-- =====================================================================
-- Mida — US15 : note moyenne des restaurants (catalogue de l'appli client)
-- =====================================================================
-- Les avis sont publics (règle « avis : lecture publique » d'US02) : la
-- vue calcule la note moyenne et le nombre d'avis de chaque restaurant.
-- `security_invoker` : la vue applique les règles d'accès de celui qui la
-- lit (pas celles de son propriétaire).
-- =====================================================================

create view public.notes_restaurants
with (security_invoker = true)
as
select restaurant_id,
       round(avg(note), 1) as note,
       count(*)::integer   as nb_avis
from public.avis
where restaurant_id is not null
group by restaurant_id;

grant select on public.notes_restaurants to anon, authenticated;
