/** Statistiques globales (US45) et réclamations (US49) de l'administration. */

export interface JourPlateforme {
  jour: string
  commandes: number
  chiffreAffaires: number
}

export interface StatsPlateforme {
  jours: number
  commandes: number
  livrees: number
  refusees: number
  annulees: number
  /** Total payé par les clients pour les commandes livrées (plats + livraison). */
  chiffreAffaires: number
  ventesRestaurants: number
  fraisLivraison: number
  commissionPct: number
  commissions: number
  gainsLivreurs: number
  panierMoyen: number
  parJour: JourPlateforme[]
  topRestaurants: { nom: string; commandes: number; ventes: number }[]
  nouveauxClients: number
  nouveauxLivreurs: number
  nouveauxRestaurants: number
  noteMoyenne: number | null
  reclamationsOuvertes: number
}

export const periodes = [
  { jours: 7, libelle: '7 jours' },
  { jours: 30, libelle: '30 jours' },
  { jours: 90, libelle: '90 jours' },
] as const

/** Réponse JSON de statistiques_plateforme → objet de l'appli. */
export function lireStatsPlateforme(s: Record<string, unknown>): StatsPlateforme {
  const n = (v: unknown) => Number(v ?? 0)
  const liste = (v: unknown) => (Array.isArray(v) ? (v as Record<string, unknown>[]) : [])
  return {
    jours: n(s.jours),
    commandes: n(s.commandes),
    livrees: n(s.livrees),
    refusees: n(s.refusees),
    annulees: n(s.annulees),
    chiffreAffaires: n(s.chiffre_affaires),
    ventesRestaurants: n(s.ventes_restaurants),
    fraisLivraison: n(s.frais_livraison),
    commissionPct: n(s.commission_pct),
    commissions: n(s.commissions),
    gainsLivreurs: n(s.gains_livreurs),
    panierMoyen: n(s.panier_moyen),
    parJour: liste(s.par_jour).map((j) => ({
      jour: String(j.jour),
      commandes: n(j.commandes),
      chiffreAffaires: n(j.chiffre_affaires),
    })),
    topRestaurants: liste(s.top_restaurants).map((r) => ({
      nom: String(r.nom),
      commandes: n(r.commandes),
      ventes: n(r.ventes),
    })),
    nouveauxClients: n(s.nouveaux_clients),
    nouveauxLivreurs: n(s.nouveaux_livreurs),
    nouveauxRestaurants: n(s.nouveaux_restaurants),
    noteMoyenne: s.note_moyenne === null || s.note_moyenne === undefined ? null : n(s.note_moyenne),
    reclamationsOuvertes: n(s.reclamations_ouvertes),
  }
}

/**
 * Revenu de Mida sur les commandes livrées : commissions + frais de
 * livraison − gains versés aux livreurs.
 */
export function revenuMida(s: Pick<StatsPlateforme, 'commissions' | 'fraisLivraison' | 'gainsLivreurs'>): number {
  return Math.round((s.commissions + s.fraisLivraison - s.gainsLivreurs) * 1000) / 1000
}

/** Pourcentage arrondi à 0,1 : « 12,5 % » (0 % sans total). */
export function part(valeur: number, total: number): string {
  const p = total ? Math.round((valeur / total) * 1000) / 10 : 0
  return `${String(p).replace('.', ',')} %`
}

export function jourCourt(jour: string): string {
  return new Date(`${jour}T12:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })
}
export function jourLong(jour: string): string {
  return new Date(`${jour}T12:00:00`).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })
}

// ---------------------------------------------------------------------
// US49 — réclamations
// ---------------------------------------------------------------------
export type EtatReclamation = 'ouverte' | 'en_cours' | 'resolue' | 'rejetee'

export const libellesReclamation: Record<EtatReclamation, string> = {
  ouverte: 'À traiter',
  en_cours: 'En cours',
  resolue: 'Résolue',
  rejetee: 'Rejetée',
}

export interface Reclamation {
  id: string
  motif: string
  description: string | null
  etat: EtatReclamation
  reponse: string | null
  montantRembourse: number | null
  creeLe: string
  traiteeLe: string | null
  commande: { id: string; numero: number; total: number; restaurant: string; livreeLe: string | null }
  client: { nom: string; email: string; telephone: string | null }
}

export const aTraiter = (r: Reclamation) => r.etat === 'ouverte' || r.etat === 'en_cours'

/** Vérifie la décision avant l'envoi ; renvoie les erreurs à afficher sous les champs. */
export function validerTraitement(
  decision: 'resolue' | 'rejetee' | null,
  reponse: string,
  montant: string,
  total: number,
): { decision?: string; reponse?: string; montant?: string; valeur?: number | null } {
  if (!decision) return { decision: 'Choisissez : réclamation fondée ou non.' }
  if (!reponse.trim()) return { reponse: 'Écrivez une réponse : elle est envoyée au client.' }
  if (reponse.trim().length > 1000) return { reponse: '1000 caractères maximum.' }
  if (decision === 'rejetee' || !montant.trim()) return { valeur: null }
  const valeur = Number(montant.trim().replace(',', '.'))
  if (!Number.isFinite(valeur) || valeur < 0) return { montant: 'Montant invalide.' }
  if (valeur > total) return { montant: `Au plus le total de la commande.` }
  return { valeur: valeur === 0 ? null : Math.round(valeur * 1000) / 1000 }
}
