import { createClient, type SupabaseClient } from '@supabase/supabase-js'

import {
  etatsEnCours,
  nomCourt,
  type Commande,
  type EtatCommande,
  type EvenementCommande,
} from '../commandes/commandes'

import { supabaseKey, supabaseUrl } from '../config'
import { lireStats, type StatsRestaurant } from '../statistiques/statistiques'
import {
  bornesDates,
  etatsDuFiltre,
  lireNumero,
  parPage,
  type AvisClient,
  type CommandeHistorique,
  type FiltresHistorique,
  type PageHistorique,
} from '../historique/historique'
import { messageCategorieExistante, type CategorieMenu } from '../menu/categories'
import type { InfosPlat, Plat } from '../menu/plats'
import { completerHoraires, heureCourte, type Horaire } from '../profil/horaires'
import { reduireImage } from '../profil/image'
import { messageErreur } from './erreurs'
import { effacerBrouillon, sauverBrouillon } from './brouillon'
import { ErreurMida, messageCodeInvalide, messageCompteExistant } from './erreurs'
import {
  messageRestaurantBloque,
  refusCompte,
  type Categorie,
  type Compte,
  type InfosResponsable,
  type InfosRestaurant,
  type ProfilEtHoraires,
  type ResultatPlat,
  type Restaurant,
  type ResultatInscription,
  type ServiceRestaurant,
} from './service'

// « Rester connecté » : session gardée dans localStorage (elle survit à la
// fermeture du navigateur) ; sinon dans sessionStorage (fermée avec l'onglet).
const cleResterConnecte = 'mida.resterConnecte'

const stockageSession = {
  getItem: (k: string) => localStorage.getItem(k) ?? sessionStorage.getItem(k),
  setItem: (k: string, v: string) => {
    const durable = localStorage.getItem(cleResterConnecte) !== 'non'
    ;(durable ? localStorage : sessionStorage).setItem(k, v)
    ;(durable ? sessionStorage : localStorage).removeItem(k)
  },
  removeItem: (k: string) => {
    localStorage.removeItem(k)
    sessionStorage.removeItem(k)
  },
}

const messageSessionExpiree = 'Votre session a expiré. Connectez-vous à nouveau.'
const messageModificationRefusee = "Ce compte n'a pas le droit de modifier ce restaurant."

export function creerClientSupabase(): SupabaseClient {
  return createClient(supabaseUrl, supabaseKey, {
    auth: { storage: stockageSession, persistSession: true, autoRefreshToken: true },
  })
}

export class ServiceRestaurantSupabase implements ServiceRestaurant {
  private readonly client: SupabaseClient

  constructor(client: SupabaseClient) {
    this.client = client
  }

  async compteActuel(): Promise<Compte | null> {
    const { data } = await this.client.auth.getSession()
    const session = data.session
    if (!session) return null
    const id = session.user.id

    const { data: profil, error } = await this.client
      .from('profiles')
      .select('nom, role, etat_compte')
      .eq('id', id)
      .maybeSingle()
    if (error) throw error
    const refus = refusCompte(profil?.role, profil?.etat_compte)
    if (refus) {
      await this.client.auth.signOut()
      throw new ErreurMida(refus)
    }

    const { data: restaurant, error: erreurResto } = await this.client
      .from('restaurants')
      .select('id, nom, ville, etat, motif_rejet, ouvert')
      .eq('responsable_id', id)
      .maybeSingle<Restaurant>()
    if (erreurResto) throw erreurResto
    if (restaurant?.etat === 'bloque') {
      await this.client.auth.signOut()
      throw new ErreurMida(messageRestaurantBloque)
    }

    return {
      email: session.user.email ?? '',
      nom: profil?.nom ?? session.user.email?.split('@')[0] ?? '',
      restaurant: restaurant ?? null,
    }
  }

  surChangement(rappel: () => void): () => void {
    const { data } = this.client.auth.onAuthStateChange((evenement) => {
      if (evenement === 'TOKEN_REFRESHED') return
      // Ne pas appeler Supabase directement dans ce rappel (risque de blocage) :
      // on laisse d'abord se terminer l'opération en cours.
      setTimeout(rappel, 0)
    })
    return () => data.subscription.unsubscribe()
  }

