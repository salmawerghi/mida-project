import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/panier_page.dart';
import 'package:mida_client/pages/restaurant_page.dart';
import 'package:mida_client/panier/panier.dart';

import 'faux_service_mida.dart';
import 'outils.dart';

final zitouna = catalogueTest.firstWhere((r) => r.id == 'r1');
final kanoun = catalogueTest.firstWhere((r) => r.id == 'r2');
final souika = catalogueTest.firstWhere((r) => r.id == 'r3');
final agneau = menuTest.plats.firstWhere((p) => p.id == 'p1');
final poisson = menuTest.plats.firstWhere((p) => p.id == 'p2'); // indisponible
final the = menuTest.plats.firstWhere((p) => p.id == 'p4');
const ojja = Plat(id: 'k1', categorieId: 'mk', nom: 'Ojja merguez', prix: 12);

/// Le chiffre « 2 » affiché entre « − » et « + » sur la carte du plat.
Finder quantiteAffichee(String plat, int n) =>
    find.descendant(of: find.bySemanticsLabel(RegExp('^Plat $plat')), matching: find.text('$n'));

/// Fait défiler jusqu'au sous-total, le vérifie, puis remonte en haut du panier.
Future<void> verifierSousTotal(WidgetTester tester, String montant) async {
  await defilerJusqua(tester, find.text('Sous-total'));
  final ligne = find.ancestor(of: find.text('Sous-total'), matching: find.byType(Row)).first;
  expect(find.descendant(of: ligne, matching: find.text(montant)), findsOneWidget);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
}

void main() {
  group('panier (US18)', () {
    test('ajouter, modifier les quantités, retirer : le total suit', () {
      final panier = Panier();
      var notifications = 0;
      panier.addListener(() => notifications++);

      expect(panier.ajouter(zitouna, agneau), ResultatAjout.ajoute);
      panier.ajouter(zitouna, agneau);
      panier.ajouter(zitouna, the);
      expect((panier.nbArticles, panier.sousTotal, panier.quantiteDe('p1')), (3, 38.5, 2));

      panier.retirer('p1');
      expect((panier.nbArticles, panier.sousTotal), (2, 20.5));
      panier.retirer('p1'); // dernière : la ligne disparaît
      expect(panier.lignes.map((l) => l.plat.nom), ['Thé à la menthe']);
      panier.supprimer('p4');
      expect((panier.estVide, panier.restaurant), (true, null));
      expect(notifications, 6);
    });

    test('un seul restaurant par panier', () {
      final panier = Panier()..ajouter(zitouna, agneau);
      expect(panier.ajouter(kanoun, ojja), ResultatAjout.autreRestaurant);
      expect(panier.restaurant!.id, 'r1');
      expect(panier.nbArticles, 1);

      expect(panier.remplacerPar(kanoun, ojja), ResultatAjout.ajoute);
      expect((panier.restaurant!.id, panier.lignes.single.plat.nom), ('r2', 'Ojja merguez'));
    });

    test('refusé : plat indisponible, restaurant fermé, plus de 20 exemplaires', () {
      final panier = Panier();
      expect(panier.ajouter(zitouna, poisson), ResultatAjout.refuse);
      expect(panier.ajouter(souika, the), ResultatAjout.refuse);
      for (var i = 0; i < Panier.quantiteMax; i++) {
        panier.ajouter(zitouna, the);
      }
      expect(panier.ajouter(zitouna, the), ResultatAjout.refuse);
      expect(panier.quantiteDe('p4'), 20);
    });

    testWidgets('depuis le menu : « + », puis « − 2 + », et la barre « Voir le panier »', (tester) async {
      final panier = Panier();
      await ouvrirPage(tester, RestaurantPage(restaurant: zitouna), panier: panier);
      expect(find.text('Voir le panier'), findsNothing);
      // pas de bouton pour le plat indisponible
      expect(find.byTooltip('Ajouter Couscous au poisson'), findsNothing);

      await tester.tap(find.byTooltip('Ajouter Couscous à l’agneau'));
      await tester.pump();
      await tester.tap(find.byTooltip('Un Couscous à l’agneau de plus'));
      await tester.pump();
      expect(quantiteAffichee('Couscous à l’agneau', 2), findsOneWidget);
      expect(find.text('Voir le panier'), findsOneWidget);
      expect(find.text('36,000 DT'), findsOneWidget);
      expect(panier.nbArticles, 2);

      // le panier est conservé quand on quitte l'écran
      await tester.tap(find.text('Voir le panier'));
      await tester.pumpAndSettle();
      expect(find.text('Votre panier'), findsOneWidget);
      expect(find.text('Dar Zitouna · 2 articles'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(quantiteAffichee('Couscous à l’agneau', 2), findsOneWidget);
    });

    testWidgets('restaurant fermé : aucun bouton d\'ajout', (tester) async {
      await ouvrirPage(tester, RestaurantPage(restaurant: souika.copieAvecMenu()));
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });

    testWidgets('plat d\'un autre restaurant : on propose de vider le panier', (tester) async {
      final panier = Panier()..ajouter(kanoun, ojja);
      await ouvrirPage(tester, RestaurantPage(restaurant: zitouna), panier: panier);
      // la barre ne montre pas le panier d'un autre restaurant
      expect(find.text('Voir le panier'), findsNothing);

      await tester.tap(find.byTooltip('Ajouter Couscous à l’agneau'));
      await tester.pumpAndSettle();
      expect(find.text('Commencer un nouveau panier ?'), findsOneWidget);
      expect(find.textContaining('Votre panier contient des plats de El Kanoun'), findsOneWidget);

      await tester.tap(find.text('Garder mon panier'));
      await tester.pumpAndSettle();
      expect(panier.restaurant!.id, 'r2');

      await tester.tap(find.byTooltip('Ajouter Couscous à l’agneau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vider et ajouter'));
      await tester.pumpAndSettle();
      expect((panier.restaurant!.id, panier.nbArticles), ('r1', 1));
      expect(find.text('Voir le panier'), findsOneWidget);
    });

    testWidgets('page panier : modifier les quantités met le total à jour, jusqu\'au panier vide', (tester) async {
      final panier = Panier()
        ..ajouter(zitouna, agneau)
        ..ajouter(zitouna, the)
        ..ajouter(zitouna, the);
      await ouvrirPage(tester, const PanierPage(), panier: panier);
      await verifierSousTotal(tester, '23,000 DT'); // 18 + 2 × 2,5

      await tester.tap(find.byTooltip('Un Thé à la menthe de plus'));
      await tester.pump();
      await verifierSousTotal(tester, '25,500 DT');

      await tester.tap(find.byTooltip('Retirer Couscous à l’agneau du panier'));
      await tester.pump();
      expect(find.text('Couscous à l’agneau'), findsNothing);
      expect(find.text('Dar Zitouna · 3 articles'), findsOneWidget);

      await tester.tap(find.text('Vider'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Vider').last);
      await tester.pumpAndSettle();
      expect(find.text('Votre panier est vide'), findsOneWidget);
      expect(panier.estVide, isTrue);
    });
  });
}

extension on RestaurantCatalogue {
  /// Bab Souika (fermé) avec le menu de test : seul l'état « fermé » compte ici.
  RestaurantCatalogue copieAvecMenu() =>
      RestaurantCatalogue(id: 'r1', nom: nom, ville: ville, ouvert: false, note: note, nbAvis: nbAvis);
}
