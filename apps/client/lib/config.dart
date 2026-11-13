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
