/// Règles de saisie des formulaires d'inscription et de connexion.
/// Chaque fonction renvoie `null` si la valeur est correcte, sinon le
/// message à afficher sous le champ.
library;

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String? validerNom(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Indiquez votre nom et prénom.';
  if (t.length < 3) return 'Le nom est trop court.';
  return null;
}

String? validerEmail(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Indiquez votre adresse e-mail.';
  if (!_email.hasMatch(t)) return 'Cette adresse e-mail n\'est pas valide.';
  return null;
}

/// Numéro tunisien : 8 chiffres après l'indicatif +216 (espaces acceptés).
String? validerTelephone(String? v) {
  final chiffres = (v ?? '').replaceAll(RegExp(r'[\s.-]'), '');
  if (chiffres.isEmpty) return 'Indiquez votre numéro de téléphone.';
  if (!RegExp(r'^\d{8}$').hasMatch(chiffres)) return 'Le numéro doit comporter 8 chiffres.';
  return null;
}

/// Format enregistré dans le profil : « +216 22 145 870 ».
String formaterTelephone(String saisie) {
  final c = saisie.replaceAll(RegExp(r'\D'), '');
  return '+216 ${c.substring(0, 2)} ${c.substring(2, 5)} ${c.substring(5)}';
}

String? validerMotDePasseInscription(String? v) {
  final t = v ?? '';
  if (t.isEmpty) return 'Choisissez un mot de passe.';
  if (t.length < 8) return '8 caractères minimum.';
  return null;
}

String? validerMotDePasseConnexion(String? v) =>
    (v == null || v.isEmpty) ? 'Indiquez votre mot de passe.' : null;

/// Code de réinitialisation reçu par e-mail : 6 chiffres (jusqu'à 10 si le
/// projet Supabase est réglé ainsi).
String? validerCode(String? v) {
  final t = (v ?? '').replaceAll(' ', '');
  if (t.isEmpty) return 'Indiquez le code reçu par e-mail.';
  if (!RegExp(r'^\d{6,10}$').hasMatch(t)) return 'Le code comporte 6 chiffres.';
  return null;
}

String? validerConfirmation(String? v, String motDePasse) {
  if (v == null || v.isEmpty) return 'Confirmez le nouveau mot de passe.';
  if (v != motDePasse) return 'Les deux mots de passe ne sont pas identiques.';
  return null;
}

/// Solidité du mot de passe, de 0 à 4 (les 4 barres sous le champ).
int soliditeMotDePasse(String mdp) {
  if (mdp.isEmpty) return 0;
  var score = 0;
  if (mdp.length >= 8) score++;
  if (RegExp(r'\d').hasMatch(mdp)) score++;
  if (RegExp(r'[a-z]').hasMatch(mdp) && RegExp(r'[A-Z]').hasMatch(mdp)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(mdp) || mdp.length >= 12) score++;
  return mdp.length < 8 ? score.clamp(0, 1) : score;
}

String libelleSolidite(int score) => switch (score) {
      0 || 1 => 'Mot de passe faible · 8 caractères minimum',
      2 => 'Mot de passe moyen · ajoutez majuscules et chiffres',
      3 => 'Mot de passe solide · 8 caractères minimum',
      _ => 'Mot de passe très solide',
    };
