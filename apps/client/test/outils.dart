import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mida_client/dependances.dart';
import 'package:mida_client/panier/panier.dart';
import 'package:mida_client/theme.dart';

import 'faux_service_auth.dart';
import 'faux_service_mida.dart';

/// Ouvre [page] sur un écran de téléphone (360 × 800), avec les faux services.
Future<void> ouvrirPage(
  WidgetTester tester,
  Widget page, {
  FauxServiceMida? mida,
  FauxServiceAuth? auth,
  Panier? panier,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(Dependances(
    auth: auth ?? FauxServiceAuth(),
    mida: mida ?? FauxServiceMida(),
    panier: panier ?? Panier(),
    child: MaterialApp(theme: construireTheme(policesGoogle: false), home: page),
  ));
  await tester.pumpAndSettle();
}

/// Fait défiler la première liste jusqu'à [cible].
Future<void> defilerJusqua(WidgetTester tester, Finder cible) =>
    tester.scrollUntilVisible(cible, 200, scrollable: find.byType(Scrollable).first);
