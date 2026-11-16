import 'package:flutter/foundation.dart';

import '../donnees/modeles.dart';

/// Une ligne du panier : un plat et sa quantité.
class LignePanier {
  const LignePanier(this.plat, this.quantite);
  final Plat plat;
  final int quantite;
  double get total => plat.prix * quantite;
}

enum ResultatAjout {
  ajoute,

  /// Le panier contient déjà des plats d'un autre restaurant : rien n'est ajouté.
  autreRestaurant,

  /// Plat indisponible, restaurant fermé ou quantité maximale atteinte : rien n'est ajouté.
  refuse,
}

/// Panier du client (US18), partagé par toute l'appli : il est conservé
/// quand on quitte un écran (et pendant la connexion d'un visiteur).
/// Il ne contient que les plats d'un seul restaurant.
class Panier extends ChangeNotifier {
  /// Quantité maximale d'un même plat (la fonction serveur applique la même limite).
  static const quantiteMax = 20;

  RestaurantCatalogue? _restaurant;
  final _lignes = <LignePanier>[];

  /// Adresse et remarque saisies au moment de commander : gardées si le client
  /// quitte le panier (pour se connecter, par exemple).
  String adresse = '';
  String remarque = '';

  RestaurantCatalogue? get restaurant => _restaurant;
  List<LignePanier> get lignes => List.unmodifiable(_lignes);
  bool get estVide => _lignes.isEmpty;
  int get nbArticles => _lignes.fold(0, (n, l) => n + l.quantite);

  /// Somme des plats (avant les frais de livraison). Le total définitif est calculé par le serveur.
  double get sousTotal => _lignes.fold(0.0, (s, l) => s + l.total);

  int quantiteDe(String platId) =>
      _lignes.firstWhere((l) => l.plat.id == platId, orElse: () => const LignePanier(_aucun, 0)).quantite;

  /// Ajoute un exemplaire de [plat] du restaurant [r].
  ResultatAjout ajouter(RestaurantCatalogue r, Plat plat) {
    if (!plat.disponible || !r.ouvert) return ResultatAjout.refuse;
    if (_restaurant != null && _restaurant!.id != r.id && _lignes.isNotEmpty) return ResultatAjout.autreRestaurant;
    final i = _lignes.indexWhere((l) => l.plat.id == plat.id);
    if (i >= 0 && _lignes[i].quantite >= quantiteMax) return ResultatAjout.refuse;
    _restaurant = r;
    if (i >= 0) {
      _lignes[i] = LignePanier(plat, _lignes[i].quantite + 1);
    } else {
      _lignes.add(LignePanier(plat, 1));
    }
    notifyListeners();
    return ResultatAjout.ajoute;
  }

  /// Vide le panier (plats d'un autre restaurant), puis ajoute [plat].
  ResultatAjout remplacerPar(RestaurantCatalogue r, Plat plat) {
    _lignes.clear();
    _restaurant = null;
    return ajouter(r, plat);
  }

  /// Retire un exemplaire ; la ligne disparaît à zéro.
  void retirer(String platId) {
    final i = _lignes.indexWhere((l) => l.plat.id == platId);
    if (i < 0) return;
    if (_lignes[i].quantite <= 1) {
      _lignes.removeAt(i);
    } else {
      _lignes[i] = LignePanier(_lignes[i].plat, _lignes[i].quantite - 1);
    }
    if (_lignes.isEmpty) _restaurant = null;
    notifyListeners();
  }

  /// Supprime la ligne entière.
  void supprimer(String platId) {
    _lignes.removeWhere((l) => l.plat.id == platId);
    if (_lignes.isEmpty) _restaurant = null;
    notifyListeners();
  }

  void vider() {
    _lignes.clear();
    _restaurant = null;
    notifyListeners();
  }
}

const _aucun = Plat(id: '', categorieId: '', nom: '', prix: 0);

/// « 1 article », « 3 articles ».
String libelleArticles(int n) => n <= 1 ? '$n article' : '$n articles';
