import 'package:flutter/widgets.dart';

import 'auth/service_auth.dart';
import 'donnees/service_mida.dart';

/// Services partagés par tous les écrans (remplaçables dans les tests) :
/// `Dependances.of(context).mida`.
class Dependances extends InheritedWidget {
  const Dependances({super.key, required this.auth, required this.mida, required super.child});

  final ServiceAuth auth;
  final ServiceMida mida;

  static Dependances of(BuildContext context) {
    final d = context.dependOnInheritedWidgetOfExactType<Dependances>();
    assert(d != null, 'Aucun widget Dependances au-dessus de ce contexte');
    return d!;
  }

  @override
  bool updateShouldNotify(Dependances ancien) => auth != ancien.auth || mida != ancien.mida;
}
