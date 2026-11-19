import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/historique_page.dart';
import 'package:mida_client/pages/noter_page.dart';
import 'package:mida_client/pages/suivi_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';
import 'outils.dart';

/// Commande n° 1047 livrée par Sami, pas encore notée.
final livree = avecEtat(
  commandeTest,
  EtatCommande.livree,
  accepteeLe: DateTime(2026, 11, 16, 19, 2),
  preteLe: DateTime(2026, 11, 16, 19, 20),
  livreeLe: DateTime(2026, 11, 16, 19, 45),
  livreurNom: 'Sami Trabelsi',
);

Future<void> etoile(WidgetTester tester, int n, String sujet) async {
  final bouton = find.byTooltip('$n étoile${n > 1 ? 's' : ''} sur 5 pour $sujet');
  await tester.ensureVisible(bouton);
  await tester.tap(bouton);
  await tester.pump();
}

Future<void> envoyer(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Envoyer mon avis'));
  await tester.tap(find.text('Envoyer mon avis'));
  await tester.pumpAndSettle();
}

void main() {
  group('avis après la livraison (US38)', () {
    test('lecture des notes et du livreur renvoyés par Supabase', () {
      final c = CommandeClient.depuis({
        'id': 'x',
        'numero': 1042,
        'etat': 'livree',
        'adresse_livraison': '12, rue du Jasmin',
        'sous_total': '31.000',
        'frais_livraison': '2.500',
        'total': '33.500',
        'created_at': '2026-11-14T19:00:00Z',
        'restaurants': {'nom': 'Dar Zitouna'},
        'lignes_commande': const [],
        'paiements': {'mode': 'especes', 'etat': 'paye'},
        'livraisons': {
          'livreurs': {
            'profiles': {'nom': 'Sami Trabelsi'},
          },
        },
        'avis': [
          {'note': 5, 'livreur_id': null},
          {'note': 4, 'livreur_id': 'l1'},
        ],
      });
      expect((c.livreurNom, c.noteRestaurant, c.noteLivreur, c.aNoter), ('Sami Trabelsi', 5, 4, false));
      final sansAvis = CommandeClient.depuis({
        'id': 'y',
        'numero': 1043,
        'etat': 'livree',
        'sous_total': 1,
        'frais_livraison': 1,
        'total': 2,
        'created_at': '2026-11-14T19:00:00Z',
        'livraisons': const [],
        'avis': const [],
      });
      expect((sansAvis.livreurNom, sansAvis.noteRestaurant, sansAvis.aNoter), (null, null, true));
    });

    testWidgets('commande livrée : le client note le restaurant et le livreur', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = livree;
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);

      expect(find.text('Bon appétit !'), findsOneWidget);
      await tester.ensureVisible(find.text('Noter la commande'));
      await tester.tap(find.text('Noter la commande'));
      await tester.pumpAndSettle();
      expect(find.byType(NoterPage), findsOneWidget);
      expect(find.text('Livreur : Sami Trabelsi'), findsOneWidget);

      await etoile(tester, 4, 'le restaurant');
      expect(find.text('Bien'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Commentaire sur le restaurant'), '  Très bon couscous ');
      // le commentaire du livreur n'apparaît qu'après sa note
      expect(find.widgetWithText(TextField, 'Commentaire sur le livreur'), findsNothing);
      await etoile(tester, 5, 'le livreur');
      await envoyer(tester);

      expect(mida.avis, [
        {
          'commande': 'cmd1',
          'restaurant': 4,
          'commentaireRestaurant': 'Très bon couscous',
          'livreur': 5,
          'commentaireLivreur': null,
        },
      ]);
      // retour au suivi : remerciement et notes données
      expect(find.byType(SuiviPage), findsOneWidget);
      expect(find.text('Merci pour votre avis !'), findsOneWidget);
      expect(find.bySemanticsLabel('Votre avis : 4 sur 5 pour Dar Zitouna, 5 sur 5 pour le livreur'), findsOneWidget);
      expect(find.text('Noter la commande'), findsNothing);
    });

    testWidgets('la note du restaurant est obligatoire, celle du livreur facultative', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = livree;
      await ouvrirPage(tester, NoterPage(commande: livree), mida: mida);

      await envoyer(tester);
      expect(find.text('Choisissez une note de 1 à 5 étoiles pour le restaurant.'), findsOneWidget);
      expect(mida.avis, isEmpty);

      await etoile(tester, 2, 'le restaurant');
      await envoyer(tester);
      expect(mida.avis.single['restaurant'], 2);
      expect(mida.avis.single['livreur'], isNull);
    });

    testWidgets('refus du serveur (déjà noté) : le message est affiché', (tester) async {
      final mida = FauxServiceMida()
        ..suivies['cmd1'] = livree
        ..erreurAvis = const PostgrestException(
          message: 'Vous avez déjà donné votre avis sur cette commande.',
          code: 'P0001',
        );
      await ouvrirPage(tester, NoterPage(commande: livree), mida: mida);
      await etoile(tester, 5, 'le restaurant');
      await envoyer(tester);
      expect(find.text('Vous avez déjà donné votre avis sur cette commande.'), findsOneWidget);
      expect(find.byType(NoterPage), findsOneWidget);
    });

    testWidgets('pas d\'invitation à noter avant la livraison, ni sans livreur pour la note du livreur', (
      tester,
    ) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = avecEtat(commandeTest, EtatCommande.enLivraison);
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);
      expect(find.text('Noter la commande'), findsNothing);

      final sansLivreur = avecEtat(commandeTest, EtatCommande.livree);
      await ouvrirPage(tester, NoterPage(commande: sansLivreur), mida: mida);
      expect(find.byTooltip('1 étoile sur 5 pour le restaurant'), findsOneWidget);
      expect(find.byTooltip('1 étoile sur 5 pour le livreur'), findsNothing);
    });

    testWidgets('historique : pastille « À noter » sur les commandes livrées sans avis', (tester) async {
      final mida = FauxServiceMida()
        ..suivies['cmd1'] = livree
        ..suivies['cmd2'] = avecEtat(
          CommandeClient(
            id: 'cmd2',
            numero: 1048,
            etat: EtatCommande.livree,
            restaurantNom: 'El Kanoun',
            adresse: 'Tunis',
            sousTotal: 10,
            fraisLivraison: 2.5,
            total: 12.5,
            creeeLe: DateTime(2026, 11, 17, 12),
          ),
          EtatCommande.livree,
          noteRestaurant: 5,
        );
      final auth = FauxServiceAuth(connecte: true);
      await ouvrirPage(tester, const HistoriquePage(), mida: mida, auth: auth);
      expect(find.text('À noter ★'), findsOneWidget);
    });
  });
}
