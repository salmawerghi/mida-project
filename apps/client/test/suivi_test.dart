import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/accueil_page.dart';
import 'package:mida_client/pages/suivi_page.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';
import 'outils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Laisse passer la relecture différée (300 ms) qui suit un événement temps réel.
Future<void> recevoir(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('suivi de la commande en temps réel (US20)', () {
    test('étapes : franchies, actuelle, à venir', () {
      final c = avecEtat(commandeTest, EtatCommande.enPreparation, accepteeLe: DateTime(2026, 11, 16, 19, 2));
      final etapes = etapesSuivi(c);
      expect(etapes.map((e) => e.libelle), [
        'Commande envoyée',
        'Acceptée par le restaurant',
        'En préparation',
        'Prête',
        'En cours de livraison',
        'Livrée',
      ]);
      expect(etapes.map((e) => e.franchie), [true, true, true, false, false, false]);
      expect(etapes.indexWhere((e) => e.actuelle), 2);
      expect(etapes[1].heure, DateTime(2026, 11, 16, 19, 2));
      expect(EtatCommande.refusee.enCours, isFalse);
    });

    test('lecture d\'une commande renvoyée par Supabase', () {
      final c = CommandeClient.depuis({
        'id': 'x',
        'numero': 1001,
        'etat': 'refusee',
        'adresse_livraison': '8, rue des Jasmins',
        'sous_total': '20.000',
        'frais_livraison': '2.500',
        'total': '22.500',
        'remarque': null,
        'motif_refus': 'Le restaurant ferme bientôt',
        'created_at': '2026-11-16T14:58:01Z',
        'acceptee_le': null,
        'prete_le': null,
        'livree_le': null,
        'annulee_le': null,
        'restaurants': {'nom': 'hot food'},
        'lignes_commande': [
          {'nom_plat': 'cosksi bl osben', 'quantite': 1, 'prix_unitaire': '20.000'},
        ],
        'paiements': {'mode': 'carte', 'etat': 'rembourse'},
      });
      expect((c.etat, c.restaurantNom, c.total, c.rembourse, c.lignes.single.nomPlat),
          (EtatCommande.refusee, 'hot food', 22.5, true, 'cosksi bl osben'));
    });

    testWidgets('l\'état se met à jour sans action du client', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = commandeTest;
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);

      expect(find.text('Commande n° 1047'), findsOneWidget);
      expect(find.text('En attente du restaurant'), findsOneWidget);
      expect(find.bySemanticsLabel('Commande envoyée, étape franchie, étape actuelle'), findsOneWidget);
      expect(find.text('19:00'), findsOneWidget);
      expect(mida.nbAbonnes, 1);

      // le restaurant accepte, puis commence la préparation
      mida.simulerChangement(avecEtat(commandeTest, EtatCommande.acceptee, accepteeLe: DateTime(2026, 11, 16, 19, 2)));
      await recevoir(tester);
      expect(find.text('Acceptée par le restaurant'), findsWidgets);
      expect(find.text('19:02'), findsOneWidget);

      mida.simulerChangement(avecEtat(commandeTest, EtatCommande.prete,
          accepteeLe: DateTime(2026, 11, 16, 19, 2), preteLe: DateTime(2026, 11, 16, 19, 24)));
      await recevoir(tester);
      expect(find.bySemanticsLabel('Prête, étape franchie, étape actuelle'), findsOneWidget);
      expect(find.bySemanticsLabel('En préparation, étape franchie'), findsOneWidget);
      expect(find.bySemanticsLabel('Livrée, à venir'), findsOneWidget);
    });

    testWidgets('détail : plats, montants, adresse, paiement, remarque', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = commandeTest;
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);
      await defilerJusqua(tester, find.text('Remarque : Sonner deux fois'));
      expect(find.text('2 × Thé à la menthe'), findsOneWidget);
      expect(find.text('25,500 DT'), findsOneWidget);
      expect(find.text('12, rue du Jasmin, La Marsa'), findsOneWidget);
      expect(find.text('Espèces à la livraison'), findsOneWidget);
    });

    testWidgets('commande refusée : le motif du restaurant est affiché, et le remboursement', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = commandeTest;
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);

      mida.simulerChangement(avecEtat(commandeTest, EtatCommande.refusee,
          motifRefus: 'Un plat est épuisé — Plus de couscous ce soir.', paiementMode: 'carte', paiementEtat: 'rembourse'));
      await recevoir(tester);

      expect(find.text('Commande refusée'), findsOneWidget);
      expect(find.text('Dar Zitouna n\'a pas pu accepter votre commande.'), findsOneWidget);
      expect(find.text('« Un plat est épuisé — Plus de couscous ce soir. »'), findsOneWidget);
      expect(find.textContaining('25,500 DT remboursés'), findsOneWidget);
      expect(find.text('Trouver un autre restaurant'), findsOneWidget);
    });

    testWidgets('quitter le suivi arrête l\'écoute en temps réel', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = commandeTest;
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);
      expect(mida.nbAbonnes, 1);
      await tester.pumpWidget(const SizedBox());
      expect(mida.nbAbonnes, 0);
    });

    testWidgets('accueil : la commande en cours mène au suivi', (tester) async {
      final mida = FauxServiceMida()
        ..suivies['cmd1'] = avecEtat(commandeTest, EtatCommande.enPreparation, accepteeLe: DateTime(2026, 11, 16, 19, 2));
      final auth = FauxServiceAuth(connecte: true);
      await ouvrirPage(tester, AccueilPage(auth: auth), mida: mida, auth: auth);

      expect(find.text('Commande n° 1047 · Dar Zitouna'), findsOneWidget);
      await tester.tap(find.text('Commande n° 1047 · Dar Zitouna'));
      await tester.pumpAndSettle();
      expect(find.byType(SuiviPage), findsOneWidget);
      expect(find.bySemanticsLabel('En préparation, étape franchie, étape actuelle'), findsOneWidget);
    });

    testWidgets('accueil d\'un visiteur : pas de commande à suivre', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = commandeTest;
      await ouvrirPage(tester, AccueilPage(auth: FauxServiceAuth(), visiteur: true), mida: mida);
      expect(find.textContaining('Commande n°'), findsNothing);
    });
  });

  group('annuler sa commande (US21)', () {
    Future<void> toucherAnnuler(WidgetTester tester) async {
      final bouton = find.widgetWithText(OutlinedButton, 'Annuler la commande');
      await tester.ensureVisible(bouton);
      await tester.pumpAndSettle();
      await tester.tap(bouton);
      await tester.pumpAndSettle();
    }

    testWidgets('en attente : annulation après confirmation, l\'état devient « annulée »', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = commandeTest;
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);

      await toucherAnnuler(tester);
      expect(find.text('Annuler la commande n° 1047 ?'), findsOneWidget);
      await tester.tap(find.text('Garder ma commande'));
      await tester.pumpAndSettle();
      expect(mida.annulations, isEmpty);

      await toucherAnnuler(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Annuler la commande'));
      await recevoir(tester);
      expect(mida.annulations, ['cmd1']);
      expect(find.text('Commande annulée'), findsOneWidget);
      expect(find.textContaining('Vous avez annulé cette commande à 19:03'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Annuler la commande'), findsNothing);
    });

    testWidgets('plus de bouton une fois la commande acceptée', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = commandeTest;
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);
      expect(find.widgetWithText(OutlinedButton, 'Annuler la commande'), findsOneWidget);

      mida.simulerChangement(avecEtat(commandeTest, EtatCommande.acceptee, accepteeLe: DateTime(2026, 11, 16, 19, 2)));
      await recevoir(tester);
      expect(find.widgetWithText(OutlinedButton, 'Annuler la commande'), findsNothing);
    });

    testWidgets('acceptée entre-temps : le refus du serveur est affiché', (tester) async {
      final mida = FauxServiceMida()
        ..suivies['cmd1'] = commandeTest
        ..erreurAnnulation = const PostgrestException(
          message: 'La commande n° 1047 ne peut plus être annulée : le restaurant l\'a déjà acceptée',
          code: 'P0001',
        );
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);
      await toucherAnnuler(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Annuler la commande'));
      await tester.pumpAndSettle();
      expect(find.text('La commande n° 1047 ne peut plus être annulée : le restaurant l\'a déjà acceptée'), findsOneWidget);
    });
  });
}
