import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/auth/erreurs.dart';
import 'package:mida_client/auth/service_auth.dart';
import 'package:mida_client/pages/accueil_page.dart';
import 'package:mida_client/pages/profil_page.dart';
import 'package:mida_client/widgets/composants.dart';

import 'faux_service_auth.dart';
import 'outils.dart';

Finder champ(String etiquette) =>
    find.descendant(of: find.widgetWithText(ChampEtiquete, etiquette), matching: find.byType(TextFormField));

void main() {
  group('profil du client (US24)', () {
    test('initiales et téléphone sans indicatif', () {
      expect(initiales('Amine Belhadj'), 'AB');
      expect(initiales('  salma  '), 'S');
      expect(initiales('Mohamed Amine Belloumi'), 'MB');
      expect(const ProfilClient(nom: 'x', email: 'e', telephone: '+216 22 145 870').telephoneLocal, '22 145 870');
      expect(const ProfilClient(nom: 'x', email: 'e').telephoneLocal, '');
    });

    testWidgets('nom et téléphone sont modifiables', (tester) async {
      final auth = FauxServiceAuth(connecte: true);
      await ouvrirPage(tester, ProfilPage(auth: auth), auth: auth);

      expect(find.text('AB'), findsOneWidget);
      expect(find.text('amine@mida.test'), findsWidgets);
      expect(tester.widget<TextFormField>(champ('Téléphone')).controller!.text, '22 145 870');

      await tester.enterText(champ('Nom et prénom'), 'Amine Ben Salah');
      await tester.enterText(champ('Téléphone'), '98 765 432');
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pumpAndSettle();

      expect(auth.profilActuel.nom, 'Amine Ben Salah');
      expect(auth.profilActuel.telephone, '+216 98 765 432');
      expect(find.text('Vos informations sont enregistrées.'), findsOneWidget);
      expect(find.text('Amine Ben Salah'), findsWidgets);
    });

    testWidgets('saisie invalide : rien n\'est envoyé', (tester) async {
      final auth = FauxServiceAuth(connecte: true);
      await ouvrirPage(tester, ProfilPage(auth: auth), auth: auth);

      await tester.enterText(champ('Nom et prénom'), '');
      await tester.enterText(champ('Téléphone'), '123');
      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Indiquez votre nom et prénom.'), findsOneWidget);
      expect(find.text('Le numéro doit comporter 8 chiffres.'), findsOneWidget);
      expect(auth.profilActuel.nom, 'Amine Belhadj');
    });

    testWidgets('refus du serveur affiché', (tester) async {
      final auth = FauxServiceAuth(connecte: true)..erreurProfil = const ErreurMida('Connexion impossible.');
      await ouvrirPage(tester, ProfilPage(auth: auth), auth: auth);

      await tester.tap(find.bySemanticsLabel('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Connexion impossible.'), findsOneWidget);
    });

    testWidgets('accueil → profil → déconnexion', (tester) async {
      final auth = FauxServiceAuth(connecte: true);
      await ouvrirPage(tester, AccueilPage(auth: auth), auth: auth);

      await tester.tap(find.byTooltip('Mon profil'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilPage), findsOneWidget);

      await defilerJusqua(tester, find.text('Se déconnecter'));
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(auth.connecte, isFalse);
      expect(find.byType(ProfilPage), findsNothing);
    });

    testWidgets('visiteur : pas de profil', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth(), visiteur: true));
      expect(find.byTooltip('Mon profil'), findsNothing);
    });
  });
}
