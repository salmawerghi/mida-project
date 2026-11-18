import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'

import { messageErreur } from './auth/erreurs'
import type { Compte, ServiceAdmin } from './service'

export type EtatSession =
  | { statut: 'chargement' }
  | { statut: 'deconnecte'; message?: string }
  | { statut: 'connecte'; compte: Compte }

interface ValeurSession {
  etat: EtatSession
  service: ServiceAdmin
  rafraichir: () => Promise<EtatSession>
}

const ContexteSession = createContext<ValeurSession | null>(null)

export function FournisseurSession({ service, children }: { service: ServiceAdmin; children: ReactNode }) {
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
    // oxlint-disable-next-line react/set-state-in-effect -- l'état change après l'appel réseau
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

/** Charge des données au montage et à la demande (`recharger`), avec l'erreur éventuelle. */
// oxlint-disable-next-line react/only-export-components
export function useDonnees<T>(charger: () => Promise<T>, dependances: unknown[] = []) {
  const [donnees, setDonnees] = useState<T | null>(null)
  const [erreur, setErreur] = useState<string | null>(null)
  // oxlint-disable-next-line react/exhaustive-deps -- `charger` change à chaque rendu
  const memo = useCallback(charger, dependances)
  const recharger = useCallback(async () => {
    try {
      const d = await memo()
      setDonnees(d)
      setErreur(null)
    } catch (e) {
      setErreur(messageErreur(e))
    }
  }, [memo])
  useEffect(() => {
    // oxlint-disable-next-line react/set-state-in-effect -- l'état change après l'appel réseau
    void recharger()
  }, [recharger])
  return { donnees, erreur, recharger }
}
