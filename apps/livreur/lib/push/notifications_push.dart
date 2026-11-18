import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/service_auth.dart';

/// Messager de l'appli (donné à MaterialApp) : affiche en bas de l'écran
/// les notifications reçues pendant que l'appli est ouverte.
final messagerPush = GlobalKey<ScaffoldMessengerState>();

/// Notifications push (US23), par Firebase Cloud Messaging.
///
/// - À la connexion, le jeton FCM du téléphone est enregistré pour le
///   compte (fonction `enregistrer_jeton`) ; la base l'utilise ensuite
///   pour chaque nouvelle ligne de `notifications` (Edge Function envoyer-push).
/// - Appli fermée ou en arrière-plan : Android affiche lui-même la
///   notification (canal « commandes_mida », créé dans MainActivity).
/// - Appli ouverte : Android n'affiche rien, on montre un bandeau.
/// - À la déconnexion, le jeton est supprimé : le téléphone ne reçoit plus
///   les notifications de ce compte.
///
/// Sans `google-services.json` (voir le README), Firebase ne démarre pas :
/// l'appli marche normalement, sans notifications push.
class NotificationsPush {
  NotificationsPush(this._client, {required this.roleAttendu});

  final SupabaseClient _client;

  /// Rôle des comptes de cette appli (« client » ou « livreur ») : le jeton
  /// n'est jamais enregistré pour un compte que l'appli va refuser.
  final String roleAttendu;

  bool _demarre = false;

  Future<void> demarrer() async {
    try {
      await Firebase.initializeApp();
      _demarre = true;
    } catch (e) {
      debugPrint('Notifications push désactivées (Firebase non configuré) : $e');
      return;
    }
    FirebaseMessaging.onMessage.listen(_afficherAuPremierPlan);
    // ignore: deprecated_member_use, voir _jeton()
    FirebaseMessaging.instance.onTokenRefresh.listen((jeton) => unawaited(_enregistrer(jeton)));
    _client.auth.onAuthStateChange.listen((etat) {
      if (etat.event == AuthChangeEvent.signedIn) unawaited(_activer());
    });
    // Session restaurée au lancement de l'appli
    if (_client.auth.currentSession != null) unawaited(_activer());
  }

  /// Supprime le jeton de ce téléphone : à appeler AVANT `signOut`, car la
  /// règle d'accès de `device_tokens` exige d'être connecté.
  Future<void> oublierAppareil() async {
    if (!_demarre || _client.auth.currentSession == null) return;
    try {
      final jeton = await _jeton();
      if (jeton != null) await _client.from('device_tokens').delete().eq('token', jeton);
    } catch (e) {
      debugPrint('Jeton push non supprimé : $e');
    }
  }

  Future<void> _activer() async {
    try {
      // Android 13 et plus : fenêtre « Autoriser les notifications ? »
      await FirebaseMessaging.instance.requestPermission();
      final jeton = await _jeton();
      if (jeton != null) await _enregistrer(jeton);
    } catch (e) {
      debugPrint('Jeton push non enregistré : $e');
    }
  }

  Future<void> _enregistrer(String jeton) async {
    final session = _client.auth.currentSession;
    if (session == null) return;
    final (role, _) = rolesDuJeton(session.accessToken);
    if (role != null && role != roleAttendu) return;
    try {
      await _client.rpc('enregistrer_jeton', params: {'p_token': jeton, 'p_plateforme': 'android'});
    } catch (e) {
      debugPrint('Jeton push non enregistré : $e');
    }
  }

  /// Jeton d'enregistrement FCM, celui qu'attend l'API HTTP v1 (champ
  /// « token ») utilisée par l'Edge Function envoyer-push. firebase_messaging 17
  /// le déclare obsolète au profit de register()/onRegistered (identifiant
  /// d'installation « direct-send ») ; on garde le jeton, qui reste accepté.
  // ignore: deprecated_member_use
  Future<String?> _jeton() => FirebaseMessaging.instance.getToken();

  void _afficherAuPremierPlan(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    messagerPush.currentState?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.title != null) Text(n.title!, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (n.body != null) Text(n.body!),
        ],
      ),
    ));
  }
}
