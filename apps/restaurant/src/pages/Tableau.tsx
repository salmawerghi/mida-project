import { Link } from 'react-router'

import type { Compte } from '../auth/service'
import Cadre from '../Cadre'

/** Tableau de bord provisoire : le vrai arrive avec les stories de gestion des commandes. */
export default function Tableau({ compte }: { compte: Compte }) {
  return (
    <Cadre compte={compte}>
      <section className="carte attente-texte">
        <span className="pastille pastille-actif">Restaurant validé</span>
        <h1>Bienvenue, {compte.restaurant?.nom}</h1>
        <p className="texte-doux">
          Connecté en tant que {compte.nom} ({compte.email}). Les commandes, le menu et les statistiques arrivent ici
          avec les prochaines versions.
        </p>
        <div className="actions" style={{ justifyContent: 'flex-start' }}>
          <Link to="/profil" className="bouton bouton-bleu">
            Profil du restaurant
          </Link>
        </div>
      </section>
    </Cadre>
  )
}
