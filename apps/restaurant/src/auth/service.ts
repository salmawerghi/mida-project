/** Opérations de compte utilisées par les écrans (remplaçables dans les tests). */

export type EtatRestaurant = 'en_attente' | 'actif' | 'rejete' | 'bloque'

export interface Restaurant {
  id: string
  nom: string
  ville: string
  etat: EtatRestaurant
  motif_rejet: string | null
}

/** Compte connecté : un responsable et, s'il l'a inscrit, son restaurant. */
export interface Compte {
  email: string
  nom: string
  restaurant: Restaurant | null
}

export interface InfosResponsable {
  nom: string
  email: string
  telephone: string // déjà au format « +216 xx xxx xxx »
  motDePasse: string
}

export interface InfosRestaurant {
  nom: string
  categorieId: string | null
  telephone: string // déjà au format « +216 xx xxx xxx »
  adresse: string
  ville: string
  description: string
}

export interface Categorie {
  id: string
  nom: string
}

export type ResultatInscription =
  /** Compte et restaurant créés, session ouverte. */
  | 'connecte'
  /** Compte créé : il faut cliquer le lien reçu par e-mail avant de se connecter. */
  | 'confirmationEmail'

export interface ServiceRestaurant {
  /** Compte de la session en cours, `null` sans session. Lève `ErreurMida` (et déconnecte) si le compte est refusé. */
  compteActuel(): Promise<Compte | null>
  /** Prévient à chaque connexion / déconnexion. Renvoie la fonction de désabonnement. */
  surChangement(rappel: () => void): () => void
  connecter(email: string, motDePasse: string, resterConnecte: boolean): Promise<void>
  inscrire(responsable: InfosResponsable, restaurant: InfosRestaurant): Promise<ResultatInscription>
  /** Pour un responsable déjà connecté qui n'a pas encore inscrit son restaurant. */
  creerRestaurant(restaurant: InfosRestaurant): Promise<void>
  categories(): Promise<Categorie[]>
  deconnecter(): Promise<void>
}

/** Seuls les comptes « responsable » non bloqués utilisent l'espace restaurant. */
export function refusCompte(role: string | null | undefined, etat: string | null | undefined): string | null {
  if (role && role !== 'responsable') {
    const appli =
      role === 'client' ? "l'application mobile Mida"
      : role === 'livreur' ? "l'application Mida Livreur"
      : "le tableau de bord d'administration"
    return `Ce compte n'est pas un compte restaurant. Utilisez ${appli}.`
  }
  if (etat === 'bloque') return 'Ce compte est suspendu. Contactez le support Mida.'
  return null
}

export const messageRestaurantBloque = 'Ce restaurant est suspendu. Contactez le support Mida.'

/** Page où envoyer un compte connecté, selon l'état de son restaurant. */
export function pageDuCompte(compte: Compte): '/inscription' | '/attente' | '/tableau' {
  if (!compte.restaurant) return '/inscription'
  return compte.restaurant.etat === 'actif' ? '/tableau' : '/attente'
}
