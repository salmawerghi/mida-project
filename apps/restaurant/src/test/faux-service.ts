import { vi } from 'vitest'

import type { Compte, InfosResponsable, InfosRestaurant, ResultatInscription, ServiceRestaurant } from '../auth/service'

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
    return { id: 'r1', nom: r.nom.trim(), ville: r.ville, etat: 'en_attente' as const, motif_rejet: null }
  }
}
