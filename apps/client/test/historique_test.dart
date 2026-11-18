import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/donnees/format.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/accueil_page.dart';
import 'package:mida_client/pages/historique_page.dart';
import 'package:mida_client/pages/suivi_page.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';
import 'outils.dart';

/// Année en cours : la date s'affiche sans l'année (« 16 nov. »).
final annee = DateTime.now().year;

CommandeClient commandeDu(
  String id,
  int numero,
  DateTime creeeLe,
  EtatCommande etat, {
  String restaurant = 'Dar Zitouna',
  String paiementMode = 'especes',
  String paiementEtat = 'en_attente',
  List<LigneCommande> lignes = const [LigneCommande(nomPlat: 'Brik à l’œuf', quantite: 1, prixUnitaire: 4)],
}) =>
    CommandeClient(
      id: id,
      numero: numero,
      etat: etat,
      restaurantNom: restaurant,
      adresse: '12, rue du Jasmin, La Marsa',
      sousTotal: 20,
      fraisLivraison: 2.5,
      total: 22.5,
      motifRefus: etat == EtatCommande.refusee ? 'Un plat est épuisé' : null,
      creeeLe: creeeLe,
      lignes: lignes,
      paiementMode: paiementMode,
      paiementEtat: paiementEtat,
    );

/// Quatre commandes, rangées volontairement dans le désordre.
FauxServiceMida avecHistorique() => FauxServiceMida()
  ..suivies.addAll({
    'a': commandeDu('a', 1044, DateTime(annee, 11, 1, 12), EtatCommande.livree, restaurant: 'Brik Bab Souika'),
    'b': commandeDu('b', 1047, DateTime(annee, 11, 16, 19), EtatCommande.enPreparation, lignes: const [
      LigneCommande(nomPlat: 'Couscous à l’agneau', quantite: 1, prixUnitaire: 18),
      LigneCommande(nomPlat: 'Thé à la menthe', quantite: 2, prixUnitaire: 2.5),
    ]),
    'c': commandeDu('c', 1045, DateTime(annee, 11, 5, 20), EtatCommande.refusee,
        restaurant: 'El Kanoun', paiementMode: 'carte', paiementEtat: 'rembourse'),
    'd': commandeDu('d', 1046, DateTime(annee, 11, 8, 13), EtatCommande.annulee, restaurant: 'Halwa Sidi Bou'),
  });

void main() {
  group('historique des commandes (US22)', () {
    test('dates courtes, avec l\'année seulement si elle diffère', () {
      final maintenant = DateTime(2026, 11, 18);
      expect(formaterDate(DateTime(2026, 11, 8, 19, 41), maintenant: maintenant), '8 nov.');
      expect(formaterDate(DateTime(2026, 2, 1), maintenant: maintenant), '1 févr.');
      expect(formaterDate(DateTime(2025, 12, 28), maintenant: maintenant), '28 déc. 2025');
      expect(commandeTest.nbArticles, 3);
    });

    testWidgets('commandes en cours puis passées, de la plus récente à la plus ancienne', (tester) async {
      await ouvrirPage(tester, const HistoriquePage(), mida: avecHistorique());

      expect(find.text('Mes commandes'), findsOneWidget);
      expect(find.text('En cours'), findsOneWidget);
      expect(find.text('Commandes passées'), findsOneWidget);
      expect(find.text('n° 1047 · 16 nov. · 3 articles'), findsOneWidget);
      expect(find.text('n° 1044 · 1 nov. · 1 article'), findsOneWidget);

      // pastilles d'état
      expect(find.text('En préparation'), findsOneWidget);
      expect(find.text('Annulée'), findsOneWidget);
      expect(find.text('Refusée · remboursée'), findsOneWidget);
      expect(find.text('Livrée'), findsOneWidget);

      double haut(String texte) => tester.getTopLeft(find.text(texte)).dy;
      expect(haut('En cours'), lessThan(haut('n° 1047 · 16 nov. · 3 articles')));
      expect(haut('n° 1047 · 16 nov. · 3 articles'), lessThan(haut('Commandes passées')));
      expect(haut('Halwa Sidi Bou'), lessThan(haut('El Kanoun')));
      expect(haut('El Kanoun'), lessThan(haut('Brik Bab Souika')));
    });

    testWidgets('le détail d\'une commande passée est consultable', (tester) async {
      await ouvrirPage(tester, const HistoriquePage(), mida: avecHistorique());

      await tester.tap(find.text('El Kanoun'));
      await tester.pumpAndSettle();
      expect(find.byType(SuiviPage), findsOneWidget);
      expect(find.text('Commande n° 1045'), findsOneWidget);
      expect(find.text('Passée le 5 nov. à 20:00'), findsOneWidget);
      expect(find.text('« Un plat est épuisé »'), findsOneWidget);
      await defilerJusqua(tester, find.text('1 × Brik à l’œuf'));
      expect(find.text('1 × Brik à l’œuf'), findsOneWidget);

      // retour : la liste est relue
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HistoriquePage), findsOneWidget);
      expect(find.text('El Kanoun'), findsOneWidget);
    });

    testWidgets('aucune commande : message et retour au catalogue', (tester) async {
      await ouvrirPage(tester, const HistoriquePage());
      expect(find.text('Vous n\'avez pas encore passé de commande.'), findsOneWidget);
      expect(find.text('Découvrir les restaurants'), findsOneWidget);
    });

    testWidgets('erreur de chargement puis « Réessayer »', (tester) async {
      final mida = avecHistorique()..erreur = Exception('réseau');
      await ouvrirPage(tester, const HistoriquePage(), mida: mida);
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.text('El Kanoun'), findsOneWidget);
    });

    testWidgets('accueil : « Mes commandes » ouvre l\'historique', (tester) async {
      final auth = FauxServiceAuth(connecte: true);
      await ouvrirPage(tester, AccueilPage(auth: auth), mida: avecHistorique(), auth: auth);

      await tester.tap(find.byTooltip('Mes commandes'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoriquePage), findsOneWidget);
      expect(find.text('Brik Bab Souika'), findsOneWidget);
    });

    testWidgets('visiteur : pas d\'accès à l\'historique', (tester) async {
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth(), visiteur: true));
      expect(find.byTooltip('Mes commandes'), findsNothing);
    });
  });
}