  async connecter(email: string, motDePasse: string, resterConnecte: boolean): Promise<void> {
    localStorage.setItem(cleResterConnecte, resterConnecte ? 'oui' : 'non')
    const { error } = await this.client.auth.signInWithPassword({ email: email.trim(), password: motDePasse })
    if (error) throw error
    // vérifie le rôle et l'état (lève ErreurMida et déconnecte si refusé)
    await this.compteActuel()
  }

  async demanderReinitialisation(email: string): Promise<void> {
    const { error } = await this.client.auth.resetPasswordForEmail(email.trim())
    if (error) throw error
  }

  async verifierCodeReinitialisation(email: string, code: string): Promise<void> {
    const { data, error } = await this.client.auth.verifyOtp({
      type: 'recovery',
      email: email.trim(),
      token: code.replace(/\s/g, ''),
    })
    if (error) throw error
    if (!data.session) throw new ErreurMida(messageCodeInvalide)
    // un compte client ou livreur n'utilise pas l'espace restaurant (déconnecté par compteActuel)
    await this.compteActuel()
  }

  async changerMotDePasse(motDePasse: string): Promise<void> {
    const { error } = await this.client.auth.updateUser({ password: motDePasse })
    if (error) throw error
  }

  async inscrire(responsable: InfosResponsable, restaurant: InfosRestaurant): Promise<ResultatInscription> {
    localStorage.setItem(cleResterConnecte, 'oui')
    // Métadonnées lues par le déclencheur creer_profil_nouvel_utilisateur
    // (migration US02) : profil « responsable », en attente de validation.
    const { data, error } = await this.client.auth.signUp({
      email: responsable.email.trim(),
      password: responsable.motDePasse,
      options: {
        data: { role: 'responsable', nom: responsable.nom.trim(), telephone: responsable.telephone },
      },
    })
    if (error) throw error
    // Confirmation d'e-mail activée : Supabase ne signale pas une adresse
    // déjà utilisée, il renvoie un utilisateur sans identité.
    if (data.user && data.user.identities?.length === 0) throw new ErreurMida(messageCompteExistant)
    if (!data.session) {
      sauverBrouillon(responsable.email, restaurant)
      return 'confirmationEmail'
    }
    await this.creerRestaurant(restaurant)
    return 'connecte'
  }

  async creerRestaurant(restaurant: InfosRestaurant): Promise<void> {
    const { data } = await this.client.auth.getUser()
    if (!data.user) throw new ErreurMida(messageSessionExpiree)
    // L'état n'est pas envoyé : la base le force à « en_attente » (déclencheur proteger_restaurant).
    const { error } = await this.client.from('restaurants').insert({
      responsable_id: data.user.id,
      nom: restaurant.nom.trim(),
      categorie_id: restaurant.categorieId,
      telephone: restaurant.telephone,
      adresse: restaurant.adresse.trim(),
      ville: restaurant.ville,
      description: restaurant.description.trim() || null,
    })
    if (error) throw error
    effacerBrouillon()
  }

  async categories(): Promise<Categorie[]> {
    const { data, error } = await this.client.from('categories_restaurant').select('id, nom').order('ordre')
    if (error) throw error
    return data ?? []
  }

  async deconnecter(): Promise<void> {
    await this.client.auth.signOut()
  }

  async changerOuverture(restaurantId: string, ouvert: boolean): Promise<void> {
    const { data, error } = await this.client.from('restaurants').update({ ouvert }).eq('id', restaurantId).select('id')
    if (error) throw error
    if (!data?.length) throw new ErreurMida(messageModificationRefusee)
  }

  async profilRestaurant(): Promise<ProfilEtHoraires> {
    const { data: session } = await this.client.auth.getSession()
    const id = session.session?.user.id
    if (!id) throw new ErreurMida(messageSessionExpiree)

    const { data: r, error } = await this.client
      .from('restaurants')
      .select('id, nom, categorie_id, telephone, adresse, ville, description, logo_url, etat')
      .eq('responsable_id', id)
      .maybeSingle()
    if (error) throw error
    if (!r) throw new ErreurMida("Aucun restaurant n'est inscrit avec ce compte.")

    const { data: lignes, error: erreurHoraires } = await this.client
      .from('horaires')
      .select('jour, ferme, ouverture, fermeture')
      .eq('restaurant_id', r.id)
    if (erreurHoraires) throw erreurHoraires
    const horaires: Horaire[] = (lignes ?? []).map((l) => ({
      jour: l.jour,
      ferme: l.ferme,
      ouverture: heureCourte(l.ouverture),
      fermeture: heureCourte(l.fermeture),
    }))

    return {
      profil: {
        id: r.id,
        nom: r.nom,
        categorieId: r.categorie_id,
        telephone: r.telephone ?? '',
        adresse: r.adresse,
        ville: r.ville,
        description: r.description ?? '',
        logoUrl: r.logo_url,
        etat: r.etat,
      },
      horaires: completerHoraires(horaires),
      horairesEnregistres: horaires.length > 0,
    }
  }

