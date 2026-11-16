import { vi } from 'vitest'

import type {
  Compte,
  InfosResponsable,
  InfosRestaurant,
  ProfilEtHoraires,
  ProfilRestaurant,
  ResultatInscription,
  ResultatPlat,
  ServiceRestaurant,
} from '../auth/service'
import { etatsEnCours, type Commande, type EtatCommande, type EvenementCommande } from '../commandes/commandes'
import type { CategorieMenu } from '../menu/categories'
import type { InfosPlat, Plat } from '../menu/plats'
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

  /** Menu gardé en mémoire (US09). */
  menu: CategorieMenu[] = [
    { id: 'c1', nom: 'Couscous', ordre: 1, nbPlats: 3 },
    { id: 'c2', nom: 'Tajines', ordre: 2, nbPlats: 0 },
    { id: 'c3', nom: 'Douceurs et thé', ordre: 3, nbPlats: 1 },
  ]
  erreurMenu: unknown = null
  private prochainId = 10

  categoriesMenu = vi.fn(async (_restaurant: string) =>
    [...this.menu]
      .sort((a, b) => a.ordre - b.ordre)
      .map((c) => ({ ...c, nbPlats: this.plats.filter((p) => p.categorieId === c.id).length })),
  )

  creerCategorieMenu = vi.fn(async (_restaurant: string, nom: string, ordre: number) => {
    if (this.erreurMenu) throw this.erreurMenu
    this.menu = [...this.menu, { id: `c${this.prochainId++}`, nom: nom.trim(), ordre, nbPlats: 0 }]
  })

  renommerCategorieMenu = vi.fn(async (id: string, nom: string) => {
    if (this.erreurMenu) throw this.erreurMenu
    this.menu = this.menu.map((c) => (c.id === id ? { ...c, nom: nom.trim() } : c))
  })

  ordonnerCategoriesMenu = vi.fn(async (_restaurant: string, categories: CategorieMenu[]) => {
    if (this.erreurMenu) throw this.erreurMenu
    this.menu = categories.map((c, i) => ({ ...c, ordre: i + 1 }))
  })

  supprimerCategorieMenu = vi.fn(async (id: string) => {
    if (this.erreurMenu) throw this.erreurMenu
    this.menu = this.menu.filter((c) => c.id !== id)
    this.plats = this.plats.filter((p) => p.categorieId !== id)
  })

  /** Plats gardés en mémoire (US10). */
  plats: Plat[] = [
    { id: 'p1', categorieId: 'c1', nom: 'Couscous à l’agneau', description: 'Semoule fine, agneau', prix: 18, imageUrl: null, disponible: true },
    { id: 'p2', categorieId: 'c1', nom: 'Couscous aux légumes', description: '', prix: 13, imageUrl: 'https://exemple.test/p2.webp', disponible: true },
    { id: 'p3', categorieId: 'c1', nom: 'Couscous au poisson', description: 'Mérou', prix: 22.5, imageUrl: null, disponible: true },
    { id: 'p4', categorieId: 'c3', nom: 'Thé à la menthe', description: '', prix: 2.5, imageUrl: null, disponible: true },
  ]
  erreurPlat: unknown = null
  /** Simule une photo refusée par le stockage (le plat est quand même enregistré). */
  erreurPhoto: string | null = null

  platsMenu = vi.fn(async (_restaurant: string) => [...this.plats])

  enregistrerPlat = vi.fn(
    async (_restaurant: string, platId: string | null, infos: InfosPlat, photo: File | null): Promise<ResultatPlat> => {
      if (this.erreurPlat) throw this.erreurPlat
      const ancien = this.plats.find((p) => p.id === platId)
      const plat: Plat = {
        id: platId ?? `p${this.prochainId++}`,
        categorieId: infos.categorieId,
        nom: infos.nom.trim(),
        description: infos.description.trim(),
        prix: infos.prix,
        imageUrl: photo && !this.erreurPhoto ? `https://exemple.test/${photo.name}` : (ancien?.imageUrl ?? null),
        disponible: ancien?.disponible ?? true,
      }
      this.plats = ancien ? this.plats.map((p) => (p.id === plat.id ? plat : p)) : [...this.plats, plat]
      return { plat, erreurPhoto: photo ? this.erreurPhoto : null }
    },
  )

  supprimerPlat = vi.fn(async (_restaurant: string, plat: Plat) => {
    if (this.erreurPlat) throw this.erreurPlat
    this.plats = this.plats.filter((p) => p.id !== plat.id)
  })

  changerDisponibilite = vi.fn(async (platId: string, disponible: boolean) => {
    if (this.erreurPlat) throw this.erreurPlat
    this.plats = this.plats.map((p) => (p.id === platId ? { ...p, disponible } : p))
  })

  /** Commandes en cours gardées en mémoire (US12) ; `maintenant` des tests : 2026-11-16 12:00. */
  commandes: Commande[] = [
    {
      id: 'k1045',
      numero: 1045,
      etat: 'en_attente',
      client: 'Youssef K.',
      total: 23,
      remarque: null,
      creeeLe: new Date('2026-11-16T11:57:00'),
      depuisLe: new Date('2026-11-16T11:57:00'),
      lignes: [
        { nomPlat: 'Couscous à l’agneau', quantite: 1, remarque: 'Piquant : moyen' },
        { nomPlat: 'Thé à la menthe', quantite: 2, remarque: null },
      ],
      paiement: { mode: 'carte', etat: 'paye' },
    },
    {
      id: 'k1044',
      numero: 1044,
      etat: 'en_preparation',
      client: 'Leïla M.',
      total: 50.5,
      remarque: 'Sonner deux fois',
      creeeLe: new Date('2026-11-16T11:48:00'),
      depuisLe: new Date('2026-11-16T11:51:00'),
      lignes: [{ nomPlat: 'Tajine de poulet aux olives', quantite: 3, remarque: null }],
      paiement: { mode: 'especes', etat: 'en_attente' },
    },
  ]
  erreurCommandes: unknown = null
  private abonnes: { rappel: (e: EvenementCommande) => void; surConnexion: () => void }[] = []

  commandesEnCours = vi.fn(async (_restaurant: string) => {
    if (this.erreurCommandes) throw this.erreurCommandes
    // comme le vrai service : seulement les commandes en cours
    return this.commandes.filter((c) => etatsEnCours.includes(c.etat))
  })

  surCommandes = vi.fn((_restaurant: string, rappel: (e: EvenementCommande) => void, surConnexion: () => void) => {
    const abonne = { rappel, surConnexion }
    this.abonnes.push(abonne)
    return () => {
      this.abonnes = this.abonnes.filter((a) => a !== abonne)
    }
  })

  get nbAbonnes(): number {
    return this.abonnes.length
  }

  /** Simule une commande passée par un client (événement temps réel). */
  simulerCommande(commande: Commande) {
    this.commandes = [...this.commandes, commande]
    for (const a of this.abonnes) a.rappel({ type: 'INSERT', id: commande.id, etat: commande.etat })
  }

  /** Simule un changement d'état (par exemple par la future fonction « accepter »). */
  simulerChangement(id: string, etat: EtatCommande) {
    this.commandes = this.commandes.map((c) => (c.id === id ? { ...c, etat } : c))
    for (const a of this.abonnes) a.rappel({ type: 'UPDATE', id, etat })
  }

  erreurDecision: unknown = null

  accepterCommande = vi.fn(async (id: string) => {
    if (this.erreurDecision) throw this.erreurDecision
    this.simulerChangement(id, 'acceptee')
  })

  refuserCommande = vi.fn(async (id: string, _motif: string) => {
    if (this.erreurDecision) throw this.erreurDecision
    // une commande refusée quitte la page « Commandes en cours »
    this.simulerChangement(id, 'refusee')
    this.commandes = this.commandes.filter((c) => c.id !== id)
  })

  avancerCommande = vi.fn(async (id: string, etat: 'en_preparation' | 'prete') => {
    if (this.erreurDecision) throw this.erreurDecision
    this.simulerChangement(id, etat)
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
