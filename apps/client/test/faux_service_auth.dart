import 'package:mida_client/auth/service_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Faux service : enregistre les appels et renvoie le résultat prévu.
class FauxServiceAuth implements ServiceAuth {
  FauxServiceAuth({
    this.resultat = ResultatInscription.confirmationEmail,
    this.erreur,
    this.erreurCode,
    this.erreursMotDePasse = const [],
  });
  final ResultatInscription resultat;

  /// Levée par `inscrire`.
  final Object? erreur;

  /// Levée par `verifierCodeReinitialisation`.
  final Object? erreurCode;

  /// Levées une à une par les appels successifs à `changerMotDePasse`.
  final List<Object> erreursMotDePasse;

  final appels = <Map<String, String>>[];

  /// Journal des appels de réinitialisation, dans l'ordre.
  final reinitialisation = <String>[];

  @override
  Session? get session => null;
  @override
  Stream<AuthState> get changements => const Stream.empty();
  @override
  String get nomAffiche => '';

  @override
  Future<ResultatInscription> inscrire({
    required String nom,
    required String email,
    required String telephone,
    required String motDePasse,
  }) async {
    appels.add({'nom': nom, 'email': email, 'telephone': telephone, 'motDePasse': motDePasse});
    if (erreur != null) throw erreur!;
    return resultat;
  }

  @override
  Future<void> connecter({required String email, required String motDePasse}) async {}
  @override
  Future<void> deconnecter() async {}

  @override
  Future<void> demanderReinitialisation(String email) async {
    reinitialisation.add('demande:${email.trim()}');
  }

  @override
  Future<void> verifierCodeReinitialisation({required String email, required String code}) async {
    reinitialisation.add('code:${email.trim()}:$code');
    if (erreurCode != null) throw erreurCode!;
  }

  var _echecs = 0;

  @override
  Future<void> changerMotDePasse(String nouveauMotDePasse) async {
    reinitialisation.add('motDePasse:$nouveauMotDePasse');
    if (_echecs < erreursMotDePasse.length) throw erreursMotDePasse[_echecs++];
  }
}