  async enregistrerProfil(restaurantId: string, infos: InfosRestaurant, horaires: Horaire[]): Promise<void> {
    // L'état et le motif de refus ne sont jamais envoyés : seul l'admin les change.
    const { data, error } = await this.client
      .from('restaurants')
      .update({
        nom: infos.nom.trim(),
        categorie_id: infos.categorieId,
        telephone: infos.telephone,
        adresse: infos.adresse.trim(),
        ville: infos.ville,
        description: infos.description.trim() || null,
      })
      .eq('id', restaurantId)
      .select('id')
    if (error) throw error
    // Les règles d'accès ne renvoient pas d'erreur : elles ne modifient aucune ligne.
    if (!data?.length) throw new ErreurMida(messageModificationRefusee)

    const { error: erreurHoraires } = await this.client.from('horaires').upsert(
      horaires.map((h) => ({
        restaurant_id: restaurantId,
        jour: h.jour,
        ferme: h.ferme,
        // un jour fermé garde ses heures (si elles existent) pour une réouverture
        ouverture: h.ouverture || null,
        fermeture: h.fermeture || null,
      })),
      { onConflict: 'restaurant_id,jour' },
    )
    if (erreurHoraires) throw erreurHoraires
  }

  async changerLogo(restaurantId: string, fichier: File): Promise<string> {
    const image = await reduireImage(fichier)
    // Chemin fixe (voir le README, « Stockage des images ») : le nouveau logo remplace l'ancien.
    const chemin = `${restaurantId}/logo.webp`
    const stockage = this.client.storage.from('restaurants')
    const { error } = await stockage.upload(chemin, image, { upsert: true, contentType: image.type, cacheControl: '3600' })
    if (error) throw error
    // « ?v= » : sinon le navigateur garderait l'ancien logo en cache.
    const url = `${stockage.getPublicUrl(chemin).data.publicUrl}?v=${Date.now()}`
    const { data, error: erreurBase } = await this.client
      .from('restaurants')
      .update({ logo_url: url })
      .eq('id', restaurantId)
      .select('id')
    if (erreurBase) throw erreurBase
    if (!data?.length) throw new ErreurMida(messageModificationRefusee)
    return url
  }

  async categoriesMenu(restaurantId: string): Promise<CategorieMenu[]> {
    const { data, error } = await this.client
      .from('categories_menu')
      .select('id, nom, ordre, plats(count)')
      .eq('restaurant_id', restaurantId)
      .order('ordre')
      .order('nom')
    if (error) throw error
    return (data ?? []).map((c) => ({
      id: c.id,
      nom: c.nom,
      ordre: c.ordre,
      nbPlats: (c.plats as { count: number }[] | null)?.[0]?.count ?? 0,
    }))
  }

  async creerCategorieMenu(restaurantId: string, nom: string, ordre: number): Promise<void> {
    const { error } = await this.client.from('categories_menu').insert({ restaurant_id: restaurantId, nom: nom.trim(), ordre })
    if (error) throw erreurCategorie(error)
  }

  async renommerCategorieMenu(categorieId: string, nom: string): Promise<void> {
    const { data, error } = await this.client
      .from('categories_menu')
      .update({ nom: nom.trim() })
      .eq('id', categorieId)
      .select('id')
    if (error) throw erreurCategorie(error)
    if (!data?.length) throw new ErreurMida(messageMenuRefuse)
  }

  async ordonnerCategoriesMenu(restaurantId: string, categories: CategorieMenu[]): Promise<void> {
    // Une seule requête pour tout le menu : l'ordre est enregistré en entier, ou pas du tout.
    const { error } = await this.client.from('categories_menu').upsert(
      categories.map((c, i) => ({ id: c.id, restaurant_id: restaurantId, nom: c.nom, ordre: i + 1 })),
      { onConflict: 'id' },
    )
    if (error) throw error
  }

