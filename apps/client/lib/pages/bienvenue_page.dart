import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/service_auth.dart';
import '../theme.dart';
import '../widgets/composants.dart';
import 'accueil_page.dart';
import 'connexion_page.dart';
import 'inscription_page.dart';

/// Écran d'accueil d'un utilisateur non connecté (maquette Client · Bienvenue).
class BienvenuePage extends StatelessWidget {
  const BienvenuePage({super.key, required this.auth});
  final ServiceAuth auth;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      body: MotifEtoiles(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    const LogoMida(),
                    const SizedBox(width: 10),
                    Text('Mida', style: textes.headlineMedium?.copyWith(color: Colors.white, fontSize: 30)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final h = c.maxHeight.clamp(0.0, 330.0);
                      return Container(
                        height: h,
                        decoration: const BoxDecoration(
                          color: Couleurs.bleuFonce,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(170)),
                          border: Border.fromBorderSide(BorderSide(color: Color(0xFF2E78E6), width: 6)),
                        ),
                        alignment: Alignment.bottomCenter,
                        child: SvgPicture.asset(
                          'assets/illustrations/mida.svg',
                          height: h * 0.8,
                          semanticsLabel: 'Une mida garnie : tajine, couscous et thé à la menthe',
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                boxShadow: [BoxShadow(color: Color(0x590B3684), blurRadius: 30, offset: Offset(0, -10))],
              ),
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مرحبا بيك',
                        textDirection: TextDirection.rtl,
                        style: textes.titleLarge?.copyWith(color: Couleurs.harissa, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text('La table tunisienne, livrée chez vous', style: textes.displaySmall),
                    const SizedBox(height: 10),
                    Text(
                      'Commandez chez les restaurants de votre quartier et suivez votre livreur jusqu\'à votre porte.',
                      style: textes.bodyMedium?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    BoutonRelief.harissa(
                      libelle: 'Créer un compte',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => InscriptionPage(auth: auth)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ConnexionPage(auth: auth)),
                          ),
                          child: const Text('J\'ai déjà un compte'),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF33415F)),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AccueilPage(auth: auth, visiteur: true)),
                          ),
                          child: const Text('Découvrir sans compte'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
