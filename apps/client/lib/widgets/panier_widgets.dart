import 'package:flutter/material.dart';

import '../dependances.dart';
import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../pages/panier_page.dart';
import '../panier/panier.dart';
import '../theme.dart';

/// « + » pour ajouter un plat, puis « − 2 + » une fois au panier (maquette « Client · Restaurant »).
class AjoutPlat extends StatelessWidget {
  const AjoutPlat({super.key, required this.restaurant, required this.plat});
  final RestaurantCatalogue restaurant;
  final Plat plat;

  @override
  Widget build(BuildContext context) {
    final panier = Dependances.of(context).panier;
    return ListenableBuilder(
      listenable: panier,
      builder: (context, _) {
        final quantite = panier.restaurant?.id == restaurant.id ? panier.quantiteDe(plat.id) : 0;
        if (quantite == 0) {
          return IconButton.filled(
            tooltip: 'Ajouter ${plat.nom}',
            style: IconButton.styleFrom(backgroundColor: Couleurs.bleu, foregroundColor: Colors.white),
            icon: const Icon(Icons.add_rounded),
            onPressed: () => ajouterAuPanier(context, restaurant, plat),
          );
        }
        return Quantite(
          nom: plat.nom,
          quantite: quantite,
          onMoins: () => panier.retirer(plat.id),
          onPlus: quantite >= Panier.quantiteMax ? null : () => ajouterAuPanier(context, restaurant, plat),
        );
      },
    );
  }
}

/// Ajoute un plat ; si le panier contient les plats d'un autre restaurant, propose de le vider.
Future<void> ajouterAuPanier(BuildContext context, RestaurantCatalogue r, Plat plat) async {
  final panier = Dependances.of(context).panier;
  if (panier.ajouter(r, plat) != ResultatAjout.autreRestaurant) return;
  final autre = panier.restaurant?.nom ?? 'un autre restaurant';
  final remplacer = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Commencer un nouveau panier ?'),
      content: Text(
        'Votre panier contient des plats de $autre. Une commande ne peut venir que d\'un seul restaurant : '
        'pour ajouter ce plat de ${r.nom}, votre panier actuel sera vidé.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Garder mon panier')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Couleurs.harissa),
          child: const Text('Vider et ajouter'),
        ),
      ],
    ),
  );
  if (remplacer == true) panier.remplacerPar(r, plat);
}

/// « − 2 + »
class Quantite extends StatelessWidget {
  const Quantite({super.key, required this.nom, required this.quantite, required this.onMoins, required this.onPlus});
  final String nom;
  final int quantite;
  final VoidCallback onMoins;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final style = IconButton.styleFrom(
      backgroundColor: const Color(0xFFE6EEFB),
      foregroundColor: Couleurs.bleu,
      minimumSize: const Size(40, 40),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: quantite == 1 ? 'Retirer $nom du panier' : 'Un $nom de moins',
          style: style,
          icon: Icon(quantite == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, size: 20),
          onPressed: onMoins,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$quantite',
            textAlign: TextAlign.center,
            semanticsLabel: '$quantite $nom au panier',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        IconButton(
          tooltip: 'Un $nom de plus',
          style: style,
          icon: const Icon(Icons.add_rounded, size: 20),
          onPressed: onPlus,
        ),
      ],
    );
  }
}

/// Barre du bas : « Voir le panier · 3 articles · 41,000 DT ».
class BarrePanier extends StatelessWidget {
  const BarrePanier({super.key, this.restaurantId});

  /// Ne s'affiche que si le panier contient des plats de ce restaurant (`null` : n'importe lequel).
  final String? restaurantId;

  @override
  Widget build(BuildContext context) {
    final panier = Dependances.of(context).panier;
    return ListenableBuilder(
      listenable: panier,
      builder: (context, _) {
        if (panier.estVide || (restaurantId != null && panier.restaurant?.id != restaurantId)) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Material(
            color: Couleurs.bleu,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => ouvrirPanier(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        '${panier.nbArticles}',
                        style: const TextStyle(color: Couleurs.bleu, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Voir le panier',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    Text(
                      formaterPrix(panier.sousTotal),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icône « panier » de la barre du haut, avec le nombre d'articles.
class IconePanier extends StatelessWidget {
  const IconePanier({super.key});

  @override
  Widget build(BuildContext context) {
    final panier = Dependances.of(context).panier;
    return ListenableBuilder(
      listenable: panier,
      builder: (context, _) => IconButton(
        tooltip: panier.estVide ? 'Panier vide' : 'Panier : ${libelleArticles(panier.nbArticles)}',
        onPressed: () => ouvrirPanier(context),
        icon: Badge(
          isLabelVisible: !panier.estVide,
          label: Text('${panier.nbArticles}'),
          backgroundColor: Couleurs.harissa,
          child: const Icon(Icons.shopping_bag_outlined, color: Couleurs.nuit),
        ),
      ),
    );
  }
}

void ouvrirPanier(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PanierPage()));