  async supprimerCategorieMenu(categorieId: string): Promise<void> {
    // Fonction de la base (migration US09) : supprime les plats puis la catégorie, dans la même transaction.
    const { error } = await this.client.rpc('supprimer_categorie_menu', { p_categorie: categorieId })
    if (error) throw error
  }

  async platsMenu(restaurantId: string): Promise<Plat[]> {
    const { data, error } = await this.client
      .from('plats')
      .select('id, categorie_id, nom, description, prix, image_url, disponible')
      .eq('restaurant_id', restaurantId)
      .order('nom')
    if (error) throw error
    return (data ?? []).map(versPlat)
  }

  async enregistrerPlat(
    restaurantId: string,
    platId: string | null,
    infos: InfosPlat,
    photo: File | null,
  ): Promise<ResultatPlat> {
    const champs = {
      categorie_id: infos.categorieId,
      nom: infos.nom.trim(),
      description: infos.description.trim() || null,
      prix: infos.prix,
    }
    // L'identifiant est choisi ici pour nommer la photo avant même la création.
    const id = platId ?? crypto.randomUUID()
    const requete = platId
      ? this.client.from('plats').update(champs).eq('id', platId)
      : this.client.from('plats').insert({ id, restaurant_id: restaurantId, ...champs })
    const { data, error } = await requete.select(colonnesPlat).maybeSingle()
    if (error) throw error
    if (!data) throw new ErreurMida(messageMenuRefuse)
    let plat = versPlat(data)

    if (!photo) return { plat, erreurPhoto: null }
    try {
      const image = await reduireImage(photo, 800)
      // Chemin fixe (README, « Stockage des images ») : la nouvelle photo remplace l'ancienne.
      const chemin = `${restaurantId}/plats/${id}.webp`
      const stockage = this.client.storage.from('restaurants')
      const envoi = await stockage.upload(chemin, image, { upsert: true, contentType: image.type, cacheControl: '3600' })
      if (envoi.error) throw envoi.error
      const url = `${stockage.getPublicUrl(chemin).data.publicUrl}?v=${Date.now()}`
      const maj = await this.client.from('plats').update({ image_url: url }).eq('id', id).select(colonnesPlat).maybeSingle()
      if (maj.error) throw maj.error
      if (maj.data) plat = versPlat(maj.data)
      return { plat, erreurPhoto: null }
    } catch (e) {
      return { plat, erreurPhoto: messageErreur(e) }
    }
  }

  async supprimerPlat(restaurantId: string, plat: Plat): Promise<void> {
    const { data, error } = await this.client.from('plats').delete().eq('id', plat.id).select('id')
    if (error) throw error
    if (!data?.length) throw new ErreurMida(messageMenuRefuse)
    // La photo n'est plus utilisée : on la retire du stockage (sans bloquer si elle n'existe pas).
    if (plat.imageUrl) await this.client.storage.from('restaurants').remove([`${restaurantId}/plats/${plat.id}.webp`])
  }

  async changerDisponibilite(platId: string, disponible: boolean): Promise<void> {
    const { data, error } = await this.client.from('plats').update({ disponible }).eq('id', platId).select('id')
    if (error) throw error
    if (!data?.length) throw new ErreurMida(messageMenuRefuse)
  }

  async commandesEnCours(restaurantId: string): Promise<Commande[]> {
    const { data, error } = await this.client
      .from('commandes')
      .select(
        'id, numero, etat, total, remarque, created_at, acceptee_le, prete_le, ' +
          'client:profiles!commandes_client_id_fkey(nom), lignes_commande(nom_plat, quantite, remarque), paiements(mode, etat)',
      )
      .eq('restaurant_id', restaurantId)
      .in('etat', etatsEnCours)
      .order('created_at')
    if (error) throw error
    return ((data ?? []) as unknown as LigneCommandeBD[]).map(versCommande)
  }

