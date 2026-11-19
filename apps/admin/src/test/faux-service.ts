import { vi } from 'vitest'

import { ErreurMida } from '../auth/erreurs'
import {
  messageNonAdmin,
  type CategorieAdmin,
  type ClientAdmin,
  type CommandeAdmin,
  type Compte,
  type FiltreCommandes,
  type LivreurAdmin,
  type Parametres,
  type RestaurantAdmin,
  type ServiceAdmin,
} from '../service'
import type { Reclamation, StatsPlateforme } from '../statistiques'

/** Faux service : données en mémoire, appels enregistrés. */
export class FauxService implements ServiceAdmin {
  compte: Compte | null = { email: 'admin@mida.test', nom: 'Administrateur Mida' }
  /** Rôle du compte qui se connecte avec `connecter`. */
  roleConnexion: string = 'admin'
  private rappels: (() => void)[] = []

  restaurantsListe: RestaurantAdmin[] = [
    {
      id: 'r4',
      nom: 'Lella Béya',
      ville: 'Sidi Bou Saïd',
      adresse: '8, rue Hédi Zarrouk',
      telephone: '+216 71 740 552',
      description: 'Couscous au poisson et cuisine de la mer.',
      categorie: 'Poissons',
      etat: 'en_attente',
      motifRejet: null,
      ouvert: false,
      creeLe: '2026-11-18T09:12:00Z',
      responsable: { id: 'u4', nom: 'Béya Ayari', email: 'lellabeya@mida.test', telephone: null, etat: 'en_attente' },
    },
    {
      id: 'r1',
      nom: 'Dar Zitouna',
      ville: 'La Marsa',
      adresse: '34, avenue Habib Bourguiba',
      telephone: null,
      description: null,
      categorie: 'Couscous et tajines',
      etat: 'actif',
      motifRejet: null,
      ouvert: true,
      creeLe: '2026-11-01T09:00:00Z',
      responsable: { id: 'u1', nom: 'Hédi Ben Ali', email: 'zitouna@mida.test', telephone: null, etat: 'actif' },
    },
  ]

  livreursListe: LivreurAdmin[] = [
    {
      id: 'l3',
      nom: 'Yassine Mejri',
      email: 'yassine@mida.test',
      telephone: '+216 29 117 930',
      etat: 'en_attente',
      creeLe: '2026-11-17T10:00:00Z',
      vehicule: 'moto',
      immatriculation: '250 TU 0912',
      disponible: false,
      documents: [
        { type: 'cin', etat: 'en_attente', chemin: 'l3/cin.jpg' },
        { type: 'permis', etat: 'en_attente', chemin: 'l3/permis.jpg' },
      ],
    },
    {
      id: 'l1',
      nom: 'Sami Ben Salah',
      email: 'sami@mida.test',
      telephone: null,
      etat: 'actif',
      creeLe: '2026-11-01T10:00:00Z',
      vehicule: 'moto',
      immatriculation: '245 TU 1830',
      disponible: true,
      documents: [],
    },
  ]

  clientsListe: ClientAdmin[] = [
    { id: 'c1', nom: 'Amine Belhadj', email: 'amine@mida.test', telephone: '+216 22 145 870', etat: 'actif', creeLe: '2026-11-02T08:00:00Z', nbCommandes: 3 },
    { id: 'c2', nom: 'Leïla Mansour', email: 'leila@mida.test', telephone: null, etat: 'bloque', creeLe: '2026-11-03T08:00:00Z', nbCommandes: 1 },
  ]

