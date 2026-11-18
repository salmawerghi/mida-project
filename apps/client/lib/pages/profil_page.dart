import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/erreurs.dart';
import '../auth/service_auth.dart';
import '../auth/validation.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Profil du client (maquette « Client · Profil », US24) : nom et téléphone
/// modifiables, e-mail affiché (il sert d'identifiant), déconnexion.
class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key, required this.auth});
  final ServiceAuth auth;

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  ProfilClient? _profil;
  String? _erreurChargement;
  String? _erreur;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _erreurChargement = null);
    try {
      final p = await widget.auth.profil();
      if (!mounted) return;
      setState(() {
        _profil = p;
        _nom.text = p.nom;
        _telephone.text = p.telephoneLocal;
      });
    } catch (e) {
      if (mounted) setState(() => _erreurChargement = messageErreur(e));
    }
  }

  Future<void> _enregistrer() async {
    FocusScope.of(context).unfocus();
    if (!_formulaire.currentState!.validate()) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await widget.auth.modifierProfil(nom: _nom.text.trim(), telephone: formaterTelephone(_telephone.text));
      if (!mounted) return;
      final p = _profil!;
      setState(() => _profil = ProfilClient(
            nom: _nom.text.trim(),
            email: p.email,
            telephone: formaterTelephone(_telephone.text),
          ));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Vos informations sont enregistrées.')));
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _deconnecter() async {
    // L'écran racine affiche la page de bienvenue dès la fin de la session :
    // on referme d'abord les écrans ouverts par-dessus.
    Navigator.of(context).popUntil((r) => r.isFirst);
    await widget.auth.deconnecter();
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final p = _profil;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text('Mon profil', style: textes.titleLarge),
      ),
      body: p == null
          ? Center(
              child: _erreurChargement != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        MessageErreur(_erreurChargement!),
                        TextButton(onPressed: _charger, child: const Text('Réessayer')),
                      ]),
                    )
                  : const CircularProgressIndicator(semanticsLabel: 'Chargement du profil'),
            )
          : Form(
              key: _formulaire,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Couleurs.bleu,
                        child: Text(
                          initiales(p.nom),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nom, style: textes.titleLarge),
                            Text(p.email, style: textes.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Semantics(header: true, child: Text('Informations personnelles', style: textes.titleMedium)),
                  const SizedBox(height: 12),
                  ChampEtiquete(
                    etiquette: 'Nom et prénom',
                    champ: TextFormField(
                      controller: _nom,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: validerNom,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ChampEtiquete(
                    etiquette: 'Téléphone',
                    champ: TextFormField(
                      controller: _telephone,
                      keyboardType: TextInputType.phone,
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
                    etiquette: 'E-mail',
                    champ: TextFormField(
                      initialValue: p.email,
                      enabled: false,
                      decoration: const InputDecoration(helperText: 'L\'adresse e-mail sert à vous connecter.'),
                    ),
                  ),
                  if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
                  const SizedBox(height: 20),
                  BoutonRelief(libelle: 'Enregistrer', enCours: _enCours, onPressed: _enregistrer),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: _deconnecter,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Se déconnecter'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Couleurs.harissa,
                      side: const BorderSide(color: Couleurs.harissa, width: 2),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// « Amine Belhadj » → « AB » ; « salma » → « S ».
String initiales(String nom) {
  final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty).toList();
  if (mots.isEmpty) return '?';
  final premieres = mots.length == 1 ? mots.first[0] : '${mots.first[0]}${mots.last[0]}';
  return premieres.toUpperCase();
}
