import type { InfosRestaurant } from './service'

/**
 * Brouillon du restaurant saisi à l'inscription, gardé dans le navigateur
 * quand Supabase exige de confirmer l'e-mail avant la connexion : à la
 * première connexion, l'étape « Restaurant » est préremplie avec.
 */
const cle = 'mida.brouillonRestaurant'

export function sauverBrouillon(email: string, restaurant: InfosRestaurant): void {
  try {
    localStorage.setItem(cle, JSON.stringify({ email: email.trim().toLowerCase(), restaurant }))
  } catch {
    // stockage indisponible : le responsable ressaisira ses informations
  }
}

export function lireBrouillon(email: string): InfosRestaurant | null {
  try {
    const brut = localStorage.getItem(cle)
    if (!brut) return null
    const b = JSON.parse(brut) as { email?: string; restaurant?: InfosRestaurant }
    return b.email === email.trim().toLowerCase() && b.restaurant ? b.restaurant : null
  } catch {
    return null
  }
}

export function effacerBrouillon(): void {
  try {
    localStorage.removeItem(cle)
  } catch {
    // rien à faire
  }
}
