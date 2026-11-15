import { isAuthError, isAuthRetryableFetchError } from '@supabase/supabase-js'

/** Erreur métier affichée telle quelle à l'utilisateur. */
export class ErreurMida extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'ErreurMida'
  }
}

export const messageIdentifiantsIncorrects = 'E-mail ou mot de passe incorrect.'
export const messageHorsLigne = 'Pas de connexion internet. Vérifiez votre réseau puis réessayez.'
export const messageCompteExistant = 'Un compte existe déjà avec cette adresse e-mail. Connectez-vous.'

/** Traduit une erreur de Supabase (Auth, base) ou du réseau en message clair. */
export function messageErreur(erreur: unknown): string {
  if (erreur instanceof ErreurMida) return erreur.message
  if (isAuthRetryableFetchError(erreur)) return messageHorsLigne
  if (erreur instanceof TypeError && /fetch|network/i.test(erreur.message)) return messageHorsLigne

  if (isAuthError(erreur)) {
    const code = erreur.code ?? ''
    const message = erreur.message.toLowerCase()
    if (code === 'invalid_credentials' || message.includes('invalid login credentials')) {
      return messageIdentifiantsIncorrects
    }
    if (code === 'email_not_confirmed' || message.includes('email not confirmed')) {
      return "Votre adresse e-mail n'est pas encore confirmée. Ouvrez le lien reçu par e-mail, puis connectez-vous."
    }
    if (code === 'user_already_exists' || code === 'email_exists' || message.includes('already registered')) {
      return messageCompteExistant
    }
    if (code === 'weak_password') return 'Mot de passe trop faible : 8 caractères minimum, avec lettres et chiffres.'
    if (code === 'email_address_invalid') return "Cette adresse e-mail n'est pas acceptée."
    if (code.startsWith('over_') || erreur.status === 429) {
      return 'Trop de tentatives. Patientez quelques minutes puis réessayez.'
    }
    if (code === 'signup_disabled') return 'Les inscriptions sont momentanément fermées.'
  }

  // Erreurs du stockage des images : { statusCode, message }
  if (typeof erreur === 'object' && erreur !== null && 'statusCode' in erreur) {
    const statut = String((erreur as { statusCode: unknown }).statusCode)
    if (statut === '413') return 'Image trop lourde : 5 Mo maximum.'
    if (statut === '415') return 'Format non accepté : choisissez une image JPEG, PNG ou WebP.'
    if (statut === '401' || statut === '403') return "Ce compte n'a pas le droit de modifier cette image."
  }

  // Erreurs de la base (PostgREST) : { code, message, details }
  if (typeof erreur === 'object' && erreur !== null && 'code' in erreur) {
    const code = String((erreur as { code: unknown }).code)
    if (code === '23505') return 'Ce compte a déjà inscrit un restaurant.'
    if (code === '42501') return "Ce compte n'a pas le droit de faire cette action."
    if (code === '23514') return 'Une information du restaurant est invalide. Vérifiez le formulaire.'
  }
  return 'Une erreur est survenue. Réessayez dans un instant.'
}
