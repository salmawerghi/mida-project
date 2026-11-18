import { createClient, type SupabaseClient } from '@supabase/supabase-js'

import { ErreurMida } from './auth/erreurs'
import { supabaseKey, supabaseUrl } from './config'
import {
  bornesJour,
  refusCompte,
  type CategorieAdmin,
  type ClientAdmin,
  type CommandeAdmin,
  type Compte,
  type FiltreCommandes,
  type LivreurAdmin,
  type Parametres,
  type RestaurantAdmin,
  type Resume,
  type ServiceAdmin,
} from './service'

type Ligne = Record<string, unknown>

/** Un embed PostgREST vaut un objet, un tableau d'un élément, ou null. */
function premier<T = Ligne>(v: unknown): T | null {
  if (Array.isArray(v)) return (v[0] as T) ?? null
  return (v as T) ?? null
}
const nombre = (v: unknown) => (typeof v === 'number' ? v : Number(v ?? 0))

export function creerClientSupabase(): SupabaseClient {
  // session gardée dans l'onglet seulement : l'administration se ferme avec le navigateur
  return createClient(supabaseUrl, supabaseKey, {
    auth: { storage: sessionStorage, persistSession: true, autoRefreshToken: true },
  })
}

export class ServiceAdminSupabase implements ServiceAdmin {
  private readonly client: SupabaseClient

  constructor(client: SupabaseClient) {
    this.client = client
  }

  async compteActuel(): Promise<Compte | null> {
    const { data } = await this.client.auth.getSession()
    const session = data.session
    if (!session) return null
    const { data: profil, error } = await this.client
      .from('profiles')
      .select('nom, email, role, etat_compte')
      .eq('id', session.user.id)
      .maybeSingle()
    if (error) throw error
    const refus = refusCompte(profil?.role, profil?.etat_compte)
    if (refus) {
      await this.client.auth.signOut()
      throw new ErreurMida(refus)
    }
    return { email: profil!.email, nom: profil!.nom }
  }

  surChangement(rappel: () => void): () => void {
    const { data } = this.client.auth.onAuthStateChange((evenement) => {
      if (evenement === 'SIGNED_IN' || evenement === 'SIGNED_OUT') setTimeout(rappel, 0)
    })
    return () => data.subscription.unsubscribe()
  }

  async connecter(email: string, motDePasse: string): Promise<void> {
    const { error } = await this.client.auth.signInWithPassword({ email: email.trim(), password: motDePasse })
    if (error) throw error
    // refuse tout de suite un compte qui n'est pas administrateur
    await this.compteActuel()
  }

  async deconnecter(): Promise<void> {
    await this.client.auth.signOut()
  }

  private async compter(requete: PromiseLike<{ count: number | null; error: unknown }>): Promise<number> {
    const { count, error } = await requete
    if (error) throw error
    return count ?? 0
  }

  async resume(): Promise<Resume> {
    const t = (table: string) => this.client.from(table).select('id', { count: 'exact', head: true })
    const aujourdhui = new Date()
    aujourdhui.setHours(0, 0, 0, 0)
    const ilYa7j = new Date(Date.now() - 7 * 24 * 3600 * 1000).toISOString()
    const [restaurantsEnAttente, livreursEnAttente, commandesAujourdhui, commandesEnCours, commandes7j, refusees7j,
      clients, restaurantsActifs, livreursActifs] = await Promise.all([
      this.compter(t('restaurants').eq('etat', 'en_attente')),
      this.compter(t('profiles').eq('role', 'livreur').eq('etat_compte', 'en_attente')),
      this.compter(t('commandes').gte('created_at', aujourdhui.toISOString())),
      this.compter(t('commandes').in('etat', ['en_attente', 'acceptee', 'en_preparation', 'prete', 'en_livraison'])),
      this.compter(t('commandes').gte('created_at', ilYa7j)),
      this.compter(t('commandes').eq('etat', 'refusee').gte('created_at', ilYa7j)),
      this.compter(t('profiles').eq('role', 'client')),
      this.compter(t('restaurants').eq('etat', 'actif')),
      this.compter(t('profiles').eq('role', 'livreur').eq('etat_compte', 'actif')),
    ])
    const { data: livrees, error } = await this.client
      .from('commandes')
      .select('total')
      .eq('etat', 'livree')
      .gte('created_at', ilYa7j)
    if (error) throw error
    const chiffreAffaires7j = (livrees ?? []).reduce((s, l) => s + nombre(l.total), 0)
    return {
      restaurantsEnAttente,
      livreursEnAttente,
      commandesAujourdhui,
      commandesEnCours,
      chiffreAffaires7j,
      commandes7j,
      refusees7j,
      clients,
      restaurantsActifs,
      livreursActifs,
    }
  }

