import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/auth/service_auth.dart';
import 'package:mida_client/pages/connexion_page.dart';
import 'package:mida_client/pages/inscription_page.dart';
import 'package:mida_client/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Faux service : enregistre les appels et renvoie le résultat prévu.
class FauxServiceAuth implements ServiceAuth {
  FauxServiceAuth({this.resultat = ResultatInscription.confirmationEmail, this.erreur});
  final ResultatInscription resultat;
  final Object? erreur;
  final appels = <Map<String, String>>[];

  @override
  Session? get session => null;
  @override
  Stream<AuthState> get changements => const Stream.empty();
  @override
  String get nomAffiche => '';

  @override
  Future<ResultatInscription> inscrire({
    required String nom,
    required String email,
    required String telephone,
    required String motDePasse,
  }) async {
    appels.add({'nom': nom, 'email': email, 'telephone': telephone, 'motDePasse': motDePasse});
    if (erreur != null) throw erreur!;
    return resultat;
  }

  @override
  Future<void> connecter({required String email, required String motDePasse}) async {}
  @override
  Future<void> deconnecter() async {}
}

Future<void> ouvrir(WidgetTester tester, FauxServiceAuth auth) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3; // écran de 360 × 800
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: construireTheme(policesGoogle: false),
    home: InscriptionPage(auth: auth),
  ));
}

Future<void> remplir(WidgetTester tester) async {
  final champs = find.byType(TextFormField);
  await tester.enterText(champs.at(0), 'Salma Ouerghi');
  await tester.enterText(champs.at(1), ' salma@mida.test ');
  await tester.enterText(champs.at(2), '22 145 870');
  await tester.enterText(champs.at(3), 'Mida2026!');
  await tester.pump();
}

Future<void> cocherConditions(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byType(Checkbox), 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
}

Future<void> valider(WidgetTester tester) async {
  // La ListView ne construit le bas du formulaire qu'en défilant.
  final bouton = find.text('Créer mon compte');
  await tester.scrollUntilVisible(bouton, 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(bouton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('formulaire vide : messages sous les champs, aucun appel', (tester) async {
    final auth = FauxServiceAuth();
    await ouvrir(tester, auth);
    await valider(tester);

    expect(find.text('Indiquez votre nom et prénom.'), findsOneWidget);
    expect(find.text('Indiquez votre adresse e-mail.'), findsOneWidget);
    expect(find.text('Indiquez votre numéro de téléphone.'), findsOneWidget);
    expect(find.text('Choisissez un mot de passe.'), findsOneWidget);
    expect(find.text('Acceptez les conditions pour créer votre compte.'), findsOneWidget);
    expect(auth.appels, isEmpty);
  });

  testWidgets('conditions non acceptées : pas d\'inscription', (tester) async {
    final auth = FauxServiceAuth();
    await ouvrir(tester, auth);
    await remplir(tester);
    await valider(tester);

    expect(find.text('Acceptez les conditions pour créer votre compte.'), findsOneWidget);
    expect(auth.appels, isEmpty);
  });

  testWidgets('la jauge suit la solidité du mot de passe', (tester) async {
    await ouvrir(tester, FauxServiceAuth());
    await tester.enterText(find.byType(TextFormField).at(3), 'abcdefgh');
    await tester.pump();
    expect(find.textContaining('Mot de passe faible'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(3), 'Mida2026!');
    await tester.pump();
    expect(find.text('Mot de passe très solide'), findsOneWidget);
  });

  testWidgets('formulaire valide : inscription puis écran de connexion avec le message de confirmation',
      (tester) async {
    final auth = FauxServiceAuth(resultat: ResultatInscription.confirmationEmail);
    await ouvrir(tester, auth);
    await remplir(tester);
    await cocherConditions(tester);
    await valider(tester);

    expect(auth.appels, hasLength(1));
    expect(auth.appels.single['telephone'], '+216 22 145 870');
    expect(auth.appels.single['motDePasse'], 'Mida2026!');
    expect(find.byType(ConnexionPage), findsOneWidget);
    expect(find.textContaining('lien de confirmation à salma@mida.test'), findsOneWidget);
  });

  testWidgets('adresse déjà utilisée : message clair, on reste sur l\'écran', (tester) async {
    final auth = FauxServiceAuth(erreur: const AuthApiException('User already registered', code: 'user_already_exists'));
    await ouvrir(tester, auth);
    await remplir(tester);
    await cocherConditions(tester);
    await valider(tester);

    expect(find.text('Un compte existe déjà avec cette adresse e-mail. Connectez-vous.'), findsOneWidget);
    expect(find.byType(InscriptionPage), findsOneWidget);
  });
}
