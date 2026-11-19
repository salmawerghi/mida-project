import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/donnees/modeles.dart';
import 'package:mida_client/pages/adresses_page.dart';
import 'package:mida_client/pages/panier_page.dart';
import 'package:mida_client/pages/signaler_page.dart';
import 'package:mida_client/pages/suivi_page.dart';
import 'package:mida_client/panier/panier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';
import 'outils.dart';

const maison = AdresseClient(id: 'a1', libelle: 'Maison', rue: '12, rue du Jasmin', ville: 'La Marsa', parDefaut: true);
const travail = AdresseClient(
  id: 'a2',
  libelle: 'Travail',
  rue: 'Immeuble Lac Palace',
  complement: '3e étage',
  ville: 'Les Berges du Lac',
);

Future<void> toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

void main() {
  group('adresses de livraison (US47)', () {
    test('texte de l\'adresse et ordre : la principale d\'abord', () {
      expect(maison.texte, '12, rue du Jasmin, La Marsa');
      expect(travail.texte, 'Immeuble Lac Palace, 3e étage, Les Berges du Lac');
      expect(trierAdresses([travail, maison]).map((a) => a.id), ['a1', 'a2']);
      final lue = AdresseClient.depuis({
        'id': 'x',
        'libelle': 'Famille',
        'rue': '3, rue de Marseille',
        'ville': 'Sousse',
        'complement': null,
        'par_defaut': false,
      });
      expect((lue.texte, lue.parDefaut), ('3, rue de Marseille, Sousse', false));
    });

    testWidgets('ajouter une adresse principale, en choisir une autre, en supprimer une', (tester) async {
      final mida = FauxServiceMida()..adresses = [maison];
      await ouvrirPage(tester, const AdressesPage(), mida: mida);
      expect(find.text('Principale'), findsOneWidget);

      await toucher(tester, find.text('Ajouter une adresse'));
      expect(find.byType(NouvelleAdressePage), findsOneWidget);
      await toucher(tester, find.text('Enregistrer l\'adresse'));
      expect(find.text('Indiquez la rue et le numéro.'), findsOneWidget);
      expect(find.text('Indiquez la ville.'), findsOneWidget);

      await toucher(tester, find.widgetWithText(ChoiceChip, 'Travail'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Rue et numéro'), 'Immeuble Lac Palace');
      await tester.enterText(find.widgetWithText(TextFormField, 'Complément (facultatif)'), '3e étage');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ville'), 'Les Berges du Lac');
      await toucher(tester, find.text('Adresse principale'));
      await toucher(tester, find.text('Enregistrer l\'adresse'));

      // retour à la liste : « Travail » est la nouvelle principale, en tête
      expect(find.byType(AdressesPage), findsOneWidget);
      expect(mida.adresses.where((a) => a.parDefaut).single.libelle, 'Travail');
      expect(find.text('Immeuble Lac Palace, 3e étage, Les Berges du Lac'), findsOneWidget);

      await toucher(tester, find.text('Choisir « Maison » comme principale'));
      expect(mida.adresses.where((a) => a.parDefaut).single.libelle, 'Maison');
      expect(find.text('« Maison » est votre adresse principale.'), findsOneWidget);

      await toucher(tester, find.text('Supprimer « Travail »'));
      await toucher(tester, find.widgetWithText(TextButton, 'Supprimer'));
      expect(mida.adresses.map((a) => a.libelle), ['Maison']);
    });

    testWidgets('première adresse : elle devient la principale', (tester) async {
      final mida = FauxServiceMida();
      await ouvrirPage(tester, const AdressesPage(), mida: mida);
      expect(find.text('Aucune adresse enregistrée pour le moment.'), findsOneWidget);
      await toucher(tester, find.text('Ajouter une adresse'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Rue et numéro'), '12, rue du Jasmin');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ville'), 'La Marsa');
      await toucher(tester, find.text('Enregistrer l\'adresse'));
      expect(mida.adresses.single.parDefaut, isTrue);
    });

    testWidgets('panier : l\'adresse principale est proposée, une autre se choisit en un toucher', (tester) async {
      final mida = FauxServiceMida()..adresses = [maison, travail];
      final panier = Panier()..ajouter(catalogueTest.firstWhere((r) => r.id == 'r1'), menuTest.plats.first);
      await ouvrirPage(tester, const PanierPage(), mida: mida, panier: panier, auth: FauxServiceAuth(connecte: true));

      final champ = find.widgetWithText(TextFormField, 'Adresse de livraison');
      await tester.ensureVisible(champ);
      expect(tester.widget<TextFormField>(champ).controller!.text, '12, rue du Jasmin, La Marsa');
      await toucher(tester, find.widgetWithText(ChoiceChip, 'Travail'));
      expect(tester.widget<TextFormField>(champ).controller!.text, 'Immeuble Lac Palace, 3e étage, Les Berges du Lac');
      expect(panier.adresse, 'Immeuble Lac Palace, 3e étage, Les Berges du Lac');
    });

    testWidgets('panier d\'un visiteur : pas d\'adresses proposées', (tester) async {
      final mida = FauxServiceMida()..adresses = [maison];
      final panier = Panier()..ajouter(catalogueTest.firstWhere((r) => r.id == 'r1'), menuTest.plats.first);
      await ouvrirPage(tester, const PanierPage(), mida: mida, panier: panier);
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('signaler un problème (US49)', () {
    final livree = avecEtat(
      commandeTest,
      EtatCommande.livree,
      accepteeLe: DateTime.now().subtract(const Duration(hours: 2)),
      livreeLe: DateTime.now().subtract(const Duration(hours: 1)),
    );

    test('possible dans les 7 jours après la livraison, sans réclamation en cours', () {
      final maintenant = DateTime(2026, 11, 19, 21);
      CommandeClient livreeIlYa(Duration d, {ReclamationClient? r}) =>
          avecEtat(commandeTest, EtatCommande.livree, livreeLe: maintenant.subtract(d), reclamation: r);
      expect(livreeIlYa(const Duration(days: 2)).peutSignaler(maintenant), isTrue);
      expect(livreeIlYa(const Duration(days: 8)).peutSignaler(maintenant), isFalse);
      expect(avecEtat(commandeTest, EtatCommande.enLivraison).peutSignaler(maintenant), isFalse);
      final ouverte = ReclamationClient(motif: 'Plat manquant', etat: 'ouverte', creeeLe: maintenant);
      final rejetee = ReclamationClient(motif: 'Plat manquant', etat: 'rejetee', creeeLe: maintenant);
      expect(livreeIlYa(const Duration(days: 1), r: ouverte).peutSignaler(maintenant), isFalse);
      expect(livreeIlYa(const Duration(days: 1), r: rejetee).peutSignaler(maintenant), isTrue);
    });

    test('lecture de la dernière réclamation renvoyée par Supabase', () {
      final r = ReclamationClient.derniere([
        {
          'motif': 'Retard important',
          'etat': 'rejetee',
          'reponse': 'Non',
          'montant_rembourse': null,
          'created_at': '2026-11-18T10:00:00Z',
        },
        {
          'motif': 'Plat manquant',
          'etat': 'resolue',
          'reponse': 'Désolés',
          'montant_rembourse': '2.500',
          'created_at': '2026-11-19T10:00:00Z',
        },
      ])!;
      expect((r.motif, r.etat, r.montantRembourse, r.enCours), ('Plat manquant', 'resolue', 2.5, false));
      expect(ReclamationClient.derniere(const []), isNull);
    });

    testWidgets('le client signale un problème depuis le suivi d\'une commande livrée', (tester) async {
      final mida = FauxServiceMida()..suivies['cmd1'] = livree;
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);
      await toucher(tester, find.text('Signaler un problème'));
      expect(find.byType(SignalerPage), findsOneWidget);

      await toucher(tester, find.text('Envoyer à Mida'));
      expect(find.text('Choisissez le problème rencontré.'), findsOneWidget);
      await toucher(tester, find.text('Autre problème'));
      await toucher(tester, find.text('Envoyer à Mida'));
      expect(find.text('Décrivez le problème en quelques mots.'), findsOneWidget);

      await toucher(tester, find.text('Plat manquant'));
      await tester.enterText(find.widgetWithText(TextField, 'Détails'), 'Il manquait le thé.');
      await toucher(tester, find.text('Envoyer à Mida'));

      expect(mida.reclamations, [
        {'commande': 'cmd1', 'motif': 'Plat manquant', 'description': 'Il manquait le thé.'},
      ]);
      expect(find.byType(SuiviPage), findsOneWidget);
      expect(find.text('Problème signalé : Mida vous répondra par une notification.'), findsOneWidget);
      await tester.ensureVisible(find.text('Réclamation envoyée : Mida l\'étudie'));
      expect(find.text('Signaler un problème'), findsNothing);
    });

    testWidgets('refus du serveur : le message est affiché', (tester) async {
      final mida = FauxServiceMida()
        ..suivies['cmd1'] = livree
        ..erreurReclamation = const PostgrestException(
          message: 'Une réclamation est déjà en cours pour cette commande.',
          code: 'P0001',
        );
      await ouvrirPage(tester, SignalerPage(commande: livree), mida: mida);
      await toucher(tester, find.text('Plat froid ou abîmé'));
      await toucher(tester, find.text('Envoyer à Mida'));
      expect(find.text('Une réclamation est déjà en cours pour cette commande.'), findsOneWidget);
    });

    testWidgets('réponse de Mida et remboursement affichés sur le suivi', (tester) async {
      final mida = FauxServiceMida()
        ..suivies['cmd1'] = avecEtat(
          commandeTest,
          EtatCommande.livree,
          livreeLe: DateTime.now().subtract(const Duration(days: 1)),
          reclamation: ReclamationClient(
            motif: 'Plat manquant',
            etat: 'resolue',
            reponse: 'Désolés pour le thé manquant.',
            montantRembourse: 2.5,
            creeeLe: DateTime.now(),
          ),
        );
      await ouvrirPage(tester, const SuiviPage(commandeId: 'cmd1'), mida: mida);
      await tester.ensureVisible(find.text('Réclamation résolue'));
      expect(find.text('Réponse de Mida : Désolés pour le thé manquant.'), findsOneWidget);
      expect(find.text('Remboursement : 2,500 DT'), findsOneWidget);
    });
  });
}
