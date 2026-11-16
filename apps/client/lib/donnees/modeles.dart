/// Données affichées par l'appli client (catalogue, menus, commandes).
library;

import 'format.dart';

/// Catégorie de restaurants (« Couscous et tajines »…), gérée par l'administrateur.
class CategorieRestaurant {
  const CategorieRestaurant({required this.id, required this.nom});
  final String id;
  final String nom;
}

/// Restaurant tel qu'il apparaît dans le catalogue (US15).
class RestaurantCatalogue {
  const RestaurantCatalogue({
    required this.id,
    required this.nom,
    required this.ville,
    this.description = '',
    this.categorieId,
    this.categorie,
    this.logoUrl,
    required this.ouvert,
    this.note,
    this.nbAvis = 0,
    this.tempsPreparationMin = 25,
  });

  final String id;
  final String nom;
  final String ville;
  final String description;
  final String? categorieId;
  final String? categorie;
  final String? logoUrl;
  final bool ouvert;

  /// Note moyenne sur 5, `null` tant qu'il n'y a aucun avis.
  final double? note;
  final int nbAvis;
  final int tempsPreparationMin;

  /// « 25–35 min » : préparation + livraison (estimation simple).
  String get delai => '$tempsPreparationMin–${tempsPreparationMin + 10} min';

  factory RestaurantCatalogue.depuis(Map<String, dynamic> ligne, {Map<String, dynamic>? note}) {
    final categorie = ligne['categories_restaurant'];
    return RestaurantCatalogue(
      id: ligne['id'] as String,
      nom: ligne['nom'] as String,
      ville: ligne['ville'] as String? ?? '',
      description: ligne['description'] as String? ?? '',
      categorieId: ligne['categorie_id'] as String?,
      categorie: categorie is Map ? categorie['nom'] as String? : null,
      logoUrl: ligne['logo_url'] as String?,
      ouvert: ligne['ouvert'] as bool? ?? false,
      note: note?['note'] == null ? null : lireNombre(note!['note']),
      nbAvis: (note?['nb_avis'] as num?)?.toInt() ?? 0,
      tempsPreparationMin: (ligne['temps_preparation_min'] as num?)?.toInt() ?? 25,
    );
  }
}

/// Rubrique du menu d'un restaurant (« Couscous », « Douceurs »…), dans l'ordre choisi par le restaurant.
class CategorieMenu {
  const CategorieMenu({required this.id, required this.nom});
  final String id;
  final String nom;
}

/// Plat du menu (US17). Un plat indisponible reste affiché mais ne peut pas être commandé.
class Plat {
  const Plat({
    required this.id,
    required this.categorieId,
    required this.nom,
    this.description = '',
    required this.prix,
    this.imageUrl,
    this.disponible = true,
  });

  final String id;
  final String categorieId;
  final String nom;
  final String description;

  /// En dinars, ex. 16.5 pour 16,500 DT.
  final double prix;
  final String? imageUrl;
  final bool disponible;

  factory Plat.depuis(Map<String, dynamic> l) => Plat(
        id: l['id'] as String,
        categorieId: l['categorie_id'] as String,
        nom: l['nom'] as String,
        description: l['description'] as String? ?? '',
        prix: lireNombre(l['prix']),
        imageUrl: l['image_url'] as String?,
        disponible: l['disponible'] as bool? ?? true,
      );
}

/// Horaires du jour : `null` si le restaurant ne les a pas renseignés.
class HoraireDuJour {
  const HoraireDuJour({required this.ferme, this.ouverture, this.fermeture});
  final bool ferme;

  /// « 11:00 » (heures locales de Tunisie, telles que saisies par le restaurant).
  final String? ouverture;
  final String? fermeture;

  factory HoraireDuJour.depuis(Map<String, dynamic> l) {
    String? court(Object? h) => h == null ? null : (h as String).substring(0, 5);
    return HoraireDuJour(
      ferme: l['ferme'] as bool? ?? false,
      ouverture: court(l['ouverture']),
      fermeture: court(l['fermeture']),
    );
  }
}

/// Menu complet d'un restaurant : rubriques dans l'ordre, et leurs plats.
class MenuRestaurant {
  const MenuRestaurant({required this.categories, required this.plats, this.horaire});
  final List<CategorieMenu> categories;
  final List<Plat> plats;
  final HoraireDuJour? horaire;

  /// Rubriques qui contiennent au moins un plat, avec leurs plats.
  List<(CategorieMenu, List<Plat>)> get rubriques => [
        for (final c in categories)
          if (plats.any((p) => p.categorieId == c.id)) (c, [for (final p in plats) if (p.categorieId == c.id) p]),
      ];
}

/// « Ouvert · jusqu'à 23:00 », « Fermé », « Fermé aujourd'hui ».
String libelleOuverture({required bool ouvert, HoraireDuJour? horaire}) {
  if (!ouvert) return horaire?.ferme == true ? 'Fermé aujourd\'hui' : 'Fermé';
  final fin = horaire?.fermeture;
  return fin == null || horaire!.ferme ? 'Ouvert' : 'Ouvert · jusqu\'à $fin';
}

/// Texte comparable : minuscules, sans accents (« Bab Souïka » ≈ « bab souika »).
String sansAccents(String texte) {
  const avec = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const sans = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final minuscules = texte.toLowerCase();
  final tampon = StringBuffer();
  for (final c in minuscules.split('')) {
    final i = avec.indexOf(c);
    tampon.write(i < 0 ? c : sans[i]);
  }
  return tampon.toString();
}

/// Recherche par nom et filtre par catégorie du catalogue (US16).
List<RestaurantCatalogue> filtrerRestaurants(
  List<RestaurantCatalogue> restaurants, {
  String recherche = '',
  String? categorieId,
}) {
  final mots = sansAccents(recherche).split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
  return [
    for (final r in restaurants)
      if ((categorieId == null || r.categorieId == categorieId) &&
          mots.every((m) => sansAccents('${r.nom} ${r.categorie ?? ''}').contains(m)))
        r,
  ];
}

/// Ordre du catalogue : restaurants ouverts d'abord, puis les mieux notés, puis par nom.
int comparerRestaurants(RestaurantCatalogue a, RestaurantCatalogue b) {
  if (a.ouvert != b.ouvert) return a.ouvert ? -1 : 1;
  final note = (b.note ?? 0).compareTo(a.note ?? 0);
  if (note != 0) return note;
  return a.nom.toLowerCase().compareTo(b.nom.toLowerCase());
}
