import 'package:flutter_test/flutter_test.dart';
import 'package:mida_livreur/donnees/modeles.dart';
import 'package:mida_livreur/pages/espace_livreur.dart';
import 'package:mida_livreur/pages/gains_page.dart';

import 'faux_services.dart';

/// Le « jour » des tests : mercredi 19 novembre 2026, 21 h.
final maintenant = DateTime(2026, 11, 19, 21);

final livreesTest = [
  copie(courseEspeces, etat: EtatCourse.livree, etatCommande: 'livree', livreeLe: DateTime(2026, 11, 19, 20, 15)),
  copie(courseCarte, etat: EtatCourse.livree, etatCommande: 'livree', livreeLe: DateTime(2026, 11, 19, 13, 5)),
  copie(courseCarte, etat: EtatCourse.livree, etatCommande: 'livree', livreeLe: DateTime(2026, 11, 18, 19, 40)),
  copie(courseEspeces, etat: EtatCourse.livree, etatCommande: 'livree', livreeLe: DateTime(2026, 11, 10, 12)),
];

void main() {
  group('historique des courses et gains (US42)', () {
    test('gains : aujourd\'hui, 7 derniers jours, total', () {
      final r = resumerGains(livreesTest, maintenant: maintenant);
      expect((r.aujourdhui, r.nbAujourdhui), (4.0, 2));
      expect((r.semaine, r.nbSemaine), (6.0, 3));
      expect((r.total, r.nb), (8.0, 4));
      // une course non livrée ne compte pas
      expect(resumerGains([courseCarte], maintenant: maintenant).nb, 0);
    });

    test('note moyenne des clients', () {
      final n = NoteLivreur.depuis([
        {'note': 5},
        {'note': 4},
      ]);
      expect((n.moyenne, n.nbAvis), (4.5, 2));
      expect(NoteLivreur.depuis(const []).moyenne, isNull);
    });

    testWidgets('l\'accueil mène à « Mes courses et gains »', (tester) async {
      final livreur = FauxServiceLivreur()..livrees = livreesTest;
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur);
      await appuyer(tester, find.byTooltip('Mes courses et gains'));
      expect(find.byType(GainsPage), findsOneWidget);
      expect(livreur.appels, contains('mesCourses'));
    });

    testWidgets('résumé, note et courses regroupées par jour', (tester) async {
      final livreur = FauxServiceLivreur()
        ..livrees = livreesTest
        ..note = const NoteLivreur(moyenne: 4.5, nbAvis: 2);
      await ouvrirPage(tester, GainsPage(maintenant: maintenant), livreur: livreur);

      expect(find.bySemanticsLabel('Aujourd\'hui : 4,000 DT, 2 courses'), findsOneWidget);
      expect(find.bySemanticsLabel('7 derniers jours : 6,000 DT, 3 courses'), findsOneWidget);
      expect(find.bySemanticsLabel('Total : 8,000 DT, 4 courses'), findsOneWidget);
      expect(find.bySemanticsLabel('Note des clients : ★ 4,5 / 5, 2 avis'), findsOneWidget);

      expect(find.text('Aujourd\'hui · 4,000 DT'), findsOneWidget);
      await defilerJusqua(tester, find.text('20:15 · n° 1045'));
      expect(find.text('Espèces encaissées : 25,500 DT'), findsWidgets);
      await defilerJusqua(tester, find.text('Hier · 2,000 DT'));
      await defilerJusqua(tester, find.text('10 nov. · 2,000 DT'));
    });

    testWidgets('aucune course, pas encore d\'avis', (tester) async {
      await ouvrirPage(tester, GainsPage(maintenant: maintenant), livreur: FauxServiceLivreur());
      expect(find.bySemanticsLabel('Total : 0,000 DT, 0 course'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Pas encore d\'avis')), findsOneWidget);
      expect(find.textContaining('Aucune course livrée pour le moment'), findsOneWidget);
    });

    testWidgets('erreur de chargement : message et « Réessayer »', (tester) async {
      final livreur = FauxServiceLivreur()..erreur = refusServeur;
      await ouvrirPage(tester, GainsPage(maintenant: maintenant), livreur: livreur);
      expect(find.text('Réessayer'), findsOneWidget);
      await appuyer(tester, find.text('Réessayer'));
      expect(find.textContaining('Aucune course livrée'), findsOneWidget);
    });
  });
}
