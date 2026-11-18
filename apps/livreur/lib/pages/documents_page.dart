import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Candidature d'un livreur, étape 2 sur 2 (maquette « Livreur · Inscription », US25) :
/// type de véhicule, immatriculation, et photos des documents (carte d'identité,
/// plus permis et carte grise pour un véhicule motorisé).
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.etat, required this.apresEnvoi});
  final EtatLivreur etat;

  /// Appelée une fois la candidature envoyée (l'espace relit le compte).
  final Future<void> Function() apresEnvoi;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  late TypeVehicule? _vehicule = widget.etat.typeVehicule;
  late final _immatriculation = TextEditingController(text: widget.etat.immatriculation);
  final _formulaire = GlobalKey<FormState>();
  final _choisis = <TypeDocument, DocumentChoisi>{};
  final _manquants = <TypeDocument>{};
  bool _vehiculeManquant = false;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _immatriculation.dispose();
    super.dispose();
  }

  bool _depose(TypeDocument t) => widget.etat.documents.containsKey(t.code);

  Future<void> _choisir(TypeDocument type) async {
    final doc = await Dependances.of(context).choisirDocument();
    if (doc == null || !mounted) return;
    setState(() {
      _choisis[type] = doc;
      _manquants.remove(type);
    });
  }

  Future<void> _envoyer() async {
    final requis = documentsRequis(_vehicule);
    setState(() {
      _erreur = null;
      _vehiculeManquant = _vehicule == null;
      _manquants
        ..clear()
        ..addAll(requis.where((t) => !_choisis.containsKey(t) && !_depose(t)));
    });
    final champsOk = _formulaire.currentState!.validate();
    if (!champsOk || _vehiculeManquant || _manquants.isNotEmpty) return;
    setState(() => _enCours = true);
    try {
      await Dependances.of(context).livreur.envoyerCandidature(
            vehicule: _vehicule!,
            immatriculation: _immatriculation.text.trim().toUpperCase(),
            // un document choisi pour un véhicule motorisé n'est pas envoyé pour un vélo
            documents: {for (final t in requis) if (_choisis[t] != null) t: _choisis[t]!},
          );
      await widget.apresEnvoi();
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final vehicule = _vehicule;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(onPressed: Dependances.of(context).auth.deconnecter, child: const Text('Se déconnecter')),
        ],
      ),
      body: Form(
        key: _formulaire,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('Étape 2 sur 2', style: textes.labelLarge?.copyWith(color: Couleurs.harissa)),
            const SizedBox(height: 4),
            Text('Vos documents', style: textes.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'L\'équipe Mida les vérifie avant d\'activer votre compte, en général sous 48 heures.',
              style: textes.bodyMedium,
            ),
            const SizedBox(height: 20),
            Semantics(header: true, child: Text('Type de véhicule', style: textes.titleMedium)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final v in TypeVehicule.values)
                  ChoiceChip(
                    label: Text(v.libelle),
                    selected: vehicule == v,
                    onSelected: (_) => setState(() {
                      _vehicule = v;
                      _vehiculeManquant = false;
                      _manquants.clear();
                    }),
                  ),
              ],
            ),
            if (_vehiculeManquant)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Choisissez votre type de véhicule.', style: TextStyle(color: Couleurs.erreur, fontSize: 13)),
              ),
            if (vehicule?.motorise ?? false) ...[
              const SizedBox(height: 14),
              ChampEtiquete(
                etiquette: 'Immatriculation',
                champ: TextFormField(
                  controller: _immatriculation,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: '215 TU 4821'),
                  validator: validerImmatriculation,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Semantics(header: true, child: Text('Pièces justificatives', style: textes.titleMedium)),
            const SizedBox(height: 8),
            for (final t in documentsRequis(vehicule)) ...[
              _LigneDocument(
                type: t,
                choisi: _choisis[t],
                depose: _depose(t),
                manquant: _manquants.contains(t),
                onChoisir: () => _choisir(t),
              ),
              const SizedBox(height: 10),
            ],
            Text('Photos nettes, en entier et lisibles (JPEG ou PNG).', style: textes.bodyMedium?.copyWith(fontSize: 13)),
            if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
            const SizedBox(height: 20),
            BoutonRelief.harissa(libelle: 'Envoyer ma candidature', enCours: _enCours, onPressed: _envoyer),
          ],
        ),
      ),
    );
  }
}

/// « 215 TU 4821 » : chiffres, lettres et espaces, 4 à 15 caractères.
String? validerImmatriculation(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Indiquez l\'immatriculation du véhicule.';
  if (!RegExp(r'^[0-9A-Za-z ]{4,15}$').hasMatch(t)) return 'Immatriculation invalide (ex. 215 TU 4821).';
  return null;
}

class _LigneDocument extends StatelessWidget {
  const _LigneDocument({
    required this.type,
    required this.choisi,
    required this.depose,
    required this.manquant,
    required this.onChoisir,
  });
  final TypeDocument type;
  final DocumentChoisi? choisi;
  final bool depose;
  final bool manquant;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final pret = choisi != null || depose;
    final detail = choisi != null
        ? '${choisi!.nom} · ${choisi!.taille}'
        : depose
            ? 'Déjà déposé · en attente de vérification'
            : 'Photo à ajouter';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: manquant ? Couleurs.erreur : Couleurs.bordure, width: manquant ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(
            pret ? Icons.check_circle_rounded : Icons.badge_outlined,
            color: pret ? Couleurs.succes : Couleurs.texteDoux,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.libelle, style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.nuit)),
                Text(
                  manquant ? 'Document obligatoire' : detail,
                  style: TextStyle(fontSize: 13, color: manquant ? Couleurs.erreur : Couleurs.texteDoux),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChoisir,
            child: Text(pret ? 'Changer' : 'Ajouter', semanticsLabel: '${pret ? 'Changer' : 'Ajouter'} : ${type.libelle}'),
          ),
        ],
      ),
    );
  }
}
