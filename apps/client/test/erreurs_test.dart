import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/auth/erreurs.dart';
import 'package:mida_client/auth/service_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Jeton JWT factice (signature non vérifiée côté appli).
String jeton(Map<String, Object?> contenu) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(contenu)}.signature';
}

void main() {
  group('messageErreur', () {
    test('identifiants incorrects (code ou message)', () {
      expect(messageErreur(const AuthApiException('x', code: 'invalid_credentials')), messageIdentifiantsIncorrects);
      expect(messageErreur(const AuthException('Invalid login credentials')), messageIdentifiantsIncorrects);
    });
    test('hors ligne', () {
      expect(messageErreur(const SocketException('down')), messageHorsLigne);
      expect(messageErreur(AuthRetryableFetchException()), messageHorsLigne);
    });
    test('codes Supabase Auth traduits', () {
      expect(messageErreur(const AuthApiException('x', code: 'email_not_confirmed')), contains('pas encore confirmée'));
      expect(messageErreur(const AuthApiException('User already registered')), contains('existe déjà'));
      expect(messageErreur(const AuthApiException('x', code: 'email_exists')), contains('existe déjà'));
      expect(messageErreur(const AuthApiException('x', code: 'weak_password')), contains('trop faible'));
      expect(messageErreur(const AuthApiException('x', code: 'email_address_invalid')), contains('pas acceptée'));
      expect(messageErreur(const AuthApiException('x', code: 'over_email_send_rate_limit')), contains('Trop de tentatives'));
      expect(messageErreur(const AuthApiException('x', statusCode: '429')), contains('Trop de tentatives'));
      expect(messageErreur(const AuthApiException('x', code: 'signup_disabled')), contains('fermées'));
    });
    test('ErreurMida affichée telle quelle, le reste en message générique', () {
      expect(messageErreur(const ErreurMida('Bonjour')), 'Bonjour');
      expect(messageErreur(StateError('?')), 'Une erreur est survenue. Réessayez dans un instant.');
    });
  });

  group('rolesDuJeton', () {
    test('lit user_role et etat_compte ajoutés par le hook', () {
      expect(rolesDuJeton(jeton({'sub': '1', 'user_role': 'client', 'etat_compte': 'actif'})), ('client', 'actif'));
    });
    test('hook inactif ou jeton invalide : (null, null)', () {
      expect(rolesDuJeton(jeton({'sub': '1'})), (null, null));
      expect(rolesDuJeton('pas-un-jeton'), (null, null));
      expect(rolesDuJeton('a.%%%.c'), (null, null));
    });
  });

  group('refusCompte', () {
    test('client actif (ou rôle inconnu) accepté', () {
      expect(refusCompte('client', 'actif'), isNull);
      expect(refusCompte(null, null), isNull);
    });
    test('autres rôles renvoyés vers leur application', () {
      expect(refusCompte('livreur', 'actif'), contains('Mida Livreur'));
      expect(refusCompte('responsable', 'actif'), contains('espace restaurant'));
      expect(refusCompte('admin', 'actif'), contains('administration'));
    });
    test('compte bloqué refusé', () {
      expect(refusCompte('client', 'bloque'), contains('suspendu'));
    });
  });
}
