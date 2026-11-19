import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/catalogue.dart';
import '../widgets/composants.dart';
import 'noter_page.dart';

/// Suivi d'une commande en temps réel (maquettes « Client · Suivi » et
/// « Client · Commande refusée », US20) : l'état change sans action du client.
class SuiviPage extends StatefulWidget {
  const SuiviPage({super.key, required this.commandeId});
  final String commandeId;

  @override
  State<SuiviPage> createState() => _SuiviPageState();
}

class _SuiviPageState extends State<SuiviPage> {
  CommandeClient? _commande;
  String? _erreur; // action refusée (annulation…)
  String? _erreurChargement;
  void Function()? _desabonner;
  Timer? _relecture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_desabonner != null) return;
    final mida = Dependances.of(context).mida;
    _charger();
    // Chaque événement relit la commande (plusieurs événements rapprochés : une seule lecture).
    _desabonner = mida.surCommande(widget.commandeId, () {
      _relecture?.cancel();
      _relecture = Timer(const Duration(milliseconds: 300), _charger);
    });
  }

  @override
  void dispose() {
    _relecture?.cancel();
    _desabonner?.call();
    super.dispose();
  }

  Future<void> _charger() async {
    final mida = Dependances.of(context).mida;
    try {
      final c = await mida.commande(widget.commandeId);
      if (mounted) {
        setState(() {
          _commande = c;
          _erreurChargement = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreurChargement = messageErreur(e));
    }
  }

  bool _annulationEnCours = false;

  /// Annulation (US21) : seulement tant que le restaurant n'a pas accepté, après confirmation.
  Future<void> _annuler(CommandeClient c) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Annuler la commande n° ${c.numero} ?'),
        content: Text('${c.restaurantNom} ne l\'a pas encore acceptée : elle sera annulée et le restaurant prévenu.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Garder ma commande')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Couleurs.harissa),
            child: const Text('Annuler la commande'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    final mida = Dependances.of(context).mida;
    setState(() {
      _annulationEnCours = true;
      _erreur = null;
    });
    try {
      await mida.annulerCommande(c.id);
    } catch (e) {
      // par exemple : le restaurant vient de l'accepter
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _annulationEnCours = false);
      // relecture directe, sans attendre l'événement temps réel
      await _charger();
    }
  }

  /// Avis après la livraison (US38).
  Future<void> _noter(CommandeClient c) async {
    final note = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NoterPage(commande: c)),
    );
    if (note != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci pour votre avis !')));
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final c = _commande;
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text(c == null ? 'Votre commande' : 'Commande n° ${c.numero}', style: textes.titleLarge),
      ),
      body: c == null
          ? Center(
              child: _erreurChargement != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        MessageErreur(_erreurChargement!),
                        TextButton(onPressed: _charger, child: const Text('Réessayer')),
                      ]),
                    )
                  : const CircularProgressIndicator(semanticsLabel: 'Chargement de la commande'),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(c.restaurantNom, style: textes.bodyMedium),
                  Text(
                    'Passée le ${formaterDate(c.creeeLe)} à ${formaterHeure(c.creeeLe)}',
                    style: textes.bodyMedium?.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    liveRegion: true,
                    child: Text(c.etat.titre, style: textes.headlineMedium),
                  ),
                  const SizedBox(height: 16),
                  if (c.etat == EtatCommande.refusee)
                    _Refus(commande: c)
                  else if (c.etat == EtatCommande.annulee)
                    _Annulation(commande: c)
                  else
                    _Etapes(commande: c),
                  if (c.etat == EtatCommande.livree) ...[
                    const SizedBox(height: 16),
                    _Avis(commande: c, surNoter: () => _noter(c)),
                  ],
                  if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
                  if (c.etat == EtatCommande.enAttente) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _annulationEnCours ? null : () => _annuler(c),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Annuler la commande'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Couleurs.harissa,
                        side: const BorderSide(color: Couleurs.harissa, width: 2),
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Possible tant que le restaurant n\'a pas accepté votre commande.',
                      style: textes.bodyMedium?.copyWith(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _Detail(commande: c),
                ],
              ),
            ),
    );
  }
}

/// Étapes franchies (avec leur heure) et étape actuelle.
class _Etapes extends StatelessWidget {
  const _Etapes({required this.commande});
  final CommandeClient commande;

