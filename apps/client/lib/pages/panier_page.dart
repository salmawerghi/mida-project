import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../panier/panier.dart';
import '../theme.dart';
import '../widgets/catalogue.dart';
import '../widgets/composants.dart';
import '../widgets/panier_widgets.dart';
import 'connexion_requise_page.dart';
import 'suivi_page.dart';

/// Panier (maquette « Client · Panier ») : quantités modifiables et total à
/// jour (US18), puis validation avec l'adresse de livraison et le paiement
/// en espèces (US19). Le total définitif est calculé par le serveur.
class PanierPage extends StatefulWidget {
  const PanierPage({super.key, this.apresCommande});

  /// Appelé quand la commande est enregistrée (par défaut : suivi de la commande, US20).
  final void Function(BuildContext context, CommandePassee commande)? apresCommande;

  @override
  State<PanierPage> createState() => _PanierPageState();
}

class _PanierPageState extends State<PanierPage> {
  final _formulaire = GlobalKey<FormState>();
  late final TextEditingController _adresse;
  late final TextEditingController _remarque;
  double? _frais;
  bool _enCours = false;
  String? _erreur;
  bool _initialise = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialise) return;
    _initialise = true;
    final d = Dependances.of(context);
    _adresse = TextEditingController(text: d.panier.adresse)..addListener(() => d.panier.adresse = _adresse.text);
    _remarque = TextEditingController(text: d.panier.remarque)..addListener(() => d.panier.remarque = _remarque.text);
    // Aperçu seulement : le serveur applique les frais en vigueur au moment de la commande.
    d.mida.fraisLivraison().then((f) {
      if (mounted) setState(() => _frais = f);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _adresse.dispose();
    _remarque.dispose();
    super.dispose();
  }

  Future<void> _commander() async {
    final d = Dependances.of(context);
    setState(() => _erreur = null);
    if (!_formulaire.currentState!.validate()) return;
    // Visiteur : la connexion est demandée maintenant ; le panier est gardé.
    if (d.auth.session == null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnexionRequisePage()));
      if (!mounted || d.auth.session == null) return;
    }
    final panier = d.panier;
    setState(() => _enCours = true);
    try {
      final commande = await d.mida.passerCommande(
        restaurantId: panier.restaurant!.id,
        lignes: panier.lignes,
        adresse: _adresse.text.trim(),
        remarque: _remarque.text.trim().isEmpty ? null : _remarque.text.trim(),
      );
      panier.vider();
      if (!mounted) return;
      (widget.apresCommande ?? _ouvrirSuivi)(context, commande);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  /// Retour à l'accueil (le panier et le menu ne servent plus), puis suivi de la commande.
  static void _ouvrirSuivi(BuildContext context, CommandePassee commande) {
    final navigateur = Navigator.of(context);
    navigateur.popUntil((r) => r.isFirst);
    navigateur.push(MaterialPageRoute(builder: (_) => SuiviPage(commandeId: commande.id)));
  }

  @override
  Widget build(BuildContext context) {
    final panier = Dependances.of(context).panier;
    final textes = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: panier,
      builder: (context, _) {
        final restaurant = panier.restaurant;
        final frais = _frais;
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
                  onPressed: _enCours ? null : () => _confirmerVidage(context, panier),
                  style: TextButton.styleFrom(foregroundColor: Couleurs.harissa),
                  child: const Text('Vider'),
                ),
            ],
          ),
          body: panier.estVide
              ? _PanierVide()
              : Form(
                  key: _formulaire,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      for (final l in panier.lignes) ...[
                        _Ligne(ligne: l, actif: !_enCours),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                      Text('Livraison', style: textes.titleLarge),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _adresse,
                        enabled: !_enCours,
                        maxLength: 300,
                        minLines: 1,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Adresse de livraison',
                          hintText: '12, rue du Jasmin, La Marsa',
                          prefixIcon: Icon(Icons.place_outlined),
                          counterText: '',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Indiquez l\'adresse de livraison.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarque,
                        enabled: !_enCours,
                        maxLength: 300,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Remarque pour le restaurant (facultatif)',
                          hintText: 'Sans piment, sonner deux fois…',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Paiement', style: textes.titleLarge),
                      const SizedBox(height: 8),
                      const _ModePaiement(
                        titre: 'Espèces',
                        detail: 'À payer au livreur, à la livraison',
                        icone: Icons.payments_outlined,
                        choisi: true,
                      ),
                      const SizedBox(height: 18),
                      _Montant('Sous-total', panier.sousTotal),
                      _Montant('Frais de livraison', frais),
                      const Divider(height: 20),
                      _Montant('Total', frais == null ? null : panier.sousTotal + frais, fort: true),
                      const SizedBox(height: 4),
                      Text(
                        'Le montant définitif est calculé par Mida à la validation.',
                        style: textes.bodyMedium?.copyWith(fontSize: 12),
                      ),
                      if (_erreur != null) ...[
                        const SizedBox(height: 14),
                        MessageErreur(_erreur!),
                      ],
                      const SizedBox(height: 18),
                      BoutonRelief(
                        libelle: frais == null
                            ? 'Commander'
                            : 'Commander · ${formaterPrix(panier.sousTotal + frais)}',
                        enCours: _enCours,
                        onPressed: _commander,
                      ),
                    ],
                  ),
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
  const _Ligne({required this.ligne, required this.actif});
  final LignePanier ligne;
  final bool actif;

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
          IgnorePointer(
            ignoring: !actif,
            child: Quantite(
              nom: p.nom,
              quantite: ligne.quantite,
              onMoins: () => panier.retirer(p.id),
              onPlus: ligne.quantite >= Panier.quantiteMax ? null : () => panier.ajouter(panier.restaurant!, p),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModePaiement extends StatelessWidget {
  const _ModePaiement({required this.titre, required this.detail, required this.icone, required this.choisi});
  final String titre;
  final String detail;
  final IconData icone;
  final bool choisi;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: choisi,
      enabled: choisi,
      label: '$titre, $detail',
      excludeSemantics: true,
      child: Opacity(
        opacity: choisi ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: choisi ? const Color(0xFFE6EEFB) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: choisi ? Couleurs.bleu : Couleurs.bordure, width: 2),
          ),
          child: Row(
            children: [
              Icon(icone, color: choisi ? Couleurs.bleu : Couleurs.texteDoux),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.nuit)),
                    Text(detail, style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux)),
                  ],
                ),
              ),
              Icon(
                choisi ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: choisi ? Couleurs.bleu : Couleurs.bordure,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Montant extends StatelessWidget {
  const _Montant(this.libelle, this.montant, {this.fort = false});
  final String libelle;
  final double? montant;
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
          Text(montant == null ? '…' : formaterPrix(montant!), style: style),
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
