/** Opérations de compte utilisées par les écrans (remplaçables dans les tests). */

import type { Horaire } from '../profil/horaires'

export type EtatRestaurant = 'en_attente' | 'actif' | 'rejete' | 'bloque'

export interface Restaurant {
  id: string
  nom: string
  ville: string
  etat: EtatRestaurant
  motif_rejet: string | null
  /** Interrupteur « ouvert / fermé » (US08) : un restaurant fermé ne reçoit plus de commande. */
  ouvert: boolean
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

/** Profil complet du restaurant, tel qu'il est modifiable par son responsable (US07). */
export interface ProfilRestaurant {
  id: string
  nom: string
  categorieId: string | null
  /** Tel qu'enregistré : « +216 xx xxx xxx », ou vide. */
  telephone: string
  adresse: string
  ville: string
  description: string
  logoUrl: string | null
  etat: EtatRestaurant
}

export interface ProfilEtHoraires {
  profil: ProfilRestaurant
  /** Toujours les 7 jours, du lundi au dimanche. */
  horaires: Horaire[]
  /** `false` tant que le responsable n'a jamais enregistré ses horaires. */
  horairesEnregistres: boolean
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

  /** Ouvre ou ferme le restaurant aux commandes (réservé aux restaurants validés). */
  changerOuverture(restaurantId: string, ouvert: boolean): Promise<void>

  /** Profil et horaires du restaurant du responsable connecté. */
  profilRestaurant(): Promise<ProfilEtHoraires>
  /** Enregistre les informations et les 7 jours d'horaires. */
  enregistrerProfil(restaurantId: string, infos: InfosRestaurant, horaires: Horaire[]): Promise<void>
  /** Envoie le nouveau logo et renvoie son adresse publique. */
  changerLogo(restaurantId: string, fichier: File): Promise<string>
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
