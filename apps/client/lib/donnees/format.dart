/// Formats d'affichage partagés par les écrans (montants en dinars, notes).
library;

/// 16.5 → « 16,500 DT » (format tunisien, 3 décimales, espace des milliers).
String formaterPrix(num prix) {
  final morceaux = prix.toDouble().toStringAsFixed(3).split('.');
  final entier = morceaux[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '$entier,${morceaux[1]} DT';
}

/// 4.5 → « 4,5 ».
String formaterNote(double note) => note.toStringAsFixed(1).replaceAll('.', ',');

/// PostgREST renvoie les colonnes `numeric` en nombre ou en texte selon les cas.
double lireNombre(Object? valeur) {
  if (valeur is num) return valeur.toDouble();
  if (valeur is String) return double.parse(valeur);
  throw FormatException('Nombre attendu : $valeur');
}

/// « 19:05 » (heure locale).
String formaterHeure(DateTime date) {
  final d = date.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
