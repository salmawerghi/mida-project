import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/erreurs.dart';
import '../auth/service_auth.dart';
import '../auth/validation.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Candidature d'un livreur, étape 1 sur 2 (US25) : le compte. L'étape 2
/// (véhicule et documents) s'affiche ensuite d'elle-même, dès que la session
/// est ouverte (voir `EspaceLivreur`).
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
  bool _masque = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    for (final c in [_nom, _email, _telephone, _motDePasse]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _continuer() async {
    setState(() => _erreur = null);
    if (!_formulaire.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      await widget.auth.inscrire(
        nom: _nom.text,
        email: _email.text,
        telephone: formaterTelephone(_telephone.text),
        motDePasse: _motDePasse.text,
      );
      // Compte créé et session ouverte : l'écran racine passe à l'étape 2.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
      body: SafeArea(
        child: Form(
          key: _formulaire,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: BoutonRetour()),
                const SizedBox(height: 14),
                Text('Étape 1 sur 2', style: textes.labelLarge?.copyWith(color: Couleurs.harissa)),
                const SizedBox(height: 4),
                Text('Devenir livreur Mida', style: textes.headlineMedium),
                const SizedBox(height: 6),
                Text('Créez votre compte, puis déposez vos documents à l\'étape suivante.', style: textes.bodyMedium),
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
                if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
                const SizedBox(height: 20),
                BoutonRelief.harissa(libelle: 'Continuer', enCours: _enCours, onPressed: _continuer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
