import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Avis sur une commande livrée (US38) : le restaurant (obligatoire) et le
/// livreur (facultatif), de 1 à 5 étoiles, avec un commentaire facultatif.
/// Renvoie `true` à l'écran précédent une fois l'avis enregistré.
class NoterPage extends StatefulWidget {
  const NoterPage({super.key, required this.commande});
  final CommandeClient commande;

  @override
  State<NoterPage> createState() => _NoterPageState();
}

class _NoterPageState extends State<NoterPage> {
  int? _noteRestaurant;
  int? _noteLivreur;
  final _commentaireRestaurant = TextEditingController();
  final _commentaireLivreur = TextEditingController();
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _commentaireRestaurant.dispose();
    _commentaireLivreur.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final note = _noteRestaurant;
    if (note == null) {
      setState(() => _erreur = 'Choisissez une note de 1 à 5 étoiles pour le restaurant.');
      return;
    }
    final mida = Dependances.of(context).mida;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    String? texte(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await mida.noterCommande(
        widget.commande.id,
        noteRestaurant: note,
        commentaireRestaurant: texte(_commentaireRestaurant),
        noteLivreur: _noteLivreur,
        commentaireLivreur: _noteLivreur == null ? null : texte(_commentaireLivreur),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.commande;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text('Votre avis', style: textes.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Commande n° ${c.numero} livrée. Comment s\'est-elle passée ?', style: textes.bodyMedium),
            const SizedBox(height: 16),
            _Bloc(
              titre: c.restaurantNom,
              sousTitre: 'Les plats, la qualité, la quantité',
              note: _noteRestaurant,
              surNote: (n) => setState(() {
                _noteRestaurant = n;
                _erreur = null;
              }),
              sujet: 'le restaurant',
              commentaire: _commentaireRestaurant,
              indice: 'Ce que vous avez aimé, ce qui peut être amélioré…',
            ),
            if (c.livreurNom != null) ...[
              const SizedBox(height: 16),
              _Bloc(
                titre: 'Livreur : ${c.livreurNom}',
                sousTitre: 'Facultatif : rapidité, amabilité',
                note: _noteLivreur,
                surNote: (n) => setState(() => _noteLivreur = n),
                sujet: 'le livreur',
                commentaire: _commentaireLivreur,
                indice: 'Un mot pour le livreur (facultatif)',
                commentaireVisible: _noteLivreur != null,
              ),
            ],
            if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
            const SizedBox(height: 20),
            BoutonRelief(libelle: 'Envoyer mon avis', onPressed: _envoi ? null : _envoyer, enCours: _envoi),
            const SizedBox(height: 8),
            Text(
              'Votre avis est public : il aide les autres clients et le restaurant. Il ne peut plus être modifié ensuite.',
              style: textes.bodyMedium?.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  const _Bloc({
    required this.titre,
    required this.sousTitre,
    required this.note,
    required this.surNote,
    required this.sujet,
    required this.commentaire,
    required this.indice,
    this.commentaireVisible = true,
  });

  final String titre;
  final String sousTitre;
  final int? note;
  final ValueChanged<int> surNote;
  final String sujet;
  final TextEditingController commentaire;
  final String indice;
  final bool commentaireVisible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Couleurs.bordure, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Couleurs.nuit),
          ),
          Text(sousTitre, style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux)),
          const SizedBox(height: 8),
          Etoiles(note: note, surNote: surNote, sujet: sujet),
          if (commentaireVisible) ...[
            const SizedBox(height: 8),
            TextField(
              controller: commentaire,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: indice, labelText: 'Commentaire sur $sujet'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cinq étoiles à toucher ; chacune est un bouton annoncé « 3 étoiles sur 5 pour le restaurant ».
class Etoiles extends StatelessWidget {
  const Etoiles({super.key, required this.note, required this.surNote, required this.sujet});
  final int? note;
  final ValueChanged<int> surNote;
  final String sujet;

  static const _libelles = ['Très décevant', 'Décevant', 'Correct', 'Bien', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final n = note;
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i étoile${i > 1 ? 's' : ''} sur 5 pour $sujet',
            onPressed: () => surNote(i),
            isSelected: n != null && i <= n,
            icon: Icon(
              n != null && i <= n ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 34,
              color: n != null && i <= n ? Couleurs.dore : Couleurs.texteDoux,
            ),
            visualDensity: VisualDensity.compact,
          ),
        const SizedBox(width: 6),
        if (n != null)
          Flexible(
            child: Text(_libelles[n - 1], style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