  async restaurants(): Promise<RestaurantAdmin[]> {
    const { data, error } = await this.client
      .from('restaurants')
      .select(
        'id, nom, ville, adresse, telephone, description, etat, motif_rejet, ouvert, created_at, ' +
          'categories_restaurant(nom), profiles(id, nom, email, telephone, etat_compte)',
      )
      .order('created_at', { ascending: false })
    if (error) throw error
    return ((data ?? []) as unknown as Ligne[]).map((r) => {
      const p = premier(r.profiles)
      return {
        id: r.id as string,
        nom: r.nom as string,
        ville: r.ville as string,
        adresse: r.adresse as string,
        telephone: (r.telephone as string | null) ?? null,
        description: (r.description as string | null) ?? null,
        categorie: (premier(r.categories_restaurant)?.nom as string | undefined) ?? null,
        etat: r.etat as RestaurantAdmin['etat'],
        motifRejet: (r.motif_rejet as string | null) ?? null,
        ouvert: Boolean(r.ouvert),
        creeLe: r.created_at as string,
        responsable: p
          ? {
              id: p.id as string,
              nom: p.nom as string,
              email: p.email as string,
              telephone: (p.telephone as string | null) ?? null,
              etat: p.etat_compte as RestaurantAdmin['etat'],
            }
          : null,
      }
    })
  }

  async deciderRestaurant(id: string, valider: boolean, motif?: string): Promise<void> {
    const { error } = await this.client.rpc('admin_decider_restaurant', {
      p_restaurant: id,
      p_valider: valider,
      p_motif: motif ?? null,
    })
    if (error) throw error
  }

  async livreurs(): Promise<LivreurAdmin[]> {
    const { data, error } = await this.client
      .from('profiles')
      .select(
        'id, nom, email, telephone, etat_compte, created_at, ' +
          'livreurs(type_vehicule, immatriculation, disponible, documents_livreur(type, etat, fichier_url))',
      )
      .eq('role', 'livreur')
      .order('created_at', { ascending: false })
    if (error) throw error
    return ((data ?? []) as unknown as Ligne[]).map((p) => {
      const l = premier(p.livreurs)
      const docs = (l?.documents_livreur as Ligne[] | undefined) ?? []
      return {
        id: p.id as string,
        nom: p.nom as string,
        email: p.email as string,
        telephone: (p.telephone as string | null) ?? null,
        etat: p.etat_compte as LivreurAdmin['etat'],
        creeLe: p.created_at as string,
        vehicule: (l?.type_vehicule as LivreurAdmin['vehicule']) ?? null,
        immatriculation: (l?.immatriculation as string | null) ?? null,
        disponible: Boolean(l?.disponible),
        documents: docs.map((d) => ({
          type: d.type as string,
          etat: d.etat as 'en_attente' | 'valide' | 'refuse',
          chemin: d.fichier_url as string,
        })),
      }
    })
  }

  async urlDocument(chemin: string): Promise<string> {
    const { data, error } = await this.client.storage.from('documents-livreurs').createSignedUrl(chemin, 600)
    if (error) throw error
    return data.signedUrl
  }

  async deciderLivreur(id: string, valider: boolean, motif?: string): Promise<void> {
    const { error } = await this.client.rpc('admin_decider_livreur', {
      p_livreur: id,
      p_valider: valider,
      p_motif: motif ?? null,
    })
    if (error) throw error
  }

  async clients(): Promise<ClientAdmin[]> {
    const { data, error } = await this.client
      .from('profiles')
      .select('id, nom, email, telephone, etat_compte, created_at, commandes(count)')
      .eq('role', 'client')
      .order('created_at', { ascending: false })
    if (error) throw error
    return ((data ?? []) as unknown as Ligne[]).map((c) => ({
      id: c.id as string,
      nom: c.nom as string,
      email: c.email as string,
      telephone: (c.telephone as string | null) ?? null,
      etat: c.etat_compte as ClientAdmin['etat'],
      creeLe: c.created_at as string,
      nbCommandes: nombre(premier(c.commandes)?.count),
    }))
  }

  async bloquerCompte(id: string, bloquer: boolean): Promise<void> {
    const { error } = await this.client.rpc('admin_bloquer_compte', { p_compte: id, p_bloquer: bloquer })
    if (error) throw error
  }

