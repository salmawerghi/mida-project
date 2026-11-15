/** Plats du menu (US10, table `plats`). Prix en dinars, avec 3 décimales (millimes). */

export interface Plat {
  id: string
  categorieId: string
  nom: string
  description: string
  /** En dinars, ex. 16.5 pour 16,500 DT. */
  prix: number
  imageUrl: string | null
  disponible: boolean
}

/** Ce que le responsable saisit dans le formulaire. */
export interface InfosPlat {
  categorieId: string
  nom: string
  description: string
  prix: number
}

export const longueurMaxNomPlat = 60
export const longueurMaxDescription = 160
export const prixMax = 1000

/**
 * Lit un prix saisi : « 16 », « 16,5 », « 16.500 », « 16,000 DT ».
 * Renvoie `null` si ce n'est pas un nombre avec au plus 3 décimales.
 */
export function lirePrix(saisie: string): number | null {
  const t = saisie.trim().replace(/\s*(dt|tnd|د\.ت)\s*$/i, '').replace(/\s/g, '').replace(',', '.')
  if (!/^-?\d+(\.\d{1,3})?$/.test(t)) return null
  return Number(t)
}

export function validerPrix(saisie: string): string | null {
  if (!saisie.trim()) return 'Indiquez le prix.'
  const prix = lirePrix(saisie)
  if (prix === null) return 'Prix invalide : par exemple 16 ou 16,500.'
  if (prix <= 0) return 'Le prix doit être un nombre positif.'
  if (prix > prixMax) return `Le prix ne peut pas dépasser ${prixMax} DT.`
  return null
}

export function validerNomPlat(nom: string): string | null {
  const t = nom.trim()
  if (!t) return 'Indiquez le nom du plat.'
  if (t.length < 2) return 'Le nom est trop court.'
  if (t.length > longueurMaxNomPlat) return `${longueurMaxNomPlat} caractères maximum.`
  return null
}

export function validerCategoriePlat(categorieId: string): string | null {
  return categorieId ? null : 'Choisissez la catégorie du plat.'
}

/** 16.5 → « 16,500 DT » (format tunisien, 3 décimales). */
export function formaterPrix(prix: number): string {
  const [entier, decimales] = prix.toFixed(3).split('.')
  return `${entier.replace(/\B(?=(\d{3})+(?!\d))/g, ' ')},${decimales} DT`
}

/** 16.5 → « 16,500 » (valeur du champ de saisie). */
export const prixSaisi = (prix: number): string => prix.toFixed(3).replace('.', ',')
