import 'package:flutter/material.dart';

import '../dependances.dart';
import '../donnees/format.dart';
import '../panier/panier.dart';
import '../theme.dart';
import '../widgets/catalogue.dart';
import '../widgets/panier_widgets.dart';

/// Panier (maquette « Client · Panier », US18) : quantités modifiables, total à jour.
class PanierPage extends StatelessWidget {
  const PanierPage({super.key});

  @override
  Widget build(BuildContext context) {
    final panier = Dependances.of(context).panier;
    final textes = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: panier,
      builder: (context, _) {
        final restaurant = panier.restaurant;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Couleurs.fond,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Votre panier', style: textes.titleLarge),
                if (restaurant != null)
                  Text(
                    '${restaurant.nom} · ${libelleArticles(panier.nbArticles)}',
                    style: textes.bodyMedium?.copyWith(fontSize: 13),
                  ),
              ],
            ),
            actions: [
              if (!panier.estVide)
                TextButton(
                  onPressed: () => _confirmerVidage(context, panier),
                  style: TextButton.styleFrom(foregroundColor: Couleurs.harissa),
                  child: const Text('Vider'),
                ),
            ],
          ),
          body: panier.estVide
              ? _PanierVide()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    for (final l in panier.lignes) ...[
                      _Ligne(ligne: l),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    _Montant('Sous-total', panier.sousTotal, fort: true),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _confirmerVidage(BuildContext context, Panier panier) async {
    final vider = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les plats seront retirés.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Couleurs.harissa),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (vider == true) panier.vider();
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.ligne});
  final LignePanier ligne;

  @override
  Widget build(BuildContext context) {
    final panier = Dependances.of(context).panier;
    final p = ligne.plat;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Couleurs.bordure, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          ImageMida(url: p.imageUrl, nom: p.nom, taille: 56, rayon: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.nuit)),
                Text(formaterPrix(ligne.total), style: const TextStyle(color: Couleurs.bleu, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Quantite(
            nom: p.nom,
            quantite: ligne.quantite,
            onMoins: () => panier.retirer(p.id),
            onPlus: ligne.quantite >= Panier.quantiteMax ? null : () => panier.ajouter(panier.restaurant!, p),
          ),
        ],
      ),
    );
  }
}

class _Montant extends StatelessWidget {
  const _Montant(this.libelle, this.montant, {this.fort = false});
  final String libelle;
  final double montant;
  final bool fort;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fort ? 18 : 15,
      fontWeight: fort ? FontWeight.w700 : FontWeight.w500,
      color: fort ? Couleurs.nuit : Couleurs.texteDoux,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(libelle, style: style)),
          Text(formaterPrix(montant), style: style),
        ],
      ),
    );
  }
}

class _PanierVide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 64, color: Couleurs.bordure),
            const SizedBox(height: 12),
            Text('Votre panier est vide', style: textes.titleLarge),
            const SizedBox(height: 6),
            Text('Choisissez un restaurant et ajoutez vos plats.', style: textes.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Découvrir les restaurants'),
            ),
          ],
        ),
      ),
    );
  }
}
