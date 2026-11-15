import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/auth/erreurs.dart';
import 'package:mida_client/pages/connexion_page.dart';
import 'package:mida_client/pages/mot_de_passe_oublie_page.dart';
import 'package:mida_client/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'faux_service_auth.dart';

/// Ouvre la page de connexion (écran racine), puis « Mot de passe oublié ? ».
Future<void> ouvrir(WidgetTester tester, FauxServiceAuth auth, {String email = ''}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3; // écran de 360 × 800
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: construireTheme(policesGoogle: false),
    home: ConnexionPage(auth: auth, emailInitial: email, motDePasseOublie: true),
  ));
  final lien = find.text('Mot de passe oublié ?');
  await tester.scrollUntilVisible(lien, 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(lien);
  await tester.pumpAndSettle();
  expect(find.byType(MotDePasseOubliePage), findsOneWidget);
}

Future<void> appuyer(WidgetTester tester, String libelle) async {
  // La ListView ne construit le bas du formulaire qu'en défilant.
  final bouton = find.text(libelle);
  // (Les champs de texte contiennent eux aussi un Scrollable : on vise celui de la page.)
  final page = find.descendant(of: find.byType(MotDePasseOubliePage), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(bouton, 200, scrollable: page);
  await tester.tap(bouton);
  await tester.pumpAndSettle();
}

Future<void> remplirEtape2(WidgetTester tester, {String code = '123456', String mdp = 'Nouveau2026!', String? confirmation}) async {
  await saisir(tester, 0, code);
  await saisir(tester, 1, mdp);
  await saisir(tester, 2, confirmation ?? mdp);
}

/// Un champ hors de l'écran ne reçoit pas le focus : on le fait d'abord défiler.
Future<void> saisir(WidgetTester tester, int index, String texte) async {
  final champ = find.byType(TextFormField).at(index);
  await tester.ensureVisible(champ);
  await tester.pumpAndSettle();
  await tester.enterText(champ, texte);
  await tester.pump();
}

void main() {
  testWidgets("lien masqué par défaut (tant que l'envoi du code n'est pas réglé sur Supabase)", (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: construireTheme(policesGoogle: false),
      home: ConnexionPage(auth: FauxServiceAuth()),
    ));
    expect(find.text('Mot de passe oublié ?'), findsNothing);
  });

  testWidgets('l\'e-mail saisi à la connexion est repris', (tester) async {
    await ouvrir(tester, FauxServiceAuth(), email: 'salma@mida.test');
    expect(find.widgetWithText(TextFormField, 'salma@mida.test'), findsOneWidget);
  });

  testWidgets('étape 1 : e-mail invalide → message, aucun envoi', (tester) async {
    final auth = FauxServiceAuth();
    await ouvrir(tester, auth);
    await tester.enterText(find.byType(TextFormField), 'pas-un-email');
    await appuyer(tester, 'Recevoir le code');
    expect(find.text('Cette adresse e-mail n\'est pas valide.'), findsOneWidget);
    expect(auth.reinitialisation, isEmpty);
  });

  testWidgets('parcours complet : code envoyé, vérifié, mot de passe changé, retour à l\'écran racine',
      (tester) async {
    final auth = FauxServiceAuth();
    await ouvrir(tester, auth);
    await tester.enterText(find.byType(TextFormField), ' salma@mida.test ');
    await appuyer(tester, 'Recevoir le code');

    expect(auth.reinitialisation, ['demande:salma@mida.test']);
    expect(find.text('Nouveau mot de passe'), findsWidgets);
    expect(find.textContaining('Si un compte Mida existe pour salma@mida.test'), findsOneWidget);

    await remplirEtape2(tester);
    await appuyer(tester, 'Changer le mot de passe');

    expect(auth.reinitialisation, [
      'demande:salma@mida.test',
      'code:salma@mida.test:123456',
      'motDePasse:Nouveau2026!',
    ]);
    expect(find.byType(MotDePasseOubliePage), findsNothing);
    expect(find.text('Mot de passe modifié. Vous êtes connecté.'), findsOneWidget);
  });

  testWidgets('étape 2 : code trop court et confirmation différente → messages, aucun appel', (tester) async {
    final auth = FauxServiceAuth();
    await ouvrir(tester, auth, email: 'salma@mida.test');
    await appuyer(tester, 'Recevoir le code');
    await remplirEtape2(tester, code: '123', confirmation: 'Autre2026!');
    await appuyer(tester, 'Changer le mot de passe');

    expect(find.text('Le code comporte 6 chiffres.'), findsOneWidget);
    expect(find.text('Les deux mots de passe ne sont pas identiques.'), findsOneWidget);
    expect(auth.reinitialisation, ['demande:salma@mida.test']);
  });

  testWidgets('code refusé par Supabase → message clair, on reste sur la page', (tester) async {
    final auth = FauxServiceAuth(erreurCode: const AuthApiException('x', code: 'otp_expired'));
    await ouvrir(tester, auth, email: 'salma@mida.test');
    await appuyer(tester, 'Recevoir le code');
    await remplirEtape2(tester);
    await appuyer(tester, 'Changer le mot de passe');

    expect(find.text(messageCodeInvalide), findsOneWidget);
    expect(find.byType(MotDePasseOubliePage), findsOneWidget);
    expect(auth.reinitialisation.last, 'code:salma@mida.test:123456');
  });

  testWidgets('mot de passe identique à l\'ancien : 2e essai sans revérifier le code (déjà consommé)',
      (tester) async {
    final auth = FauxServiceAuth(erreursMotDePasse: [const AuthApiException('x', code: 'same_password')]);
    await ouvrir(tester, auth, email: 'salma@mida.test');
    await appuyer(tester, 'Recevoir le code');
    await remplirEtape2(tester, mdp: 'Ancien2026!');
    await appuyer(tester, 'Changer le mot de passe');
    expect(find.textContaining('différent de l\'ancien'), findsOneWidget);

    await saisir(tester, 1, 'Nouveau2026!');
    await saisir(tester, 2, 'Nouveau2026!');
    await appuyer(tester, 'Changer le mot de passe');

    expect(auth.reinitialisation, [
      'demande:salma@mida.test',
      'code:salma@mida.test:123456',
      'motDePasse:Ancien2026!',
      'motDePasse:Nouveau2026!',
    ]);
    expect(find.byType(MotDePasseOubliePage), findsNothing);
  });

  testWidgets('« Renvoyer le code » redemande un e-mail', (tester) async {
    final auth = FauxServiceAuth();
    await ouvrir(tester, auth, email: 'salma@mida.test');
    await appuyer(tester, 'Recevoir le code');
    await appuyer(tester, 'Renvoyer le code');
    expect(auth.reinitialisation, ['demande:salma@mida.test', 'demande:salma@mida.test']);
    expect(find.textContaining('Nouveau code envoyé'), findsOneWidget);
  });
}
