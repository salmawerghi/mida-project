import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/donnees/format.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/accueil_page.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';
import 'outils.dart';

void main() {
  group('formats', () {
    test('prix en dinars, 3 décimales', () {
      expect(formaterPrix(16.5), '16,500 DT');
      expect(formaterPrix(2.5), '2,500 DT');
      expect(formaterPrix(1250), '1 250,000 DT');
      expect(formaterNote(4.75), '4,8');
      expect(lireNombre('22.500'), 22.5);
      expect(lireNombre(13), 13.0);
    });

    test('lecture d\'un restaurant renvoyé par Supabase', () {
      final r = RestaurantCatalogue.depuis(
        {
          'id': 'r1',
          'nom': 'hot food',
          'ville': 'Ariana',
          'categorie_id': null,
          'logo_url': 'https://exemple.test/logo.webp',
          'ouvert': true,
          'temps_preparation_min': 25,
          'categories_restaurant': null,
        },
        note: {'restaurant_id': 'r1', 'note': '4.5', 'nb_avis': 2},
      );
      expect((r.nom, r.ouvert, r.note, r.nbAvis, r.categorie), ('hot food', true, 4.5, 2, null));
      expect(r.delai, '25–35 min');
    });
  });

  group('catalogue des restaurants (US15)', () {
    testWidgets('restaurants ouverts d\'abord, avec leur note, leur catégorie et leur état', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth()));

      final cartes = find.bySemanticsLabel(RegExp(r'^Restaurant '));
      expect(cartes, findsNWidgets(3));
      final ordre = tester.widgetList<Semantics>(find.ancestor(of: find.byType(InkWell), matching: find.byType(Semantics)))
          .map((s) => s.properties.label)
          .whereType<String>()
          .where((l) => l.startsWith('Restaurant '))
          .toList();
      expect(ordre, ['Restaurant Dar Zitouna', 'Restaurant El Kanoun', 'Restaurant Bab Souika']);

      expect(find.text('4,8 (12 avis)'), findsOneWidget);
      expect(find.text('Nouveau'), findsOneWidget); // El Kanoun : pas encore d'avis
      expect(find.text('Couscous et tajines · La Marsa'), findsOneWidget);
      expect(find.text('Ouvert'), findsNWidgets(2));
      expect(find.text('Fermé'), findsOneWidget);
      expect(find.text('20–30 min'), findsOneWidget);
    });

    testWidgets('erreur de chargement : message, puis « Réessayer »', (tester) async {
      final mida = FauxServiceMida(erreur: Exception('réseau'));
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth()), mida: mida);

      expect(find.text('Une erreur est survenue. Réessayez dans un instant.'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Dar Zitouna'), findsOneWidget);
    });

    testWidgets('aucun restaurant validé : message', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth()), mida: FauxServiceMida(restaurants: []));
      expect(find.text('Aucun restaurant pour le moment. Revenez bientôt !'), findsOneWidget);
    });

    testWidgets('visiteur : catalogue visible, et invitation à créer un compte', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth(), visiteur: true));
      expect(find.text('Bienvenue !'), findsOneWidget);
      expect(find.text('Dar Zitouna'), findsOneWidget);
      await defilerJusqua(tester, find.text('J\'ai déjà un compte'));
      expect(find.text('Créer un compte'), findsOneWidget);
    });
  });
}
