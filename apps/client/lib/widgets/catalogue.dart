import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../theme.dart';

/// Illustrations Mida utilisées quand un restaurant ou un plat n'a pas de photo.
const _illustrations = ['couscous', 'tajine', 'brik', 'ojja', 'the', 'bambalouni'];

/// Toujours la même illustration pour un même nom (pas de « clignotement » d'un écran à l'autre).
String illustrationPour(String nom) {
  final somme = nom.codeUnits.fold<int>(0, (s, c) => s + c);
  return 'assets/illustrations/${_illustrations[somme % _illustrations.length]}.svg';
}

/// Photo (logo, plat) téléchargée, ou illustration Mida si absente ou injoignable.
class ImageMida extends StatelessWidget {
  const ImageMida({super.key, required this.url, required this.nom, this.taille = 64, this.rayon = 16});
  final String? url;
  final String nom;
  final double taille;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    final secours = Padding(
      padding: EdgeInsets.all(taille * 0.12),
      child: SvgPicture.asset(illustrationPour(nom)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: Container(
        width: taille,
        height: taille,
        color: const Color(0xFFE6EEFB),
        child: url == null
            ? secours
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => secours),
      ),
    );
  }
}

/// Carte d'un restaurant dans le catalogue (maquette « Client · Accueil »).
class CarteRestaurant extends StatelessWidget {
  const CarteRestaurant({super.key, required this.restaurant, this.onTap});
  final RestaurantCatalogue restaurant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final textes = Theme.of(context).textTheme;
    final sousTitre = [if (r.categorie != null) r.categorie!, if (r.ville.isNotEmpty) r.ville].join(' · ');
    return Semantics(
      button: onTap != null,
      label: 'Restaurant ${r.nom}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Couleurs.bordure, offset: Offset(0, 5))],
            ),
            child: Opacity(
              opacity: r.ouvert ? 1 : 0.6,
              child: Row(
                children: [
                  ImageMida(url: r.logoUrl, nom: r.nom, taille: 76, rayon: 18),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.nom, style: textes.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (sousTitre.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(sousTitre, style: textes.bodyMedium?.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Pastille(
                              r.ouvert ? 'Ouvert' : 'Fermé',
                              couleur: r.ouvert ? const Color(0xFFE3F4EA) : const Color(0xFFFBE9E5),
                              texte: r.ouvert ? const Color(0xFF14552F) : Couleurs.harissaFonce,
                            ),
                            NoteRestaurant(note: r.note, nbAvis: r.nbAvis),
                            Text(r.delai, style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « ★ 4,8 (12 avis) », ou « Nouveau » sans avis.
class NoteRestaurant extends StatelessWidget {
  const NoteRestaurant({super.key, required this.note, required this.nbAvis, this.compact = false});
  final double? note;
  final int nbAvis;

  /// « ★ 4,8 » seulement (le nombre d'avis est affiché à part).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (note == null) {
      return const Text('Nouveau', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Couleurs.bleu));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 18, color: Couleurs.dore),
        const SizedBox(width: 2),
        Text(
          compact ? formaterNote(note!) : '${formaterNote(note!)} ($nbAvis avis)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Couleurs.nuit),
        ),
      ],
    );
  }
}

/// Petite étiquette arrondie (« Ouvert », « Indisponible »…).
class Pastille extends StatelessWidget {
  const Pastille(this.libelle, {super.key, required this.couleur, required this.texte});
  final String libelle;
  final Color couleur;
  final Color texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(999)),
      child: Text(libelle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: texte)),
    );
  }
}
