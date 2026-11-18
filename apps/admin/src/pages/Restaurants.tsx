import { useState } from 'react'
import { Link } from 'react-router'

import { Etat } from '../Cadre'
import { Chargement, MessageErreur } from '../composants'
import { correspond, formaterDate, libellesCompte } from '../service'
import { useDonnees, useSession } from '../session'
import Blocage from './Blocage'

/** Maquette « Admin · Restaurants » : demandes en attente (US33), puis tous les restaurants (US35). */
export default function Restaurants() {
  const { service } = useSession()
  const { donnees, erreur, recharger } = useDonnees(() => service.restaurants())
  const [recherche, setRecherche] = useState('')
  if (erreur) return <MessageErreur>{erreur}</MessageErreur>
  if (!donnees) return <Chargement />
  const demandes = donnees.filter((r) => r.etat === 'en_attente')
  const autres = donnees.filter((r) => r.etat !== 'en_attente' && correspond(`${r.nom} ${r.ville}`, recherche))
  return (
    <>
      <section aria-labelledby="demandes">
        <h2 id="demandes">
          Demandes en attente <span className="admin-compte">{demandes.length}</span>
        </h2>
        {demandes.length === 0 ? (
          <p className="texte-doux">Aucune demande à examiner.</p>
        ) : (
          <ul className="admin-demandes">
            {demandes.map((d) => (
              <li key={d.id} className="carte admin-demande">
                <div>
                  <strong>{d.nom}</strong>
                  <div className="texte-doux">
                    {d.ville} · reçue le {formaterDate(d.creeLe)}
                    {d.categorie ? ` · ${d.categorie}` : ''}
                  </div>
                </div>
                <Link
                  to={`/restaurants/${d.id}`}
                  className="bouton bouton-bleu bouton-petit"
                  aria-label={`Examiner la demande de ${d.nom}`}
                >
                  Examiner
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="tous" className="admin-section">
        <div className="admin-barre">
          <h2 id="tous">Restaurants · {autres.length}</h2>
          <input
            className="saisie admin-recherche"
            type="search"
            placeholder="Rechercher un restaurant"
            aria-label="Rechercher un restaurant"
            value={recherche}
            onChange={(e) => setRecherche(e.target.value)}
          />
        </div>
        <table className="admin-table">
          <thead>
            <tr>
              <th>Restaurant</th>
              <th>Ville</th>
              <th>Responsable</th>
              <th>État</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {autres.map((r) => (
              <tr key={r.id}>
                <td>
                  <strong>{r.nom}</strong>
                  {r.etat === 'actif' && <div className="texte-doux">{r.ouvert ? 'Ouvert' : 'Fermé'}</div>}
                  {r.motifRejet && <div className="texte-doux">Motif : {r.motifRejet}</div>}
                </td>
                <td>{r.ville}</td>
                <td>
                  {r.responsable?.nom ?? '—'}
                  <div className="texte-doux">{r.responsable?.email}</div>
                </td>
                <td>
                  <Etat etat={r.etat} libelle={libellesCompte[r.etat]} />
                </td>
                <td>
                  {r.responsable && (
                    <Blocage
                      compteId={r.responsable.id}
                      nom={r.nom}
                      etat={r.etat === 'bloque' ? 'bloque' : r.etat === 'actif' ? 'actif' : r.etat}
                      apres={recharger}
                    />
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  )
}
