/**
 * Règles de saisie des formulaires d'inscription et de connexion.
 * Chaque fonction renvoie `null` si la valeur est correcte, sinon le
 * message à afficher sous le champ (mêmes règles que l'appli client).
 */

const motifEmail = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/

export function validerNom(v: string): string | null {
  const t = v.trim()
  if (!t) return 'Indiquez votre nom et prénom.'
  if (t.length < 3) return 'Le nom est trop court.'
  return null
}

export function validerEmail(v: string): string | null {
  const t = v.trim()
  if (!t) return 'Indiquez votre adresse e-mail.'
  if (!motifEmail.test(t)) return "Cette adresse e-mail n'est pas valide."
  return null
}

/** Numéro tunisien : 8 chiffres après l'indicatif +216 (espaces, points et tirets acceptés). */
export function validerTelephone(v: string): string | null {
  const chiffres = v.replace(/[\s.-]/g, '')
  if (!chiffres) return 'Indiquez un numéro de téléphone.'
  if (!/^\d{8}$/.test(chiffres)) return 'Le numéro doit comporter 8 chiffres.'
  return null
}

/** Format enregistré en base : « +216 71 744 210 ». */
export function formaterTelephone(saisie: string): string {
  const c = saisie.replace(/\D/g, '')
  return `+216 ${c.slice(0, 2)} ${c.slice(2, 5)} ${c.slice(5)}`
}

/** « +216 71 744 210 » (base) → « 71 744 210 » (champ de saisie, indicatif affiché devant). */
export function telephoneSaisi(enregistre: string | null | undefined): string {
  return (enregistre ?? '').replace(/^\s*\+216\s*/, '')
}

export function validerMotDePasseInscription(v: string): string | null {
  if (!v) return 'Choisissez un mot de passe.'
  if (v.length < 8) return '8 caractères minimum.'
  return null
}

export function validerMotDePasseConnexion(v: string): string | null {
  return v ? null : 'Indiquez votre mot de passe.'
}

export function validerNomRestaurant(v: string): string | null {
  const t = v.trim()
  if (!t) return 'Indiquez le nom du restaurant.'
  if (t.length < 2) return 'Le nom est trop court.'
  return null
}

export function validerAdresse(v: string): string | null {
  const t = v.trim()
  if (!t) return "Indiquez l'adresse du restaurant."
  if (t.length < 6) return 'Adresse trop courte : numéro, rue et quartier.'
  return null
}

export function validerVille(v: string): string | null {
  return v ? null : 'Choisissez la ville.'
}

/** Chefs-lieux des 24 gouvernorats. */
export const villes = [
  'Tunis', 'Ariana', 'Ben Arous', 'La Manouba', 'Nabeul', 'Zaghouan', 'Bizerte', 'Béja',
  'Jendouba', 'Le Kef', 'Siliana', 'Sousse', 'Monastir', 'Mahdia', 'Sfax', 'Kairouan',
  'Kasserine', 'Sidi Bouzid', 'Gabès', 'Médenine', 'Tataouine', 'Gafsa', 'Tozeur', 'Kébili',
] as const
