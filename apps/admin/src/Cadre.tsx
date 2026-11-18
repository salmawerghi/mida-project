import type { ReactNode } from 'react'
import { NavLink } from 'react-router'

import { Logo } from './composants'
import type { Compte } from './service'
import { useSession } from './session'

const rubriques: [string, string][] = [
  ['/tableau', "Vue d'ensemble"],
  ['/restaurants', 'Restaurants'],
  ['/livreurs', 'Livreurs'],
  ['/clients', 'Clients'],
  ['/commandes', 'Commandes'],
  ['/parametres', 'Paramètres'],
]

/** Cadre des pages d'administration (maquettes « Admin · … ») : menu latéral et contenu. */
export default function Cadre({ compte, titre, children }: { compte: Compte; titre: string; children: ReactNode }) {
  const { service } = useSession()
  const classeLien = ({ isActive }: { isActive: boolean }) => (isActive ? 'cadre-lien cadre-lien-actif' : 'cadre-lien')
  return (
    <div className="cadre">
      <aside className="cadre-menu motif-blanc">
        <div className="marque">
          <Logo inverse />
          <div>
            <div className="marque-nom">Mida</div>
            <div className="cadre-sous-titre">Administration</div>
          </div>
        </div>
        <nav aria-label="Navigation principale" className="cadre-liens">
          {rubriques.map(([chemin, libelle]) => (
            <NavLink key={chemin} to={chemin} className={classeLien}>
              {libelle}
            </NavLink>
          ))}
        </nav>
        <div className="cadre-bas">
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
      <main className="cadre-contenu">
        <h1 className="admin-titre">{titre}</h1>
        {children}
      </main>
    </div>
  )
}

/** Pastille d'état colorée (actif, en attente, bloqué…). */
export function Etat({ etat, libelle }: { etat: string; libelle: string }) {
  return <span className={`etat etat-${etat}`}>{libelle}</span>
}
