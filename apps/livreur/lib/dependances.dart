import 'package:flutter/widgets.dart';

import 'auth/service_auth.dart';
import 'donnees/modeles.dart';
import 'donnees/service_livreur.dart';

/// Choix d'une photo de document sur le téléphone (remplaçable dans les tests).
typedef ChoisirDocument = Future<DocumentChoisi?> Function();

/// Services partagés par tous les écrans : `Dependances.of(context).livreur`.
class Dependances extends InheritedWidget {
  const Dependances({
    super.key,
    required this.auth,
    required this.livreur,
    required this.choisirDocument,
    required super.child,
  });

  final ServiceAuth auth;
  final ServiceLivreur livreur;
  final ChoisirDocument choisirDocument;

  static Dependances of(BuildContext context) {
    final d = context.dependOnInheritedWidgetOfExactType<Dependances>();
    assert(d != null, 'Aucun widget Dependances au-dessus de ce contexte');
    return d!;
  }

  @override
  bool updateShouldNotify(Dependances ancien) =>
      auth != ancien.auth || livreur != ancien.livreur || choisirDocument != ancien.choisirDocument;
}
