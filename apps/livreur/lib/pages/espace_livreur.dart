import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/modeles.dart';
import '../widgets/composants.dart';
import 'attente_page.dart';
import 'courses_page.dart';
import 'documents_page.dart';

/// Espace du livreur connecté : l'écran dépend de l'état de son compte.
///  • candidature incomplète (véhicule ou documents manquants) → documents (étape 2)
///  • en attente de validation, ou refusé → écran d'attente
///  • validé → courses
class EspaceLivreur extends StatefulWidget {
  const EspaceLivreur({super.key});

  @override
  State<EspaceLivreur> createState() => _EspaceLivreurState();
}

class _EspaceLivreurState extends State<EspaceLivreur> {
  EtatLivreur? _etat;
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
    final livreur = Dependances.of(context).livreur;
    setState(() => _erreur = null);
    try {
      final etat = await livreur.monEtat();
      if (mounted) setState(() => _etat = etat);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = _etat;
    if (etat == null) {
      return Scaffold(
        body: Center(
          child: _erreur != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    MessageErreur(_erreur!),
                    TextButton(onPressed: _charger, child: const Text('Réessayer')),
                    TextButton(
                      onPressed: Dependances.of(context).auth.deconnecter,
                      child: const Text('Se déconnecter'),
                    ),
                  ]),
                )
              : const CircularProgressIndicator(semanticsLabel: 'Chargement de votre compte'),
        ),
      );
    }
    if (etat.actif) return CoursesPage(etat: etat, recharger: _charger);
    if (etat.etatCompte == 'en_attente' && !etat.candidatureComplete) {
      return DocumentsPage(etat: etat, apresEnvoi: _charger);
    }
    return AttentePage(etat: etat, actualiser: _charger);
  }
}
