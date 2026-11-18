import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/catalogue.dart';
import '../widgets/composants.dart';
import 'suivi_page.dart';

/// Historique des commandes du client (maquette « Client · Mes commandes », US22) :
/// les commandes en cours puis les commandes passées, de la plus récente à la plus
/// ancienne. Un toucher ouvre le détail (l'écran de suivi, qui montre aussi les
/// commandes terminées).
class HistoriquePage extends StatefulWidget {
  const HistoriquePage({super.key});

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  List<CommandeClient>? _commandes;
  String? _erreur;
  bool _premierChargement = true;

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
      final commandes = await mida.mesCommandes();
      if (mounted) setState(() => _commandes = commandes);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _ouvrir(CommandeClient c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SuiviPage(commandeId: c.id)));
    // l'état a pu changer pendant la consultation (acceptée, annulée…)
    if (mounted) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final commandes = _commandes;
    final enCours = [for (final c in commandes ?? const <CommandeClient>[]) if (c.etat.enCours) c];
    final passees = [for (final c in commandes ?? const <CommandeClient>[]) if (!c.etat.enCours) c];

    List<Widget> section(String titre, List<CommandeClient> liste) => [
          const SizedBox(height: 12),
          Semantics(header: true, child: Text(titre, style: textes.titleMedium)),
          const SizedBox(height: 10),
          for (final c in liste) ...[
            CarteCommande(commande: c, onTap: () => _ouvrir(c)),
            const SizedBox(height: 12),
          ],
        ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text('Mes commandes', style: textes.titleLarge),
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (_erreur != null) ...[
              MessageErreur(_erreur!),
              const SizedBox(height: 12),
              Center(child: TextButton(onPressed: _charger, child: const Text('Réessayer'))),
            ] else if (commandes == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(semanticsLabel: 'Chargement de vos commandes')),
              )
            else if (commandes.isEmpty) ...[
              const SizedBox(height: 24),
              const Icon(Icons.receipt_long_rounded, size: 56, color: Couleurs.bordure),
              const SizedBox(height: 12),
              Text(
                'Vous n\'avez pas encore passé de commande.',
                style: textes.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Vos commandes apparaîtront ici, avec leur détail.',
                style: textes.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              BoutonRelief(
                libelle: 'Découvrir les restaurants',
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ] else ...[
              if (enCours.isNotEmpty) ...section('En cours', enCours),
              if (passees.isNotEmpty) ...section('Commandes passées', passees),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une commande de l'historique : restaurant, date, nombre d'articles, total et état.
class CarteCommande extends StatelessWidget {
  const CarteCommande({super.key, required this.commande, required this.onTap});
  final CommandeClient commande;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = commande;
    final (libelle, fond, texte) = pastilleEtat(c);
    final articles = c.nbArticles <= 1 ? '${c.nbArticles} article' : '${c.nbArticles} articles';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Couleurs.bordure),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.restaurantNom,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Couleurs.nuit),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'n° ${c.numero} · ${formaterDate(c.creeeLe)} · $articles',
                      style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux),
                    ),
                    const SizedBox(height: 8),
                    Pastille(libelle, couleur: fond, texte: texte),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(formaterPrix(c.total), style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.nuit)),
              const Icon(Icons.chevron_right_rounded, color: Couleurs.texteDoux),
            ],
          ),
        ),
      ),
    );
  }
}

/// Libellé et couleurs de la pastille d'état (maquette : vert livrée, rouge refusée…).
(String, Color, Color) pastilleEtat(CommandeClient c) => switch (c.etat) {
      EtatCommande.livree => ('Livrée', const Color(0xFFE3F4EA), const Color(0xFF14552F)),
      EtatCommande.refusee => (
          c.rembourse ? 'Refusée · remboursée' : 'Refusée',
          const Color(0xFFFBE9E5),
          Couleurs.harissaFonce,
        ),
      EtatCommande.annulee => ('Annulée', const Color(0xFFEEF1F6), Couleurs.texteDoux),
      EtatCommande.enAttente => ('En attente', Couleurs.doreClair, const Color(0xFF6B4A00)),
      _ => (c.etat.titre, const Color(0xFFE6EEFB), Couleurs.bleuFonce),
    };
