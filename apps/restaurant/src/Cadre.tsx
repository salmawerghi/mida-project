import { useState, type ReactNode } from 'react'
import { NavLink } from 'react-router'

import { messageErreur } from './auth/erreurs'
import { pageDuCompte, type Compte, type Restaurant } from './auth/service'
import { useSession } from './auth/session'
import { Logo } from './composants'

/**
 * Cadre des pages de l'espace restaurant (maquettes « Restaurant · … ») :
 * menu latéral bleu et contenu à droite. Les autres rubriques (commandes,
 * menu, historique, statistiques) s'ajouteront avec leurs stories.
 */
export default function Cadre({ compte, children }: { compte: Compte; children: ReactNode }) {
  const { service } = useSession()
  const accueil = pageDuCompte(compte)
  const classeLien = ({ isActive }: { isActive: boolean }) => (isActive ? 'cadre-lien cadre-lien-actif' : 'cadre-lien')
  return (
    <div className="cadre">
      <aside className="cadre-menu motif-blanc">
        <div className="marque">
          <Logo inverse />
          <div>
            <div className="marque-nom">Mida</div>
            <div className="cadre-sous-titre">Espace restaurant</div>
          </div>
        </div>
        <nav aria-label="Navigation principale" className="cadre-liens">
          <NavLink to={accueil} className={classeLien}>
            {accueil === '/tableau' ? 'Tableau de bord' : 'Ma demande'}
          </NavLink>
          <NavLink to="/profil" className={classeLien}>
            Profil du restaurant
          </NavLink>
        </nav>
        <div className="cadre-bas">
          {compte.restaurant && <Ouverture restaurant={compte.restaurant} />}
          <div className="cadre-compte">
            <span>
              {compte.nom}
              <br />
              {compte.email}
            </span>
            <button type="button" className="bouton bouton-blanc bouton-petit" onClick={() => void service.deconnecter()}>
              Se déconnecter
            </button>
          </div>
        </div>
      </aside>
      <main className="cadre-contenu">{children}</main>
    </div>
  )
}

/**
 * Interrupteur « ouvert / fermé » (US08) : un clic suffit, et un restaurant
 * fermé ne reçoit plus de commande. Réservé aux restaurants validés.
 */
function Ouverture({ restaurant }: { restaurant: Restaurant }) {
  const { service, rafraichir } = useSession()
  // valeur demandée, affichée tout de suite en attendant la réponse de Supabase
  const [demande, setDemande] = useState<boolean | null>(null)
  const [erreur, setErreur] = useState<string | null>(null)
  const ouvert = demande ?? restaurant.ouvert

  async function basculer() {
    const suivant = !ouvert
    setErreur(null)
    setDemande(suivant)
    try {
      await service.changerOuverture(restaurant.id, suivant)
      await rafraichir()
    } catch (e) {
      setErreur(messageErreur(e))
    } finally {
      setDemande(null)
    }
  }

  return (
    <div className="ouverture">
      <div className="ouverture-nom">{restaurant.nom}</div>
      {restaurant.etat === 'actif' ? (
        <>
          <button
            type="button"
            role="switch"
            aria-checked={ouvert}
            aria-describedby="ouverture-effet"
            className={ouvert ? 'interrupteur interrupteur-ouvert' : 'interrupteur'}
            disabled={demande !== null}
            onClick={() => void basculer()}
          >
            {ouvert ? 'Restaurant ouvert' : 'Restaurant fermé'}
            <span className="interrupteur-rond" aria-hidden="true" />
          </button>
          <span id="ouverture-effet" className="ouverture-effet">
            {ouvert ? 'Les clients peuvent commander.' : 'Les clients ne peuvent pas commander.'}
          </span>
          {erreur && (
            <span className="ouverture-erreur" role="alert">
              {erreur}
            </span>
          )}
        </>
      ) : (
        <span className="ouverture-effet">
          {restaurant.etat === 'rejete' ? 'Demande refusée.' : 'En attente de validation.'} Vous pourrez ouvrir le
          restaurant une fois qu'il sera validé.
        </span>
      )}
    </div>
  )
}
