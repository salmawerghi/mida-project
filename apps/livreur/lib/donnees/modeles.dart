/// Données affichées par l'appli livreur (candidature, courses).
library;

import 'dart:typed_data';

import 'format.dart';

/// Type de véhicule (type `type_vehicule` de la base).
enum TypeVehicule {
  moto('moto', 'Scooter / moto'),
  velo('velo', 'Vélo'),
  voiture('voiture', 'Voiture');

  const TypeVehicule(this.code, this.libelle);
  final String code;
  final String libelle;

  static TypeVehicule? depuis(String? code) => code == null ? null : values.firstWhere((v) => v.code == code);

  /// Un vélo n'a ni immatriculation, ni permis, ni carte grise.
  bool get motorise => this != velo;
}

/// Pièces justificatives (colonne `type` de `documents_livreur`).
enum TypeDocument {
  cin('cin', 'Carte d\'identité nationale'),
  permis('permis', 'Permis de conduire'),
  carteGrise('carte_grise', 'Carte grise du véhicule');

  const TypeDocument(this.code, this.libelle);
  final String code;
  final String libelle;
}

/// Documents demandés pour un véhicule : la carte d'identité toujours,
/// le permis et la carte grise pour un véhicule motorisé.
List<TypeDocument> documentsRequis(TypeVehicule? vehicule) => [
      TypeDocument.cin,
      if (vehicule?.motorise ?? true) ...[TypeDocument.permis, TypeDocument.carteGrise],
    ];

/// Photo d'un document choisie sur le téléphone.
class DocumentChoisi {
  const DocumentChoisi({required this.nom, required this.octets});
  final String nom;
  final Uint8List octets;

  /// « jpg », « png » ou « webp » (formats acceptés par le stockage).
  String get extension {
    final e = nom.split('.').last.toLowerCase();
    return switch (e) { 'png' => 'png', 'webp' => 'webp', _ => 'jpg' };
  }

  String get typeMime => switch (extension) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };

  /// « 860 Ko », « 1,2 Mo ».
  String get taille {
    final ko = octets.length / 1024;
    return ko < 1024 ? '${ko.round()} Ko' : '${(ko / 1024).toStringAsFixed(1).replaceAll('.', ',')} Mo';
  }
}

/// Compte du livreur connecté : état de validation, disponibilité, véhicule, documents.
class EtatLivreur {
  const EtatLivreur({
    required this.nom,
    required this.etatCompte,
    this.disponible = false,
    this.typeVehicule,
    this.immatriculation,
    this.documents = const {},
  });

  final String nom;

  /// « en_attente », « actif », « rejete » ou « bloque ».
  final String etatCompte;
  final bool disponible;
  final TypeVehicule? typeVehicule;
  final String? immatriculation;

  /// Documents déposés : code du type → état (« en_attente », « valide », « refuse »).
  final Map<String, String> documents;

  bool get actif => etatCompte == 'actif';

  /// Véhicule renseigné et tous les documents demandés déposés.
  bool get candidatureComplete =>
      typeVehicule != null && documentsRequis(typeVehicule).every((d) => documents.containsKey(d.code));

  /// « Sami » pour « Sami Ben Salah ».
  String get prenom => nom.trim().split(RegExp(r'\s+')).first;
}

/// États d'une course (type `etat_livraison`).
enum EtatCourse {
  proposee('proposee'),
  acceptee('acceptee'),
  recuperee('recuperee'),
  livree('livree'),
  annulee('annulee');

  const EtatCourse(this.code);
  final String code;
  static EtatCourse depuis(String code) => values.firstWhere((e) => e.code == code);
}

class ArticleCourse {
  const ArticleCourse({required this.nom, required this.quantite});
  final String nom;
  final int quantite;
}

/// Une course : la livraison d'une commande, du restaurant au client.
class Course {
  const Course({
    required this.id,
    required this.etat,
    required this.gain,
    required this.numero,
    required this.etatCommande,
    required this.restaurantNom,
    required this.restaurantAdresse,
    this.restaurantTelephone,
    required this.adresseClient,
    this.clientNom,
    this.clientTelephone,
    required this.total,
    required this.paiementMode,
    required this.paiementEtat,
    this.remarque,
    this.articles = const [],
    this.livreeLe,
  });

  /// Identifiant de la livraison.
  final String id;
  final EtatCourse etat;
  final double gain;
  final int numero;

  /// État de la commande (« en_preparation », « prete »…).
  final String etatCommande;
  final String restaurantNom;
  final String restaurantAdresse;
  final String? restaurantTelephone;
  final String adresseClient;

  /// Connus une fois la course acceptée (règle d'accès des profils).
  final String? clientNom;
  final String? clientTelephone;
  final double total;
  final String paiementMode;
  final String paiementEtat;
  final String? remarque;
  final List<ArticleCourse> articles;
  final DateTime? livreeLe;

  int get nbArticles => articles.fold(0, (n, a) => n + a.quantite);

  /// Le client paie en espèces à la remise (US29).
  bool get aEncaisser => paiementMode == 'especes' && paiementEtat != 'paye';

  /// « Payée en ligne » ou « À encaisser · 27,500 DT ».
  String get mentionPaiement => aEncaisser ? 'À encaisser · ${formaterPrix(total)}' : 'Payée en ligne';

  bool get commandePrete => etatCommande == 'prete';

  /// Colonnes lues : la livraison, sa commande, le restaurant, les plats, le paiement et le client.
  static const colonnes = 'id, etat, gain_livreur, livree_le, '
      'commandes(numero, etat, adresse_livraison, total, remarque, '
      'restaurants(nom, adresse, ville, telephone), lignes_commande(nom_plat, quantite), '
      'paiements(mode, etat), profiles(nom, telephone))';

  factory Course.depuis(Map<String, dynamic> l) {
    Object? premier(Object? v) => v is List ? (v.isEmpty ? null : v.first) : v;
    final c = premier(l['commandes']) as Map? ?? const {};
    final r = premier(c['restaurants']) as Map? ?? const {};
    final p = premier(c['paiements']) as Map?;
    final client = premier(c['profiles']) as Map?;
    final ville = r['ville'] as String?;
    return Course(
      id: l['id'] as String,
      etat: EtatCourse.depuis(l['etat'] as String),
      gain: lireNombre(l['gain_livreur'] ?? 0),
      numero: (c['numero'] as num?)?.toInt() ?? 0,
      etatCommande: c['etat'] as String? ?? '',
      restaurantNom: r['nom'] as String? ?? 'Restaurant',
      restaurantAdresse: [r['adresse'], if (ville != null && ville.isNotEmpty) ville].whereType<String>().join(', '),
      restaurantTelephone: r['telephone'] as String?,
      adresseClient: c['adresse_livraison'] as String? ?? '',
      clientNom: client?['nom'] as String?,
      clientTelephone: client?['telephone'] as String?,
      total: lireNombre(c['total'] ?? 0),
      paiementMode: p?['mode'] as String? ?? 'especes',
      paiementEtat: p?['etat'] as String? ?? 'en_attente',
      remarque: c['remarque'] as String?,
      articles: [
        for (final a in (c['lignes_commande'] as List? ?? const []))
          ArticleCourse(nom: a['nom_plat'] as String, quantite: (a['quantite'] as num).toInt()),
      ],
      livreeLe: l['livree_le'] == null ? null : DateTime.parse(l['livree_le'] as String),
    );
  }
}
