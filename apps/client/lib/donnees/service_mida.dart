import 'package:supabase_flutter/supabase_flutter.dart';

import '../panier/panier.dart';
import 'format.dart';
import 'modeles.dart';

/// Données de Mida lues et écrites par l'appli client (remplaçable dans les tests).
abstract class ServiceMida {
  /// Restaurants validés par Mida, ouverts ou fermés (US15).
  Future<List<RestaurantCatalogue>> restaurants();

  /// Catégories de restaurants, pour le filtre du catalogue (US16).
  Future<List<CategorieRestaurant>> categoriesRestaurant();

  /// Menu d'un restaurant : rubriques, plats (disponibles ou non) et horaires du jour (US17).
  Future<MenuRestaurant> menu(String restaurantId);

  /// Frais de livraison actuels (paramètres de la plateforme), pour l'aperçu du panier.
  Future<double> fraisLivraison();

  /// Passe la commande (US19, paiement en espèces). Le serveur recalcule tous les montants.
  Future<CommandePassee> passerCommande({
    required String restaurantId,
    required List<LignePanier> lignes,
    required String adresse,
    String? remarque,
  });
}

class ServiceMidaSupabase implements ServiceMida {
  ServiceMidaSupabase(this._client);
  final SupabaseClient _client;

  @override
  Future<List<RestaurantCatalogue>> restaurants() async {
    // Les règles d'accès ne montrent déjà que les restaurants validés ;
    // le filtre explicite garde le catalogue juste même pour un admin.
    final lignes = await _client
        .from('restaurants')
        .select('id, nom, ville, description, categorie_id, logo_url, ouvert, temps_preparation_min, '
            'categories_restaurant(nom)')
        .eq('etat', 'actif');
    // Note moyenne et nombre d'avis (vue de la migration US15).
    final notes = await _client.from('notes_restaurants').select('restaurant_id, note, nb_avis');
    final parRestaurant = {for (final n in notes) n['restaurant_id'] as String: n};
    return [
      for (final l in lignes) RestaurantCatalogue.depuis(l, note: parRestaurant[l['id']]),
    ]..sort(comparerRestaurants);
  }

  @override
  Future<List<CategorieRestaurant>> categoriesRestaurant() async {
    final lignes = await _client.from('categories_restaurant').select('id, nom').order('ordre').order('nom');
    return [for (final l in lignes) CategorieRestaurant(id: l['id'] as String, nom: l['nom'] as String)];
  }

  @override
  Future<MenuRestaurant> menu(String restaurantId) async {
    final categories =
        await _client.from('categories_menu').select('id, nom').eq('restaurant_id', restaurantId).order('ordre').order('nom');
    final plats = await _client
        .from('plats')
        .select('id, categorie_id, nom, description, prix, image_url, disponible')
        .eq('restaurant_id', restaurantId)
        .order('nom');
    // 1 = lundi … 7 = dimanche, comme DateTime.weekday
    final horaire = await _client
        .from('horaires')
        .select('ouverture, fermeture, ferme')
        .eq('restaurant_id', restaurantId)
        .eq('jour', DateTime.now().weekday)
        .maybeSingle();
    return MenuRestaurant(
      categories: [for (final c in categories) CategorieMenu(id: c['id'] as String, nom: c['nom'] as String)],
      plats: [for (final p in plats) Plat.depuis(p)],
      horaire: horaire == null ? null : HoraireDuJour.depuis(horaire),
    );
  }

  @override
  Future<double> fraisLivraison() async {
    final p = await _client.from('parametres').select('frais_livraison').eq('id', 1).single();
    return lireNombre(p['frais_livraison']);
  }

  @override
  Future<CommandePassee> passerCommande({
    required String restaurantId,
    required List<LignePanier> lignes,
    required String adresse,
    String? remarque,
  }) async {
    // Fonction de la base (migration US19) : seuls les plats et les quantités sont envoyés.
    final r = await _client.rpc('passer_commande', params: {
      'p_restaurant': restaurantId,
      'p_lignes': [
        for (final l in lignes) {'plat_id': l.plat.id, 'quantite': l.quantite},
      ],
      'p_adresse': adresse,
      'p_remarque': remarque,
    });
    return CommandePassee.depuis(Map<String, dynamic>.from(r as Map));
  }
}
