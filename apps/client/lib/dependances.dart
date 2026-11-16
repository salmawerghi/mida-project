import 'package:flutter/widgets.dart';

import 'auth/service_auth.dart';
import 'donnees/service_mida.dart';
import 'panier/panier.dart';

/// Services partagés par tous les écrans (remplaçables dans les tests) :
/// `Dependances.of(context).mida`.
class Dependances extends InheritedWidget {
  const Dependances({super.key, required this.auth, required this.mida, required this.panier, required super.child});

  final ServiceAuth auth;
  final ServiceMida mida;

  /// Panier du client (US18) : un seul pour toute l'appli.
  final Panier panier;

  static Dependances of(BuildContext context) {
    final d = context.dependOnInheritedWidgetOfExactType<Dependances>();
    assert(d != null, 'Aucun widget Dependances au-dessus de ce contexte');
    return d!;
  }

  @override
  bool updateShouldNotify(Dependances ancien) =>
      auth != ancien.auth || mida != ancien.mida || panier != ancien.panier;
}