  commandesListe: CommandeAdmin[] = [
    {
      id: 'k1',
      numero: 1043,
      etat: 'refusee',
      creeLe: '2026-11-18T12:00:00Z',
      restaurant: 'El Kanoun',
      client: 'Leïla Mansour',
      adresse: '4, rue des Orangers, Ariana',
      sousTotal: 24,
      fraisLivraison: 2.5,
      total: 26.5,
      remarque: null,
      motifRefus: 'Plus de merguez ce soir',
      paiement: { mode: 'carte', etat: 'rembourse', montant: 26.5, reference: 'pi_test_1043', payeLe: '2026-11-18T12:00:00Z' },
      lignes: [{ nom: 'Ojja merguez', quantite: 2, prixUnitaire: 12 }],
      livreur: null,
      etatCourse: null,
    },
    {
      id: 'k2',
      numero: 1046,
      etat: 'en_livraison',
      creeLe: '2026-11-17T19:00:00Z',
      restaurant: 'Dar Zitouna',
      client: 'Amine Belhadj',
      adresse: 'Les Berges du Lac',
      sousTotal: 12,
      fraisLivraison: 2.5,
      total: 14.5,
      remarque: null,
      motifRefus: null,
      paiement: { mode: 'especes', etat: 'en_attente', montant: 14.5, reference: null, payeLe: null },
      lignes: [{ nom: 'Ojja merguez', quantite: 1, prixUnitaire: 12 }],
      livreur: 'Karim Dridi',
      etatCourse: 'recuperee',
    },
  ]

  param: Parametres = { fraisLivraison: 2.5, commissionPct: 10, gainLivreur: 2 }
  categoriesListe: CategorieAdmin[] = [
    { id: 'k1', nom: 'Couscous et tajines', ordre: 1, nbRestaurants: 2 },
    { id: 'k2', nom: 'Poissons', ordre: 2, nbRestaurants: 1 },
  ]

  /** Levée (une fois) par la prochaine action si elle est fournie. */
  erreurAction: unknown = null
  private action() {
    const e = this.erreurAction
    this.erreurAction = null
    if (e) throw e
  }

  compteActuel = vi.fn(async () => this.compte)
  surChangement(rappel: () => void) {
    this.rappels.push(rappel)
    return () => {
      this.rappels = this.rappels.filter((r) => r !== rappel)
    }
  }
  connecter = vi.fn(async (email: string) => {
    if (this.roleConnexion !== 'admin') throw new ErreurMida(messageNonAdmin)
    this.compte = { email, nom: 'Administrateur Mida' }
  })
  deconnecter = vi.fn(async () => {
    this.compte = null
    this.rappels.forEach((r) => r())
  })

  resume = vi.fn(async () => ({
    restaurantsEnAttente: 1,
    livreursEnAttente: 1,
    commandesAujourdhui: 4,
    commandesEnCours: 2,
    chiffreAffaires7j: 1234.5,
    commandes7j: 20,
    refusees7j: 1,
    clients: 2,
    restaurantsActifs: 1,
    livreursActifs: 1,
    reclamationsOuvertes: this.reclamationsListe.filter((r) => r.etat === 'ouverte').length,
  }))

  stats: StatsPlateforme = statsTest
  statistiques = vi.fn(async (jours: number) => {
    this.action()
    return { ...this.stats, jours }
  })

  reclamationsListe: Reclamation[] = [
    {
      id: 'rc1',
      motif: 'Plat manquant',
      description: 'Il manquait un fricassé dans ma commande.',
      etat: 'ouverte',
      reponse: null,
      montantRembourse: null,
      creeLe: '2026-11-19T19:30:00Z',
      traiteeLe: null,
      commande: { id: 'c1040', numero: 1040, total: 15.5, restaurant: 'Brik Bab Souika', livreeLe: '2026-11-19T19:00:00Z' },
      client: { nom: 'Amine Belhadj', email: 'amine@mida.test', telephone: '+216 22 145 870' },
    },
    {
      id: 'rc2',
      motif: 'Retard important',
      description: null,
      etat: 'rejetee',
      reponse: 'La commande a été livrée dans le délai annoncé.',
      montantRembourse: null,
      creeLe: '2026-11-15T12:00:00Z',
      traiteeLe: '2026-11-15T15:00:00Z',
      commande: { id: 'c1030', numero: 1030, total: 20, restaurant: 'Dar Zitouna', livreeLe: '2026-11-15T11:00:00Z' },
      client: { nom: 'Leïla Mansour', email: 'leila@mida.test', telephone: null },
    },
  ]
  reclamations = vi.fn(async () => this.reclamationsListe.map((r) => ({ ...r })))
  traiterReclamation = vi.fn(async (id: string, resolue: boolean, reponse: string, montant: number | null) => {
    this.action()
    this.reclamationsListe = this.reclamationsListe.map((r) =>
      r.id === id
        ? { ...r, etat: resolue ? 'resolue' : 'rejetee', reponse, montantRembourse: montant, traiteeLe: '2026-11-19T21:00:00Z' }
        : r,
    )
  })

