import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../donnees/service_livreur.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Course acceptée (maquettes « Livreur · Vers le restaurant » et « Course en
/// cours », US28) : 1. récupérer la commande quand elle est prête, 2. la remettre
/// au client (et encaisser les espèces, le cas échéant).
class CoursePage extends StatefulWidget {
  const CoursePage({super.key, required this.courseId});
  final String courseId;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  Course? _course;
  String? _erreurChargement;
  String? _erreur;
  bool _enCours = false;
  bool _especesRecues = false;
  void Function()? _desabonner;
  Timer? _attente;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_desabonner != null) return;
    _charger();
    // « Prête » chez le restaurant : le bouton s'active sans action du livreur.
    _desabonner = Dependances.of(context).livreur.surChangements(() {
      _attente?.cancel();
      _attente = Timer(const Duration(milliseconds: 300), _charger);
    });
  }

  @override
  void dispose() {
    _attente?.cancel();
    _desabonner?.call();
    super.dispose();
  }

  Future<void> _charger() async {
    if (!mounted) return;
    try {
      final c = await Dependances.of(context).livreur.course(widget.courseId);
      if (mounted) {
        setState(() {
          _course = c;
          _erreurChargement = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreurChargement = messageErreur(e));
    }
  }

  Future<void> _agir(Future<void> Function() action, {bool termine = false}) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await action();
      if (!mounted) return;
      if (termine) {
        final c = _course!;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LivreePage(course: c, remiseLe: DateTime.now())),
        );
        return;
      }
      await _charger();
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
      await _charger();
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final c = _course;
    final livreur = Dependances.of(context).livreur;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text(c == null ? 'Course' : 'Commande n° ${c.numero}', style: textes.titleLarge),
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
                  : const CircularProgressIndicator(semanticsLabel: 'Chargement de la course'),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _Etapes(recuperee: c.etat != EtatCourse.acceptee),
                  const SizedBox(height: 16),
                  if (c.etat == EtatCourse.acceptee) ..._recuperation(c, textes, livreur)
                  else if (c.etat == EtatCourse.recuperee) ..._remise(c, textes, livreur)
                  else
                    Text('Cette course est terminée.', style: textes.bodyMedium),
                  if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
                ],
              ),
            ),
    );
  }

  /// Étape 1 : au restaurant.
  List<Widget> _recuperation(Course c, TextTheme textes, ServiceLivreur livreur) {
    final prete = c.commandePrete;
    return [
      _Carte(children: [
        Text(c.restaurantNom, style: textes.titleLarge),
        Text(c.restaurantAdresse, style: textes.bodyMedium),
        if (c.restaurantTelephone != null) Text('Tél. ${c.restaurantTelephone}', style: textes.bodyMedium),
        const Divider(height: 22),
        Text('Commande n° ${c.numero} · ${c.nbArticles} article${c.nbArticles > 1 ? 's' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        for (final a in c.articles) Text('${a.quantite} × ${a.nom}'),
        if (c.remarque != null) ...[
          const SizedBox(height: 6),
          Text('Remarque : ${c.remarque}', style: const TextStyle(color: Couleurs.texteDoux, fontSize: 13)),
        ],
      ]),
      const SizedBox(height: 14),
      Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: prete ? const Color(0xFFE3F4EA) : Couleurs.doreClair,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Icon(prete ? Icons.check_circle_rounded : Icons.soup_kitchen_rounded,
                color: prete ? Couleurs.succes : const Color(0xFF6B4A00)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                prete ? 'Prête : vous pouvez la récupérer' : 'En préparation au restaurant',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      BoutonRelief(
        libelle: 'J\'ai récupéré la commande',
        enCours: _enCours,
        onPressed: prete ? () => _agir(() => livreur.recupererCourse(c.id)) : null,
      ),
      if (!prete) ...[
        const SizedBox(height: 6),
        Text('Le bouton s\'active quand le restaurant indique « Prête ».',
            style: textes.bodyMedium?.copyWith(fontSize: 13), textAlign: TextAlign.center),
      ],
    ];
  }

  /// Étape 2 : chez le client.
  List<Widget> _remise(Course c, TextTheme textes, ServiceLivreur livreur) {
    final peutConfirmer = !c.aEncaisser || _especesRecues;
    return [
      _Carte(children: [
        Text(c.adresseClient, style: textes.titleLarge),
        if (c.clientNom != null) Text('Client : ${c.clientNom}', style: textes.bodyMedium),
        if (c.clientTelephone != null) Text('Tél. ${c.clientTelephone}', style: textes.bodyMedium),
        if (c.remarque != null) ...[
          const SizedBox(height: 6),
          Text('Remarque : ${c.remarque}', style: const TextStyle(color: Couleurs.texteDoux, fontSize: 13)),
        ],
      ]),
      const SizedBox(height: 14),
      _Carte(children: [
        if (c.aEncaisser) ...[
          const Text('À encaisser en espèces', style: TextStyle(color: Couleurs.texteDoux)),
          Text(formaterPrix(c.total), style: textes.headlineMedium),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _especesRecues,
            onChanged: (v) => setState(() => _especesRecues = v ?? false),
            title: Text('J\'ai bien reçu ${formaterPrix(c.total)} du client'),
          ),
        ] else
          const Row(children: [
            Icon(Icons.credit_card_rounded, color: Couleurs.succes),
            SizedBox(width: 10),
            Expanded(child: Text('Payée en ligne : rien à encaisser.', style: TextStyle(fontWeight: FontWeight.w600))),
          ]),
      ]),
      const SizedBox(height: 16),
      BoutonRelief.harissa(
        libelle: 'Confirmer la livraison',
        enCours: _enCours,
        onPressed: peutConfirmer ? () => _agir(() => livreur.livrerCourse(c.id), termine: true) : null,
      ),
    ];
  }
}

