import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/erreurs.dart';
import '../auth/service_auth.dart';
import '../auth/validation.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Réinitialisation du mot de passe (US06), en deux étapes :
/// 1. l'adresse e-mail → Supabase envoie un code ;
/// 2. le code reçu + le nouveau mot de passe → session ouverte.
class MotDePasseOubliePage extends StatefulWidget {
  const MotDePasseOubliePage({super.key, required this.auth, this.emailInitial});
  final ServiceAuth auth;
  final String? emailInitial;

  @override
  State<MotDePasseOubliePage> createState() => _MotDePasseOubliePageState();
}

class _MotDePasseOubliePageState extends State<MotDePasseOubliePage> {
  final _formulaire = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailInitial?.trim());
  final _code = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();

  /// `false` : étape 1 (e-mail) ; `true` : étape 2 (code + mot de passe).
  bool _codeEnvoye = false;

  /// Le code a déjà été accepté : il est consommé, on ne le revérifie pas
  /// si l'enregistrement du mot de passe échoue (ex. même mot de passe).
  bool _codeVerifie = false;

  bool _masque = true;
  bool _enCours = false;
  String? _erreur;
  String? _information;

  @override
  void initState() {
    super.initState();
    _motDePasse.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_email, _code, _motDePasse, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _executer(Future<void> Function() action) async {
    setState(() => _erreur = null);
    if (!_formulaire.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _envoyerCode() => _executer(() async {
        await widget.auth.demanderReinitialisation(_email.text);
        if (!mounted) return;
        setState(() {
          _codeEnvoye = true;
          _information = _messageEnvoi(_email.text.trim());
        });
      });

  Future<void> _renvoyerCode() async {
    setState(() {
      _erreur = null;
      _enCours = true;
    });
    try {
      await widget.auth.demanderReinitialisation(_email.text);
      if (mounted) setState(() => _information = 'Nouveau code envoyé. ${_messageEnvoi(_email.text.trim())}');
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _changerMotDePasse() => _executer(() async {
        if (!_codeVerifie) {
          await widget.auth.verifierCodeReinitialisation(email: _email.text, code: _code.text);
          _codeVerifie = true;
        }
        await widget.auth.changerMotDePasse(_motDePasse.text);
        if (!mounted) return;
        // La session est ouverte : retour à l'écran racine (accueil).
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mot de passe modifié. Vous êtes connecté.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      });

  void _changerEmail() => setState(() {
        _codeEnvoye = false;
        _codeVerifie = false;
        _erreur = null;
        _information = null;
        _code.clear();
      });

  static String _messageEnvoi(String email) =>
      'Si un compte Mida existe pour $email, un code vient d\'y être envoyé. '
      'Pensez à regarder dans les courriers indésirables.';

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formulaire,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: BoutonRetour()),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_codeEnvoye ? 'Nouveau mot de passe' : 'Mot de passe oublié',
                              style: textes.headlineMedium),
                          const SizedBox(height: 6),
                          Text(
                            _codeEnvoye
                                ? 'Saisissez le code reçu par e-mail, puis choisissez un nouveau mot de passe.'
                                : 'Indiquez l\'e-mail de votre compte : nous vous envoyons un code '
                                    'pour choisir un nouveau mot de passe.',
                            style: textes.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset('assets/illustrations/the.svg', width: 80, height: 80),
                  ],
                ),
                const SizedBox(height: 18),
                if (!_codeEnvoye) ..._etapeEmail() else ..._etapeCode(),
                if (_erreur != null) ...[
                  const SizedBox(height: 12),
                  MessageErreur(_erreur!),
                ],
                const SizedBox(height: 24),
                if (!_codeEnvoye)
                  BoutonRelief(libelle: 'Recevoir le code', enCours: _enCours, onPressed: _envoyerCode)
                else ...[
                  BoutonRelief(
                      libelle: 'Changer le mot de passe', enCours: _enCours, onPressed: _changerMotDePasse),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton(
                          onPressed: _enCours || _codeVerifie ? null : _renvoyerCode,
                          child: const Text('Renvoyer le code')),
                      TextButton(
                          onPressed: _enCours || _codeVerifie ? null : _changerEmail,
                          child: const Text('Changer d\'adresse')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _etapeEmail() => [
        ChampEtiquete(
          etiquette: 'E-mail',
          champ: TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _envoyerCode(),
            validator: validerEmail,
          ),
        ),
      ];

  List<Widget> _etapeCode() => [
        if (_information != null) ...[
          BandeauInformation(_information!),
          const SizedBox(height: 16),
        ],
        ChampEtiquete(
          etiquette: 'Code reçu par e-mail',
          champ: TextFormField(
            controller: _code,
            enabled: !_codeVerifie,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            validator: _codeVerifie ? null : validerCode,
            style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: '123456'),
          ),
        ),
        const SizedBox(height: 14),
        ChampEtiquete(
          etiquette: 'Nouveau mot de passe',
          champ: TextFormField(
            controller: _motDePasse,
            obscureText: _masque,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            validator: validerMotDePasseInscription,
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
        if (_motDePasse.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          JaugeSolidite(score: soliditeMotDePasse(_motDePasse.text)),
        ],
        const SizedBox(height: 14),
        ChampEtiquete(
          etiquette: 'Confirmer le mot de passe',
          champ: TextFormField(
            controller: _confirmation,
            obscureText: _masque,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _changerMotDePasse(),
            validator: (v) => validerConfirmation(v, _motDePasse.text),
          ),
        ),
      ];
}
