import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/auth/erreurs.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/panier_page.dart';
import 'package:mida_client/panier/panier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';
import 'outils.dart';

final zitouna = catalogueTest.firstWhere((r) => r.id == 'r1');
final agneau = menuTest.plats.firstWhere((p) => p.id == 'p1');
final the = menuTest.plats.firstWhere((p) => p.id == 'p4');

Panier panierRempli() => Panier()
  ..ajouter(zitouna, agneau)
  ..ajouter(zitouna, the)
  ..ajouter(zitouna, the);

Future<void> saisirAdresse(WidgetTester tester, String adresse) async {
  final champ = find.widgetWithText(TextFormField, 'Adresse de livraison');
  await defilerJusqua(tester, champ);
  await tester.enterText(champ, adresse);
  await tester.pump();
}

Future<void> commander(WidgetTester tester) async {
  final bouton = find.textContaining('Commander');
  await defilerJusqua(tester, bouton);
  await tester.tap(bouton);
  await tester.pumpAndSettle();
}

void main() {
  group('valider la commande (US19)', () {
    test('lecture de la réponse du serveur', () {
      final c = CommandePassee.depuis(
          {'id': 'x', 'numero': 1047, 'sous_total': 23, 'frais_livraison': '2.500', 'total': 25.5});
      expect((c.numero, c.fraisLivraison, c.total), (1047, 2.5, 25.5));
    });

    test('les refus du serveur sont affichés tels quels', () {
      expect(
        messageErreur(const PostgrestException(message: 'Ce restaurant est fermé', code: 'P0001')),
        'Ce restaurant est fermé',
      );
      expect(
        messageErreur(const PostgrestException(message: 'Seul un compte client peut passer commande', code: '42501')),
        'Seul un compte client peut passer commande',
      );
      expect(
        messageErreur(const PostgrestException(message: 'permission denied for function x', code: '42501')),
        'Ce compte n\'a pas le droit de faire cette action.',
      );
    });

    testWidgets('récapitulatif : sous-total, frais de livraison, total ; paiement en espèces', (tester) async {
      await ouvrirPage(tester, const PanierPage(), panier: panierRempli(), auth: FauxServiceAuth(connecte: true));
      await defilerJusqua(tester, find.text('Total'));
      expect(find.text('23,000 DT'), findsWidgets); // sous-total
      expect(find.text('2,500 DT'), findsWidgets); // frais
      expect(find.text('25,500 DT'), findsOneWidget); // total
      expect(find.bySemanticsLabel('Espèces, À payer au livreur, à la livraison'), findsOneWidget);
      // paiement par carte abandonné (US30-US31 annulées) : espèces seulement
      expect(find.textContaining('Carte'), findsNothing);
    });

    testWidgets('adresse obligatoire, puis commande envoyée : panier vidé', (tester) async {
      final mida = FauxServiceMida();
      final panier = panierRempli();
      CommandePassee? envoyee;
      await ouvrirPage(
        tester,
        PanierPage(apresCommande: (_, c) => envoyee = c),
        mida: mida,
        panier: panier,
        auth: FauxServiceAuth(connecte: true),
      );

      await commander(tester);
      expect(find.text('Indiquez l\'adresse de livraison.'), findsOneWidget);
      expect(mida.commandes, isEmpty);

      await saisirAdresse(tester, '  12, rue du Jasmin, La Marsa ');
      final remarque = find.widgetWithText(TextFormField, 'Remarque pour le restaurant (facultatif)');
      await defilerJusqua(tester, remarque);
      await tester.enterText(remarque, 'Sonner deux fois');
      await commander(tester);

      expect(mida.commandes.single, {
        'restaurant': 'r1',
        'lignes': ['1 × Couscous à l’agneau', '2 × Thé à la menthe'],
        'adresse': '12, rue du Jasmin, La Marsa',
        'remarque': 'Sonner deux fois',
      });
      expect(envoyee?.numero, 1047);
      expect(panier.estVide, isTrue);
    });

    testWidgets('refus du serveur (restaurant fermé entre-temps) : message, panier gardé', (tester) async {
      final mida = FauxServiceMida()
        ..erreurCommande = const PostgrestException(
          message: 'Ce restaurant est fermé : il n\'accepte pas de commande pour le moment',
          code: 'P0001',
        );
      final panier = panierRempli();
      await ouvrirPage(tester, const PanierPage(), mida: mida, panier: panier, auth: FauxServiceAuth(connecte: true));
      await saisirAdresse(tester, '12, rue du Jasmin');
      await commander(tester);

      expect(find.text('Ce restaurant est fermé : il n\'accepte pas de commande pour le moment'), findsOneWidget);
      expect(panier.nbArticles, 3);
    });

    testWidgets('visiteur : connexion demandée, panier gardé, puis retour au panier pour commander', (tester) async {
      final auth = FauxServiceAuth();
      final mida = FauxServiceMida();
      final panier = panierRempli();
      await ouvrirPage(tester, const PanierPage(apresCommande: _rien), mida: mida, panier: panier, auth: auth);
      await saisirAdresse(tester, '4, rue des Orangers, Ariana');
      await commander(tester);

      expect(find.text('Connectez-vous pour commander'), findsOneWidget);
      expect(find.text('Dar Zitouna · 3 articles'), findsOneWidget);
      expect(find.text('Panier conservé'), findsOneWidget);
      expect(mida.commandes, isEmpty);

      await tester.tap(find.text('J\'ai déjà un compte'));
      await tester.pumpAndSettle();
      final champs = find.byType(TextFormField);
      await tester.enterText(champs.at(0), 'amine@mida.test');
      await tester.enterText(champs.at(1), 'Mida2026!');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      // de retour sur le panier, connecté, avec l'adresse déjà saisie
      expect(auth.connecte, isTrue);
      expect(find.text('Votre panier'), findsOneWidget);
      expect(find.text('4, rue des Orangers, Ariana'), findsOneWidget);
      expect(panier.nbArticles, 3);

      await commander(tester);
      expect(mida.commandes.single['adresse'], '4, rue des Orangers, Ariana');
    });

    testWidgets('visiteur qui renonce : « Continuer à explorer », rien n\'est envoyé', (tester) async {
      final mida = FauxServiceMida();
      await ouvrirPage(tester, const PanierPage(), mida: mida, panier: panierRempli());
      await saisirAdresse(tester, '4, rue des Orangers');
      await commander(tester);
      await tester.ensureVisible(find.text('Continuer à explorer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer à explorer'));
      await tester.pumpAndSettle();
      expect(find.text('Votre panier'), findsOneWidget);
      expect(mida.commandes, isEmpty);
    });
  });
}

void _rien(BuildContext context, CommandePassee commande) {}
