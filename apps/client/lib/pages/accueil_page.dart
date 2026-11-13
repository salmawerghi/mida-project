import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/service_auth.dart';
import '../theme.dart';
import '../widgets/composants.dart';
import 'connexion_page.dart';
import 'inscription_page.dart';

/// Accueil provisoire : le catalogue des restaurants arrive avec les
/// stories du sprint 2. Il montre ici l'état du compte (connecté ou
/// visiteur) pour valider US04.
class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key, required this.auth, this.visiteur = false});
  final ServiceAuth auth;
  final bool visiteur;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        automaticallyImplyLeading: visiteur,
        titleSpacing: visiteur ? 0 : 20,
        title: Row(
          children: [
            const LogoMida(taille: 32),
            const SizedBox(width: 8),
            Text('Mida', style: textes.titleLarge?.copyWith(fontSize: 24)),
          ],
        ),
        actions: [
          if (!visiteur)
            IconButton(
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout_rounded, color: Couleurs.nuit),
              onPressed: auth.deconnecter,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            visiteur ? 'Bienvenue !' : 'Bonjour, ${auth.nomAffiche}',
            style: textes.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            visiteur
                ? 'Vous découvrez Mida sans compte. Vous pourrez parcourir les restaurants et '
                    'remplir votre panier ; la connexion sera demandée pour valider la commande.'
                : 'Vous êtes connecté. Votre session reste ouverte même après la fermeture de l\'application.',
            style: textes.bodyMedium,
          ),
          const SizedBox(height: 28),
          Center(child: SvgPicture.asset('assets/illustrations/mida.svg', height: 200)),
          const SizedBox(height: 20),
          Text(
            'Les restaurants arrivent bientôt ici.',
            textAlign: TextAlign.center,
            style: textes.bodyMedium,
          ),
          if (visiteur) ...[
            const SizedBox(height: 28),
            BoutonRelief.harissa(
              libelle: 'Créer un compte',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => InscriptionPage(auth: auth)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ConnexionPage(auth: auth)),
              ),
              child: const Text('J\'ai déjà un compte'),
            ),
          ],
        ],
      ),
    );
  }
}
