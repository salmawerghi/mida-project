import { useState } from 'react'

import { Etat } from '../Cadre'
import { Chargement, MessageErreur } from '../composants'
import { correspond, formaterDate, libellesCompte, type EtatCompte } from '../service'
import { useDonnees, useSession } from '../session'
import Blocage from './Blocage'

/** Maquette « Admin · Clients » : recherche, filtre par état, blocage / réactivation (US35). */
export default function Clients() {
  const { service } = useSession()
  const { donnees, erreur, recharger } = useDonnees(() => service.clients())
  const [recherche, setRecherche] = useState('')
  const [etat, setEtat] = useState<'' | EtatCompte>('')
  if (erreur) return <MessageErreur>{erreur}</MessageErreur>
  if (!donnees) return <Chargement />
  const bloques = donnees.filter((c) => c.etat === 'bloque').length
  const liste = donnees.filter(
    (c) => (!etat || c.etat === etat) && correspond(`${c.nom} ${c.email} ${c.telephone ?? ''}`, recherche),
  )
  return (
    <>
      <p className="texte-doux">
        {donnees.length} compte{donnees.length > 1 ? 's' : ''} · {bloques} bloqué{bloques > 1 ? 's' : ''}
      </p>
      <div className="admin-filtres">
        <input
          className="saisie admin-recherche"
          type="search"
          placeholder="Rechercher un client"
          aria-label="Rechercher un client"
          value={recherche}
          onChange={(e) => setRecherche(e.target.value)}
        />
        <select
          className="saisie"
          aria-label="Filtrer par état"
          value={etat}
          onChange={(e) => setEtat(e.target.value as '' | EtatCompte)}
        >
          <option value="">Tous les états</option>
          <option value="actif">Actifs</option>
          <option value="bloque">Bloqués</option>
        </select>
      </div>
      <table className="admin-table">
        <thead>
          <tr>
            <th>Client</th>
            <th>Téléphone</th>
            <th>Inscrit le</th>
            <th>Commandes</th>
            <th>État</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {liste.map((c) => (
            <tr key={c.id}>
              <td>
                <strong>{c.nom}</strong>
                <div className="texte-doux">{c.email}</div>
              </td>
              <td>{c.telephone ?? '—'}</td>
              <td>{formaterDate(c.creeLe)}</td>
              <td>{c.nbCommandes}</td>
              <td>
                <Etat etat={c.etat} libelle={libellesCompte[c.etat]} />
              </td>
              <td>
                <Blocage compteId={c.id} nom={c.nom} etat={c.etat} apres={recharger} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {liste.length === 0 && <p className="texte-doux">Aucun client ne correspond.</p>}
    </>
  )
}
