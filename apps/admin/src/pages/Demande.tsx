import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router'

import { Etat } from '../Cadre'
import { messageErreur } from '../auth/erreurs'
import { Bouton, Chargement, MessageErreur } from '../composants'
import { formaterDateHeure, libellesCompte } from '../service'
import { useDonnees, useSession } from '../session'

/** Maquette « Admin · Examiner une demande » : valider ou rejeter un restaurant (US33). */
export default function Demande() {
  const { id } = useParams()
  const { service } = useSession()
  const navigate = useNavigate()
  const { donnees, erreur } = useDonnees(() => service.restaurants(), [id])
  const [motif, setMotif] = useState('')
  const [erreurMotif, setErreurMotif] = useState<string | null>(null)
  const [erreurAction, setErreurAction] = useState<string | null>(null)
  const [enCours, setEnCours] = useState<'valider' | 'rejeter' | null>(null)

  if (erreur) return <MessageErreur>{erreur}</MessageErreur>
  if (!donnees) return <Chargement />
  const r = donnees.find((x) => x.id === id)
  if (!r) return <MessageErreur>Ce restaurant n'existe pas.</MessageErreur>

  async function decider(valider: boolean) {
    setErreurAction(null)
    if (!valider && !motif.trim()) {
      setErreurMotif('Indiquez le motif du rejet : il est communiqué au responsable.')
      return
    }
    setErreurMotif(null)
    setEnCours(valider ? 'valider' : 'rejeter')
    try {
      await service.deciderRestaurant(r!.id, valider, valider ? undefined : motif.trim())
      navigate('/restaurants', { replace: true })
    } catch (e) {
      setErreurAction(messageErreur(e))
    } finally {
      setEnCours(null)
    }
  }

  return (
    <div className="admin-demande-page">
      <p>
        <Link to="/restaurants">← Restaurants</Link>
      </p>
      <section className="carte">
        <div className="admin-barre">
          <h2>{r.nom}</h2>
          <Etat etat={r.etat} libelle={libellesCompte[r.etat]} />
        </div>
        <p className="texte-doux">Demande reçue le {formaterDateHeure(r.creeLe)}</p>
        {r.description && <p>« {r.description} »</p>}
        <dl className="admin-details">
          <dt>Responsable</dt>
          <dd>{r.responsable?.nom ?? '—'}</dd>
          <dt>Téléphone</dt>
          <dd>{r.telephone ?? r.responsable?.telephone ?? '—'}</dd>
          <dt>E-mail</dt>
          <dd>{r.responsable?.email ?? '—'}</dd>
          <dt>Catégorie</dt>
          <dd>{r.categorie ?? '—'}</dd>
          <dt>Adresse</dt>
          <dd>
            {r.adresse}, {r.ville}
          </dd>
        </dl>
      </section>

      {r.etat === 'en_attente' ? (
        <section className="carte" aria-labelledby="decision">
          <h2 id="decision">Décision</h2>
          <Bouton plein enCours={enCours === 'valider'} disabled={enCours !== null} onClick={() => void decider(true)}>
            Valider le restaurant
          </Bouton>
          <div className="champ">
            <label htmlFor="motif">Motif en cas de rejet</label>
            <textarea
              id="motif"
              className="saisie"
              rows={3}
              value={motif}
              aria-invalid={erreurMotif ? true : undefined}
              aria-describedby={erreurMotif ? 'motif-erreur' : undefined}
              onChange={(e) => setMotif(e.target.value)}
            />
            {erreurMotif && (
              <span id="motif-erreur" className="erreur-champ">
                {erreurMotif}
              </span>
            )}
          </div>
          <Bouton
            variante="harissa"
            plein
            enCours={enCours === 'rejeter'}
            disabled={enCours !== null}
            onClick={() => void decider(false)}
          >
            Rejeter la demande
          </Bouton>
          {erreurAction && <MessageErreur>{erreurAction}</MessageErreur>}
          <p className="texte-doux">
            Le responsable est prévenu dans les deux cas. Un restaurant validé devient visible par les clients dès qu'il
            ouvre.
          </p>
        </section>
      ) : (
        <p className="texte-doux">Cette demande a déjà été traitée.</p>
      )}
    </div>
  )
}
