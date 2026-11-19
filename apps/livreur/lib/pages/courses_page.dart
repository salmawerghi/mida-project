import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/composants.dart';
import 'course_page.dart';
import 'gains_page.dart';

/// Accueil du livreur validé (maquette « Livreur · Courses proposées ») :
/// interrupteur « Disponible » (US26), course en cours, courses proposées (US27).
class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key, required this.etat, required this.recharger, this.relecture = const Duration(seconds: 20)});
  final EtatLivreur etat;
  final Future<void> Function() recharger;

  /// Relecture régulière : une course prise par un autre livreur ne lui est
  /// plus visible, la base n'envoie donc pas d'événement aux autres.
  final Duration relecture;

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  late bool _disponible = widget.etat.disponible;
  List<Course>? _proposees;
  Course? _enCours;
  String? _erreur;
  String? _acceptation; // course en train d'être acceptée
  void Function()? _desabonner;
  Timer? _attente;
  Timer? _minuterie;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_desabonner != null) return;
    _charger();
    _desabonner = Dependances.of(context).livreur.surChangements(() {
      _attente?.cancel();
      _attente = Timer(const Duration(milliseconds: 300), _charger);
    });
    _minuterie = Timer.periodic(widget.relecture, (_) => _charger());
  }

  @override
  void dispose() {
    _attente?.cancel();
    _minuterie?.cancel();
    _desabonner?.call();
    super.dispose();
  }

  Future<void> _charger() async {
    if (!mounted) return;
    final livreur = Dependances.of(context).livreur;
    try {
      final enCours = await livreur.courseEnCours();
      final proposees = _disponible && enCours == null ? await livreur.coursesProposees() : <Course>[];
      if (mounted) {
        setState(() {
          _enCours = enCours;
          _proposees = proposees;
          _erreur = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  Future<void> _basculer(bool oui) async {
    final livreur = Dependances.of(context).livreur;
    setState(() {
      _disponible = oui;
      _erreur = null;
    });
    try {
      await livreur.definirDisponible(oui);
      await _charger();
    } catch (e) {
      if (mounted) {
        setState(() {
          _disponible = !oui;
          _erreur = messageErreur(e);
        });
      }
    }
  }

  Future<void> _accepter(Course c) async {
    final livreur = Dependances.of(context).livreur;
    setState(() => _acceptation = c.id);
    try {
      await livreur.accepterCourse(c.id);
      if (!mounted) return;
      await _ouvrir(c.id);
    } catch (e) {
      if (!mounted) return;
      // par exemple : un autre livreur l'a acceptée juste avant
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(messageErreur(e))));
      await _charger();
    } finally {
      if (mounted) setState(() => _acceptation = null);
    }
  }

  Future<void> _ouvrir(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CoursePage(courseId: id)));
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final enCours = _enCours;
    final proposees = _proposees;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('عسلامة', textDirection: TextDirection.rtl, style: textes.labelLarge?.copyWith(color: Couleurs.harissa)),
            Text('Aslema, ${widget.etat.prenom}', style: textes.titleLarge),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mes courses et gains',
            icon: const Icon(Icons.account_balance_wallet_outlined, color: Couleurs.nuit),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GainsPage())),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout_rounded, color: Couleurs.nuit),
            onPressed: Dependances.of(context).auth.deconnecter,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Material(
              color: _disponible ? const Color(0xFFE3F4EA) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: SwitchListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                title: Text(_disponible ? 'Disponible' : 'Indisponible',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.nuit)),
                subtitle: Text(_disponible ? 'Vous recevez les nouvelles courses.' : 'Aucune course ne vous est proposée.'),
                value: _disponible,
                activeThumbColor: Couleurs.succes,
                onChanged: _basculer,
              ),
            ),
            if (_erreur != null) ...[const SizedBox(height: 12), MessageErreur(_erreur!)],
            const SizedBox(height: 20),
            if (enCours != null) ...[
              Semantics(header: true, child: Text('Course en cours', style: textes.titleMedium)),
              const SizedBox(height: 10),
              _CarteCourseEnCours(course: enCours, onTap: () => _ouvrir(enCours.id)),
              const SizedBox(height: 12),
              Text('Terminez cette course pour en accepter une nouvelle.', style: textes.bodyMedium),
            ] else ...[
              Semantics(header: true, child: Text('Courses proposées', style: textes.titleMedium)),
              const SizedBox(height: 10),
              if (!_disponible)
                Text('Passez « Disponible » pour recevoir des courses.', style: textes.bodyMedium)
              else if (proposees == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(semanticsLabel: 'Chargement des courses')),
                )
              else if (proposees.isEmpty)
                Text('Aucune course pour le moment. Les nouvelles courses apparaissent ici d\'elles-mêmes.',
                    style: textes.bodyMedium)
              else
                for (final c in proposees) ...[
                  CarteCourse(course: c, enCours: _acceptation == c.id, onAccepter: _acceptation == null ? () => _accepter(c) : null),
                  const SizedBox(height: 14),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Course proposée : paiement, gain, restaurant, adresse du client, bouton « Accepter ».
class CarteCourse extends StatelessWidget {
  const CarteCourse({super.key, required this.course, required this.onAccepter, this.enCours = false});
  final Course course;
  final VoidCallback? onAccepter;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    final c = course;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Couleurs.bordure, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              PastillePaiement(course: c),
              Text('+ ${formaterPrix(c.gain)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Couleurs.succes)),
            ],
          ),
          const SizedBox(height: 12),
          _Trajet(
            icone: Icons.storefront_rounded,
            titre: c.restaurantNom,
            detail: c.restaurantAdresse,
          ),
          const SizedBox(height: 8),
          _Trajet(
            icone: Icons.place_rounded,
            titre: c.adresseClient,
            detail: 'n° ${c.numero} · ${c.nbArticles <= 1 ? '${c.nbArticles} article' : '${c.nbArticles} articles'}',
          ),
          const SizedBox(height: 14),
          BoutonRelief(libelle: 'Accepter la course', enCours: enCours, onPressed: onAccepter),
        ],
      ),
    );
  }
}

/// « Payée en ligne » (vert) ou « À encaisser · 27,500 DT » (doré).
class PastillePaiement extends StatelessWidget {
  const PastillePaiement({super.key, required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final encaisser = course.aEncaisser;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: encaisser ? Couleurs.doreClair : const Color(0xFFE3F4EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        course.mentionPaiement,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: encaisser ? const Color(0xFF6B4A00) : const Color(0xFF14552F),
        ),
      ),
    );
  }
}

class _Trajet extends StatelessWidget {
  const _Trajet({required this.icone, required this.titre, required this.detail});
  final IconData icone;
  final String titre;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: Couleurs.bleu, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.nuit)),
              if (detail.isNotEmpty) Text(detail, style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CarteCourseEnCours extends StatelessWidget {
  const _CarteCourseEnCours({required this.course, required this.onTap});
  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final etape = c.etat == EtatCourse.recuperee ? 'À livrer au client' : 'À récupérer chez ${c.restaurantNom}';
    return Material(
      color: Couleurs.bleu,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Commande n° ${c.numero}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                Text(etape, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}
