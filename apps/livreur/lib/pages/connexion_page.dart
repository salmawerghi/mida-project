import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/erreurs.dart';
import '../auth/service_auth.dart';
import '../auth/validation.dart';
import '../theme.dart';
import '../widgets/composants.dart';
import 'inscription_page.dart';

/// Connexion du livreur (maquette « Livreur · Connexion ») ; lien vers la candidature.
class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key, required this.auth});
  final ServiceAuth auth;

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  final _formulaire = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _masque = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    setState(() => _erreur = null);
    if (!_formulaire.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      // La session ouverte, l'écran racine affiche l'espace du livreur.
      await widget.auth.connecter(email: _email.text, motDePasse: _motDePasse.text);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 270,
              child: MotifEtoiles(
                child: SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 20,
                        top: 16,
                        child: Row(children: [
                          const LogoMida(taille: 34),
                          const SizedBox(width: 8),
                          Text('Mida', style: textes.titleLarge?.copyWith(color: Colors.white, fontSize: 24)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: Couleurs.dore, borderRadius: BorderRadius.circular(999)),
                            child: const Text('Livreur',
                                style: TextStyle(color: Couleurs.nuit, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ]),
                      ),
                      Positioned(
                        right: 24,
                        bottom: 36,
                        child: SvgPicture.asset('assets/illustrations/koffa.svg', width: 120, height: 120),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 50,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('يعطيك الصحة',
                                textDirection: TextDirection.rtl,
                                style: textes.titleLarge
                                    ?.copyWith(color: Couleurs.doreClair, fontSize: 16, fontWeight: FontWeight.w600)),
                            Text('Prêt pour\nvos courses ?',
                                style: textes.displaySmall?.copyWith(color: Colors.white, fontSize: 32)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                decoration: const BoxDecoration(
                  color: Couleurs.fond,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                child: Form(
                  key: _formulaire,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Connexion', style: textes.headlineSmall),
                        const SizedBox(height: 16),
                        ChampEtiquete(
                          etiquette: 'E-mail',
                          champ: TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            validator: validerEmail,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ChampEtiquete(
                          etiquette: 'Mot de passe',
                          champ: TextFormField(
                            controller: _motDePasse,
                            obscureText: _masque,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _seConnecter(),
                            validator: validerMotDePasseConnexion,
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                tooltip: _masque ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                                icon: Icon(_masque ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: Couleurs.texteDoux),
                                onPressed: () => setState(() => _masque = !_masque),
                              ),
                            ),
                          ),
                        ),
                        if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
                        const SizedBox(height: 20),
                        BoutonRelief(libelle: 'Se connecter', enCours: _enCours, onPressed: _seConnecter),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Nouveau livreur ?', style: textes.bodyMedium),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => InscriptionPage(auth: widget.auth)),
                              ),
                              child: const Text('Déposer ma candidature'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
