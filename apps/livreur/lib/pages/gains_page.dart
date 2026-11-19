import 'package:flutter/material.dart';

import '../auth/erreurs.dart';
import '../dependances.dart';
import '../donnees/format.dart';
import '../donnees/modeles.dart';
import '../theme.dart';
import '../widgets/composants.dart';

/// Historique des courses et gains du livreur (US42) : gains du jour, des
/// 7 derniers jours et au total, note moyenne des clients, puis les courses
/// livrées regroupées par jour.
class GainsPage extends StatefulWidget {
  const GainsPage({super.key, this.maintenant});

  /// Date du jour (fixée dans les tests).
  final DateTime? maintenant;

  @override
  State<GainsPage> createState() => _GainsPageState();
}

class _GainsPageState extends State<GainsPage> {
  List<Course>? _courses;
  NoteLivreur _note = const NoteLivreur();
  String? _erreur;
  bool _demarre = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_demarre) return;
    _demarre = true;
    _charger();
  }

  Future<void> _charger() async {
    final livreur = Dependances.of(context).livreur;
    try {
      final courses = await livreur.mesCourses();
      // La note est un plus : si elle ne se charge pas, l'historique reste affiché.
      final note = await livreur.maNote().catchError((_) => const NoteLivreur());
      if (mounted) {
        setState(() {
          _courses = courses;
          _note = note;
          _erreur = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final courses = _courses;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Couleurs.fond,
        title: Text('Mes courses et gains', style: textes.titleLarge),
      ),
      body: courses == null
          ? Center(
              child: _erreur != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MessageErreur(_erreur!),
                          TextButton(onPressed: _charger, child: const Text('Réessayer')),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(semanticsLabel: 'Chargement de vos courses'),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _Resume(
                    resume: resumerGains(courses, maintenant: widget.maintenant),
                    note: _note,
                  ),
                  const SizedBox(height: 22),
                  Semantics(header: true, child: Text('Courses livrées', style: textes.titleMedium)),
                  const SizedBox(height: 10),
                  if (courses.isEmpty)
                    Text(
                      'Aucune course livrée pour le moment. Vos courses terminées apparaîtront ici.',
                      style: textes.bodyMedium,
                    )
                  else
                    for (final (jour, duJour) in _parJour(courses)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Text(
                          '${_libelleJour(jour)} · ${formaterPrix(duJour.fold(0.0, (s, c) => s + c.gain))}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.texteDoux),
                        ),
                      ),
                      for (final c in duJour) ...[_LigneCourse(course: c), const SizedBox(height: 10)],
                    ],
                ],
              ),
            ),
    );
  }

  /// Courses regroupées par jour de livraison (dates locales), dans l'ordre reçu.
  List<(DateTime, List<Course>)> _parJour(List<Course> courses) {
    final groupes = <(DateTime, List<Course>)>[];
    for (final c in courses) {
      final d = (c.livreeLe ?? DateTime(2000)).toLocal();
      final jour = DateTime(d.year, d.month, d.day);
      if (groupes.isEmpty || groupes.last.$1 != jour) groupes.add((jour, []));
      groupes.last.$2.add(c);
    }
    return groupes;
  }

  String _libelleJour(DateTime jour) {
    final m = (widget.maintenant ?? DateTime.now()).toLocal();
    final aujourdhui = DateTime(m.year, m.month, m.day);
    if (jour == aujourdhui) return 'Aujourd\'hui';
    if (jour == aujourdhui.subtract(const Duration(days: 1))) return 'Hier';
    return formaterDate(jour, maintenant: m);
  }
}

class _Resume extends StatelessWidget {
  const _Resume({required this.resume, required this.note});
  final ResumeGains resume;
  final NoteLivreur note;

  String _nb(int n) => n <= 1 ? '$n course' : '$n courses';

  @override
  Widget build(BuildContext context) {
    final moyenne = note.moyenne;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Couleurs.bleu,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Couleurs.bleuFonce, offset: Offset(0, 5))],
          ),
          child: Semantics(
            container: true,
            label: 'Aujourd\'hui : ${formaterPrix(resume.aujourdhui)}, ${_nb(resume.nbAujourdhui)}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gagné aujourd\'hui', style: TextStyle(color: Colors.white, fontSize: 13)),
                Text(
                  formaterPrix(resume.aujourdhui),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
                Text(_nb(resume.nbAujourdhui), style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Tuile(
                titre: '7 derniers jours',
                valeur: formaterPrix(resume.semaine),
                detail: _nb(resume.nbSemaine),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Tuile(titre: 'Total', valeur: formaterPrix(resume.total), detail: _nb(resume.nb)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Tuile(
          titre: 'Note des clients',
          valeur: moyenne == null ? 'Pas encore d\'avis' : '★ ${formaterNote(moyenne)} / 5',
          detail: moyenne == null ? 'Les clients peuvent vous noter après la livraison.' : '${note.nbAvis} avis',
        ),
      ],
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({required this.titre, required this.valeur, required this.detail});
  final String titre;
  final String valeur;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Couleurs.bordure),
      ),
      child: Semantics(
        container: true,
        label: '$titre : $valeur, $detail',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre, style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux)),
            const SizedBox(height: 2),
            Text(
              valeur,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Couleurs.nuit),
            ),
            Text(detail, style: const TextStyle(fontSize: 12, color: Couleurs.texteDoux)),
          ],
        ),
      ),
    );
  }
}

/// Une course livrée : heure, n°, restaurant → adresse, gain, espèces encaissées.
class _LigneCourse extends StatelessWidget {
  const _LigneCourse({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final heure = c.livreeLe == null ? '' : '${formaterHeure(c.livreeLe!)} · ';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Couleurs.bordure),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${heure}n° ${c.numero}', style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux)),
                Text(
                  c.restaurantNom,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Couleurs.nuit),
                ),
                Text('→ ${c.adresseClient}', style: const TextStyle(fontSize: 13, color: Couleurs.texteDoux)),
                if (c.paiementMode == 'especes')
                  Text(
                    'Espèces encaissées : ${formaterPrix(c.total)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B4A00)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+ ${formaterPrix(c.gain)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Couleurs.succes),
          ),
        ],
      ),
    );
  }
}
