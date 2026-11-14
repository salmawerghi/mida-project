import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'

import { messageErreur } from './erreurs'
import type { Compte, ServiceRestaurant } from './service'

export type EtatSession =
  | { statut: 'chargement' }
  | { statut: 'deconnecte'; message?: string }
  | { statut: 'connecte'; compte: Compte }

interface ValeurSession {
  etat: EtatSession
  service: ServiceRestaurant
  /** Relit le compte (après une inscription ou une connexion). */
  rafraichir: () => Promise<EtatSession>
}

const ContexteSession = createContext<ValeurSession | null>(null)

export function FournisseurSession({ service, children }: { service: ServiceRestaurant; children: ReactNode }) {
  const [etat, setEtat] = useState<EtatSession>({ statut: 'chargement' })

  const rafraichir = useCallback(async (): Promise<EtatSession> => {
    let suivant: EtatSession
    try {
      const compte = await service.compteActuel()
      suivant = compte ? { statut: 'connecte', compte } : { statut: 'deconnecte' }
    } catch (e) {
      suivant = { statut: 'deconnecte', message: messageErreur(e) }
    }
    setEtat(suivant)
    return suivant
  }, [service])

  useEffect(() => {
    // rafraichir() ne change l'état qu'après l'appel réseau à Supabase
    // oxlint-disable-next-line react/set-state-in-effect
    void rafraichir()
    return service.surChangement(() => void rafraichir())
  }, [service, rafraichir])

  const valeur = useMemo(() => ({ etat, service, rafraichir }), [etat, service, rafraichir])
  return <ContexteSession.Provider value={valeur}>{children}</ContexteSession.Provider>
}

// oxlint-disable-next-line react/only-export-components -- le crochet accompagne son fournisseur
export function useSession(): ValeurSession {
  const v = useContext(ContexteSession)
  if (!v) throw new Error('useSession doit être utilisé dans <FournisseurSession>')
  return v
}
