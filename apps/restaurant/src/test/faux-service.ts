import { vi } from 'vitest'

import type {
  Compte,
  InfosResponsable,
  InfosRestaurant,
  ProfilEtHoraires,
  ProfilRestaurant,
  ResultatInscription,
  ServiceRestaurant,
} from '../auth/service'
import { horairesParDefaut, type Horaire } from '../profil/horaires'

/** Faux service : garde le compte en mémoire et enregistre les appels. */
export class FauxService implements ServiceRestaurant {
  compte: Compte | null
  erreurCompte: Error | null = null
  resultatInscription: ResultatInscription = 'connecte'
  erreurInscription: unknown = null
  private rappels: (() => void)[] = []

  inscrire = vi.fn(async (responsable: InfosResponsable, restaurant: InfosRestaurant): Promise<ResultatInscription> => {
    if (this.erreurInscription) throw this.erreurInscription
    if (this.resultatInscription === 'connecte') {
      this.compte = { email: responsable.email.trim(), nom: responsable.nom, restaurant: null }
      this.prevenir() // comme Supabase : SIGNED_IN avant la création du restaurant
      this.compte = { ...this.compte, restaurant: this.restaurantDe(restaurant) }
    }
    return this.resultatInscription
  })

  creerRestaurant = vi.fn(async (restaurant: InfosRestaurant) => {
    if (!this.compte) throw new Error('pas de session')
    this.compte = { ...this.compte, restaurant: this.restaurantDe(restaurant) }
  })

  connecter = vi.fn(async () => {})
  deconnecter = vi.fn(async () => {
    this.compte = null
    this.prevenir()
  })

  erreurOuverture: unknown = null
  changerOuverture = vi.fn(async (_id: string, ouvert: boolean) => {
    if (this.erreurOuverture) throw this.erreurOuverture
    if (this.compte?.restaurant) this.compte = { ...this.compte, restaurant: { ...this.compte.restaurant, ouvert } }
  })

  /** Profil renvoyé par `profilRestaurant` (US07). */
  profil: ProfilRestaurant = {
    id: 'r1',
    nom: 'Dar Zitouna',
    categorieId: 'k1',
    telephone: '+216 71 744 210',
    adresse: '34, avenue Habib Bourguiba, La Marsa',
    ville: 'Tunis',
    description: 'Cuisine familiale de la médina.',
    logoUrl: null,
    etat: 'actif',
  }
  horaires: Horaire[] = horairesParDefaut().map((h) => (h.jour === 1 ? { ...h, ferme: true } : h))
  horairesEnregistres = true
  erreurProfil: unknown = null

  async profilRestaurant(): Promise<ProfilEtHoraires> {
    return { profil: this.profil, horaires: this.horaires, horairesEnregistres: this.horairesEnregistres }
  }

  enregistrerProfil = vi.fn(async (_id: string, infos: InfosRestaurant, _horaires: Horaire[]) => {
    if (this.erreurProfil) throw this.erreurProfil
    if (this.compte?.restaurant) {
      this.compte = { ...this.compte, restaurant: { ...this.compte.restaurant, nom: infos.nom.trim(), ville: infos.ville } }
    }
  })

  changerLogo = vi.fn(async (_id: string, fichier: File) => {
    if (this.erreurProfil) throw this.erreurProfil
    return `https://exemple.test/restaurants/r1/${fichier.name}`
  })

  constructor(compte: Compte | null = null) {
    this.compte = compte
  }

  async compteActuel(): Promise<Compte | null> {
    if (this.erreurCompte) throw this.erreurCompte
    return this.compte
  }

  surChangement(rappel: () => void): () => void {
    this.rappels.push(rappel)
    return () => {
      this.rappels = this.rappels.filter((r) => r !== rappel)
    }
  }

  async categories() {
    return [
      { id: 'k1', nom: 'Couscous et tajines' },
      { id: 'k2', nom: 'Ojja et grillades' },
    ]
  }

  private prevenir() {
    for (const r of this.rappels) setTimeout(r, 0)
  }

  private restaurantDe(r: InfosRestaurant) {
    return { id: 'r1', nom: r.nom.trim(), ville: r.ville, etat: 'en_attente' as const, motif_rejet: null, ouvert: false }
  }
}
