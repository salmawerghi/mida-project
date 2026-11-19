/** Historique des commandes du restaurant (US39) et avis des clients (US48). */
import { etatsEnCours, type Commande, type EtatCommande } from '../commandes/commandes'

// ---------------------------------------------------------------------
// US39 — historique des commandes
// ---------------------------------------------------------------------

/** Commande de l'historique : la commande en cours (US12) avec son issue. */
export interface CommandeHistorique extends Commande {
  motifRefus: string | null
  livreeLe: Date | null
  annuleeLe: Date | null
}

export type FiltreEtat = 'toutes' | 'en_cours' | 'livree' | 'refusee' | 'annulee'

export interface FiltresHistorique {
  etat: FiltreEtat
  /** Dates du formulaire, « 2026-11-19 » ou vide. */
  du: string
  au: string
  /** Numéro de commande cherché (chiffres), ou vide. */
  numero: string
}

export const filtresParDefaut: FiltresHistorique = { etat: 'toutes', du: '', au: '', numero: '' }

export const choixEtats: { valeur: FiltreEtat; libelle: string }[] = [
  { valeur: 'toutes', libelle: 'Toutes' },
  { valeur: 'livree', libelle: 'Livrées' },
  { valeur: 'refusee', libelle: 'Refusées' },
  { valeur: 'annulee', libelle: 'Annulées par le client' },
  { valeur: 'en_cours', libelle: 'En cours' },
]

/** Commandes par page de l'historique. */
export const parPage = 20

export interface PageHistorique {
  commandes: CommandeHistorique[]
  /** Nombre total de commandes qui correspondent aux filtres. */
  total: number
  /** Commandes livrées parmi elles, et leur montant (chiffre d'affaires). */
  nbLivrees: number
  chiffreAffaires: number
}

/** États de la base à lire pour un choix du filtre (`null` : tous). */
export function etatsDuFiltre(filtre: FiltreEtat): EtatCommande[] | null {
  if (filtre === 'toutes') return null
  if (filtre === 'en_cours') return etatsEnCours
  return [filtre]
}

/**
 * Bornes de date (heure locale du restaurant) : du 18 au 19 novembre =
 * depuis le 18 à 0 h jusqu'au 20 à 0 h (exclu). Renvoie une erreur si
 * « du » est après « au ».
 */
export function bornesDates(du: string, au: string): { depuis: string | null; avant: string | null; erreur: string | null } {
  const debut = du ? new Date(`${du}T00:00:00`) : null
  const fin = au ? new Date(`${au}T00:00:00`) : null
  if (fin) fin.setDate(fin.getDate() + 1)
  if (debut && fin && debut >= fin) {
    return { depuis: null, avant: null, erreur: 'La date de début doit précéder la date de fin.' }
  }
  return { depuis: debut?.toISOString() ?? null, avant: fin?.toISOString() ?? null, erreur: null }
}

/** « 1042 », « n° 1042 », « #1042 » → 1042 ; vide → null ; autre chose → NaN (aucun résultat). */
export function lireNumero(saisie: string): number | null {
  const texte = saisie.trim().replace(/^(n°|#)\s*/i, '')
  if (!texte) return null
  return /^\d{1,9}$/.test(texte) ? Number(texte) : Number.NaN
}

/** Libellé et style de la pastille d'état. */
export function pastilleEtat(etat: EtatCommande): { libelle: string; classe: string } {
  switch (etat) {
    case 'livree':
      return { libelle: 'Livrée', classe: 'pastille-actif' }
    case 'refusee':
      return { libelle: 'Refusée', classe: 'pastille-refus' }
    case 'annulee':
      return { libelle: 'Annulée', classe: 'pastille-refus' }
    case 'en_attente':
      return { libelle: 'En attente', classe: 'pastille-attente' }
    case 'acceptee':
      return { libelle: 'Acceptée', classe: 'pastille-attente' }
    case 'en_preparation':
      return { libelle: 'En préparation', classe: 'pastille-attente' }
    case 'prete':
      return { libelle: 'Prête', classe: 'pastille-attente' }
    case 'en_livraison':
      return { libelle: 'En livraison', classe: 'pastille-attente' }
  }
}

/** « 19 nov. 2026 · 20:15 » (heure locale). */
export function formaterDateHeure(date: Date): string {
  const jour = date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' })
  const heure = date.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
  return `${jour} · ${heure}`
}

// ---------------------------------------------------------------------
// US48 — avis des clients
// ---------------------------------------------------------------------

export interface AvisClient {
  id: string
  note: number
  commentaire: string | null
  creeLe: Date
  numero: number | null
  /** « Leïla M. » */
  client: string
}

export interface ResumeAvis {
  moyenne: number | null
  nombre: number
  /** Nombre d'avis par note : [5 étoiles, 4, 3, 2, 1]. */
  repartition: [number, number, number, number, number]
  avecCommentaire: number
}

export function resumerAvis(avis: AvisClient[]): ResumeAvis {
  const repartition: ResumeAvis['repartition'] = [0, 0, 0, 0, 0]
  let somme = 0
  let avecCommentaire = 0
  for (const a of avis) {
    repartition[5 - a.note] += 1
    somme += a.note
    if (a.commentaire) avecCommentaire += 1
  }
  return {
    moyenne: avis.length ? somme / avis.length : null,
    nombre: avis.length,
    repartition,
    avecCommentaire,
  }
}

/** 4.666 → « 4,7 ». */
export function formaterNote(note: number): string {
  return note.toFixed(1).replace('.', ',')
}

/** « ★★★★☆ » */
export function etoiles(note: number): string {
  return '★'.repeat(note) + '☆'.repeat(5 - note)
}

export type FiltreAvis = 'tous' | 'commentaires' | 1 | 2 | 3 | 4 | 5

export function filtrerAvis(avis: AvisClient[], filtre: FiltreAvis): AvisClient[] {
  if (filtre === 'tous') return avis
  if (filtre === 'commentaires') return avis.filter((a) => a.commentaire)
  return avis.filter((a) => a.note === filtre)
}
