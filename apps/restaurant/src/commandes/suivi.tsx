import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'

import { messageErreur } from '../auth/erreurs'
import { useSession } from '../auth/session'
import type { Commande } from './commandes'
import { enregistrerSonPrefere, lecteurWebAudio, sonPrefere, type LecteurAlerte } from './son'

/**
 * Suivi des commandes en temps réel (US12), partagé par toutes les pages de
 * l'espace restaurant : la liste, le nombre de commandes à traiter (menu,
 * titre de l'onglet), les nouvelles arrivées (alerte) et le son.
 */
interface ValeurCommandes {
  /** Faux tant que le restaurant n'est pas validé (pas de commandes à suivre). */
  actif: boolean
  commandes: Commande[] | null
  erreur: string | null
  /** Commandes « en attente » : à accepter ou refuser. */
  aTraiter: number
  /** Arrivées en temps réel et pas encore vues sur la page Commandes. */
  nouvelles: string[]
  marquerVues: () => void
  recharger: () => Promise<void>
  son: boolean
  /** Le navigateur bloque le son tant que la page n'a reçu aucun clic. */
  sonBloque: boolean
  changerSon: (actif: boolean) => void
}

const inactif: ValeurCommandes = {
  actif: false,
  commandes: null,
  erreur: null,
  aTraiter: 0,
  nouvelles: [],
  marquerVues: () => {},
  recharger: async () => {},
  son: false,
  sonBloque: false,
  changerSon: () => {},
}

const ContexteCommandes = createContext<ValeurCommandes>(inactif)

/** Délai avant de relire les commandes après un événement (plusieurs événements → une seule lecture). */
const delaiRelecture = 300

export function FournisseurCommandes({ lecteur, children }: { lecteur?: LecteurAlerte; children: ReactNode }) {
  const { etat } = useSession()
  const restaurant = etat.statut === 'connecte' ? etat.compte.restaurant : null
  const restaurantId = restaurant?.etat === 'actif' ? restaurant.id : null
  const lecteurParDefaut = useMemo(() => lecteurWebAudio(), [])

  if (!restaurantId) return <ContexteCommandes.Provider value={inactif}>{children}</ContexteCommandes.Provider>
  // `key` : tout repart de zéro si un autre restaurant se connecte
  return (
    <SuiviActif key={restaurantId} restaurantId={restaurantId} alerte={lecteur ?? lecteurParDefaut}>
      {children}
    </SuiviActif>
  )
}

function SuiviActif({
  restaurantId,
  alerte,
  children,
}: {
  restaurantId: string
  alerte: LecteurAlerte
  children: ReactNode
}) {
  const { service } = useSession()
  const [commandes, setCommandes] = useState<Commande[] | null>(null)
  const [erreur, setErreur] = useState<string | null>(null)
  const [nouvelles, setNouvelles] = useState<string[]>([])
  const [son, setSon] = useState(sonPrefere)
  const [sonBloque, setSonBloque] = useState(() => alerte.bloque())
  const sonRef = useRef(son)
  useEffect(() => {
    sonRef.current = son
  }, [son])

  const recharger = useCallback(async () => {
    try {
      setCommandes(await service.commandesEnCours(restaurantId))
      setErreur(null)
    } catch (e) {
      setErreur(messageErreur(e))
    }
  }, [service, restaurantId])

  useEffect(() => {
    let minuterie: ReturnType<typeof setTimeout> | undefined
    const relireBientot = () => {
      clearTimeout(minuterie)
      minuterie = setTimeout(() => void recharger(), delaiRelecture)
    }
    // recharger() ne change l'état qu'après l'appel réseau à Supabase
    // oxlint-disable-next-line react/set-state-in-effect
    void recharger()
    const desabonner = service.surCommandes(
      restaurantId,
      (evenement) => {
        if (evenement.type === 'INSERT' && evenement.etat === 'en_attente' && evenement.id) {
          const id = evenement.id
          setNouvelles((liste) => (liste.includes(id) ? liste : [...liste, id]))
          if (sonRef.current) setSonBloque(!alerte.jouer())
        }
        relireBientot()
      },
      // (re)connexion au temps réel : relire ce qui a pu arriver pendant la coupure
      relireBientot,
    )
    return () => {
      clearTimeout(minuterie)
      desabonner()
    }
  }, [service, restaurantId, recharger, alerte])

  // Le premier clic dans la page débloque le son (règle « autoplay » des navigateurs).
  useEffect(() => {
    if (!sonBloque) return
    const debloquer = () => {
      alerte.debloquer()
      setSonBloque(false)
    }
    window.addEventListener('pointerdown', debloquer, { once: true })
    return () => window.removeEventListener('pointerdown', debloquer)
  }, [sonBloque, alerte])

  const aTraiter = commandes?.filter((c) => c.etat === 'en_attente').length ?? 0

  // Titre de l'onglet : « (2) Mida — Espace restaurant », visible même dans un autre onglet.
  useEffect(() => {
    if (aTraiter === 0) return
    const titre = document.title
    document.title = `(${aTraiter}) ${titre.replace(/^\(\d+\) /, '')}`
    return () => {
      document.title = titre
    }
  }, [aTraiter])

  const marquerVues = useCallback(() => setNouvelles([]), [])

  const changerSon = useCallback(
    (actif: boolean) => {
      enregistrerSonPrefere(actif)
      setSon(actif)
      if (actif) {
        // appelé pendant le clic : c'est le moment où le navigateur autorise le son
        alerte.debloquer()
        setSonBloque(false)
        alerte.jouer()
      }
    },
    [alerte],
  )

  const valeur = useMemo<ValeurCommandes>(
    () => ({ actif: true, commandes, erreur, aTraiter, nouvelles, marquerVues, recharger, son, sonBloque, changerSon }),
    [commandes, erreur, aTraiter, nouvelles, marquerVues, recharger, son, sonBloque, changerSon],
  )
  return <ContexteCommandes.Provider value={valeur}>{children}</ContexteCommandes.Provider>
}

// oxlint-disable-next-line react/only-export-components -- le crochet accompagne son fournisseur
export function useCommandes(): ValeurCommandes {
  return useContext(ContexteCommandes)
}