class _Etapes extends StatelessWidget {
  const _Etapes({required this.recuperee});
  final bool recuperee;

  @override
  Widget build(BuildContext context) {
    Widget etape(int n, String libelle, {required bool faite, required bool actuelle}) => Expanded(
          child: Semantics(
            container: true,
            label: '$libelle${faite ? ', fait' : actuelle ? ', étape actuelle' : ', à venir'}',
            excludeSemantics: true,
            child: Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: faite ? Couleurs.succes : actuelle ? Couleurs.harissa : Couleurs.bordure,
                child: faite
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(libelle,
                    style: TextStyle(fontWeight: actuelle ? FontWeight.w700 : FontWeight.w500, color: Couleurs.nuit)),
              ),
            ]),
          ),
        );
    return Row(children: [
      etape(1, recuperee ? 'Récupérée' : 'Récupérer', faite: recuperee, actuelle: !recuperee),
      etape(2, 'Livrer au client', faite: false, actuelle: recuperee),
    ]);
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Fond porté par un Material : la case « J'ai bien reçu… » (ListTile) y dessine son effet de toucher.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Couleurs.bordure, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ),
    );
  }
}

/// Livraison confirmée (maquette « Livreur · Livrée »).
class LivreePage extends StatelessWidget {
  const LivreePage({super.key, required this.course, required this.remiseLe});
  final Course course;
  final DateTime remiseLe;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final c = course;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          children: [
            Center(child: SvgPicture.asset('assets/illustrations/koffa.svg', width: 130, height: 130)),
            const SizedBox(height: 12),
            Text('يعطيك الصحة',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: textes.titleLarge?.copyWith(color: Couleurs.harissa, fontSize: 18)),
            Text('Livraison confirmée', style: textes.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Commande n° ${c.numero} remise${c.clientNom == null ? '' : ' à ${c.clientNom}'} à ${formaterHeure(remiseLe)}',
              style: textes.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _Carte(children: [
              Row(children: [
                const Expanded(child: Text('Votre gain')),
                Text('+ ${formaterPrix(c.gain)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Couleurs.succes, fontSize: 17)),
              ]),
              if (c.aEncaisser) ...[
                const Divider(height: 22),
                Row(children: [
                  const Expanded(child: Text('Espèces encaissées')),
                  Text(formaterPrix(c.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ],
            ]),
            const SizedBox(height: 24),
            BoutonRelief(
              libelle: 'Voir les nouvelles courses',
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}
