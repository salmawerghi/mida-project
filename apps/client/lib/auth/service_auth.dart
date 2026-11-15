import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'erreurs.dart';

enum ResultatInscription {
  /// Compte créé et session ouverte (confirmation d'e-mail désactivée).
  connecte,

  /// Compte créé : l'utilisateur doit d'abord cliquer le lien reçu par e-mail.
  confirmationEmail,
}

/// Opérations de compte utilisées par les écrans (remplaçable dans les tests).
abstract class ServiceAuth {
  Session? get session;
  Stream<AuthState> get changements;
  String get nomAffiche;

  Future<ResultatInscription> inscrire({
    required String nom,
    required String email,
    required String telephone,
    required String motDePasse,
  });
  Future<void> connecter({required String email, required String motDePasse});
  Future<void> deconnecter();

  /// Envoie le code de réinitialisation à [email]. Ne dit jamais si un compte
  /// existe pour cette adresse (Supabase répond pareil dans les deux cas).
  Future<void> demanderReinitialisation(String email);

  /// Vérifie le code reçu par e-mail : ouvre une session de récupération.
  /// Lève `ErreurMida` (et déconnecte) si le compte n'est pas un compte client.
  Future<void> verifierCodeReinitialisation({required String email, required String code});

  /// Enregistre le nouveau mot de passe (session de récupération ouverte).
  Future<void> changerMotDePasse(String nouveauMotDePasse);
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
  String get nomAffiche {
    final user = _auth.currentUser;
    final nom = user?.userMetadata?['nom'] as String?;
    return (nom != null && nom.trim().isNotEmpty) ? nom.trim() : (user?.email?.split('@').first ?? '');
  }

  @override
  Future<ResultatInscription> inscrire({
    required String nom,
    required String email,
    required String telephone,
    required String motDePasse,
  }) async {
    // Métadonnées lues par le déclencheur creer_profil_nouvel_utilisateur
    // (migration US02) pour remplir la table profiles.
    final reponse = await _auth.signUp(
      email: email.trim(),
      password: motDePasse,
      data: {'role': 'client', 'nom': nom.trim(), 'telephone': telephone},
    );
    // Quand la confirmation d'e-mail est activée, Supabase ne signale pas
    // une adresse déjà utilisée (pour ne pas révéler qui est inscrit) :
    // il renvoie un utilisateur sans identité.
    if (reponse.user?.identities?.isEmpty ?? false) {
      throw const ErreurMida('Un compte existe déjà avec cette adresse e-mail. Connectez-vous.');
    }
    if (reponse.session == null) return ResultatInscription.confirmationEmail;
    await _verifierCompteClient(reponse.session!);
    return ResultatInscription.connecte;
  }

  @override
  Future<void> connecter({required String email, required String motDePasse}) async {
    final reponse = await _auth.signInWithPassword(email: email.trim(), password: motDePasse);
    final session = reponse.session;
    if (session == null) throw const ErreurMida(messageIdentifiantsIncorrects);
    await _verifierCompteClient(session);
  }

  @override
  Future<void> deconnecter() => _auth.signOut();

  @override
  Future<void> demanderReinitialisation(String email) => _auth.resetPasswordForEmail(email.trim());

  @override
  Future<void> verifierCodeReinitialisation({required String email, required String code}) async {
    final reponse = await _auth.verifyOTP(
      type: OtpType.recovery,
      email: email.trim(),
      token: code.replaceAll(' ', ''),
    );
    final session = reponse.session;
    if (session == null) throw const ErreurMida(messageCodeInvalide);
    await _verifierCompteClient(session);
  }

  @override
  Future<void> changerMotDePasse(String nouveauMotDePasse) async {
    await _auth.updateUser(UserAttributes(password: nouveauMotDePasse));
  }

  /// Cette application est réservée aux clients : un compte livreur,
  /// restaurant ou admin, ou un compte bloqué, est déconnecté aussitôt.
  Future<void> _verifierCompteClient(Session session) async {
    var (role, etat) = rolesDuJeton(session.accessToken);
    if (role == null) {
      // Le hook qui ajoute le rôle au jeton n'est pas actif : on lit le profil.
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

/// Message de refus si le compte ne peut pas utiliser l'application client.
String? refusCompte(String? role, String? etat) {
  if (role != null && role != 'client') {
    final appli = switch (role) {
      'livreur' => 'l\'application Mida Livreur',
      'responsable' => 'l\'espace restaurant Mida (sur le web)',
      _ => 'le tableau de bord d\'administration',
    };
    return 'Ce compte n\'est pas un compte client. Utilisez $appli.';
  }
  if (etat == 'bloque') {
    return 'Ce compte est suspendu. Contactez le support Mida.';
  }
  return null;
}
