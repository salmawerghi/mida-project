import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Couleurs de l'identité Mida (voir la page « Identité visuelle » des maquettes).
abstract final class Couleurs {
  static const bleu = Color(0xFF1554C0); // bleu Sidi Bou Saïd
  static const bleuFonce = Color(0xFF0B3684);
  static const harissa = Color(0xFFC93A22);
  static const harissaFonce = Color(0xFF8F2413);
  static const dore = Color(0xFFF2B233);
  static const doreClair = Color(0xFFFCE7B0);
  static const nuit = Color(0xFF0F1B33);
  static const fond = Color(0xFFF4F7FC);
  static const bordure = Color(0xFFDCE3EF);
  static const texteDoux = Color(0xFF4A5672);
  static const erreur = Color(0xFFA32B17);
  static const succes = Color(0xFF1E7A46);
}

/// Thème de l'application.
///
/// [policesGoogle] : `false` dans les tests (les polices El Messiri et
/// IBM Plex Sans Arabic sont téléchargées à l'exécution par google_fonts).
ThemeData construireTheme({bool policesGoogle = true}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Couleurs.bleu,
      primary: Couleurs.bleu,
      secondary: Couleurs.harissa,
      error: Couleurs.erreur,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Couleurs.fond,
  );

  final TextTheme corps = policesGoogle
      ? GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme)
      : base.textTheme;
  TextStyle titre(double taille) {
    final style = TextStyle(fontSize: taille, fontWeight: FontWeight.w700, height: 1.1, color: Couleurs.nuit);
    return policesGoogle ? GoogleFonts.elMessiri(textStyle: style) : style;
  }

  return base.copyWith(
    textTheme: corps.copyWith(
      displaySmall: titre(34),
      headlineMedium: titre(28),
      headlineSmall: titre(26),
      titleLarge: titre(20),
      bodyLarge: corps.bodyLarge?.copyWith(fontSize: 16, color: Couleurs.nuit),
      bodyMedium: corps.bodyMedium?.copyWith(fontSize: 15, color: Couleurs.texteDoux, height: 1.45),
      labelLarge: corps.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: Couleurs.nuit),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: _bord(Couleurs.bordure),
      focusedBorder: _bord(Couleurs.bleu),
      errorBorder: _bord(Couleurs.harissa),
      focusedErrorBorder: _bord(Couleurs.harissa),
      errorStyle: const TextStyle(color: Couleurs.erreur, fontSize: 13),
      errorMaxLines: 2,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Couleurs.bleu,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
  );
}

OutlineInputBorder _bord(Color couleur) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: couleur, width: 2),
    );
