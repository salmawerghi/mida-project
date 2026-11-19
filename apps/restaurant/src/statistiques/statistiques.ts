/** Statistiques de ventes du restaurant (US44), calculées par la base (statistiques_restaurant). */

export interface VenteJour {
  /** « 2026-11-19 » (jour à l'heure de Tunis) */
  jour: string
  commandes: number
  ventes: number
}

export interface PlatVendu {
  nom: string
  quantite: number
  ventes: number
}

export interface StatsRestaurant {
  jours: number
  commandes: number
  livrees: number
  refusees: number
  annulees: number
  /** Montant des plats des commandes livrées (sans les frais de livraison). */
  ventes: number
  panierMoyen: number
  commissionPct: number
  commission: number
  parJour: VenteJour[]
  topPlats: PlatVendu[]
  noteMoyenne: number | null
  nbAvis: number
}

export const periodes = [
  { jours: 7, libelle: '7 jours' },
  { jours: 30, libelle: '30 jours' },
  { jours: 90, libelle: '90 jours' },
] as const

/** Réponse JSON de la fonction de la base → objet de l'appli (les montants arrivent en texte ou en nombre). */
export function lireStats(s: Record<string, unknown>): StatsRestaurant {
  const n = (v: unknown) => Number(v ?? 0)
  const liste = (v: unknown) => (Array.isArray(v) ? (v as Record<string, unknown>[]) : [])
  return {
    jours: n(s.jours),
    commandes: n(s.commandes),
    livrees: n(s.livrees),
    refusees: n(s.refusees),
    annulees: n(s.annulees),
    ventes: n(s.ventes),
    panierMoyen: n(s.panier_moyen),
    commissionPct: n(s.commission_pct),
    commission: n(s.commission),
    parJour: liste(s.par_jour).map((j) => ({ jour: String(j.jour), commandes: n(j.commandes), ventes: n(j.ventes) })),
    topPlats: liste(s.top_plats).map((p) => ({ nom: String(p.nom), quantite: n(p.quantite), ventes: n(p.ventes) })),
    noteMoyenne: s.note_moyenne === null || s.note_moyenne === undefined ? null : n(s.note_moyenne),
    nbAvis: n(s.nb_avis),
  }
}

/** Part des commandes refusées, en pourcentage arrondi à 0,1 (0 sans commande). */
export function tauxRefus(s: Pick<StatsRestaurant, 'commandes' | 'refusees'>): number {
  return s.commandes ? Math.round((s.refusees / s.commandes) * 1000) / 10 : 0
}

/** « 19 nov. » pour l'axe ; « mercredi 19 novembre » pour l'info-bulle. */
export function jourCourt(jour: string): string {
  return new Date(`${jour}T12:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })
}
export function jourLong(jour: string): string {
  return new Date(`${jour}T12:00:00`).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })
}

/** « 12,5 % » */
export function pourcentage(valeur: number): string {
  return `${String(valeur).replace('.', ',')} %`
}