  surCommandes(restaurantId: string, rappel: (e: EvenementCommande) => void, surConnexion: () => void): () => void {
    // Supabase Realtime (migration US12) : seules les commandes que ce compte peut lire arrivent.
    const canal = this.client
      .channel(`commandes-${restaurantId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'commandes', filter: `restaurant_id=eq.${restaurantId}` },
        (changement) => {
          const ligne = (changement.eventType === 'DELETE' ? changement.old : changement.new) as {
            id?: string
            etat?: EtatCommande
          }
          rappel({ type: changement.eventType, id: ligne.id ?? null, etat: ligne.etat ?? null })
        },
      )
      .subscribe((statut) => {
        if (statut === 'SUBSCRIBED') surConnexion()
      })
    return () => {
      void this.client.removeChannel(canal)
    }
  }

  async accepterCommande(commandeId: string): Promise<void> {
    // Fonction de la base (migration US13) : vérifie le restaurant et l'état, prévient le client.
    const { error } = await this.client.rpc('accepter_commande', { p_commande: commandeId })
    if (error) throw error
  }

  async refuserCommande(commandeId: string, motif: string): Promise<void> {
    const { error } = await this.client.rpc('refuser_commande', { p_commande: commandeId, p_motif: motif })
    if (error) throw error
  }

  async avancerCommande(commandeId: string, etat: 'en_preparation' | 'prete'): Promise<void> {
    // Fonction de la base (migration US14) : une étape à la fois, sans retour en arrière.
    const { error } = await this.client.rpc('avancer_commande', { p_commande: commandeId, p_etat: etat })
    if (error) throw error
  }

  async historiqueCommandes(restaurantId: string, filtres: FiltresHistorique, page: number): Promise<PageHistorique> {
    // Lecture seule : la règle d'accès d'US02 ne montre que les commandes de ce restaurant.
    const debut = page * parPage
    const f = planFiltres(filtres)
    let requete = this.client
      .from('commandes')
      .select(
        'id, numero, etat, total, remarque, motif_refus, created_at, acceptee_le, prete_le, livree_le, annulee_le, ' +
          'client:profiles!commandes_client_id_fkey(nom), lignes_commande(nom_plat, quantite, remarque), paiements(mode, etat)',
        { count: 'exact' },
      )
      .eq('restaurant_id', restaurantId)
    if (f.etats) requete = requete.in('etat', f.etats)
    if (f.depuis) requete = requete.gte('created_at', f.depuis)
    if (f.avant) requete = requete.lt('created_at', f.avant)
    if (f.numero !== null) requete = requete.eq('numero', f.numero)
    const { data, error, count } = await requete.order('created_at', { ascending: false }).range(debut, debut + parPage - 1)
    if (error) throw error

    // Chiffre d'affaires : commandes livrées parmi celles du filtre (toutes les pages).
    let chiffreAffaires = 0
    let nbLivrees = 0
    if (filtres.etat === 'toutes' || filtres.etat === 'livree') {
      let somme = this.client.from('commandes').select('total').eq('restaurant_id', restaurantId).eq('etat', 'livree')
      if (f.depuis) somme = somme.gte('created_at', f.depuis)
      if (f.avant) somme = somme.lt('created_at', f.avant)
      if (f.numero !== null) somme = somme.eq('numero', f.numero)
      const ca = await somme.limit(10000)
      if (ca.error) throw ca.error
      for (const l of ca.data ?? []) chiffreAffaires += Number(l.total)
      nbLivrees = ca.data?.length ?? 0
    }
    return {
      commandes: ((data ?? []) as unknown as LigneHistoriqueBD[]).map(versCommandeHistorique),
      total: count ?? 0,
      nbLivrees,
      chiffreAffaires: Math.round(chiffreAffaires * 1000) / 1000,
    }
  }

  async statistiques(restaurantId: string, jours: number): Promise<StatsRestaurant> {
    // Fonction de la base (migration US44), calculée avec les droits du responsable.
    const { data, error } = await this.client.rpc('statistiques_restaurant', { p_restaurant: restaurantId, p_jours: jours })
    if (error) throw error
    return lireStats((data ?? {}) as Record<string, unknown>)
  }

  async avisRestaurant(restaurantId: string): Promise<AvisClient[]> {
    // Les avis sont publics (US02) ; le nom du client est lisible car c'est un client du restaurant.
    const { data, error } = await this.client
      .from('avis')
      .select('id, note, commentaire, created_at, commandes(numero), client:profiles!avis_client_id_fkey(nom)')
      .eq('restaurant_id', restaurantId)
      .order('created_at', { ascending: false })
      .limit(500)
    if (error) throw error
    return ((data ?? []) as unknown as LigneAvisBD[]).map((l) => {
      const commande = premier(l.commandes)
      return {
        id: l.id,
        note: l.note,
        commentaire: l.commentaire,
        creeLe: new Date(l.created_at),
        numero: commande ? Number(commande.numero) : null,
        client: nomCourt(premier(l.client)?.nom ?? ''),
      }
    })
  }
}

/** Filtres de l'historique, communs à la page de commandes et au chiffre d'affaires. */
function planFiltres(filtres: FiltresHistorique) {
  const { depuis, avant } = bornesDates(filtres.du, filtres.au)
  const numero = lireNumero(filtres.numero)
  return {
    etats: etatsDuFiltre(filtres.etat),
    depuis,
    avant,
    // un numéro mal saisi ne correspond à aucune commande
    numero: numero === null ? null : Number.isNaN(numero) ? -1 : numero,
  }
}

interface LigneCommandeBD {
  id: string
  numero: number | string
  etat: EtatCommande
  total: number | string
  remarque: string | null
  created_at: string
  acceptee_le: string | null
  prete_le: string | null
  client: { nom: string } | { nom: string }[] | null
  lignes_commande: { nom_plat: string; quantite: number; remarque: string | null }[] | null
  // paiements.commande_id est unique : PostgREST renvoie un objet (un tableau par prudence)
  paiements: NonNullable<Commande['paiement']> | NonNullable<Commande['paiement']>[] | null
}

interface LigneHistoriqueBD extends LigneCommandeBD {
  motif_refus: string | null
  livree_le: string | null
  annulee_le: string | null
}

function versCommandeHistorique(l: LigneHistoriqueBD): CommandeHistorique {
  return {
    ...versCommande(l),
    motifRefus: l.motif_refus,
    livreeLe: l.livree_le ? new Date(l.livree_le) : null,
    annuleeLe: l.annulee_le ? new Date(l.annulee_le) : null,
  }
}

interface LigneAvisBD {
  id: string
  note: number
  commentaire: string | null
  created_at: string
  commandes: { numero: number | string } | { numero: number | string }[] | null
  client: { nom: string } | { nom: string }[] | null
}

function premier<T>(valeur: T | T[] | null): T | null {
  return Array.isArray(valeur) ? (valeur[0] ?? null) : valeur
}

function versCommande(l: LigneCommandeBD): Commande {
  const creeeLe = new Date(l.created_at)
  const depuis = { en_attente: null, acceptee: l.acceptee_le, en_preparation: l.acceptee_le, prete: l.prete_le }[
    l.etat as 'en_attente' | 'acceptee' | 'en_preparation' | 'prete'
  ]
  return {
    id: l.id,
    numero: Number(l.numero),
    etat: l.etat,
    client: nomCourt(premier(l.client)?.nom ?? ''),
    total: Number(l.total),
    remarque: l.remarque,
    creeeLe,
    depuisLe: depuis ? new Date(depuis) : l.etat === 'en_livraison' && l.prete_le ? new Date(l.prete_le) : creeeLe,
    lignes: (l.lignes_commande ?? []).map((x) => ({ nomPlat: x.nom_plat, quantite: x.quantite, remarque: x.remarque })),
    paiement: premier(l.paiements),
  }
}

const colonnesPlat = 'id, categorie_id, nom, description, prix, image_url, disponible'

interface LignePlat {
  id: string
  categorie_id: string
  nom: string
  description: string | null
  prix: number | string // numeric : PostgREST peut le renvoyer en texte
  image_url: string | null
  disponible: boolean
}

function versPlat(l: LignePlat): Plat {
  return {
    id: l.id,
    categorieId: l.categorie_id,
    nom: l.nom,
    description: l.description ?? '',
    prix: Number(l.prix),
    imageUrl: l.image_url,
    disponible: l.disponible,
  }
}

const messageMenuRefuse = "Ce compte n'a pas le droit de modifier ce menu."

/** Deux catégories d'un même menu ne peuvent pas porter le même nom (contrainte de la base). */
function erreurCategorie(erreur: { code?: string }): unknown {
  return erreur.code === '23505' ? new ErreurMida(messageCategorieExistante) : erreur
}
