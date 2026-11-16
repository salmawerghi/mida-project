import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../auth/service_auth.dart';
import '../dependances.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/catalogue.dart';
import '../widgets/composants.dart';
import 'connexion_page.dart';
import 'inscription_page.dart';
import 'restaurant_page.dart';

/// Accueil : le catalogue des restaurants (maquette « Client · Accueil »,
/// US15), avec recherche par nom et filtre par catégorie (US16). Ouvert aussi aux visiteurs sans compte : la connexion n'est
/// demandée qu'au moment de commander.
class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key, required this.auth, this.visiteur = false});
  final ServiceAuth auth;
  final bool visiteur;

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  List<RestaurantCatalogue>? _restaurants;
  List<CategorieRestaurant> _categories = const [];
  String? _erreur;
  bool _premierChargement = true;
  final _recherche = TextEditingController();
  String? _categorieId;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _effacerFiltres() {
    _recherche.clear();
    setState(() => _categorieId = null);
  }

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
      final restaurants = await mida.restaurants();
      // Le filtre par catégorie est un plus : sans lui, le catalogue reste utilisable.
      final categories = await mida.categoriesRestaurant().catchError((_) => <CategorieRestaurant>[]);
      if (mounted) {
        setState(() {
          _restaurants = restaurants;
          // seules les catégories qui ont au moins un restaurant servent de filtre
          _categories = [
            for (final k in categories)
              if (restaurants.any((r) => r.categorieId == k.id)) k,
          ];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final tous = _restaurants;
    final restaurants =
        tous == null ? null : filtrerRestaurants(tous, recherche: _recherche.text, categorieId: _categorieId);
    final filtre = _recherche.text.trim().isNotEmpty || _categorieId != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        automaticallyImplyLeading: widget.visiteur,
        titleSpacing: widget.visiteur ? 0 : 20,
        title: Row(
          children: [
            const LogoMida(taille: 32),
            const SizedBox(width: 8),
            Text('Mida', style: textes.titleLarge?.copyWith(fontSize: 24)),
          ],
        ),
        actions: [
          if (!widget.visiteur)
            IconButton(
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout_rounded, color: Couleurs.nuit),
              onPressed: widget.auth.deconnecter,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              widget.visiteur ? 'Bienvenue !' : 'Bonjour, ${widget.auth.nomAffiche}',
              style: textes.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text('Qu\'est-ce qu\'on mange aujourd\'hui ?', style: textes.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _recherche,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Rechercher un restaurant',
                hintText: 'Dar Zitouna, couscous…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _recherche.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_recherche.clear),
                      ),
              ),
            ),
            if (_categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (id, nom) in [(null, 'Tous'), for (final k in _categories) (k.id, k.nom)])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(nom),
                          selected: _categorieId == id,
                          onSelected: (_) => setState(() => _categorieId = id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Restaurants', style: textes.headlineSmall?.copyWith(fontSize: 22)),
            const SizedBox(height: 12),
            if (_erreur != null) ...[
              MessageErreur(_erreur!),
              const SizedBox(height: 12),
              Center(child: TextButton(onPressed: _charger, child: const Text('Réessayer'))),
            ] else if (restaurants == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(semanticsLabel: 'Chargement des restaurants')),
              )
            else if (restaurants.isEmpty && filtre) ...[
              Text(
                _recherche.text.trim().isEmpty
                    ? 'Aucun restaurant dans cette catégorie pour le moment.'
                    : 'Aucun restaurant ne correspond à « ${_recherche.text.trim()} ».',
                style: textes.bodyMedium,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: _effacerFiltres, child: const Text('Effacer les filtres')),
              ),
            ] else if (restaurants.isEmpty)
              Text('Aucun restaurant pour le moment. Revenez bientôt !', style: textes.bodyMedium)
            else
              for (final r in restaurants) ...[
                CarteRestaurant(
                  restaurant: r,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => RestaurantPage(restaurant: r)),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            if (widget.visiteur) ...[
              const SizedBox(height: 16),
              Text(
                'Vous découvrez Mida sans compte : la connexion sera demandée pour valider la commande.',
                style: textes.bodyMedium,
              ),
              const SizedBox(height: 16),
              BoutonRelief.harissa(
                libelle: 'Créer un compte',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => InscriptionPage(auth: widget.auth)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ConnexionPage(auth: widget.auth)),
                ),
                child: const Text('J\'ai déjà un compte'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