  async commandes(filtre: FiltreCommandes): Promise<CommandeAdmin[]> {
    let requete = this.client
      .from('commandes')
      .select(
        'id, numero, etat, created_at, adresse_livraison, sous_total, frais_livraison, total, remarque, motif_refus, ' +
          'restaurants(nom), profiles(nom), paiements(mode, etat, montant, reference_passerelle, paye_le), ' +
          'lignes_commande(nom_plat, quantite, prix_unitaire), livraisons(etat, livreurs(profiles(nom)))',
      )
      .order('created_at', { ascending: false })
      .limit(200)
    if (filtre.etat) requete = requete.eq('etat', filtre.etat)
    if (filtre.restaurantId) requete = requete.eq('restaurant_id', filtre.restaurantId)
    if (filtre.date) {
      const [debut, fin] = bornesJour(filtre.date)
      requete = requete.gte('created_at', debut).lt('created_at', fin)
    }
    const { data, error } = await requete
    if (error) throw error
    return ((data ?? []) as unknown as Ligne[]).map((c) => {
      const p = premier(c.paiements)
      const course = premier(c.livraisons)
      const livreur = premier(premier(course?.livreurs)?.profiles)
      return {
        id: c.id as string,
        numero: nombre(c.numero),
        etat: c.etat as CommandeAdmin['etat'],
        creeLe: c.created_at as string,
        restaurant: (premier(c.restaurants)?.nom as string | undefined) ?? '—',
        client: (premier(c.profiles)?.nom as string | undefined) ?? '—',
        adresse: c.adresse_livraison as string,
        sousTotal: nombre(c.sous_total),
        fraisLivraison: nombre(c.frais_livraison),
        total: nombre(c.total),
        remarque: (c.remarque as string | null) ?? null,
        motifRefus: (c.motif_refus as string | null) ?? null,
        paiement: p
          ? {
              mode: p.mode as 'carte' | 'especes',
              etat: p.etat as 'en_attente' | 'paye' | 'echoue' | 'rembourse',
              montant: nombre(p.montant),
              reference: (p.reference_passerelle as string | null) ?? null,
              payeLe: (p.paye_le as string | null) ?? null,
            }
          : null,
        lignes: ((c.lignes_commande as Ligne[] | undefined) ?? []).map((l) => ({
          nom: l.nom_plat as string,
          quantite: nombre(l.quantite),
          prixUnitaire: nombre(l.prix_unitaire),
        })),
        livreur: (livreur?.nom as string | undefined) ?? null,
        etatCourse: (course?.etat as string | undefined) ?? null,
      }
    })
  }

  async parametres(): Promise<Parametres> {
    const { data, error } = await this.client
      .from('parametres')
      .select('frais_livraison, commission_pct, gain_livreur')
      .eq('id', 1)
      .single()
    if (error) throw error
    return {
      fraisLivraison: nombre(data.frais_livraison),
      commissionPct: nombre(data.commission_pct),
      gainLivreur: nombre(data.gain_livreur),
    }
  }

  async enregistrerParametres(p: Parametres): Promise<void> {
    const { data, error } = await this.client
      .from('parametres')
      .update({ frais_livraison: p.fraisLivraison, commission_pct: p.commissionPct, gain_livreur: p.gainLivreur })
      .eq('id', 1)
      .select('id')
    if (error) throw error
    if (!data?.length) throw new ErreurMida("Ce compte n'a pas le droit de modifier les paramètres.")
  }

  async categories(): Promise<CategorieAdmin[]> {
    const { data, error } = await this.client
      .from('categories_restaurant')
      .select('id, nom, ordre, restaurants(count)')
      .order('ordre')
      .order('nom')
    if (error) throw error
    return ((data ?? []) as unknown as Ligne[]).map((c) => ({
      id: c.id as string,
      nom: c.nom as string,
      ordre: nombre(c.ordre),
      nbRestaurants: nombre(premier(c.restaurants)?.count),
    }))
  }

  async ajouterCategorie(nom: string, ordre: number): Promise<void> {
    const { error } = await this.client.from('categories_restaurant').insert({ nom: nom.trim(), ordre })
    if (error) throw error
  }

  async renommerCategorie(id: string, nom: string): Promise<void> {
    const { error } = await this.client.from('categories_restaurant').update({ nom: nom.trim() }).eq('id', id)
    if (error) throw error
  }

  async supprimerCategorie(id: string): Promise<void> {
    // les restaurants de cette catégorie restent, sans catégorie (on delete set null)
    const { error } = await this.client.from('categories_restaurant').delete().eq('id', id)
    if (error) throw error
  }
}
