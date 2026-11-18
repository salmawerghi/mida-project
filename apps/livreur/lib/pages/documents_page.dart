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
  /// « Avez-vous une moto ? » : oui = moto, non = vélo (`null` : pas encore répondu).
  late bool? _moto = widget.etat.typeVehicule?.motorise;

  /// « Avez-vous un permis de conduire ? »
  late bool? _permis = widget.etat.documents.containsKey(TypeDocument.permis.code) ? true : null;
  late final _immatriculation = TextEditingController(text: widget.etat.immatriculation);
  final _formulaire = GlobalKey<FormState>();
  final _choisis = <TypeDocument, DocumentChoisi>{};
  final _manquants = <TypeDocument>{};
  bool _reponsesManquantes = false;
  bool _enCours = false;
  String? _erreur;

  TypeVehicule? get _vehicule => _moto == null ? null : (_moto! ? TypeVehicule.moto : TypeVehicule.velo);
  List<TypeDocument> get _requis => documentsRequis(_vehicule, permis: _permis);

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
    final requis = _requis;
    final refus = refusVehicule(moto: _moto, permis: _permis);
    setState(() {
      _erreur = refus;
      _reponsesManquantes = _moto == null || _permis == null;
      _manquants
        ..clear()
        ..addAll(requis.where((t) => !_choisis.containsKey(t) && !_depose(t)));
    });
    final champsOk = _formulaire.currentState!.validate();
    if (!champsOk || refus != null || _reponsesManquantes || _manquants.isNotEmpty) return;
    setState(() => _enCours = true);
    try {
      await Dependances.of(context).livreur.envoyerCandidature(
            vehicule: _vehicule!,
            immatriculation: _moto == true ? _immatriculation.text.trim().toUpperCase() : null,
            // un document choisi puis devenu inutile (réponse changée) n'est pas envoyé
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
    final refus = refusVehicule(moto: _moto, permis: _permis);
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
            QuestionOuiNon(
              question: 'Avez-vous une moto ?',
              aide: 'Sinon, vous livrerez à vélo.',
              reponse: _moto,
              manquante: _reponsesManquantes && _moto == null,
              onChanged: (oui) => setState(() {
                _moto = oui;
                _manquants.clear();
                _erreur = null;
              }),
            ),
            const SizedBox(height: 16),
            QuestionOuiNon(
              question: 'Avez-vous un permis de conduire ?',
              reponse: _permis,
              manquante: _reponsesManquantes && _permis == null,
              onChanged: (oui) => setState(() {
                _permis = oui;
                _manquants.clear();
                _erreur = null;
              }),
            ),
            if (refus != null) ...[const SizedBox(height: 10), MessageErreur(refus)],
            if (_moto == true) ...[
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
            for (final t in _requis) ...[
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
            if (_erreur != null && _erreur != refus) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
            const SizedBox(height: 20),
            BoutonRelief.harissa(libelle: 'Envoyer ma candidature', enCours: _enCours, onPressed: _envoyer),
          ],
        ),
      ),
    );
  }
}

/// Question à deux réponses (« Oui » / « Non ») de la candidature.
class QuestionOuiNon extends StatelessWidget {
  const QuestionOuiNon({
    super.key,
    required this.question,
    required this.reponse,
    required this.onChanged,
    this.aide,
    this.manquante = false,
  });
  final String question;
  final String? aide;
  final bool? reponse;
  final bool manquante;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(question, style: textes.titleMedium)),
        if (aide != null) Text(aide!, style: textes.bodyMedium?.copyWith(fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final (oui, libelle) in [(true, 'Oui'), (false, 'Non')])
            ChoiceChip(
              label: Text(libelle, semanticsLabel: '$question $libelle'),
              selected: reponse == oui,
              onSelected: (_) => onChanged(oui),
            ),
        ]),
        if (manquante)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Répondez à cette question.', style: TextStyle(color: Couleurs.erreur, fontSize: 13)),
          ),
      ],
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
