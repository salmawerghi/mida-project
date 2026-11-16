import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/donnees/format.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/accueil_page.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';
import 'outils.dart';

/// Les puces de catégorie défilent horizontalement : on amène la puce à l'écran avant de la toucher.
Future<void> toucherCategorie(WidgetTester tester, String nom) async {
  final puce = find.widgetWithText(ChoiceChip, nom);
  await tester.ensureVisible(puce);
  await tester.pumpAndSettle();
  await tester.tap(puce);
}

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

  group('recherche et filtre par catégorie (US16)', () {
    test('recherche sans tenir compte des majuscules ni des accents, par mots', () {
      List<String> noms(String recherche, {String? categorie}) =>
          filtrerRestaurants(catalogueTest, recherche: recherche, categorieId: categorie).map((r) => r.nom).toList();
      expect(noms('zitou'), ['Dar Zitouna']);
      expect(noms('BAB souïka'), ['Bab Souika']);
      expect(noms('  '), hasLength(3));
      expect(noms('couscous'), containsAll(['Dar Zitouna', 'Bab Souika'])); // nom de la catégorie
      expect(noms('', categorie: 'k2'), ['El Kanoun']);
      expect(noms('dar', categorie: 'k2'), isEmpty);
    });

    testWidgets('la recherche par nom filtre la liste au fil de la saisie', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth()));
      await tester.enterText(find.byType(TextField), 'kanoun');
      await tester.pump();
      expect(find.text('El Kanoun'), findsOneWidget);
      expect(find.text('Dar Zitouna'), findsNothing);

      await tester.tap(find.byTooltip('Effacer la recherche'));
      await tester.pump();
      expect(find.text('Dar Zitouna'), findsOneWidget);
    });

    testWidgets('filtre par catégorie (seules les catégories utilisées sont proposées)', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth()));
      expect(find.widgetWithText(ChoiceChip, 'Tous'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Douceurs'), findsNothing); // aucun restaurant

      await toucherCategorie(tester, 'Ojja et grillades');
      await tester.pump();
      expect(find.text('El Kanoun'), findsOneWidget);
      expect(find.text('Dar Zitouna'), findsNothing);

      await toucherCategorie(tester, 'Tous');
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'^Restaurant ')), findsNWidgets(3));
    });

    testWidgets('aucun résultat : message, et « Effacer les filtres » remet tout', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth()));
      await toucherCategorie(tester, 'Ojja et grillades');
      await tester.enterText(find.byType(TextField), 'pizza');
      await tester.pump();
      expect(find.text('Aucun restaurant ne correspond à « pizza ».'), findsOneWidget);

      await tester.tap(find.text('Effacer les filtres'));
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'^Restaurant ')), findsNWidgets(3));
      expect(find.text('pizza'), findsNothing);
    });

    testWidgets('sans les catégories (erreur), le catalogue reste utilisable', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth()), mida: FauxServiceMida()..erreurCategories = true);
      expect(find.text('Dar Zitouna'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });
}
