import { createClient, type SupabaseClient } from '@supabase/supabase-js'

import { supabaseKey, supabaseUrl } from '../config'
import { effacerBrouillon, sauverBrouillon } from './brouillon'
import { ErreurMida, messageCompteExistant } from './erreurs'
import {
  messageRestaurantBloque,
  refusCompte,
  type Categorie,
  type Compte,
  type InfosResponsable,
  type InfosRestaurant,
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
      .select('id, nom, ville, etat, motif_rejet')
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
    if (!data.user) throw new ErreurMida('Votre session a expiré. Connectez-vous à nouveau.')
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
}
