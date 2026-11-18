import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_livreur/auth/erreurs.dart';
import 'package:mida_livreur/auth/service_auth.dart';
import 'package:mida_livreur/dependances.dart';
import 'package:mida_livreur/donnees/modeles.dart';
import 'package:mida_livreur/donnees/service_livreur.dart';
import 'package:mida_livreur/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Faux service de compte : enregistre les appels.
class FauxServiceAuth implements ServiceAuth {
  FauxServiceAuth({this.connecte = false, this.erreur});
  bool connecte;
  Object? erreur;
  final appels = <String>[];

  @override
  Session? get session => connecte ? sessionTest : null;
  @override
  Stream<AuthState> get changements => const Stream.empty();

  @override
  Future<void> inscrire({
    required String nom,
    required String email,
    required String telephone,
    required String motDePasse,
  }) async {
    appels.add('inscrire:$nom:$email:$telephone');
    if (erreur != null) throw erreur!;
    connecte = true;
  }

  @override
  Future<void> connecter({required String email, required String motDePasse}) async {
    appels.add('connecter:$email');
    if (erreur != null) throw erreur!;
    connecte = true;
  }

  @override
  Future<void> deconnecter() async {
    appels.add('deconnecter');
    connecte = false;
  }
}

final sessionTest = Session(
  accessToken: 'jeton',
  tokenType: 'bearer',
  user: User(id: 'l1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-11-18T00:00:00Z'),
);

/// Faux service de données : compte, courses en mémoire, appels enregistrés.
class FauxServiceLivreur implements ServiceLivreur {
  FauxServiceLivreur({EtatLivreur? etat, List<Course>? proposees}) : etat = etat ?? livreurActif {
    for (final c in proposees ?? [courseCarte, courseEspeces]) {
      courses[c.id] = c;
    }
  }

  EtatLivreur etat;
  final courses = <String, Course>{};
  final appels = <String>[];

  /// Levée (une fois) par la prochaine action si elle est fournie.
  Object? erreur;

  Future<void> _action(String appel) async {
    appels.add(appel);
    final e = erreur;
    if (e != null) {
      erreur = null;
      throw e;
    }
  }

  @override
  Future<EtatLivreur> monEtat() async => etat;

  Map<TypeDocument, DocumentChoisi>? candidature;

  @override
  Future<void> envoyerCandidature({
    required TypeVehicule vehicule,
    String? immatriculation,
    required Map<TypeDocument, DocumentChoisi> documents,
  }) async {
    await _action('candidature:${vehicule.code}:$immatriculation:${documents.keys.map((d) => d.code).join(',')}');
    candidature = documents;
    etat = EtatLivreur(
      nom: etat.nom,
      etatCompte: etat.etatCompte,
      typeVehicule: vehicule,
      immatriculation: immatriculation,
      documents: {...etat.documents, for (final d in documents.keys) d.code: 'en_attente'},
    );
  }

  @override
  Future<void> definirDisponible(bool disponible) async {
    await _action('disponible:$disponible');
    etat = EtatLivreur(nom: etat.nom, etatCompte: etat.etatCompte, disponible: disponible);
  }

  @override
  Future<List<Course>> coursesProposees() async =>
      [for (final c in courses.values) if (c.etat == EtatCourse.proposee) c];

  @override
  Future<Course?> courseEnCours() async {
    for (final c in courses.values) {
      if (c.etat == EtatCourse.acceptee || c.etat == EtatCourse.recuperee) return c;
    }
    return null;
  }

  @override
  Future<Course> course(String id) async => courses[id]!;

  @override
  Future<void> accepterCourse(String id) async {
    await _action('accepter:$id');
    courses[id] = copie(courses[id]!, etat: EtatCourse.acceptee);
  }

  @override
  Future<void> recupererCourse(String id) async {
    await _action('recuperer:$id');
    courses[id] = copie(courses[id]!, etat: EtatCourse.recuperee, etatCommande: 'en_livraison');
  }

