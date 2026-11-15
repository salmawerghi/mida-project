import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/auth/validation.dart';

void main() {
  group('validerNom', () {
    test('refuse un nom vide ou trop court', () {
      expect(validerNom(null), isNotNull);
      expect(validerNom('   '), 'Indiquez votre nom et prénom.');
      expect(validerNom('Al'), 'Le nom est trop court.');
    });
    test('accepte un nom complet (espaces ignorés)', () {
      expect(validerNom('  Salma Ouerghi '), isNull);
    });
  });

  group('validerEmail', () {
    test('refuse les adresses mal formées', () {
      expect(validerEmail(''), 'Indiquez votre adresse e-mail.');
      for (final e in ['salma', 'salma@', 'salma@mida', 'sal ma@mida.tn', '@mida.tn', 'a@b.c']) {
        expect(validerEmail(e), 'Cette adresse e-mail n\'est pas valide.', reason: e);
      }
    });
    test('accepte une adresse correcte', () {
      expect(validerEmail(' salma.o@mida.tn '), isNull);
      expect(validerEmail('client1@mida.test'), isNull);
    });
  });

  group('téléphone', () {
    test('exige 8 chiffres (espaces, points et tirets acceptés)', () {
      expect(validerTelephone(''), 'Indiquez votre numéro de téléphone.');
      expect(validerTelephone('22 145 87'), 'Le numéro doit comporter 8 chiffres.');
      expect(validerTelephone('22 145 8700'), 'Le numéro doit comporter 8 chiffres.');
      expect(validerTelephone('22a45870'), 'Le numéro doit comporter 8 chiffres.');
      expect(validerTelephone('22 145 870'), isNull);
      expect(validerTelephone('22.145-870'), isNull);
    });
    test('formate au format enregistré dans le profil', () {
      expect(formaterTelephone('22145870'), '+216 22 145 870');
      expect(formaterTelephone('22 145 870'), '+216 22 145 870');
    });
  });

  group('mots de passe', () {
    test('inscription : 8 caractères minimum', () {
      expect(validerMotDePasseInscription(''), 'Choisissez un mot de passe.');
      expect(validerMotDePasseInscription('Abc123!'), '8 caractères minimum.');
      expect(validerMotDePasseInscription('Mida2026'), isNull);
    });
    test('connexion : seulement non vide', () {
      expect(validerMotDePasseConnexion(null), 'Indiquez votre mot de passe.');
      expect(validerMotDePasseConnexion('x'), isNull);
    });
    test('solidité de 0 à 4', () {
      expect(soliditeMotDePasse(''), 0);
      expect(soliditeMotDePasse('Ab1!'), 1); // trop court : plafonné à 1
      expect(soliditeMotDePasse('abcdefgh'), 1);
      expect(soliditeMotDePasse('abcdefg1'), 2);
      expect(soliditeMotDePasse('Abcdefg1'), 3);
      expect(soliditeMotDePasse('Mida2026!'), 4);
      expect(soliditeMotDePasse('abcdefghijk1'), 3); // 12 caractères comptent comme « spécial »
    });
    test('libellés de la jauge', () {
      expect(libelleSolidite(0), startsWith('Mot de passe faible'));
      expect(libelleSolidite(2), startsWith('Mot de passe moyen'));
      expect(libelleSolidite(3), startsWith('Mot de passe solide'));
      expect(libelleSolidite(4), 'Mot de passe très solide');
    });
  });

  group('réinitialisation (US06)', () {
    test('code : 6 chiffres attendus', () {
      expect(validerCode(''), 'Indiquez le code reçu par e-mail.');
      expect(validerCode('12345'), 'Le code comporte 6 chiffres.');
      expect(validerCode('12a456'), 'Le code comporte 6 chiffres.');
      expect(validerCode('123456'), isNull);
      expect(validerCode('123 456'), isNull);
      expect(validerCode('12345678'), isNull); // projet réglé sur 8 chiffres
    });
    test('confirmation identique au mot de passe', () {
      expect(validerConfirmation('', 'Mida2026!'), 'Confirmez le nouveau mot de passe.');
      expect(validerConfirmation('Mida2025!', 'Mida2026!'), contains('pas identiques'));
      expect(validerConfirmation('Mida2026!', 'Mida2026!'), isNull);
    });
  });
}
