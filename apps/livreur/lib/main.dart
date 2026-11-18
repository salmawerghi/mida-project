import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/service_auth.dart';
import 'config.dart';
import 'dependances.dart';
import 'donnees/modeles.dart';
import 'donnees/service_livreur.dart';
import 'pages/connexion_page.dart';
import 'pages/espace_livreur.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Session conservée sur le téléphone et restaurée au prochain lancement.
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  final client = Supabase.instance.client;
  runApp(AppLivreur(
    auth: ServiceAuthSupabase(client),
    livreur: ServiceLivreurSupabase(client),
    choisirDocument: choisirPhoto,
  ));
}

/// Photo d'un document prise dans la galerie (recompressée en JPEG, 2000 px au plus).
Future<DocumentChoisi?> choisirPhoto() async {
  final photo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 80);
  if (photo == null) return null;
  return DocumentChoisi(nom: photo.name, octets: await photo.readAsBytes());
}

class AppLivreur extends StatelessWidget {
  const AppLivreur({
    super.key,
    required this.auth,
    required this.livreur,
    required this.choisirDocument,
    this.theme,
  });
  final ServiceAuth auth;
  final ServiceLivreur livreur;
  final ChoisirDocument choisirDocument;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return Dependances(
      auth: auth,
      livreur: livreur,
      choisirDocument: choisirDocument,
      child: MaterialApp(
        title: 'Mida Livreur',
        debugShowCheckedModeBanner: false,
        theme: theme ?? construireTheme(),
        home: StreamBuilder<AuthState>(
          stream: auth.changements,
          builder: (context, _) {
            // Écran racine : l'espace du livreur si une session est ouverte, sinon la connexion.
            final session = auth.session;
            return session != null
                ? EspaceLivreur(key: ValueKey(session.user.id))
                : ConnexionPage(auth: auth);
          },
        ),
      ),
    );
  }
}
