import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Erreur métier affichée telle quelle à l'utilisateur.
class ErreurMida implements Exception {
  const ErreurMida(this.message);
  final String message;
  @override
  String toString() => message;
}

const messageIdentifiantsIncorrects = 'E-mail ou mot de passe incorrect.';
const messageHorsLigne = 'Pas de connexion internet. Vérifiez votre réseau puis réessayez.';

/// Traduit une erreur de Supabase Auth (ou du réseau) en message clair.
String messageErreur(Object erreur) {
  if (erreur is ErreurMida) return erreur.message;
  if (erreur is SocketException || erreur is AuthRetryableFetchException) {
    return messageHorsLigne;
  }
  if (erreur is AuthException) {
    final code = erreur.code ?? '';
    final message = erreur.message.toLowerCase();
    if (code == 'invalid_credentials' || message.contains('invalid login credentials')) {
      return messageIdentifiantsIncorrects;
    }
    if (code == 'email_not_confirmed' || message.contains('email not confirmed')) {
      return 'Votre adresse e-mail n\'est pas encore confirmée. '
          'Ouvrez le lien reçu par e-mail, puis connectez-vous.';
    }
    if (code == 'user_already_exists' || code == 'email_exists' || message.contains('already registered')) {
      return 'Un compte existe déjà avec cette adresse e-mail. Connectez-vous.';
    }
    if (code == 'weak_password') {
      return 'Mot de passe trop faible : 8 caractères minimum, avec lettres et chiffres.';
    }
    if (code == 'email_address_invalid') {
      return 'Cette adresse e-mail n\'est pas acceptée.';
    }
    if (code.startsWith('over_') || erreur.statusCode == '429') {
      return 'Trop de tentatives. Patientez quelques minutes puis réessayez.';
    }
    if (code == 'signup_disabled') {
      return 'Les inscriptions sont momentanément fermées.';
    }
  }
  return 'Une erreur est survenue. Réessayez dans un instant.';
}