  @override
  Future<void> livrerCourse(String id) async {
    await _action('livrer:$id');
    courses[id] = copie(courses[id]!, etat: EtatCourse.livree, etatCommande: 'livree');
  }

  final _abonnes = <void Function()>[];
  int get nbAbonnes => _abonnes.length;

  @override
  void Function() surChangements(void Function() rappel) {
    _abonnes.add(rappel);
    return () => _abonnes.remove(rappel);
  }

  /// Simule un changement venu de la base (temps réel).
  void simulerChangement(Course c) {
    courses[c.id] = c;
    for (final r in [..._abonnes]) {
      r();
    }
  }
}

const livreurActif = EtatLivreur(nom: 'Sami Ben Salah', etatCompte: 'actif', disponible: true,
    typeVehicule: TypeVehicule.moto, immatriculation: '245 TU 1830', documents: {'cin': 'valide', 'permis': 'valide', 'carte_grise': 'valide'});

const courseCarte = Course(
  id: 'l1',
  etat: EtatCourse.proposee,
  gain: 2,
  numero: 1044,
  etatCommande: 'en_preparation',
  restaurantNom: 'Dar Zitouna',
  restaurantAdresse: '34, avenue Habib Bourguiba, La Marsa',
  adresseClient: '4, rue des Orangers, Ariana',
  total: 50.5,
  paiementMode: 'carte',
  paiementEtat: 'paye',
  articles: [ArticleCourse(nom: 'Tajine de poulet aux olives', quantite: 3)],
);

const courseEspeces = Course(
  id: 'l2',
  etat: EtatCourse.proposee,
  gain: 2,
  numero: 1045,
  etatCommande: 'prete',
  restaurantNom: 'El Kanoun',
  restaurantAdresse: 'Rue de la Plage, Gammarth',
  adresseClient: '27, avenue de Paris, Tunis',
  clientNom: 'Youssef Trabelsi',
  clientTelephone: '+216 98 120 334',
  total: 25.5,
  paiementMode: 'especes',
  paiementEtat: 'en_attente',
  remarque: 'Sonner deux fois',
  articles: [
    ArticleCourse(nom: 'Couscous à l’agneau', quantite: 1),
    ArticleCourse(nom: 'Thé à la menthe', quantite: 2),
  ],
);

Course copie(Course c, {EtatCourse? etat, String? etatCommande}) => Course(
      id: c.id,
      etat: etat ?? c.etat,
      gain: c.gain,
      numero: c.numero,
      etatCommande: etatCommande ?? c.etatCommande,
      restaurantNom: c.restaurantNom,
      restaurantAdresse: c.restaurantAdresse,
      restaurantTelephone: c.restaurantTelephone,
      adresseClient: c.adresseClient,
      clientNom: c.clientNom,
      clientTelephone: c.clientTelephone,
      total: c.total,
      paiementMode: c.paiementMode,
      paiementEtat: c.paiementEtat,
      remarque: c.remarque,
      articles: c.articles,
    );

/// Photo factice choisie dans la galerie.
DocumentChoisi photo(String nom) => DocumentChoisi(nom: nom, octets: Uint8List(880 * 1024));

/// Ouvre [page] sur un écran de téléphone (360 × 800) avec les faux services.
Future<void> ouvrirPage(
  WidgetTester tester,
  Widget page, {
  FauxServiceAuth? auth,
  FauxServiceLivreur? livreur,
  ChoisirDocument? choisirDocument,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(Dependances(
    auth: auth ?? FauxServiceAuth(connecte: true),
    livreur: livreur ?? FauxServiceLivreur(),
    choisirDocument: choisirDocument ?? () async => null,
    child: MaterialApp(theme: construireTheme(policesGoogle: false), home: page),
  ));
  await tester.pumpAndSettle();
}

Future<void> defilerJusqua(WidgetTester tester, Finder cible) async {
  await tester.scrollUntilVisible(cible, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
}

/// Rend [cible] entièrement visible, puis la touche.
Future<void> appuyer(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

const refusServeur = ErreurMida('Cette course a déjà été acceptée par un autre livreur');
