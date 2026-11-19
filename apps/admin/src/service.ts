/** Données et actions du tableau de bord d'administration (remplaçables dans les tests). */

export type EtatCompte = 'en_attente' | 'actif' | 'rejete' | 'bloque'

/** Administrateur connecté. */
export interface Compte {
  email: string
  nom: string
}

/** Chiffres de la page « Vue d'ensemble ». */
export interface Resume {
  restaurantsEnAttente: number
  livreursEnAttente: number
  commandesAujourdhui: number
  commandesEnCours: number
  /** Total des commandes livrées sur 7 jours, en dinars. */
  chiffreAffaires7j: number
  commandes7j: number
  refusees7j: number
  clients: number
  restaurantsActifs: number
  livreursActifs: number
  /** Réclamations des clients pas encore traitées (US49). */
  reclamationsOuvertes: number
}

export interface Responsable {
  id: string
  nom: string
  email: string
  telephone: string | null
  etat: EtatCompte
}

export interface RestaurantAdmin {
  id: string
  nom: string
  ville: string
  adresse: string
  telephone: string | null
  description: string | null
  categorie: string | null
  etat: EtatCompte
  motifRejet: string | null
  ouvert: boolean
  creeLe: string
  responsable: Responsable | null
}

export interface DocumentLivreur {
  /** « cin », « permis », « carte_grise », « photo ». */
  type: string
  etat: 'en_attente' | 'valide' | 'refuse'
  /** Chemin dans le stockage privé `documents-livreurs`. */
  chemin: string
}

export interface LivreurAdmin {
  id: string
  nom: string
  email: string
  telephone: string | null
  etat: EtatCompte
  creeLe: string
  vehicule: 'moto' | 'velo' | 'voiture' | null
  immatriculation: string | null
  disponible: boolean
  documents: DocumentLivreur[]
}

export interface ClientAdmin {
  id: string
  nom: string
  email: string
  telephone: string | null
  etat: EtatCompte
  creeLe: string
  nbCommandes: number
}

export type EtatCommande =
  | 'en_attente'
  | 'acceptee'
  | 'en_preparation'
  | 'prete'
  | 'en_livraison'
  | 'livree'
  | 'refusee'
  | 'annulee'

export interface CommandeAdmin {
  id: string
  numero: number
  etat: EtatCommande
  creeLe: string
  restaurant: string
  client: string
  adresse: string
  sousTotal: number
  fraisLivraison: number
  total: number
  remarque: string | null
  motifRefus: string | null
  paiement: {
    mode: 'carte' | 'especes'
    etat: 'en_attente' | 'paye' | 'echoue' | 'rembourse'
    montant: number
    reference: string | null
    payeLe: string | null
  } | null
  lignes: { nom: string; quantite: number; prixUnitaire: number }[]
  livreur: string | null
  etatCourse: string | null
}

export interface FiltreCommandes {
  etat?: EtatCommande | ''
  restaurantId?: string
  /** « 2026-11-18 » : commandes passées ce jour-là (heure locale). */
  date?: string
}

export interface Parametres {
  fraisLivraison: number
  commissionPct: number
  gainLivreur: number
}

export interface CategorieAdmin {
  id: string
  nom: string
  ordre: number
  nbRestaurants: number
}

import type { Reclamation, StatsPlateforme } from './statistiques'

export interface ServiceAdmin {
  /** Administrateur de la session, `null` sans session. Lève une erreur (et déconnecte) pour tout autre compte. */
  compteActuel(): Promise<Compte | null>
  surChangement(rappel: () => void): () => void
  connecter(email: string, motDePasse: string): Promise<void>
  deconnecter(): Promise<void>

  resume(): Promise<Resume>

  /** Tous les restaurants, les plus récents d'abord (US33). */
  restaurants(): Promise<RestaurantAdmin[]>
  deciderRestaurant(id: string, valider: boolean, motif?: string): Promise<void>

  /** Tous les livreurs avec leur véhicule et leurs documents (US34). */
  livreurs(): Promise<LivreurAdmin[]>
  /** Adresse temporaire (10 min) d'un document privé, pour le consulter. */
  urlDocument(chemin: string): Promise<string>
  deciderLivreur(id: string, valider: boolean, motif?: string): Promise<void>

