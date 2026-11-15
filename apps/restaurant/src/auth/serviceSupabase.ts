import { createClient, type SupabaseClient } from '@supabase/supabase-js'

import { supabaseKey, supabaseUrl } from '../config'
import { messageCategorieExistante, type CategorieMenu } from '../menu/categories'
import { completerHoraires, heureCourte, type Horaire } from '../profil/horaires'
import { reduireImage } from '../profil/image'
import { effacerBrouillon, sauverBrouillon } from './brouillon'
import { ErreurMida, messageCompteExistant } from './erreurs'
import {
  messageRestaurantBloque,
  refusCompte,
  type Categorie,
  type Compte,
  type InfosResponsable,
  type InfosRestaurant,
  type ProfilEtHoraires,
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
}

const messageMenuRefuse = "Ce compte n'a pas le droit de modifier ce menu."

/** Deux catégories d'un même menu ne peuvent pas porter le même nom (contrainte de la base). */
function erreurCategorie(erreur: { code?: string }): unknown {
  return erreur.code === '23505' ? new ErreurMida(messageCategorieExistante) : erreur
}