  restaurants = vi.fn(async () => this.restaurantsListe.map((r) => ({ ...r })))
  deciderRestaurant = vi.fn(async (id: string, valider: boolean, motif?: string) => {
    this.action()
    this.restaurantsListe = this.restaurantsListe.map((r) =>
      r.id === id ? { ...r, etat: valider ? 'actif' : 'rejete', motifRejet: valider ? null : (motif ?? null) } : r,
    )
  })

  livreurs = vi.fn(async () => this.livreursListe.map((l) => ({ ...l })))
  urlDocument = vi.fn(async (chemin: string) => `https://stockage.test/${chemin}?jeton=x`)
  deciderLivreur = vi.fn(async (id: string, valider: boolean) => {
    this.action()
    this.livreursListe = this.livreursListe.map((l) => (l.id === id ? { ...l, etat: valider ? 'actif' : 'rejete' } : l))
  })

  clients = vi.fn(async () => this.clientsListe.map((c) => ({ ...c })))
  bloquerCompte = vi.fn(async (id: string, bloquer: boolean) => {
    this.action()
    const etat = bloquer ? 'bloque' : 'actif'
    this.clientsListe = this.clientsListe.map((c) => (c.id === id ? { ...c, etat } : c))
    this.livreursListe = this.livreursListe.map((l) => (l.id === id ? { ...l, etat } : l))
    this.restaurantsListe = this.restaurantsListe.map((r) =>
      r.responsable?.id === id ? { ...r, etat, responsable: { ...r.responsable, etat } } : r,
    )
  })

  commandes = vi.fn(async (filtre: FiltreCommandes) =>
    this.commandesListe.filter(
      (c) =>
        (!filtre.etat || c.etat === filtre.etat) &&
        (!filtre.restaurantId || c.restaurant === this.restaurantsListe.find((r) => r.id === filtre.restaurantId)?.nom) &&
        (!filtre.date || c.creeLe.startsWith(filtre.date)),
    ),
  )

  parametres = vi.fn(async () => ({ ...this.param }))
  enregistrerParametres = vi.fn(async (p: Parametres) => {
    this.action()
    this.param = p
  })
  categories = vi.fn(async () => this.categoriesListe.map((c) => ({ ...c })))
  ajouterCategorie = vi.fn(async (nom: string, ordre: number) => {
    this.action()
    this.categoriesListe = [...this.categoriesListe, { id: `k${ordre + 10}`, nom: nom.trim(), ordre, nbRestaurants: 0 }]
  })
  renommerCategorie = vi.fn(async (id: string, nom: string) => {
    this.categoriesListe = this.categoriesListe.map((c) => (c.id === id ? { ...c, nom } : c))
  })
  supprimerCategorie = vi.fn(async (id: string) => {
    this.categoriesListe = this.categoriesListe.filter((c) => c.id !== id)
  })
}

export const statsTest: StatsPlateforme = {
  jours: 30,
  commandes: 10,
  livrees: 6,
  refusees: 1,
  annulees: 1,
  chiffreAffaires: 165,
  ventesRestaurants: 150,
  fraisLivraison: 15,
  commissionPct: 10,
  commissions: 15,
  gainsLivreurs: 12,
  panierMoyen: 27.5,
  parJour: [
    { jour: '2026-11-18', commandes: 4, chiffreAffaires: 55 },
    { jour: '2026-11-19', commandes: 6, chiffreAffaires: 110 },
  ],
  topRestaurants: [
    { nom: 'Dar Zitouna', commandes: 4, ventes: 110 },
    { nom: 'El Kanoun', commandes: 2, ventes: 40 },
  ],
  nouveauxClients: 3,
  nouveauxLivreurs: 1,
  nouveauxRestaurants: 2,
  noteMoyenne: 4.6,
  reclamationsOuvertes: 1,
}
