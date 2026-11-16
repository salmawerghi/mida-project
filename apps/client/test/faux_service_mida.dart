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

  final menusDemandes = <String>[];

  @override
  Future<MenuRestaurant> menu(String restaurantId) {
    menusDemandes.add(restaurantId);
    return _repondre(restaurantId == 'r1' ? menuTest : const MenuRestaurant(categories: [], plats: []));
  }

  /// Les catégories ne se chargent pas (le catalogue doit rester utilisable).
  bool erreurCategories = false;

  @override
  Future<List<CategorieRestaurant>> categoriesRestaurant() async {
    if (erreurCategories) throw Exception('catégories indisponibles');
    return categoriesTest;
  }
}

/// Menu de Dar Zitouna (r1) ; les autres restaurants n'ont pas encore de menu.
const menuTest = MenuRestaurant(
  categories: [
    CategorieMenu(id: 'm1', nom: 'Couscous'),
    CategorieMenu(id: 'm2', nom: 'Tajines'), // vide : pas affichée
    CategorieMenu(id: 'm3', nom: 'Douceurs et thé'),
  ],
  plats: [
    Plat(id: 'p1', categorieId: 'm1', nom: 'Couscous à l’agneau', description: 'Semoule fine, agneau', prix: 18),
    Plat(id: 'p2', categorieId: 'm1', nom: 'Couscous au poisson', description: 'Mérou', prix: 22.5, disponible: false),
    Plat(id: 'p3', categorieId: 'm1', nom: 'Couscous aux légumes', prix: 13),
    Plat(id: 'p4', categorieId: 'm3', nom: 'Thé à la menthe', prix: 2.5),
  ],
  horaire: HoraireDuJour(ferme: false, ouverture: '11:00', fermeture: '23:00'),
);

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
