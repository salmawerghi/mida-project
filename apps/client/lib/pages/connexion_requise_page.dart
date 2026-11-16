import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../dependances.dart';
import '../donnees/format.dart';
import '../panier/panier.dart';
import '../theme.dart';
import '../widgets/composants.dart';
import 'connexion_page.dart';
import 'inscription_page.dart';

/// « Connectez-vous pour commander » (maquette « Client · Connexion requise ») :
/// un visiteur valide son panier. Le panier est gardé pendant la connexion,
/// puis l'appli revient au panier.
class ConnexionRequisePage extends StatelessWidget {
  const ConnexionRequisePage({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Dependances.of(context);
    final panier = d.panier;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(backgroundColor: Couleurs.fond),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          SvgPicture.asset('assets/illustrations/mida.svg', height: 150),
          const SizedBox(height: 16),
          Text('Connectez-vous pour commander', style: textes.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Votre panier est gardé. Il nous faut un compte pour la livraison, le paiement et le suivi de votre commande.',
            style: textes.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (!panier.estVide) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${panier.restaurant?.nom} · ${libelleArticles(panier.nbArticles)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Text('Panier conservé', style: TextStyle(fontSize: 13, color: Couleurs.succes)),
                      ],
                    ),
                  ),
                  Text(formaterPrix(panier.sousTotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          BoutonRelief.harissa(
            libelle: 'Créer un compte',
            // remplace cet écran : après l'inscription, retour direct au panier
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => InscriptionPage(auth: d.auth, retourApresConnexion: true)),
            ),
          ),
          const SizedBox(height: 12),
          BoutonRelief(
            libelle: 'J\'ai déjà un compte',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ConnexionPage(auth: d.auth, retourApresConnexion: true)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Continuer à explorer')),
        ],
      ),
    );
  }
}
