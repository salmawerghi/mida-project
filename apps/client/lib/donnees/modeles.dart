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

/// Commande enregistrée par le serveur (US19) : montants calculés par la base.
class CommandePassee {
  const CommandePassee({
    required this.id,
    required this.numero,
    required this.sousTotal,
    required this.fraisLivraison,
    required this.total,
  });
  final String id;
  final int numero;
  final double sousTotal;
  final double fraisLivraison;
  final double total;

  factory CommandePassee.depuis(Map<String, dynamic> r) => CommandePassee(
        id: r['id'] as String,
        numero: (r['numero'] as num).toInt(),
        sousTotal: lireNombre(r['sous_total']),
        fraisLivraison: lireNombre(r['frais_livraison']),
        total: lireNombre(r['total']),
      );
}

/// États d'une commande (type `etat_commande` de la base).
enum EtatCommande {
  enAttente('en_attente', 'En attente du restaurant'),
  acceptee('acceptee', 'Acceptée par le restaurant'),
  enPreparation('en_preparation', 'En préparation'),
  prete('prete', 'Prête'),
  enLivraison('en_livraison', 'En cours de livraison'),
  livree('livree', 'Livrée'),
  refusee('refusee', 'Commande refusée'),
  annulee('annulee', 'Commande annulée');

  const EtatCommande(this.code, this.titre);
  final String code;
  final String titre;

  static EtatCommande depuis(String code) => values.firstWhere((e) => e.code == code);

  /// Commande encore en cours (ni livrée, ni refusée, ni annulée).
  bool get enCours => !{livree, refusee, annulee}.contains(this);
}

class LigneCommande {
  const LigneCommande({required this.nomPlat, required this.quantite, required this.prixUnitaire});
  final String nomPlat;
  final int quantite;
  final double prixUnitaire;
}

/// Commande vue par le client (suivi, US20).
class CommandeClient {
  const CommandeClient({
    required this.id,
    required this.numero,
    required this.etat,
    required this.restaurantNom,
    required this.adresse,
    required this.sousTotal,
    required this.fraisLivraison,
    required this.total,
    this.remarque,
    this.motifRefus,
    required this.creeeLe,
    this.accepteeLe,
    this.preteLe,
    this.livreeLe,
    this.annuleeLe,
    this.lignes = const [],
    this.paiementMode = 'especes',
    this.paiementEtat = 'en_attente',
  });

  final String id;
  final int numero;
  final EtatCommande etat;
  final String restaurantNom;
  final String adresse;
  final double sousTotal;
  final double fraisLivraison;
  final double total;
  final String? remarque;
  final String? motifRefus;
  final DateTime creeeLe;
  final DateTime? accepteeLe;
  final DateTime? preteLe;
  final DateTime? livreeLe;
  final DateTime? annuleeLe;
  final List<LigneCommande> lignes;
  final String paiementMode;
  final String paiementEtat;

  bool get rembourse => paiementMode == 'carte' && paiementEtat == 'rembourse';

  /// Nombre de plats commandés (quantités additionnées) : « 3 articles ».
  int get nbArticles => lignes.fold(0, (n, l) => n + l.quantite);

  /// Colonnes lues par l'appli (avec le nom du restaurant, les lignes et le paiement).
  static const colonnes = 'id, numero, etat, adresse_livraison, sous_total, frais_livraison, total, remarque, '
      'motif_refus, created_at, acceptee_le, prete_le, livree_le, annulee_le, '
      'restaurants(nom), lignes_commande(nom_plat, quantite, prix_unitaire), paiements(mode, etat)';

  factory CommandeClient.depuis(Map<String, dynamic> l) {
    DateTime? date(Object? v) => v == null ? null : DateTime.parse(v as String);
    Object? premier(Object? v) => v is List ? (v.isEmpty ? null : v.first) : v;
    final restaurant = premier(l['restaurants']) as Map?;
    final paiement = premier(l['paiements']) as Map?;
    return CommandeClient(
      id: l['id'] as String,
      numero: (l['numero'] as num).toInt(),
      etat: EtatCommande.depuis(l['etat'] as String),
      restaurantNom: restaurant?['nom'] as String? ?? 'Restaurant',
      adresse: l['adresse_livraison'] as String? ?? '',
      sousTotal: lireNombre(l['sous_total']),
      fraisLivraison: lireNombre(l['frais_livraison']),
      total: lireNombre(l['total']),
      remarque: l['remarque'] as String?,
      motifRefus: l['motif_refus'] as String?,
      creeeLe: date(l['created_at'])!,
      accepteeLe: date(l['acceptee_le']),
      preteLe: date(l['prete_le']),
      livreeLe: date(l['livree_le']),
      annuleeLe: date(l['annulee_le']),
      lignes: [
        for (final x in (l['lignes_commande'] as List? ?? const []))
          LigneCommande(
            nomPlat: x['nom_plat'] as String,
            quantite: (x['quantite'] as num).toInt(),
            prixUnitaire: lireNombre(x['prix_unitaire']),
          ),
      ],
      paiementMode: paiement?['mode'] as String? ?? 'especes',
      paiementEtat: paiement?['etat'] as String? ?? 'en_attente',
    );
  }
}

/// Une étape du suivi : son libellé, son heure (si connue), franchie ou non.
typedef EtapeSuivi = ({String libelle, DateTime? heure, bool franchie, bool actuelle});

/// Étapes affichées pour une commande en cours ou livrée (maquette « Client · Suivi »).
List<EtapeSuivi> etapesSuivi(CommandeClient c) {
  const ordre = [
    EtatCommande.enAttente,
    EtatCommande.acceptee,
    EtatCommande.enPreparation,
    EtatCommande.prete,
    EtatCommande.enLivraison,
    EtatCommande.livree,
  ];
  final rang = ordre.indexOf(c.etat);
  final heures = <EtatCommande, DateTime?>{
    EtatCommande.enAttente: c.creeeLe,
    EtatCommande.acceptee: c.accepteeLe,
    EtatCommande.prete: c.preteLe,
    EtatCommande.livree: c.livreeLe,
  };
  return [
    for (final (i, e) in ordre.indexed)
      (
        libelle: e == EtatCommande.enAttente ? 'Commande envoyée' : e.titre,
        heure: i <= rang ? heures[e] : null,
        franchie: i <= rang,
        actuelle: i == rang,
      ),
  ];
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
