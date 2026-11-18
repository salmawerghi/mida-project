import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../dependances.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Candidature envoyée, en attente de validation par l'administrateur
/// (maquette « Livreur · Attente », US25) ; ou candidature refusée.
class AttentePage extends StatefulWidget {
  const AttentePage({super.key, required this.etat, required this.actualiser});
  final EtatLivreur etat;
  final Future<void> Function() actualiser;

  @override
  State<AttentePage> createState() => _AttentePageState();
}

class _AttentePageState extends State<AttentePage> {
  bool _enCours = false;

  Future<void> _actualiser() async {
    setState(() => _enCours = true);
    try {
      await widget.actualiser();
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final e = widget.etat;
    final refuse = e.etatCompte == 'rejete';
    final bloque = e.etatCompte == 'bloque';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            Center(child: SvgPicture.asset('assets/illustrations/the.svg', width: 120, height: 120)),
            const SizedBox(height: 16),
            Text(
              bloque ? 'Compte suspendu' : refuse ? 'Candidature non retenue' : 'En attente de validation',
              style: textes.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              bloque
                  ? 'Votre compte a été suspendu par l\'équipe Mida. Contactez le support pour en savoir plus.'
                  : refuse
                  ? 'Désolés ${e.prenom}, votre candidature n\'a pas été acceptée. '
                      'Contactez le support Mida pour en savoir plus.'
                  : 'Merci ${e.prenom}, votre candidature est envoyée. Un administrateur vérifie vos documents : '
                      'votre compte sera activé dès qu\'ils seront validés.',
              style: textes.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (!refuse && !bloque) ...[
              const SizedBox(height: 20),
              _Etape(libelle: 'Candidature reçue', faite: true),
              _Etape(libelle: 'Vérification des documents', faite: false, actuelle: true),
              _Etape(libelle: 'Compte activé', faite: false),
            ],
            const SizedBox(height: 20),
            Semantics(header: true, child: Text('Vos documents', style: textes.titleMedium)),
            const SizedBox(height: 8),
            for (final t in e.documentsDemandes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(t.libelle)),
                  Text(
                    switch (e.documents[t.code]) {
                      'valide' => 'Validé',
                      'refuse' => 'Refusé',
                      null => 'Manquant',
                      _ => 'En vérification',
                    },
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: switch (e.documents[t.code]) {
                        'valide' => Couleurs.succes,
                        'refuse' || null => Couleurs.erreur,
                        _ => Couleurs.texteDoux,
                      },
                    ),
                  ),
                ]),
              ),
            if (e.typeVehicule != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Véhicule : ${e.typeVehicule!.libelle}${e.immatriculation == null ? '' : ' · ${e.immatriculation}'}',
                  style: textes.bodyMedium?.copyWith(fontSize: 13),
                ),
              ),
            const SizedBox(height: 24),
            if (!refuse && !bloque) BoutonRelief(libelle: 'Actualiser', enCours: _enCours, onPressed: _actualiser),
            const SizedBox(height: 8),
            TextButton(onPressed: Dependances.of(context).auth.deconnecter, child: const Text('Se déconnecter')),
          ],
        ),
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  const _Etape({required this.libelle, required this.faite, this.actuelle = false});
  final String libelle;
  final bool faite;
  final bool actuelle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$libelle${faite ? ', fait' : actuelle ? ', en cours' : ', à venir'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(
            faite ? Icons.check_circle_rounded : actuelle ? Icons.hourglass_top_rounded : Icons.radio_button_unchecked,
            color: faite ? Couleurs.succes : actuelle ? Couleurs.harissa : Couleurs.bordure,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(libelle, style: TextStyle(fontWeight: actuelle ? FontWeight.w700 : FontWeight.w500))),
        ]),
      ),
    );
  }
}
