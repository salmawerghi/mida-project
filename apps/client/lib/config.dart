/// Connexion au projet Supabase de Mida.
///
/// La clé « publishable » est faite pour être embarquée dans une application :
/// elle ne donne que les droits d'un visiteur, la sécurité repose sur les
/// règles d'accès (RLS) de la base. Ne jamais mettre ici la clé « secret »
/// ou « service_role ».
///
/// Les valeurs peuvent être remplacées au lancement :
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://tpfpuwlgnxhwhezicuto.supabase.co',
);
const supabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_xxD9ZnF7RkGUTpX1tT1flA_iO0fa0pk',
);

/// Affiche le lien « Mot de passe oublié ? » (US06). Désactivé tant que le
/// projet Supabase n'envoie pas le code par e-mail : il faut un SMTP
/// personnalisé pour pouvoir mettre `{{ .Token }}` dans le modèle
/// « Reset password » (voir le README). Pour l'activer :
///   flutter run --dart-define=MOT_DE_PASSE_OUBLIE=true
const motDePasseOublieActif = bool.fromEnvironment('MOT_DE_PASSE_OUBLIE');
