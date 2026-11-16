import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/catalogue.dart';
import '../widgets/composants.dart';

/// Menu d'un restaurant, classé par rubriques (maquette « Client · Restaurant », US17).
class RestaurantPage extends StatefulWidget {
  const RestaurantPage({super.key, required this.restaurant});
  final RestaurantCatalogue restaurant;

  @override
  State<RestaurantPage> createState() => _RestaurantPageState();
}

class _RestaurantPageState extends State<RestaurantPage> {
  MenuRestaurant? _menu;
  String? _erreur;
  bool _premierChargement = true;
  final _rubriques = <String, GlobalKey>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_premierChargement) {
      _premierChargement = false;
      _charger();
    }
  }

  Future<void> _charger() async {
    final mida = Dependances.of(context).mida;
    setState(() => _erreur = null);
    try {
      final menu = await mida.menu(widget.restaurant.id);
      if (mounted) setState(() => _menu = menu);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  /// Fait défiler le menu jusqu'à la rubrique choisie.
  void _allerA(String categorieId) {
    final cible = _rubriques[categorieId]?.currentContext;
    if (cible != null) Scrollable.ensureVisible(cible, duration: const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final textes = Theme.of(context).textTheme;
    final menu = _menu;
    final rubriques = menu?.rubriques ?? const [];
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _charger,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 190,
              backgroundColor: Couleurs.bleu,
              foregroundColor: Colors.white,
              title: Text(r.nom, style: textes.titleLarge?.copyWith(color: Colors.white)),
              flexibleSpace: FlexibleSpaceBar(
                background: MotifEtoiles(
                  child: Align(
                    alignment: const Alignment(0, 0.55),
                    child: ImageMida(url: r.logoUrl, nom: r.nom, taille: 96, rayon: 48),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              sliver: SliverList.list(
                children: [
                  _Infos(restaurant: r, horaire: menu?.horaire),
                  if (!r.ouvert) ...[
                    const SizedBox(height: 14),
                    const _Bandeau(
                      'Ce restaurant est fermé pour le moment : vous pouvez consulter son menu, '
                      'mais pas commander.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (rubriques.length > 1)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (c, _) in rubriques)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(label: Text(c.nom), onPressed: () => _allerA(c.id)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (_erreur != null)
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.list(children: [
                  MessageErreur(_erreur!),
                  Center(child: TextButton(onPressed: _charger, child: const Text('Réessayer'))),
                ]),
              )
            else if (menu == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(semanticsLabel: 'Chargement du menu')),
              )
            else if (rubriques.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverToBoxAdapter(
                  child: Text('Ce restaurant n\'a pas encore publié son menu.', style: textes.bodyMedium),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                sliver: SliverList.list(
                  children: [
                    for (final (c, plats) in rubriques) ...[
                      Padding(
                        key: _rubriques.putIfAbsent(c.id, GlobalKey.new),
                        padding: const EdgeInsets.only(top: 12, bottom: 10),
                        child: Semantics(header: true, child: Text(c.nom, style: textes.headlineSmall?.copyWith(fontSize: 22))),
                      ),
                      for (final p in plats) ...[
                        CartePlat(plat: p),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Note, délai et ouverture du restaurant.
class _Infos extends StatelessWidget {
  const _Infos({required this.restaurant, this.horaire});
  final RestaurantCatalogue restaurant;
  final HoraireDuJour? horaire;

  @override
  Widget build(BuildContext context) {
    Widget bloc(Widget haut, String bas) => Expanded(
          child: Column(
            children: [
              haut,
              const SizedBox(height: 2),
              Text(bas, style: const TextStyle(fontSize: 12, color: Couleurs.texteDoux)),
            ],
          ),
        );
    final ouverture = libelleOuverture(ouvert: restaurant.ouvert, horaire: horaire);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Couleurs.bordure, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          bloc(
            NoteRestaurant(note: restaurant.note, nbAvis: restaurant.nbAvis, compact: true),
            restaurant.nbAvis == 0 ? 'Note' : '${restaurant.nbAvis} avis',
          ),
          bloc(Text(restaurant.delai, style: const TextStyle(fontWeight: FontWeight.w700)), 'Livraison'),
          bloc(
            Text(
              ouverture.split(' · ').first,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: restaurant.ouvert ? Couleurs.succes : Couleurs.harissaFonce,
              ),
            ),
            ouverture.contains(' · ') ? ouverture.split(' · ').last : 'Aujourd\'hui',
          ),
        ],
      ),
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1C3B9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.storefront_outlined, color: Couleurs.harissaFonce),
          const SizedBox(width: 10),
          Expanded(child: Text(texte, style: const TextStyle(color: Couleurs.harissaFonce, fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}

/// Plat du menu : photo, nom, description, prix ; « Indisponible » s'il est épuisé.
/// [action] : le bouton d'ajout au panier (US18).
class CartePlat extends StatelessWidget {
  const CartePlat({super.key, required this.plat, this.action});
  final Plat plat;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = plat;
    return Semantics(
      label: 'Plat ${p.nom}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.disponible ? Colors.white : const Color(0xFFEDF1F8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Couleurs.bordure, offset: Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(opacity: p.disponible ? 1 : 0.5, child: ImageMida(url: p.imageUrl, nom: p.nom, taille: 72)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Couleurs.nuit)),
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(p.description, style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux, height: 1.35)),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formaterPrix(p.prix),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: p.disponible ? Couleurs.bleu : Couleurs.texteDoux,
                        ),
                      ),
                      if (!p.disponible)
                        const Pastille('Indisponible', couleur: Color(0xFFFBE9E5), texte: Couleurs.harissaFonce),
                    ],
                  ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action!],
          ],
        ),
      ),
    );
  }
}
