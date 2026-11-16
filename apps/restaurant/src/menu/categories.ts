/** Catégories du menu d'un restaurant (US09, table `categories_menu`). */

export interface CategorieMenu {
  id: string
  nom: string
  /** Position dans le menu (la plus petite en premier). */
  ordre: number
  nbPlats: number
}

export const longueurMaxNomCategorie = 40
export const messageCategorieExistante = 'Une catégorie porte déjà ce nom.'

const cle = (nom: string) => nom.trim().toLocaleLowerCase('fr')

/**
 * `null` si le nom est correct, sinon le message à afficher.
 * `sauf` : la catégorie en cours de renommage (elle peut garder son nom).
 */
export function validerNomCategorie(nom: string, existantes: CategorieMenu[], sauf?: string): string | null {
  const t = nom.trim()
  if (!t) return 'Indiquez le nom de la catégorie.'
  if (t.length > longueurMaxNomCategorie) return `${longueurMaxNomCategorie} caractères maximum.`
  if (existantes.some((c) => c.id !== sauf && cle(c.nom) === cle(t))) return messageCategorieExistante
  return null
}

/** Position de la prochaine catégorie : à la fin du menu. */
export function ordreSuivant(categories: CategorieMenu[]): number {
  return categories.reduce((max, c) => Math.max(max, c.ordre), 0) + 1
}

/** Monte (-1) ou descend (+1) une catégorie d'un rang ; liste inchangée si elle est déjà au bout. */
export function deplacer(categories: CategorieMenu[], id: string, sens: -1 | 1): CategorieMenu[] {
  const i = categories.findIndex((c) => c.id === id)
  const j = i + sens
  if (i < 0 || j < 0 || j >= categories.length) return categories
  const liste = [...categories]
  const deplacee = liste[i]
  liste[i] = liste[j]
  liste[j] = deplacee
  return liste
}

/** « 1 plat », « 3 plats », « aucun plat ». */
export function libellePlats(n: number): string {
  if (n === 0) return 'aucun plat'
  return n === 1 ? '1 plat' : `${n} plats`
}

/** « 4 catégories · 14 plats · 1 plat indisponible » (sous-titre de la page). */
export function resumeMenu(categories: CategorieMenu[], nbIndisponibles = 0): string {
  const n = categories.length
  const plats = categories.reduce((somme, c) => somme + c.nbPlats, 0)
  const resume = `${n === 1 ? '1 catégorie' : `${n} catégories`} · ${libellePlats(plats)}`
  if (nbIndisponibles === 0) return resume
  return `${resume} · ${nbIndisponibles === 1 ? '1 plat indisponible' : `${nbIndisponibles} plats indisponibles`}`
}
