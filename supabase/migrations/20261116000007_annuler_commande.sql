-- =====================================================================
-- Mida — US21 : le client annule sa commande tant qu'elle n'est pas acceptée
-- =====================================================================
-- Seul le client de la commande peut l'annuler, et seulement à l'état
-- « en attente » : une fois acceptée, le restaurant a commencé son travail.
-- Le restaurant voit la commande passer à « annulée » (temps réel US12)
-- et reçoit une notification. Un paiement par carte déjà encaissé est
-- remboursé (comme pour un refus, US13).
-- =====================================================================

create function public.annuler_commande(p_commande uuid)
returns void
language plpgsql
security definer                     -- les applications n'ont pas le droit de modifier une commande
set search_path = ''
as $$
declare
  v public.commandes;
  v_responsable uuid;
begin
  -- verrou : une acceptation et une annulation simultanées ne passent pas toutes les deux
  select * into v from public.commandes where id = p_commande for update;
  if not found or v.client_id is distinct from (select auth.uid()) then
    raise exception 'Commande introuvable' using errcode = '42501';
  end if;
  if v.etat <> 'en_attente' then
    raise exception '%', case v.etat
        when 'annulee' then format('La commande n° %s est déjà annulée', v.numero)
        when 'refusee' then format('La commande n° %s a déjà été refusée par le restaurant', v.numero)
        else format('La commande n° %s ne peut plus être annulée : le restaurant l''a déjà acceptée', v.numero)
      end
      using errcode = 'P0001', hint = v.etat::text;
  end if;

  update public.commandes
     set etat = 'annulee', annulee_le = now()
   where id = v.id;

  update public.paiements
     set etat = 'rembourse'
   where commande_id = v.id and mode = 'carte' and etat = 'paye';

  select responsable_id into v_responsable from public.restaurants where id = v.restaurant_id;
  insert into public.notifications (destinataire_id, titre, message, type, commande_id)
  values (v_responsable, 'Commande annulée',
          format('Le client a annulé la commande n° %s avant son acceptation.', v.numero),
          'commande', v.id);
end;
$$;

revoke execute on function public.annuler_commande(uuid) from public, anon;
grant execute on function public.annuler_commande(uuid) to authenticated, service_role;
