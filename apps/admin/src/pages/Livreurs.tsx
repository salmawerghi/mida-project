import { useEffect, useState } from 'react'

import { Etat } from '../Cadre'
import { messageErreur } from '../auth/erreurs'
import { Bouton, Chargement, MessageErreur } from '../composants'
import {
  formaterDate,
  libellesCompte,
  libellesDocument,
  libellesVehicule,
  type DocumentLivreur,
  type LivreurAdmin,
} from '../service'
import { useDonnees, useSession } from '../session'
import Blocage from './Blocage'

/** Maquette « Admin · Livreurs » : candidatures avec leurs documents (US34), puis tous les livreurs (US35). */
export default function Livreurs() {
  const { service } = useSession()
  const { donnees, erreur, recharger } = useDonnees(() => service.livreurs())
  const [choisi, setChoisi] = useState<string | null>(null)
  if (erreur) return <MessageErreur>{erreur}</MessageErreur>
  if (!donnees) return <Chargement />
  const candidatures = donnees.filter((l) => l.etat === 'en_attente')
  const autres = donnees.filter((l) => l.etat !== 'en_attente')
  const selection = candidatures.find((l) => l.id === choisi) ?? candidatures[0] ?? null

  return (
    <>
      <section aria-labelledby="candidatures">
        <h2 id="candidatures">
          Candidatures <span className="admin-compte">{candidatures.length}</span>
        </h2>
        {candidatures.length === 0 ? (
          <p className="texte-doux">Aucune candidature à examiner.</p>
        ) : (
          <div className="admin-candidatures">
            <ul className="admin-liste-candidats">
              {candidatures.map((c) => (
                <li key={c.id}>
                  <button
                    type="button"
                    className={c.id === selection?.id ? 'admin-candidat admin-candidat-choisi' : 'admin-candidat'}
                    aria-pressed={c.id === selection?.id}
                    onClick={() => setChoisi(c.id)}
                  >
                    <strong>{c.nom}</strong>
                    <span className="texte-doux">
                      {c.vehicule ? libellesVehicule[c.vehicule] : 'Véhicule non renseigné'} · {formaterDate(c.creeLe)}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
            {selection && <Candidature key={selection.id} livreur={selection} apres={recharger} />}
          </div>
        )}
      </section>

      <section aria-labelledby="tous-livreurs" className="admin-section">
        <h2 id="tous-livreurs">Livreurs · {autres.length}</h2>
        <table className="admin-table">
          <thead>
            <tr>
              <th>Livreur</th>
              <th>Véhicule</th>
              <th>Disponibilité</th>
              <th>État</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {autres.map((l) => (
              <tr key={l.id}>
                <td>
                  <strong>{l.nom}</strong>
                  <div className="texte-doux">
                    {l.email}
                    {l.telephone ? ` · ${l.telephone}` : ''}
                  </div>
                </td>
                <td>
                  {l.vehicule ? libellesVehicule[l.vehicule] : '—'}
                  {l.immatriculation && <div className="texte-doux">{l.immatriculation}</div>}
                </td>
                <td>{l.etat === 'actif' ? (l.disponible ? 'Disponible' : 'Indisponible') : '—'}</td>
                <td>
                  <Etat etat={l.etat} libelle={libellesCompte[l.etat]} />
                </td>
                <td>
                  <Blocage compteId={l.id} nom={l.nom} etat={l.etat} apres={recharger} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </>
  )
}

/** Détail d'une candidature : coordonnées, véhicule, documents consultables, décision. */
function Candidature({ livreur: l, apres }: { livreur: LivreurAdmin; apres: () => Promise<void> }) {
  const { service } = useSession()
  const [motif, setMotif] = useState('')
  const [erreurMotif, setErreurMotif] = useState<string | null>(null)
  const [erreur, setErreur] = useState<string | null>(null)
  const [enCours, setEnCours] = useState<'valider' | 'rejeter' | null>(null)

  async function decider(valider: boolean) {
    setErreur(null)
    if (!valider && !motif.trim()) {
      setErreurMotif('Indiquez le motif du rejet : il est communiqué au livreur.')
      return
    }
    setErreurMotif(null)
    setEnCours(valider ? 'valider' : 'rejeter')
    try {
      await service.deciderLivreur(l.id, valider, valider ? undefined : motif.trim())
      await apres()
    } catch (e) {
      setErreur(messageErreur(e))
    } finally {
      setEnCours(null)
    }
  }

  return (
    <article className="carte admin-candidature" aria-label={`Candidature de ${l.nom}`}>
      <h3>{l.nom}</h3>
      <p className="texte-doux">
        {l.telephone ?? 'Téléphone non renseigné'} · {l.email}
        <br />
        {l.vehicule ? libellesVehicule[l.vehicule] : 'Véhicule non renseigné'}
        {l.immatriculation ? ` · ${l.immatriculation}` : ''}
      </p>
      <h4>Documents déposés</h4>
      {l.documents.length === 0 ? (
        <p className="texte-doux">Aucun document déposé.</p>
      ) : (
        <ul className="admin-documents">
          {l.documents.map((d) => (
            <ApercuDocument key={d.type} document={d} />
          ))}
        </ul>
      )}
      <Bouton plein enCours={enCours === 'valider'} disabled={enCours !== null} onClick={() => void decider(true)}>
        Valider le livreur
      </Bouton>
      <div className="champ">
        <label htmlFor={`motif-${l.id}`}>Motif en cas de rejet</label>
        <textarea
          id={`motif-${l.id}`}
          className="saisie"
          rows={2}
          value={motif}
          aria-invalid={erreurMotif ? true : undefined}
          onChange={(e) => setMotif(e.target.value)}
        />
        {erreurMotif && <span className="erreur-champ">{erreurMotif}</span>}
      </div>
      <Bouton
        variante="harissa"
        plein
        enCours={enCours === 'rejeter'}
        disabled={enCours !== null}
        onClick={() => void decider(false)}
      >
        Rejeter la candidature
      </Bouton>
      {erreur && <MessageErreur>{erreur}</MessageErreur>}
    </article>
  )
}

/** Un document privé : adresse temporaire demandée au stockage, aperçu et lien. */
function ApercuDocument({ document: d }: { document: DocumentLivreur }) {
  const { service } = useSession()
  const [url, setUrl] = useState<string | null>(null)
  const [erreur, setErreur] = useState<string | null>(null)
  useEffect(() => {
    let actif = true
    service
      .urlDocument(d.chemin)
      .then((u) => actif && setUrl(u))
      .catch((e) => actif && setErreur(messageErreur(e)))
    return () => {
      actif = false
    }
  }, [service, d.chemin])
  const libelle = libellesDocument[d.type] ?? d.type
  return (
    <li className="admin-document">
      {url && !d.chemin.endsWith('.pdf') && <img src={url} alt={libelle} className="admin-document-image" />}
      <div>
        <strong>{libelle}</strong>
        <div className="texte-doux">{d.etat === 'valide' ? 'Validé' : d.etat === 'refuse' ? 'Refusé' : 'À vérifier'}</div>
        {url && (
          <a href={url} target="_blank" rel="noreferrer" aria-label={`Ouvrir : ${libelle}`}>
            Ouvrir
          </a>
        )}
        {erreur && <span className="erreur-champ">{erreur}</span>}
      </div>
    </li>
  )
}
