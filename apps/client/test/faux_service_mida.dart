import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/donnees/service_mida.dart';

/// Faux service de données : catalogue en mémoire, appels enregistrés.
class FauxServiceMida implements ServiceMida {
  FauxServiceMida({List<RestaurantCatalogue>? restaurants, this.erreur}) : _restaurants = restaurants ?? catalogueTest;

  final List<RestaurantCatalogue> _restaurants;

  /// Levée par chaque lecture si elle est fournie (puis effacée : « Réessayer » réussit).
  Object? erreur;
  int lectures = 0;

  Future<T> _repondre<T>(T valeur) async {
    lectures++;
    final e = erreur;
    if (e != null) {
      erreur = null;
      throw e;
    }
    return valeur;
  }

  @override
  Future<List<RestaurantCatalogue>> restaurants() => _repondre([..._restaurants]..sort(comparerRestaurants));

  /// Les catégories ne se chargent pas (le catalogue doit rester utilisable).
  bool erreurCategories = false;

  @override
  Future<List<CategorieRestaurant>> categoriesRestaurant() async {
    if (erreurCategories) throw Exception('catégories indisponibles');
    return categoriesTest;
  }
}

const categoriesTest = [
  CategorieRestaurant(id: 'k1', nom: 'Couscous et tajines'),
  CategorieRestaurant(id: 'k2', nom: 'Ojja et grillades'),
  CategorieRestaurant(id: 'k3', nom: 'Douceurs'),
];

const catalogueTest = [
  RestaurantCatalogue(
    id: 'r2',
    nom: 'El Kanoun',
    ville: 'Tunis',
    categorieId: 'k2',
    categorie: 'Ojja et grillades',
    ouvert: true,
    tempsPreparationMin: 20,
  ),
  RestaurantCatalogue(
    id: 'r3',
    nom: 'Bab Souika',
    ville: 'Tunis',
    categorieId: 'k1',
    categorie: 'Couscous et tajines',
    ouvert: false,
    note: 4.2,
    nbAvis: 5,
  ),
  RestaurantCatalogue(
    id: 'r1',
    nom: 'Dar Zitouna',
    ville: 'La Marsa',
    categorieId: 'k1',
    categorie: 'Couscous et tajines',
    ouvert: true,
    note: 4.8,
    nbAvis: 12,
  ),
];
