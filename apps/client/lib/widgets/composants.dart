import 'package:flutter/material.dart';

import '../auth/validation.dart';
import '../theme.dart';

/// Bouton « en relief » des maquettes : ombre pleine sous le bouton.
class BoutonRelief extends StatelessWidget {
  const BoutonRelief({
    super.key,
    required this.libelle,
    required this.onPressed,
    this.couleur = Couleurs.bleu,
    this.ombre = Couleurs.bleuFonce,
    this.enCours = false,
  });

  /// Bouton principal rouge harissa (création de compte).
  const BoutonRelief.harissa({
    super.key,
    required this.libelle,
    required this.onPressed,
    this.enCours = false,
  })  : couleur = Couleurs.harissa,
        ombre = Couleurs.harissaFonce;

  final String libelle;
  final VoidCallback? onPressed;
  final Color couleur;
  final Color ombre;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null && !enCours;
    return Semantics(
      button: true,
      enabled: actif,
      label: libelle,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: ombre, offset: const Offset(0, 6)),
            BoxShadow(color: couleur.withValues(alpha: 0.28), offset: const Offset(0, 16), blurRadius: 24),
          ],
        ),
        child: Material(
          color: couleur,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: actif ? onPressed : null,
            child: SizedBox(
              height: 56,
              child: Center(
                child: enCours
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                      )
                    : Text(
                        libelle,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton retour carré blanc des maquettes.
class BoutonRetour extends StatelessWidget {
  const BoutonRetour({super.key, this.ombre = Couleurs.bordure});
  final Color ombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: ombre, offset: const Offset(0, 4))],
      ),
      child: IconButton(
        tooltip: 'Retour',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.chevron_left_rounded, color: Couleurs.nuit, size: 28),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// Champ de formulaire avec son étiquette au-dessus.
class ChampEtiquete extends StatelessWidget {
  const ChampEtiquete({super.key, required this.etiquette, required this.champ});
  final String etiquette;
  final Widget champ;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(etiquette, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        champ,
      ],
    );
  }
}

/// Message d'erreur renvoyé par le serveur, sous le formulaire.
class MessageErreur extends StatelessWidget {
  const MessageErreur(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 18, color: Couleurs.erreur),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: const TextStyle(color: Couleurs.erreur, fontSize: 14, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Motif d'étoiles à 8 branches (zellige) en filigrane sur les fonds bleus.
class MotifEtoiles extends StatelessWidget {
  const MotifEtoiles({super.key, required this.child, this.couleur = Couleurs.bleu});
  final Widget child;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: couleur,
      child: CustomPaint(painter: _PeintreEtoiles(), child: child),
    );
  }
}

class _PeintreEtoiles extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.16);
    const pas = 80.0;
    for (var y = 0.0; y < size.height + pas; y += pas) {
      for (var x = 0.0; x < size.width + pas; x += pas) {
        final losange = Path()
          ..moveTo(x + 40, y + 12)
          ..lineTo(x + 68, y + 40)
          ..lineTo(x + 40, y + 68)
          ..lineTo(x + 12, y + 40)
          ..close();
        canvas.drawPath(losange, p);
        canvas.drawRect(Rect.fromLTRB(x + 20.2, y + 20.2, x + 59.8, y + 59.8), p);
        canvas.drawCircle(Offset(x + 40, y + 40), 9, p);
        canvas.drawCircle(Offset(x, y), 7, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo Mida : étoile bleue sur disque blanc, cœur harissa.
class LogoMida extends StatelessWidget {
  const LogoMida({super.key, this.taille = 40});
  final double taille;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: taille, child: CustomPaint(painter: _PeintreLogo()));
  }
}

class _PeintreLogo extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final e = size.width / 40;
    canvas.scale(e);
    canvas.drawCircle(const Offset(20, 20), 20, Paint()..color = Colors.white);
    final bleu = Paint()..color = Couleurs.bleu;
    canvas.drawPath(
      Path()
        ..moveTo(20, 5)
        ..lineTo(35, 20)
        ..lineTo(20, 35)
        ..lineTo(5, 20)
        ..close(),
      bleu,
    );
    canvas.drawRect(const Rect.fromLTRB(9.4, 9.4, 30.6, 30.6), bleu);
    canvas.drawCircle(const Offset(20, 20), 6, Paint()..color = Couleurs.harissa);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Jauge de solidité du mot de passe (4 barres et un conseil).
class JaugeSolidite extends StatelessWidget {
  const JaugeSolidite({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final couleur = score >= 3 ? Couleurs.succes : (score == 2 ? Couleurs.dore : Couleurs.harissa);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < score ? couleur : Couleurs.bordure,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(libelleSolidite(score),
            style: TextStyle(fontSize: 13, color: score >= 3 ? const Color(0xFF1E5C3A) : Couleurs.texteDoux)),
      ],
    );
  }
}

/// Bandeau vert d'information (e-mail envoyé, compte créé…).
class BandeauInformation extends StatelessWidget {
  const BandeauInformation(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB9DFC8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_read_outlined, color: Couleurs.succes),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte, style: const TextStyle(color: Color(0xFF1E5C3A), fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
