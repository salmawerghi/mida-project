import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'erreurs.dart';

/// Opérations de compte de l'appli livreur (remplaçable dans les tests).
abstract class ServiceAuth {
  Session? get session;
  Stream<AuthState> get changements;

  /// Crée le compte livreur (US25) : le profil et la fiche livreur sont créés
  /// par la base, « en attente » de validation par l'administrateur.
  /// Lève `ErreurMida` si la confirmation d'e-mail est demandée (pas de session).
  Future<void> inscrire({
    required String nom,
    required String email,
    required String telephone,
    required String motDePasse,
  });
  Future<void> connecter({required String email, required String motDePasse});
  Future<void> deconnecter();
}

class ServiceAuthSupabase implements ServiceAuth {
  ServiceAuthSupabase(this._client);
  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Session? get session => _auth.currentSession;

  @override
  Stream<AuthState> get changements => _auth.onAuthStateChange;

  @override
  Future<void> inscrire({
    required String nom,
    required String email,
    required String telephone,
    required String motDePasse,
  }) async {
    // Métadonnées lues par le déclencheur creer_profil_nouvel_utilisateur
    // (US02) : rôle livreur → profil « en attente » + fiche dans `livreurs`.
    final reponse = await _auth.signUp(
      email: email.trim(),
      password: motDePasse,
      data: {'role': 'livreur', 'nom': nom.trim(), 'telephone': telephone},
    );
    if (reponse.user?.identities?.isEmpty ?? false) {
      throw const ErreurMida('Un compte existe déjà avec cette adresse e-mail. Connectez-vous.');
    }
    if (reponse.session == null) {
      throw ErreurMida('Compte créé : ouvrez le lien reçu à l\'adresse ${email.trim()}, '
          'puis connectez-vous pour déposer vos documents.');
    }
    await _verifierCompteLivreur(reponse.session!);
  }

  @override
  Future<void> connecter({required String email, required String motDePasse}) async {
    final reponse = await _auth.signInWithPassword(email: email.trim(), password: motDePasse);
    final session = reponse.session;
    if (session == null) throw const ErreurMida(messageIdentifiantsIncorrects);
    await _verifierCompteLivreur(session);
  }

  @override
  Future<void> deconnecter() => _auth.signOut();

  /// Appli réservée aux livreurs : tout autre compte, ou un compte bloqué,
  /// est déconnecté aussitôt. Un livreur en attente ou refusé peut se
  /// connecter : il voit l'état de sa candidature.
  Future<void> _verifierCompteLivreur(Session session) async {
    var (role, etat) = rolesDuJeton(session.accessToken);
    if (role == null) {
      final profil = await _client
          .from('profiles')
          .select('role, etat_compte')
          .eq('id', session.user.id)
          .maybeSingle();
      role = profil?['role'] as String?;
      etat = profil?['etat_compte'] as String?;
    }
    final refus = refusCompte(role, etat);
    if (refus != null) {
      await _auth.signOut();
      throw ErreurMida(refus);
    }
  }
}

/// Lit `user_role` et `etat_compte` ajoutés au jeton par custom_access_token_hook.
(String?, String?) rolesDuJeton(String jeton) {
  try {
    final morceaux = jeton.split('.');
    if (morceaux.length != 3) return (null, null);
    final contenu = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(morceaux[1]))));
    if (contenu is! Map) return (null, null);
    return (contenu['user_role'] as String?, contenu['etat_compte'] as String?);
  } on FormatException {
    return (null, null);
  }
}

/// Message de refus si le compte ne peut pas utiliser l'application livreur.
String? refusCompte(String? role, String? etat) {
  if (role != null && role != 'livreur') {
    final appli = switch (role) {
      'client' => 'l\'application Mida',
      'responsable' => 'l\'espace restaurant Mida (sur le web)',
      _ => 'le tableau de bord d\'administration',
    };
    return 'Ce compte n\'est pas un compte livreur. Utilisez $appli.';
  }
  if (etat == 'bloque') {
    return 'Ce compte est suspendu. Contactez le support Mida.';
  }
  return null;
}
