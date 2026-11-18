import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_livreur/auth/erreurs.dart';
import 'package:mida_livreur/auth/service_auth.dart';
import 'package:mida_livreur/donnees/modeles.dart';
import 'package:mida_livreur/pages/attente_page.dart';
import 'package:mida_livreur/pages/connexion_page.dart';
import 'package:mida_livreur/pages/course_page.dart';
import 'package:mida_livreur/pages/courses_page.dart';
import 'package:mida_livreur/pages/documents_page.dart';
import 'package:mida_livreur/pages/espace_livreur.dart';
import 'package:mida_livreur/pages/inscription_page.dart';

import 'faux_services.dart';

Finder champ(String etiquette) => find.descendant(
      of: find.ancestor(of: find.text(etiquette), matching: find.byType(Column)).first,
      matching: find.byType(TextFormField),
    );

/// Laisse passer la relecture différée (300 ms) qui suit un événement temps réel.
Future<void> recevoir(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('modèles', () {
    test('documents demandés selon le véhicule', () {
      expect(documentsRequis(TypeVehicule.moto), [TypeDocument.cin, TypeDocument.permis, TypeDocument.carteGrise]);
      expect(documentsRequis(TypeVehicule.velo), [TypeDocument.cin]);
      expect(photo('permis.jpg').taille, '880 Ko');
      expect(photo('scan.PNG').typeMime, 'image/png');
      expect(photo('cin.heic').extension, 'jpg');
    });

    test('lecture d\'une course renvoyée par Supabase', () {
      final c = Course.depuis({
        'id': 'x',
        'etat': 'proposee',
        'gain_livreur': '2.000',
        'livree_le': null,
        'commandes': {
          'numero': 1005,
          'etat': 'prete',
          'adresse_livraison': 'Tozeur rue de Safir school',
          'total': '56.500',
          'remarque': null,
          'restaurants': {'nom': 'hot food', 'adresse': '8, rue des Jasmins', 'ville': 'Ariana', 'telephone': null},
          'lignes_commande': [
            {'nom_plat': 'cosksi', 'quantite': 2},
            {'nom_plat': 'brik', 'quantite': 1},
          ],
          'paiements': [
            {'mode': 'especes', 'etat': 'en_attente'},
          ],
          'profiles': null,
        },
      });
      expect((c.numero, c.restaurantAdresse, c.nbArticles, c.gain, c.commandePrete, c.clientNom),
          (1005, '8, rue des Jasmins, Ariana', 3, 2.0, true, null));
      expect(c.mentionPaiement, 'À encaisser · 56,500 DT');
      expect(courseCarte.mentionPaiement, 'Payée en ligne');
    });

    test('seuls les comptes livreur non bloqués entrent', () {
      expect(refusCompte('livreur', 'en_attente'), isNull);
      expect(refusCompte('livreur', 'actif'), isNull);
      expect(refusCompte('client', 'actif'), 'Ce compte n\'est pas un compte livreur. Utilisez l\'application Mida.');
      expect(refusCompte('livreur', 'bloque'), contains('suspendu'));
    });
  });

  group('candidature du livreur (US25)', () {
    testWidgets('étape 1 : le compte, puis retour à l\'écran racine', (tester) async {
      final auth = FauxServiceAuth();
      await ouvrirPage(tester, ConnexionPage(auth: auth), auth: auth);
      await tester.tap(find.text('Déposer ma candidature'));
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 sur 2'), findsOneWidget);

      await tester.enterText(champ('Nom et prénom'), 'Nour Jebali');
      await tester.enterText(champ('E-mail'), 'nour@mida.test');
      await tester.enterText(champ('Téléphone'), '50111222');
      await tester.enterText(champ('Mot de passe'), 'Livreur2026!');
      await defilerJusqua(tester, find.text('Continuer'));
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(auth.appels, ['inscrire:Nour Jebali:nour@mida.test:+216 50 111 222']);
      expect(find.byType(InscriptionPage), findsNothing);
    });

    testWidgets('candidature incomplète → étape 2 ; envoyée → en attente de validation', (tester) async {
      final livreur = FauxServiceLivreur(etat: const EtatLivreur(nom: 'Nour Jebali', etatCompte: 'en_attente'));
      final photos = ['cin.jpg', 'permis.jpg', 'carte_grise.jpg'].iterator;
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur, choisirDocument: () async {
        photos.moveNext();
        return photo(photos.current);
      });
      expect(find.byType(DocumentsPage), findsOneWidget);
      expect(find.text('Étape 2 sur 2'), findsOneWidget);

      // rien choisi : véhicule et documents demandés
      await defilerJusqua(tester, find.text('Envoyer ma candidature'));
      await tester.tap(find.text('Envoyer ma candidature'));
      await tester.pumpAndSettle();
      expect(livreur.appels, isEmpty);
      expect(find.text('Document obligatoire'), findsNWidgets(3));
      await tester.scrollUntilVisible(find.text('Choisissez votre type de véhicule.'), -200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Choisissez votre type de véhicule.'), findsOneWidget);

      await tester.tap(find.text('Scooter / moto'));
      await tester.pumpAndSettle();
      await tester.enterText(champ('Immatriculation'), '215 tu 4821');
      for (final doc in ['Carte d\'identité nationale', 'Permis de conduire', 'Carte grise du véhicule']) {
        await defilerJusqua(tester, find.bySemanticsLabel('Ajouter : $doc'));
        await tester.tap(find.bySemanticsLabel('Ajouter : $doc'));
        await tester.pumpAndSettle();
      }
      expect(find.text('permis.jpg · 880 Ko'), findsOneWidget);

      await defilerJusqua(tester, find.text('Envoyer ma candidature'));
      await tester.tap(find.text('Envoyer ma candidature'));
      await tester.pumpAndSettle();
      expect(livreur.appels, ['candidature:moto:215 TU 4821:cin,permis,carte_grise']);
      expect(find.byType(AttentePage), findsOneWidget);
      expect(find.text('En attente de validation'), findsOneWidget);
      expect(find.textContaining('Merci Nour'), findsOneWidget);
    });

    testWidgets('à vélo : seule la carte d\'identité est demandée', (tester) async {
      final livreur = FauxServiceLivreur(etat: const EtatLivreur(nom: 'Nour Jebali', etatCompte: 'en_attente'));
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur, choisirDocument: () async => photo('cin.png'));
      await tester.tap(find.text('Vélo'));
      await tester.pumpAndSettle();
      expect(find.text('Immatriculation'), findsNothing);
      expect(find.text('Permis de conduire'), findsNothing);

      await defilerJusqua(tester, find.text('Envoyer ma candidature'));
      await tester.tap(find.text('Envoyer ma candidature'));
      await tester.pumpAndSettle();
      expect(find.text('Document obligatoire'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Ajouter : Carte d\'identité nationale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Envoyer ma candidature'));
      await tester.pumpAndSettle();
      expect(livreur.appels.single, startsWith('candidature:velo:'));
      expect(livreur.appels.single, endsWith(':cin'));
    });

    testWidgets('candidature refusée : message, pas de courses', (tester) async {
      final livreur = FauxServiceLivreur(etat: const EtatLivreur(nom: 'Nour Jebali', etatCompte: 'rejete',
          typeVehicule: TypeVehicule.velo, documents: {'cin': 'refuse'}));
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur);
      expect(find.text('Candidature non retenue'), findsOneWidget);
      expect(find.text('Refusé'), findsOneWidget);
      expect(find.byType(CoursesPage), findsNothing);
    });
  });

  group('disponibilité (US26) et courses proposées (US27)', () {
    testWidgets('chaque course affiche le restaurant, l\'adresse du client, le gain et le paiement', (tester) async {
      await ouvrirPage(tester, const EspaceLivreur());
      expect(find.byType(CoursesPage), findsOneWidget);
      expect(find.text('Aslema, Sami'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Dar Zitouna'), findsOneWidget);
      expect(find.text('4, rue des Orangers, Ariana'), findsOneWidget);
      expect(find.text('+ 2,000 DT'), findsNWidgets(2));
      expect(find.text('Payée en ligne'), findsOneWidget);
      expect(find.text('À encaisser · 25,500 DT'), findsOneWidget);
    });

    testWidgets('indisponible : aucune proposition, et l\'état est enregistré', (tester) async {
      final livreur = FauxServiceLivreur();
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(livreur.appels, ['disponible:false']);
      expect(livreur.etat.disponible, isFalse);
      expect(find.text('Indisponible'), findsOneWidget);
      expect(find.text('Dar Zitouna'), findsNothing);
      expect(find.text('Passez « Disponible » pour recevoir des courses.'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Dar Zitouna'), findsOneWidget);
    });

    testWidgets('refus du serveur : l\'interrupteur revient en arrière', (tester) async {
      final livreur = FauxServiceLivreur()..erreur = const ErreurMida('Votre compte doit être validé par Mida');
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Votre compte doit être validé par Mida'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
    });

    testWidgets('accepter une course ouvre la course ; au retour, plus de propositions', (tester) async {
      final livreur = FauxServiceLivreur();
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur);

      await tester.tap(find.text('Accepter la course').first);
      await tester.pumpAndSettle();
      expect(livreur.appels, ['accepter:l1']);
      expect(find.byType(CoursePage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Course en cours'), findsOneWidget);
      expect(find.text('À récupérer chez Dar Zitouna'), findsOneWidget);
      expect(find.text('Accepter la course'), findsNothing);
    });

    testWidgets('course déjà prise par un autre livreur : message et liste relue', (tester) async {
      final livreur = FauxServiceLivreur()..erreur = refusServeur;
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur);
      livreur.courses.remove('l1'); // elle a disparu pour ce livreur
      await tester.tap(find.text('Accepter la course').first);
      await tester.pumpAndSettle();
      expect(find.text('Cette course a déjà été acceptée par un autre livreur'), findsOneWidget);
      expect(find.text('Dar Zitouna'), findsNothing);
      expect(find.byType(CoursePage), findsNothing);
    });

    testWidgets('une nouvelle course apparaît en temps réel', (tester) async {
      final livreur = FauxServiceLivreur(proposees: []);
      await ouvrirPage(tester, const EspaceLivreur(), livreur: livreur);
      expect(find.textContaining('Aucune course pour le moment'), findsOneWidget);
      livreur.simulerChangement(courseEspeces);
      await recevoir(tester);
      expect(find.text('El Kanoun'), findsOneWidget);
    });
  });

  group('récupération puis remise (US28)', () {
    testWidgets('récupération possible seulement quand la commande est prête', (tester) async {
      final livreur = FauxServiceLivreur()..courses['l1'] = copie(courseCarte, etat: EtatCourse.acceptee);
      await ouvrirPage(tester, const CoursePage(courseId: 'l1'), livreur: livreur);

      expect(find.text('En préparation au restaurant'), findsOneWidget);
      await appuyer(tester, find.text('J\'ai récupéré la commande'));
      expect(livreur.appels, isEmpty);

      // le restaurant marque la commande « prête »
      livreur.simulerChangement(copie(courseCarte, etat: EtatCourse.acceptee, etatCommande: 'prete'));
      await recevoir(tester);
      expect(find.text('Prête : vous pouvez la récupérer'), findsOneWidget);
      await appuyer(tester, find.text('J\'ai récupéré la commande'));
      expect(livreur.appels, ['recuperer:l1']);
      expect(find.bySemanticsLabel('Livrer au client, étape actuelle'), findsOneWidget);
      expect(find.text('Payée en ligne : rien à encaisser.'), findsOneWidget);

      await appuyer(tester, find.text('Confirmer la livraison'));
      expect(livreur.appels.last, 'livrer:l1');
      expect(find.byType(LivreePage), findsOneWidget);
      expect(find.text('Livraison confirmée'), findsOneWidget);
    });

    testWidgets('espèces : confirmer l\'encaissement avant la remise', (tester) async {
      final livreur = FauxServiceLivreur()..courses['l2'] = copie(courseEspeces, etat: EtatCourse.recuperee);
      await ouvrirPage(tester, const CoursePage(courseId: 'l2'), livreur: livreur);

      expect(find.text('Client : Youssef Trabelsi'), findsOneWidget);
      expect(find.text('À encaisser en espèces'), findsOneWidget);
      await defilerJusqua(tester, find.text('Confirmer la livraison'));
      await appuyer(tester, find.text('Confirmer la livraison'));
      expect(livreur.appels, isEmpty);

      await appuyer(tester, find.text('J\'ai bien reçu 25,500 DT du client'));
      await appuyer(tester, find.text('Confirmer la livraison'));
      expect(livreur.appels, ['livrer:l2']);
      expect(find.text('Espèces encaissées'), findsOneWidget);
      expect(find.text('Commande n° 1045 remise à Youssef Trabelsi', findRichText: false), findsNothing);
      expect(find.textContaining('Commande n° 1045 remise à Youssef Trabelsi à '), findsOneWidget);
    });

    testWidgets('refus du serveur affiché sur la course', (tester) async {
      final livreur = FauxServiceLivreur()
        ..courses['l2'] = copie(courseEspeces, etat: EtatCourse.acceptee)
        ..erreur = const ErreurMida('La commande n° 1045 n\'est pas encore prête');
      await ouvrirPage(tester, const CoursePage(courseId: 'l2'), livreur: livreur);
      await appuyer(tester, find.text('J\'ai récupéré la commande'));
      expect(find.text('La commande n° 1045 n\'est pas encore prête'), findsOneWidget);
    });

    testWidgets('quitter la course arrête l\'écoute en temps réel', (tester) async {
      final livreur = FauxServiceLivreur()..courses['l1'] = copie(courseCarte, etat: EtatCourse.acceptee);
      await ouvrirPage(tester, const CoursePage(courseId: 'l1'), livreur: livreur);
      expect(livreur.nbAbonnes, 1);
      await tester.pumpWidget(const SizedBox());
      expect(livreur.nbAbonnes, 0);
    });
  });
}
