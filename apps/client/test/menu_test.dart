import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/accueil_page.dart';
import 'package:mida_client/pages/restaurant_page.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';
import 'outils.dart';

final zitouna = catalogueTest.firstWhere((r) => r.id == 'r1');
final souika = catalogueTest.firstWhere((r) => r.id == 'r3');

void main() {
  group('menu d\'un restaurant (US17)', () {
    test('horaires du jour', () {
      const h = HoraireDuJour(ferme: false, ouverture: '11:00', fermeture: '23:00');
      expect(libelleOuverture(ouvert: true, horaire: h), 'Ouvert · jusqu\'à 23:00');
      expect(libelleOuverture(ouvert: true), 'Ouvert');
      expect(libelleOuverture(ouvert: false, horaire: h), 'Fermé');
      expect(libelleOuverture(ouvert: false, horaire: const HoraireDuJour(ferme: true)), 'Fermé aujourd\'hui');
      expect(HoraireDuJour.depuis({'ferme': false, 'ouverture': '11:00:00', 'fermeture': '22:30:00'}).fermeture, '22:30');
    });

    test('lecture d\'un plat renvoyé par Supabase', () {
      final p = Plat.depuis({
        'id': 'p9',
        'categorie_id': 'm1',
        'nom': 'Ojja',
        'description': null,
        'prix': '12.500',
        'image_url': null,
        'disponible': false,
      });
      expect((p.prix, p.description, p.disponible), (12.5, '', false));
    });

    testWidgets('toucher un restaurant du catalogue ouvre son menu', (tester) async {
      final mida = FauxServiceMida();
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth()), mida: mida);
      await tester.tap(find.text('Dar Zitouna'));
      await tester.pumpAndSettle();
      expect(mida.menusDemandes, ['r1']);
      expect(find.text('Couscous à l’agneau'), findsOneWidget);
    });

    testWidgets('plats classés par rubrique, avec description et prix ; rubrique vide masquée', (tester) async {
      await ouvrirPage(tester, RestaurantPage(restaurant: zitouna));

      expect(find.text('Dar Zitouna'), findsOneWidget);
      expect(find.text('4,8'), findsOneWidget);
      expect(find.text('12 avis'), findsOneWidget);
      expect(find.text('jusqu\'à 23:00'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Couscous'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Tajines'), findsNothing);

      expect(find.text('Semoule fine, agneau'), findsOneWidget);
      expect(find.text('18,000 DT'), findsOneWidget);
      await defilerJusqua(tester, find.text('Thé à la menthe'));
      expect(find.text('2,500 DT'), findsOneWidget);
      expect(find.text('Douceurs et thé'), findsWidgets);
    });

    testWidgets('les plats indisponibles sont signalés', (tester) async {
      await ouvrirPage(tester, RestaurantPage(restaurant: zitouna));
      final poisson = find.bySemanticsLabel(RegExp(r'^Plat Couscous au poisson'));
      expect(poisson, findsOneWidget);
      expect(find.descendant(of: poisson, matching: find.text('Indisponible')), findsOneWidget);
      // un seul plat épuisé dans ce menu
      expect(find.text('Indisponible'), findsOneWidget);
    });

    testWidgets('restaurant fermé : menu consultable, avec un bandeau', (tester) async {
      await ouvrirPage(tester, RestaurantPage(restaurant: souika));
      expect(find.textContaining('Ce restaurant est fermé pour le moment'), findsOneWidget);
      expect(find.text('Ce restaurant n\'a pas encore publié son menu.'), findsOneWidget);
    });

    testWidgets('erreur de chargement : message et « Réessayer »', (tester) async {
      await ouvrirPage(tester, RestaurantPage(restaurant: zitouna), mida: FauxServiceMida(erreur: Exception('réseau')));
      expect(find.text('Une erreur est survenue. Réessayez dans un instant.'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('Couscous à l’agneau'), findsOneWidget);
    });
  });
}
