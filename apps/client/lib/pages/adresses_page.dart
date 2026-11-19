import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/catalogue.dart';
import '../widgets/composants.dart';

/// Adresses de livraison enregistrées (US47) : l'adresse principale est
/// proposée d'office dans le panier ; les autres en un toucher.
class AdressesPage extends StatefulWidget {
  const AdressesPage({super.key});

  @override
  State<AdressesPage> createState() => _AdressesPageState();
}

class _AdressesPageState extends State<AdressesPage> {
  List<AdresseClient>? _adresses;
  String? _erreur;
  bool _demarre = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_demarre) return;
    _demarre = true;
    _charger();
  }

  Future<void> _charger() async {
    try {
      final a = await Dependances.of(context).mida.mesAdresses();
      if (mounted) {
        setState(() {
          _adresses = a;
          _erreur = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _agir(Future<void> Function() action, String message) async {
    try {
      await action();
      await _charger();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _supprimer(AdresseClient a) async {
    final oui = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${a.libelle} » ?'),
        content: Text(a.texte),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Garder')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Couleurs.harissa),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (oui != true || !mounted) return;
    final mida = Dependances.of(context).mida;
    await _agir(() => mida.supprimerAdresse(a.id), 'Adresse « ${a.libelle} » supprimée.');
  }

  Future<void> _ajouter() async {
    final ajoutee = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => NouvelleAdressePage(premiere: (_adresses ?? const []).isEmpty)));
    if (ajoutee == true) await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final adresses = _adresses;
    final mida = Dependances.of(context).mida;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text('Mes adresses', style: textes.titleLarge),
      ),
      floatingActionButton: adresses == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _ajouter,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Ajouter une adresse'),
            ),
      body: adresses == null
          ? Center(
              child: _erreur != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MessageErreur(_erreur!),
                          TextButton(onPressed: _charger, child: const Text('Réessayer')),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(semanticsLabel: 'Chargement des adresses'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [
                Text('L\'adresse principale est proposée d\'office dans votre panier.', style: textes.bodyMedium),
                if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
                const SizedBox(height: 16),
                if (adresses.isEmpty)
                  Text('Aucune adresse enregistrée pour le moment.', style: textes.bodyMedium)
                else
                  for (final a in adresses) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: a.parDefaut ? Couleurs.bleu : Couleurs.bordure,
                          width: a.parDefaut ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                a.libelle,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Couleurs.nuit),
                              ),
                              if (a.parDefaut)
                                const Pastille('Principale', couleur: Color(0xFFE6EEFB), texte: Couleurs.bleuFonce),
                            ],
                          ),
                          Text(a.texte, style: const TextStyle(color: Couleurs.texteDoux)),
                          Wrap(
                            spacing: 4,
                            children: [
                              if (!a.parDefaut)
                                TextButton(
                                  onPressed: () => _agir(
                                    () => mida.definirAdresseParDefaut(a.id),
                                    '« ${a.libelle} » est votre adresse principale.',
                                  ),
                                  child: Text('Choisir « ${a.libelle} » comme principale'),
                                ),
                              TextButton(
                                onPressed: () => _supprimer(a),
                                style: TextButton.styleFrom(foregroundColor: Couleurs.harissa),
                                child: Text('Supprimer « ${a.libelle} »'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
    );
  }
}

/// Formulaire d'une nouvelle adresse ; renvoie `true` une fois enregistrée.
class NouvelleAdressePage extends StatefulWidget {
  const NouvelleAdressePage({super.key, this.premiere = false});

  /// Première adresse du client : elle devient la principale.
  final bool premiere;

  @override
  State<NouvelleAdressePage> createState() => _NouvelleAdressePageState();
}

class _NouvelleAdressePageState extends State<NouvelleAdressePage> {
  final _formulaire = GlobalKey<FormState>();
  final _libelle = TextEditingController(text: 'Maison');
  final _rue = TextEditingController();
  final _complement = TextEditingController();
  final _ville = TextEditingController();
  late bool _parDefaut = widget.premiere;
  bool _enCours = false;
  String? _erreur;

  static const _libelles = ['Maison', 'Travail', 'Famille'];

  @override
  void dispose() {
    _libelle.dispose();
    _rue.dispose();
    _complement.dispose();
    _ville.dispose();
    super.dispose();
  }

  String? _obligatoire(String? v, String message) => (v ?? '').trim().isEmpty ? message : null;

  Future<void> _enregistrer() async {
    if (!_formulaire.currentState!.validate()) return;
    final mida = Dependances.of(context).mida;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await mida.ajouterAdresse(
        libelle: _libelle.text,
        rue: _rue.text,
        ville: _ville.text,
        complement: _complement.text,
        parDefaut: _parDefaut,
      );
      if (mounted) Navigator.of(context).pop(true);
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
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text('Nouvelle adresse', style: textes.titleLarge),
      ),
      body: Form(
        key: _formulaire,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final l in _libelles)
                    ChoiceChip(
                      label: Text(l),
                      selected: _libelle.text == l,
                      onSelected: (_) => setState(() => _libelle.text = l),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _libelle,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Nom de l\'adresse', counterText: ''),
                onChanged: (_) => setState(() {}),
                validator: (v) => _obligatoire(v, 'Donnez un nom à l\'adresse (Maison, Travail…).'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rue,
                maxLength: 150,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Rue et numéro',
                  hintText: '12, rue du Jasmin',
                  counterText: '',
                ),
                validator: (v) => _obligatoire(v, 'Indiquez la rue et le numéro.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _complement,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Complément (facultatif)',
                  hintText: 'Immeuble, étage, code…',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ville,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ville', hintText: 'La Marsa', counterText: ''),
                validator: (v) => _obligatoire(v, 'Indiquez la ville.'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _parDefaut,
                onChanged: widget.premiere ? null : (v) => setState(() => _parDefaut = v ?? false),
                title: const Text('Adresse principale'),
                subtitle: const Text('Proposée d\'office dans le panier'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_erreur != null) ...[const SizedBox(height: 8), MessageErreur(_erreur!)],
              const SizedBox(height: 16),
              BoutonRelief(
                libelle: 'Enregistrer l\'adresse',
                enCours: _enCours,
                onPressed: _enCours ? null : _enregistrer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
