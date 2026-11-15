import type { ReactNode } from 'react'
import { NavLink } from 'react-router'

import { pageDuCompte, type Compte } from './auth/service'
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
      </aside>
      <main className="cadre-contenu">{children}</main>
    </div>
  )
}
