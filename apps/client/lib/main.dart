import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/service_auth.dart';
import 'config.dart';
import 'dependances.dart';
import 'donnees/service_mida.dart';
import 'pages/accueil_page.dart';
import 'pages/bienvenue_page.dart';
import 'panier/panier.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La session est enregistrée sur le téléphone par supabase_flutter :
  // elle est restaurée (et rafraîchie) au prochain lancement.
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  final client = Supabase.instance.client;
  runApp(AppMida(auth: ServiceAuthSupabase(client), mida: ServiceMidaSupabase(client), panier: Panier()));
}

class AppMida extends StatelessWidget {
  const AppMida({super.key, required this.auth, required this.mida, required this.panier, this.theme});
  final ServiceAuth auth;
  final ServiceMida mida;
  final Panier panier;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    // Les services sont placés au-dessus de MaterialApp : tous les écrans,
    // y compris ceux ouverts par Navigator.push, y ont accès.
    return Dependances(
      auth: auth,
      mida: mida,
      panier: panier,
      child: MaterialApp(
        title: 'Mida',
        debugShowCheckedModeBanner: false,
        theme: theme ?? construireTheme(),
        home: StreamBuilder<AuthState>(
          stream: auth.changements,
          builder: (context, _) {
            // Écran racine : accueil si une session est ouverte, sinon bienvenue.
            final connecte = auth.session != null;
            return connecte ? AccueilPage(auth: auth) : BienvenuePage(auth: auth);
          },
        ),
      ),
    );
  }
}
