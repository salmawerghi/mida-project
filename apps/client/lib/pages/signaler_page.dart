import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Signaler un problème sur une commande livrée (US49) : un motif, une
/// description facultative ; Mida répond par une notification. Renvoie
/// `true` une fois la réclamation envoyée.
class SignalerPage extends StatefulWidget {
  const SignalerPage({super.key, required this.commande});
  final CommandeClient commande;

  @override
  State<SignalerPage> createState() => _SignalerPageState();
}

class _SignalerPageState extends State<SignalerPage> {
  String? _motif;
  final _description = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final motif = _motif;
    if (motif == null) {
      setState(() => _erreur = 'Choisissez le problème rencontré.');
      return;
    }
    if (motif == 'Autre problème' && _description.text.trim().isEmpty) {
      setState(() => _erreur = 'Décrivez le problème en quelques mots.');
      return;
    }
    final mida = Dependances.of(context).mida;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await mida.signalerProbleme(widget.commande.id, motif: motif, description: _description.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final c = widget.commande;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text('Signaler un problème', style: textes.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Commande n° ${c.numero} · ${c.restaurantNom}', style: textes.bodyMedium),
            const SizedBox(height: 16),
            Semantics(header: true, child: Text('Quel est le problème ?', style: textes.titleMedium)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _motif,
              onChanged: (v) => setState(() {
                _motif = v;
                _erreur = null;
              }),
              child: Column(
                children: [
                  for (final m in motifsReclamation)
                    RadioListTile<String>(value: m, title: Text(m), contentPadding: EdgeInsets.zero),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              maxLength: 1000,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Détails',
                hintText: 'Par exemple : il manquait un fricassé.',
              ),
            ),
            if (_erreur != null) ...[const SizedBox(height: 8), MessageErreur(_erreur!)],
            const SizedBox(height: 16),
            BoutonRelief.harissa(libelle: 'Envoyer à Mida', enCours: _enCours, onPressed: _enCours ? null : _envoyer),
            const SizedBox(height: 8),
            Text(
              'L\'équipe Mida étudie votre demande et vous répond par une notification. '
              'Un remboursement peut être accordé.',
              style: textes.bodyMedium?.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
