import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/erreurs.dart';
import '../auth/service_auth.dart';
import '../auth/validation.dart';
import '../theme.dart';
import '../widgets/composants.dart';
import 'connexion_page.dart';

/// Création d'un compte client (maquette Client · Inscription).
class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key, required this.auth});
  final ServiceAuth auth;

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _conditions = false;
  bool _conditionsErreur = false;
  bool _masque = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _motDePasse.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_nom, _email, _telephone, _motDePasse]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _creerCompte() async {
    setState(() {
      _erreur = null;
      _conditionsErreur = !_conditions;
    });
    final valide = _formulaire.currentState!.validate();
    if (!valide || !_conditions) return;

    setState(() => _enCours = true);
    try {
      final resultat = await widget.auth.inscrire(
        nom: _nom.text,
        email: _email.text,
        telephone: formaterTelephone(_telephone.text),
        motDePasse: _motDePasse.text,
      );
      if (!mounted) return;
      if (resultat == ResultatInscription.connecte) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ConnexionPage(
            auth: widget.auth,
            emailInitial: _email.text.trim(),
            information: 'Compte créé ! Nous avons envoyé un lien de confirmation à '
                '${_email.text.trim()}. Ouvrez-le, puis connectez-vous ici.',
          ),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final solidite = soliditeMotDePasse(_motDePasse.text);
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
                          Text('Créer votre compte', style: textes.headlineMedium),
                          const SizedBox(height: 6),
                          Text('Quelques informations, et la mida est servie.', style: textes.bodyMedium),
                        ],
                      ),
                    ),
                    SvgPicture.asset('assets/illustrations/bambalouni.svg', width: 86, height: 86),
                  ],
                ),
                const SizedBox(height: 18),
                ChampEtiquete(
                  etiquette: 'Nom et prénom',
                  champ: TextFormField(
                    controller: _nom,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    textInputAction: TextInputAction.next,
                    validator: validerNom,
                  ),
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 14),
                ChampEtiquete(
                  etiquette: 'Téléphone',
                  champ: TextFormField(
                    controller: _telephone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: validerTelephone,
                    decoration: const InputDecoration(
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 14, right: 8),
                        child: Text('+216', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                      prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '22 145 870',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ChampEtiquete(
                  etiquette: 'Mot de passe',
                  champ: TextFormField(
                    controller: _motDePasse,
                    obscureText: _masque,
                    autofillHints: const [AutofillHints.newPassword],
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
                  JaugeSolidite(score: solidite),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() {
                    _conditions = !_conditions;
                    if (_conditions) _conditionsErreur = false;
                  }),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _conditions,
                        isError: _conditionsErreur,
                        onChanged: (v) => setState(() {
                          _conditions = v ?? false;
                          if (_conditions) _conditionsErreur = false;
                        }),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'J\'accepte les conditions d\'utilisation et la politique de confidentialité de Mida.',
                            style: TextStyle(fontSize: 14, color: Color(0xFF33415F), height: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_conditionsErreur)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Acceptez les conditions pour créer votre compte.',
                        style: TextStyle(color: Couleurs.erreur, fontSize: 13)),
                  ),
                if (_erreur != null) ...[
                  const SizedBox(height: 12),
                  MessageErreur(_erreur!),
                ],
                const SizedBox(height: 24),
                BoutonRelief.harissa(libelle: 'Créer mon compte', enCours: _enCours, onPressed: _creerCompte),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Déjà inscrit ?', style: textes.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => ConnexionPage(auth: widget.auth)),
                      ),
                      child: const Text('Se connecter'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
