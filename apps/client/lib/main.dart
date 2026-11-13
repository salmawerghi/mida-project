import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/service_auth.dart';
import 'config.dart';
import 'pages/accueil_page.dart';
import 'pages/bienvenue_page.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // La session est enregistrée sur le téléphone par supabase_flutter :
  // elle est restaurée (et rafraîchie) au prochain lancement.
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(AppMida(auth: ServiceAuthSupabase(Supabase.instance.client)));
}

class AppMida extends StatelessWidget {
  const AppMida({super.key, required this.auth, this.theme});
  final ServiceAuth auth;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
