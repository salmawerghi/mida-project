import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/erreurs.dart';
import '../auth/service_auth.dart';
import '../auth/validation.dart';
import '../theme.dart';
import '../widgets/composants.dart';
import 'inscription_page.dart';

/// Connexion par e-mail et mot de passe (maquette Client · Connexion).
class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key, required this.auth, this.emailInitial, this.information});
  final ServiceAuth auth;
  final String? emailInitial;

  /// Message affiché en haut du formulaire (ex. après l'inscription).
  final String? information;

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  final _formulaire = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailInitial);
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
      await widget.auth.connecter(email: _email.text, motDePasse: _motDePasse.text);
      // La session est ouverte : l'écran racine affiche désormais l'accueil.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
                      const Positioned(left: 20, top: 12, child: BoutonRetour(ombre: Couleurs.bleuFonce)),
                      Positioned(
                        right: 24,
                        bottom: 36,
                        child: SvgPicture.asset('assets/illustrations/the.svg', width: 130, height: 130),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 50,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('أهلا وسهلا',
                                textDirection: TextDirection.rtl,
                                style: textes.titleLarge
                                    ?.copyWith(color: Couleurs.doreClair, fontSize: 16, fontWeight: FontWeight.w600)),
                            Text('Bon retour\nparmi nous',
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
                        if (widget.information != null) ...[
                          const SizedBox(height: 12),
                          _Information(widget.information!),
                        ],
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
                              enabledBorder: _erreur == null
                                  ? null
                                  : OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Couleurs.harissa, width: 2),
                                    ),
                              suffixIcon: IconButton(
                                tooltip: _masque ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                                icon: Icon(_masque ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: Couleurs.texteDoux),
                                onPressed: () => setState(() => _masque = !_masque),
                              ),
                            ),
                          ),
                        ),
                        if (_erreur != null) ...[
                          const SizedBox(height: 8),
                          MessageErreur(_erreur!),
                        ],
                        const SizedBox(height: 24),
                        BoutonRelief(libelle: 'Se connecter', enCours: _enCours, onPressed: _seConnecter),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Pas encore de compte ?', style: textes.bodyMedium),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => InscriptionPage(auth: widget.auth)),
                              ),
                              child: const Text('Créer un compte'),
                            ),
                          ],
                        ),
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

class _Information extends StatelessWidget {
  const _Information(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB9DFC8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_read_outlined, color: Couleurs.succes),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte, style: const TextStyle(color: Color(0xFF1E5C3A), fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
