import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/donnees/service_mida.dart';
import 'package:mida_client/panier/panier.dart';

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

  @override
  Future<double> fraisLivraison() async => 2.5;

  /// Commandes passées (US19) : restaurant, lignes, adresse, remarque.
  final commandes = <Map<String, Object?>>[];

  /// Levée par `passerCommande` (refus du serveur).
  Object? erreurCommande;

  @override
  Future<CommandePassee> passerCommande({
    required String restaurantId,
    required List<LignePanier> lignes,
    required String adresse,
    String? remarque,
  }) async {
    if (erreurCommande != null) throw erreurCommande!;
    commandes.add({
      'restaurant': restaurantId,
      'lignes': [for (final l in lignes) '${l.quantite} × ${l.plat.nom}'],
      'adresse': adresse,
      'remarque': remarque,
    });
    final sousTotal = lignes.fold(0.0, (s, l) => s + l.total);
    return CommandePassee(
      id: 'cmd${commandes.length}',
      numero: 1046 + commandes.length,
      sousTotal: sousTotal,
      fraisLivraison: 2.5,
      total: sousTotal + 2.5,
    );
  }

  /// Commandes du client (suivi, US20), par identifiant.
  final suivies = <String, CommandeClient>{};
  final _abonnes = <String, List<void Function()>>{};
  int get nbAbonnes => _abonnes.values.fold(0, (n, l) => n + l.length);

  @override
  Future<CommandeClient> commande(String id) => _repondre(suivies[id]!);

  @override
  Future<List<CommandeClient>> commandesEnCours() async =>
      [for (final c in suivies.values) if (c.etat.enCours) c];

  @override
  Future<List<CommandeClient>> mesCommandes() =>
      _repondre([...suivies.values]..sort((a, b) => b.creeeLe.compareTo(a.creeeLe)));

  @override
  void Function() surCommande(String id, void Function() rappel) {
    _abonnes.putIfAbsent(id, () => []).add(rappel);
    return () => _abonnes[id]?.remove(rappel);
  }

  /// Levée par `annulerCommande` (refus du serveur : déjà acceptée…).
  Object? erreurAnnulation;
  final annulations = <String>[];

  @override
  Future<void> annulerCommande(String id) async {
    annulations.add(id);
    if (erreurAnnulation != null) throw erreurAnnulation!;
    simulerChangement(avecEtat(suivies[id]!, EtatCommande.annulee, annuleeLe: DateTime(2026, 11, 16, 19, 3)));
  }

  /// Avis envoyés (US38) ; `erreurAvis` est levée à la place si elle est fournie.
  final avis = <Map<String, Object?>>[];
  Object? erreurAvis;

  @override
  Future<void> noterCommande(
    String id, {
    required int noteRestaurant,
    String? commentaireRestaurant,
    int? noteLivreur,
    String? commentaireLivreur,
  }) async {
    if (erreurAvis != null) throw erreurAvis!;
    avis.add({
      'commande': id,
      'restaurant': noteRestaurant,
      'commentaireRestaurant': commentaireRestaurant,
      'livreur': noteLivreur,
      'commentaireLivreur': commentaireLivreur,
    });
    final c = suivies[id]!;
    suivies[id] = avecEtat(c, c.etat,
        accepteeLe: c.accepteeLe,
        preteLe: c.preteLe,
        livreeLe: c.livreeLe,
        paiementMode: c.paiementMode,
        paiementEtat: c.paiementEtat,
        livreurNom: c.livreurNom,
        noteRestaurant: noteRestaurant,
        noteLivreur: noteLivreur);
  }

  /// Adresses du client (US47).
  List<AdresseClient> adresses = [];
  int _numeroAdresse = 0;

  @override
  Future<List<AdresseClient>> mesAdresses() async => trierAdresses(adresses);

  @override
  Future<void> ajouterAdresse({
    required String libelle,
    required String rue,
    required String ville,
    String? complement,
    bool parDefaut = false,
  }) async {
    if (parDefaut) adresses = [for (final a in adresses) _copieAdresse(a, false)];
    adresses = [
      ...adresses,
      AdresseClient(
        id: 'nouvelle${++_numeroAdresse}',
        libelle: libelle,
        rue: rue,
        ville: ville,
        complement: complement,
        parDefaut: parDefaut,
      ),
    ];
  }

  @override
  Future<void> supprimerAdresse(String id) async => adresses = [for (final a in adresses) if (a.id != id) a];

  @override
  Future<void> definirAdresseParDefaut(String id) async =>
      adresses = [for (final a in adresses) _copieAdresse(a, a.id == id)];

  AdresseClient _copieAdresse(AdresseClient a, bool parDefaut) => AdresseClient(
      id: a.id, libelle: a.libelle, rue: a.rue, ville: a.ville, complement: a.complement, parDefaut: parDefaut);

  /// Problèmes signalés (US49) ; `erreurReclamation` est levée à la place si elle est fournie.
  final reclamations = <Map<String, Object?>>[];
  Object? erreurReclamation;

  @override
  Future<void> signalerProbleme(String commandeId, {required String motif, String? description}) async {
    if (erreurReclamation != null) throw erreurReclamation!;
    reclamations.add({'commande': commandeId, 'motif': motif, 'description': description});
    final c = suivies[commandeId]!;
    suivies[commandeId] = avecEtat(c, c.etat,
        accepteeLe: c.accepteeLe,
        preteLe: c.preteLe,
        livreeLe: c.livreeLe,
        livreurNom: c.livreurNom,
        noteRestaurant: c.noteRestaurant,
        noteLivreur: c.noteLivreur,
        reclamation: ReclamationClient(motif: motif, etat: 'ouverte', creeeLe: DateTime(2026, 11, 19, 21)));
  }

  /// Simule un changement fait par le restaurant (événement temps réel).
  void simulerChangement(CommandeClient c) {
    suivies[c.id] = c;
    for (final rappel in [...?_abonnes[c.id]]) {
      rappel();
    }
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

/// Commande n° 1047 de test, en attente chez Dar Zitouna.
final commandeTest = CommandeClient(
  id: 'cmd1',
  numero: 1047,
  etat: EtatCommande.enAttente,
  restaurantNom: 'Dar Zitouna',
  adresse: '12, rue du Jasmin, La Marsa',
  sousTotal: 23,
  fraisLivraison: 2.5,
  total: 25.5,
  remarque: 'Sonner deux fois',
  creeeLe: DateTime(2026, 11, 16, 19, 0),
  lignes: const [
    LigneCommande(nomPlat: 'Couscous à l’agneau', quantite: 1, prixUnitaire: 18),
    LigneCommande(nomPlat: 'Thé à la menthe', quantite: 2, prixUnitaire: 2.5),
  ],
);

/// Copie de [c] avec un autre état et d'autres dates (changements faits par le restaurant).
CommandeClient avecEtat(
  CommandeClient c,
  EtatCommande etat, {
  DateTime? accepteeLe,
  DateTime? preteLe,
  DateTime? annuleeLe,
  String? motifRefus,
  String paiementMode = 'especes',
  String paiementEtat = 'en_attente',
  DateTime? livreeLe,
  String? livreurNom,
  int? noteRestaurant,
  int? noteLivreur,
  ReclamationClient? reclamation,
}) =>
    CommandeClient(
      id: c.id,
      numero: c.numero,
      etat: etat,
      restaurantNom: c.restaurantNom,
      adresse: c.adresse,
      sousTotal: c.sousTotal,
      fraisLivraison: c.fraisLivraison,
      total: c.total,
      remarque: c.remarque,
      motifRefus: motifRefus,
      creeeLe: c.creeeLe,
      accepteeLe: accepteeLe,
      preteLe: preteLe,
      annuleeLe: annuleeLe,
      lignes: c.lignes,
      paiementMode: paiementMode,
      paiementEtat: paiementEtat,
      livreeLe: livreeLe,
      livreurNom: livreurNom,
      noteRestaurant: noteRestaurant,
      noteLivreur: noteLivreur,
      reclamation: reclamation,
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
