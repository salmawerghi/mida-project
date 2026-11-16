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
