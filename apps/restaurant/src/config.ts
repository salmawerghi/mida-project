/**
 * Connexion au projet Supabase de Mida.
 *
 * La clé « publishable » est faite pour être embarquée dans une application :
 * elle ne donne que les droits d'un visiteur, la sécurité repose sur les
 * règles d'accès (RLS) de la base. Ne jamais mettre ici la clé « secret »
 * ou « service_role ».
 *
 * Remplaçables par un fichier `.env.local` :
 *   VITE_SUPABASE_URL=...   VITE_SUPABASE_KEY=...
 */
export const supabaseUrl: string =
  import.meta.env.VITE_SUPABASE_URL ?? 'https://tpfpuwlgnxhwhezicuto.supabase.co'
export const supabaseKey: string =
  import.meta.env.VITE_SUPABASE_KEY ?? 'sb_publishable_xxD9ZnF7RkGUTpX1tT1flA_iO0fa0pk'

/**
 * « Mot de passe oublié ? » (US06) : masqué tant que l'envoi d'e-mails n'est
 * pas réglé sur Supabase (SMTP personnalisé + modèle « Reset password » avec
 * {{ .Token }}). L'activer avec VITE_MOT_DE_PASSE_OUBLIE=true dans .env.local.
 */
export const motDePasseOublieActif: boolean = import.meta.env.VITE_MOT_DE_PASSE_OUBLIE === 'true'