  /** Comptes clients avec leur nombre de commandes (US35). */
  clients(): Promise<ClientAdmin[]>
  /** Bloque ou réactive un compte (client, livreur ou responsable de restaurant). */
  bloquerCompte(id: string, bloquer: boolean): Promise<void>

  /** Commandes de la plateforme, les plus récentes d'abord (200 au plus) (US36). */
  commandes(filtre: FiltreCommandes): Promise<CommandeAdmin[]>

  parametres(): Promise<Parametres>
  enregistrerParametres(p: Parametres): Promise<void>
  categories(): Promise<CategorieAdmin[]>
  ajouterCategorie(nom: string, ordre: number): Promise<void>
  renommerCategorie(id: string, nom: string): Promise<void>
  supprimerCategorie(id: string): Promise<void>

  /** Statistiques globales sur les `jours` derniers jours (US45). */
  statistiques(jours: number): Promise<StatsPlateforme>
  /** Réclamations des clients, les plus récentes d'abord (US49). */
  reclamations(): Promise<Reclamation[]>
  /** Résout (avec remboursement éventuel) ou rejette une réclamation ; le client est prévenu. */
  traiterReclamation(id: string, resolue: boolean, reponse: string, montant: number | null): Promise<void>
}

export const messageNonAdmin =
  "Ce compte n'a pas le rôle administrateur. Utilisez l'application qui correspond à votre profil."

/** Seuls les administrateurs non bloqués entrent dans le tableau de bord (US32). */
export function refusCompte(role: string | null | undefined, etat: string | null | undefined): string | null {
  if (role !== 'admin') return messageNonAdmin
  if (etat === 'bloque') return 'Ce compte est suspendu.'
  return null
}

/** Libellés des états de commande. */
export const libellesEtat: Record<EtatCommande, string> = {
  en_attente: 'En attente',
  acceptee: 'Acceptée',
  en_preparation: 'En préparation',
  prete: 'Prête',
  en_livraison: 'En cours de livraison',
  livree: 'Livrée',
  refusee: 'Refusée',
  annulee: 'Annulée',
}

export const libellesCompte: Record<EtatCompte, string> = {
  en_attente: 'En attente',
  actif: 'Actif',
  rejete: 'Rejeté',
  bloque: 'Bloqué',
}

export const libellesDocument: Record<string, string> = {
  cin: "Carte d'identité",
  permis: 'Permis de conduire',
  carte_grise: 'Carte grise',
  photo: "Photo d'identité",
}

export const libellesVehicule: Record<string, string> = { moto: 'Moto', velo: 'Vélo', voiture: 'Voiture' }

/** 16.5 → « 16,500 DT ». */
export function formaterPrix(montant: number): string {
  const [entier, decimales] = montant.toFixed(3).split('.')
  return `${entier.replace(/\B(?=(\d{3})+(?!\d))/g, ' ')},${decimales} DT`
}

/** « 18/11/2026 à 14:57 » (heure locale). */
export function formaterDateHeure(iso: string): string {
  const d = new Date(iso)
  const deux = (n: number) => String(n).padStart(2, '0')
  return `${deux(d.getDate())}/${deux(d.getMonth() + 1)}/${d.getFullYear()} à ${deux(d.getHours())}:${deux(d.getMinutes())}`
}

/** « 18/11/2026 ». */
export function formaterDate(iso: string): string {
  return formaterDateHeure(iso).slice(0, 10)
}

/** Bornes [début, fin[ d'un jour local « 2026-11-18 », en ISO. */
export function bornesJour(jour: string): [string, string] {
  const [a, m, j] = jour.split('-').map(Number)
  const debut = new Date(a, m - 1, j)
  const fin = new Date(a, m - 1, j + 1)
  return [debut.toISOString(), fin.toISOString()]
}

/** Recherche sans tenir compte des majuscules ni des accents. */
export function correspond(texte: string, recherche: string): boolean {
  const n = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
  return recherche
    .split(/\s+/)
    .filter(Boolean)
    .every((mot) => n(texte).includes(n(mot)))
}

/** « 2,5 » ou « 2.500 » → 2.5 ; `null` si ce n'est pas un nombre positif (3 décimales au plus). */
export function lireMontant(saisie: string): number | null {
  const t = saisie.trim().replace(',', '.')
  if (!/^\d+(\.\d{1,3})?$/.test(t)) return null
  return Number(t)
}
