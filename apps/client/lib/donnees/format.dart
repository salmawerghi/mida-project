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

const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « 8 nov. » (date locale), avec l'année si ce n'est pas celle de [maintenant] : « 28 déc. 2025 ».
String formaterDate(DateTime date, {DateTime? maintenant}) {
  final d = date.toLocal();
  final annee = (maintenant ?? DateTime.now()).year;
  return '${d.day} ${_mois[d.month - 1]}${d.year == annee ? '' : ' ${d.year}'}';
}

/// « 19:05 » (heure locale).
String formaterHeure(DateTime date) {
  final d = date.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
