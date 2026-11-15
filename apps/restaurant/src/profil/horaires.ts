/** Horaires d'ouverture d'un restaurant (table `horaires`, 1 = lundi … 7 = dimanche). */

export interface Horaire {
  jour: number
  /** Jour de fermeture hebdomadaire. */
  ferme: boolean
  /** « HH:MM » (vide si jamais renseigné). */
  ouverture: string
  fermeture: string
}

export const nomsJours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'] as const

export const nomJour = (jour: number): string => nomsJours[jour - 1] ?? ''

/** Proposition de départ : ouvert tous les jours de 11 h à 23 h. */
export function horairesParDefaut(): Horaire[] {
  return nomsJours.map((_, i) => ({ jour: i + 1, ferme: false, ouverture: '11:00', fermeture: '23:00' }))
}

/** Les 7 jours dans l'ordre ; un jour absent de la base reprend la proposition de départ. */
export function completerHoraires(lignes: Horaire[]): Horaire[] {
  return horairesParDefaut().map((defaut) => lignes.find((l) => l.jour === defaut.jour) ?? defaut)
}

/** « 11:30:00 » (base) → « 11:30 » (champ de saisie). */
export const heureCourte = (heure: string | null | undefined): string => (heure ?? '').slice(0, 5)

const motifHeure = /^([01]\d|2[0-3]):[0-5]\d$/

/**
 * `null` si le jour est correct, sinon le message à afficher.
 * Une fermeture avant l'ouverture est acceptée : le restaurant ferme après minuit.
 */
export function validerHoraire(h: Horaire): string | null {
  if (h.ferme) return null
  if (!motifHeure.test(h.ouverture) || !motifHeure.test(h.fermeture)) {
    return "Indiquez l'heure d'ouverture et l'heure de fermeture."
  }
  if (h.ouverture === h.fermeture) return "L'ouverture et la fermeture ne peuvent pas être à la même heure."
  return null
}

/** Vrai si le restaurant ferme le lendemain (ex. 18:00 → 02:00). */
export const fermeApresMinuit = (h: Horaire): boolean => !h.ferme && validerHoraire(h) === null && h.fermeture < h.ouverture
