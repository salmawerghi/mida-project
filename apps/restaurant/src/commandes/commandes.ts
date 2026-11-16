/** Commandes en cours du restaurant (US12, table `commandes` et son détail). */

export type EtatCommande =
  | 'en_attente'
  | 'acceptee'
  | 'en_preparation'
  | 'prete'
  | 'en_livraison'
  | 'livree'
  | 'refusee'
  | 'annulee'

/** États affichés sur la page « Commandes en cours » (les autres sont dans l'historique). */
export const etatsEnCours: EtatCommande[] = ['en_attente', 'acceptee', 'en_preparation', 'prete', 'en_livraison']

export interface LigneCommande {
  nomPlat: string
  quantite: number
  remarque: string | null
}

export interface Commande {
  id: string
  numero: number
  etat: EtatCommande
  /** Nom du client tel qu'il l'a saisi à l'inscription. */
  client: string
  total: number
  remarque: string | null
  creeeLe: Date
  /** Date du dernier changement d'état utile (acceptation, prête…), sinon la création. */
  depuisLe: Date
  lignes: LigneCommande[]
  paiement: { mode: 'carte' | 'especes'; etat: 'en_attente' | 'paye' | 'echoue' | 'rembourse' } | null
}

/** Changement reçu en temps réel (Supabase Realtime). */
export interface EvenementCommande {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  id: string | null
  etat: EtatCommande | null
}

/** « Leïla Mansour » → « Leïla M. » (comme sur la maquette : prénom et initiale). */
export function nomCourt(nom: string): string {
  const mots = nom.trim().split(/\s+/).filter(Boolean)
  if (mots.length < 2) return mots[0] ?? 'Client'
  return `${mots[0]} ${mots[mots.length - 1][0].toUpperCase()}.`
}

/** Les 4 colonnes de la maquette « Restaurant · Commandes en cours ». */
export const colonnes: { titre: string; etats: EtatCommande[]; vide: string }[] = [
  { titre: 'En attente', etats: ['en_attente'], vide: 'Aucune nouvelle commande.' },
  { titre: 'En préparation', etats: ['acceptee', 'en_preparation'], vide: 'Rien en préparation.' },
  { titre: 'Prête', etats: ['prete'], vide: 'Aucune commande prête.' },
  { titre: 'En cours de livraison', etats: ['en_livraison'], vide: 'Aucune livraison en cours.' },
]

/** « Carte · payée », « Espèces »… */
export function libellePaiement(paiement: Commande['paiement']): string {
  if (!paiement) return 'Paiement non indiqué'
  if (paiement.mode === 'especes') return 'Espèces à la livraison'
  const etats = { paye: 'payée', en_attente: 'en attente', echoue: 'paiement échoué', rembourse: 'remboursée' }
  return `Carte · ${etats[paiement.etat]}`
}

/** Minutes écoulées, arrondies vers le bas (jamais négatives). */
function minutes(depuis: Date, maintenant: Date): number {
  return Math.max(0, Math.floor((maintenant.getTime() - depuis.getTime()) / 60_000))
}

/** « à l'instant », « il y a 3 min », « il y a 1 h 05 ». */
export function ilYa(depuis: Date, maintenant: Date): string {
  const m = minutes(depuis, maintenant)
  if (m === 0) return "à l'instant"
  if (m < 60) return `il y a ${m} min`
  return `il y a ${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')}`
}

/** « depuis 9 min » (temps passé dans l'état actuel). */
export function duree(depuis: Date, maintenant: Date): string {
  const m = minutes(depuis, maintenant)
  if (m === 0) return "depuis moins d'1 min"
  if (m < 60) return `depuis ${m} min`
  return `depuis ${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')}`
}

/** « 1 nouvelle commande à traiter », « 2 nouvelles commandes à traiter ». */
export function libelleATraiter(n: number): string {
  return n === 1 ? '1 nouvelle commande à traiter' : `${n} nouvelles commandes à traiter`
}

/** Motifs de refus proposés (maquette « Restaurant · Refus »), US13. */
export const motifsRefus = ['Un plat est épuisé', 'Trop de commandes en cours', 'Le restaurant ferme bientôt', 'Autre motif'] as const
export type MotifRefus = (typeof motifsRefus)[number]
export const longueurMaxMessageRefus = 250

/** Vérifie le formulaire de refus ; renvoie les erreurs à afficher sous les champs. */
export function validerRefus(motif: MotifRefus | null, message: string): { motif?: string; message?: string } {
  if (!motif) return { motif: 'Choisissez le motif du refus.' }
  if (motif === 'Autre motif' && !message.trim()) return { message: 'Précisez le motif pour le client.' }
  if (message.trim().length > longueurMaxMessageRefus) return { message: `${longueurMaxMessageRefus} caractères maximum.` }
  return {}
}

/** Motif enregistré et envoyé au client : « Un plat est épuisé — Plus de merguez ce soir. » */
export function composerMotif(motif: MotifRefus, message: string): string {
  const texte = message.trim()
  if (motif === 'Autre motif') return texte
  return texte ? `${motif} — ${texte}` : motif
}

/** « 2 × Brik à l'œuf, 1 × Ojja merguez » (résumé d'une commande). */
export function resumePlats(commande: Commande): string {
  return commande.lignes.map((l) => `${l.quantite} × ${l.nomPlat}`).join(', ')
}

/** Étape suivante proposée au restaurant (US14) : acceptée → en préparation → prête. */
export function etapeSuivante(etat: EtatCommande): { etat: 'en_preparation' | 'prete'; bouton: string } | null {
  if (etat === 'acceptee') return { etat: 'en_preparation', bouton: 'Commencer la préparation' }
  if (etat === 'en_preparation') return { etat: 'prete', bouton: 'Marquer comme prête' }
  return null
}