  @override
  Widget build(BuildContext context) {
    final etapes = etapesSuivi(commande);
    return _Carte(
      child: Column(
        children: [
          for (final (i, e) in etapes.indexed)
            Semantics(
              container: true,
              label: '${e.libelle}${e.franchie ? ', étape franchie' : ', à venir'}${e.actuelle ? ', étape actuelle' : ''}',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: e.franchie ? (e.actuelle ? Couleurs.harissa : Couleurs.succes) : Colors.white,
                          border: Border.all(color: e.franchie ? Colors.transparent : Couleurs.bordure, width: 2),
                        ),
                        child: e.franchie && !e.actuelle
                            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                            : null,
                      ),
                      if (i < etapes.length - 1)
                        Container(width: 2, height: 26, color: etapes[i + 1].franchie ? Couleurs.succes : Couleurs.bordure),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        e.libelle,
                        style: TextStyle(
                          fontWeight: e.actuelle ? FontWeight.w700 : FontWeight.w500,
                          color: e.franchie ? Couleurs.nuit : Couleurs.texteDoux,
                        ),
                      ),
                    ),
                  ),
                  if (e.heure != null)
                    Text(formaterHeure(e.heure!), style: const TextStyle(color: Couleurs.texteDoux, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Avis du client (US38) : invitation à noter, ou rappel des notes données.
class _Avis extends StatelessWidget {
  const _Avis({required this.commande, required this.surNoter});
  final CommandeClient commande;
  final VoidCallback surNoter;

  static String _etoiles(int n) => '${'★' * n}${'☆' * (5 - n)}';

  @override
  Widget build(BuildContext context) {
    final c = commande;
    if (c.aNoter) {
      return _Carte(
        couleur: const Color(0xFFFFF6DE),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Bon appétit !', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Couleurs.nuit)),
            const SizedBox(height: 4),
            Text(
              'Donnez votre avis sur ${c.restaurantNom}${c.livreurNom == null ? '' : ' et votre livreur'} : '
              'il aide les autres clients.',
              style: const TextStyle(color: Couleurs.texteDoux),
            ),
            const SizedBox(height: 12),
            BoutonRelief(libelle: 'Noter la commande', onPressed: surNoter),
          ],
        ),
      );
    }
    final noteResto = c.noteRestaurant!;
    final noteLivreur = c.noteLivreur;
    return _Carte(
      child: Semantics(
        container: true,
        label: 'Votre avis : $noteResto sur 5 pour ${c.restaurantNom}'
            '${noteLivreur == null ? '' : ', $noteLivreur sur 5 pour le livreur'}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Merci pour votre avis', style: TextStyle(fontWeight: FontWeight.w700, color: Couleurs.nuit)),
            const SizedBox(height: 4),
            Text('${_etoiles(noteResto)}  ${c.restaurantNom}', style: const TextStyle(color: Couleurs.texteDoux)),
            if (noteLivreur != null)
              Text('${_etoiles(noteLivreur)}  Livreur', style: const TextStyle(color: Couleurs.texteDoux)),
          ],
        ),
      ),
    );
  }
}

/// Commande refusée : motif du restaurant, remboursement éventuel.
class _Refus extends StatelessWidget {
  const _Refus({required this.commande});
  final CommandeClient commande;

  @override
  Widget build(BuildContext context) {
    final c = commande;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Carte(
          couleur: const Color(0xFFFBE9E5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${c.restaurantNom} n\'a pas pu accepter votre commande.',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.harissaFonce)),
              const SizedBox(height: 8),
              const Text('Motif indiqué par le restaurant', style: TextStyle(fontSize: 13, color: Couleurs.texteDoux)),
              Text('« ${c.motifRefus ?? 'Non précisé'} »', style: const TextStyle(fontSize: 15, color: Couleurs.nuit)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          c.rembourse
              ? '${formaterPrix(c.total)} remboursés : le remboursement sur votre carte est lancé.'
              : 'Vous n\'avez rien payé : aucun remboursement n\'est nécessaire.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        BoutonRelief(
          libelle: 'Trouver un autre restaurant',
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ],
    );
  }
}

class _Annulation extends StatelessWidget {
  const _Annulation({required this.commande});
  final CommandeClient commande;

  @override
  Widget build(BuildContext context) {
    final heure = commande.annuleeLe;
    return _Carte(
      child: Text(
        'Vous avez annulé cette commande${heure == null ? '' : ' à ${formaterHeure(heure)}'}. '
        'Le restaurant a été prévenu.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

/// Plats, adresse, paiement et montants.
class _Detail extends StatelessWidget {
  const _Detail({required this.commande});
  final CommandeClient commande;

  @override
  Widget build(BuildContext context) {
    final c = commande;
    Widget montant(String libelle, double valeur, {bool fort = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(libelle, style: TextStyle(fontWeight: fort ? FontWeight.w700 : FontWeight.w400))),
            Text(formaterPrix(valeur), style: TextStyle(fontWeight: fort ? FontWeight.w700 : FontWeight.w400)),
          ]),
        );
    return _Carte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in c.lignes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${l.quantite} × ${l.nomPlat}')),
                Text(formaterPrix(l.prixUnitaire * l.quantite)),
              ]),
            ),
          const Divider(height: 20),
          montant('Sous-total', c.sousTotal),
          montant('Frais de livraison', c.fraisLivraison),
          montant('Total', c.total, fort: true),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.place_outlined, size: 18, color: Couleurs.texteDoux),
            const SizedBox(width: 6),
            Expanded(child: Text(c.adresse, style: const TextStyle(color: Couleurs.texteDoux))),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            Pastille(
              c.paiementMode == 'carte' ? 'Carte' : 'Espèces à la livraison',
              couleur: const Color(0xFFE6EEFB),
              texte: Couleurs.bleuFonce,
            ),
          ]),
          if (c.remarque != null) ...[
            const SizedBox(height: 8),
            Text('Remarque : ${c.remarque}', style: const TextStyle(color: Couleurs.texteDoux, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.child, this.couleur = Colors.white});
  final Widget child;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Couleurs.bordure, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }
}
