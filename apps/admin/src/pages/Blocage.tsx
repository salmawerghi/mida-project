import { useState } from 'react'

import { messageErreur } from '../auth/erreurs'
import type { EtatCompte } from '../service'
import { useSession } from '../session'

/**
 * Bouton « Bloquer » / « Réactiver » d'un compte (US35), avec confirmation
 * en deux temps (pas de fenêtre du navigateur).
 */
export default function Blocage({
  compteId,
  nom,
  etat,
  apres,
}: {
  compteId: string
  nom: string
  etat: EtatCompte
  apres: () => Promise<void>
}) {
  const { service } = useSession()
  const [confirmation, setConfirmation] = useState(false)
  const [enCours, setEnCours] = useState(false)
  const [erreur, setErreur] = useState<string | null>(null)
  const bloque = etat === 'bloque'
  if (etat !== 'actif' && !bloque) return null

  async function confirmer() {
    setEnCours(true)
    setErreur(null)
    try {
      await service.bloquerCompte(compteId, !bloque)
      setConfirmation(false)
      await apres()
    } catch (e) {
      setErreur(messageErreur(e))
    } finally {
      setEnCours(false)
    }
  }

  if (!confirmation) {
    return (
      <button
        type="button"
        className={bloque ? 'lien-bouton' : 'lien-bouton lien-danger'}
        aria-label={`${bloque ? 'Réactiver' : 'Bloquer'} ${nom}`}
        onClick={() => setConfirmation(true)}
      >
        {bloque ? 'Réactiver' : 'Bloquer'}
      </button>
    )
  }
  return (
    <span className="admin-confirmation" role="group" aria-label={`Confirmer pour ${nom}`}>
      {bloque ? 'Réactiver ce compte ?' : 'Bloquer ce compte ?'}
      <button type="button" className="lien-bouton lien-danger" disabled={enCours} onClick={() => void confirmer()}>
        Oui, {bloque ? 'réactiver' : 'bloquer'}
      </button>
      <button type="button" className="lien-bouton" onClick={() => setConfirmation(false)}>
        Non
      </button>
      {erreur && (
        <span className="erreur-champ" role="alert">
          {erreur}
        </span>
      )}
    </span>
  )
}
