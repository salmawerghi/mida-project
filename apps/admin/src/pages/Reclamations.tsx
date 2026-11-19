import { useState, type FormEvent } from 'react'

import { messageErreur } from '../auth/erreurs'
import { Etat } from '../Cadre'
import { Chargement, MessageErreur, MessageInfo } from '../composants'
import { formaterDateHeure, formaterPrix } from '../service'
import { useDonnees, useSession } from '../session'
import { aTraiter, libellesReclamation, validerTraitement, type Reclamation } from '../statistiques'

/**
 * Réclamations des clients (US49) : à traiter d'abord ; l'administrateur
 * lit le problème et la commande, puis la déclare fondée (avec un
 * remboursement éventuel) ou non, avec une réponse envoyée au client.
 */
export default function Reclamations() {
  const { service } = useSession()
  const { donnees, erreur, recharger } = useDonnees(() => service.reclamations())
  const [onglet, setOnglet] = useState<'a_traiter' | 'traitees'>('a_traiter')
  const [choisie, setChoisie] = useState<string | null>(null)
  const [confirmation, setConfirmation] = useState<string | null>(null)

  if (erreur) return <MessageErreur>{erreur}</MessageErreur>
  if (!donnees) return <Chargement />

  const enAttente = donnees.filter(aTraiter)
  const traitees = donnees.filter((r) => !aTraiter(r))
  const liste = onglet === 'a_traiter' ? enAttente : traitees
  const selection = donnees.find((r) => r.id === choisie) ?? null

  return (
    <>
      <div className="admin-filtres" role="group" aria-label="Réclamations affichées">
        <button
          type="button"
          className={`bouton bouton-petit ${onglet === 'a_traiter' ? 'bouton-bleu' : 'bouton-blanc'}`}
          aria-pressed={onglet === 'a_traiter'}
          onClick={() => setOnglet('a_traiter')}
        >
          À traiter ({enAttente.length})
        </button>
        <button
          type="button"
          className={`bouton bouton-petit ${onglet === 'traitees' ? 'bouton-bleu' : 'bouton-blanc'}`}
          aria-pressed={onglet === 'traitees'}
          onClick={() => setOnglet('traitees')}
        >
          Traitées ({traitees.length})
        </button>
      </div>
      {confirmation && <MessageInfo>{confirmation}</MessageInfo>}
      <div className="admin-commandes">
        <div>
          {liste.length === 0 ? (
            <p className="texte-doux">
              {onglet === 'a_traiter' ? 'Aucune réclamation à traiter. 🎉' : 'Aucune réclamation traitée pour le moment.'}
            </p>
          ) : (
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Commande</th>
                  <th>Motif · client</th>
                  <th>Reçue le</th>
                  <th>État</th>
                </tr>
              </thead>
              <tbody>
                {liste.map((r) => (
                  <tr key={r.id} className={r.id === choisie ? 'admin-ligne-choisie' : undefined}>
                    <td>
                      <button
                        type="button"
                        className="lien-bouton"
                        aria-label={`Réclamation sur la commande n° ${r.commande.numero}`}
                        onClick={() => {
                          setChoisie(r.id)
                          setConfirmation(null)
                        }}
                      >
                        n° {r.commande.numero}
                      </button>
                    </td>
                    <td>
                      {r.motif}
                      <div className="texte-doux">
                        {r.client.nom} · {r.commande.restaurant}
                      </div>
                    </td>
                    <td>{formaterDateHeure(r.creeLe)}</td>
                    <td>
                      <Etat etat={`reclamation-${r.etat}`} libelle={libellesReclamation[r.etat]} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
        {selection && (
          <Detail
            key={selection.id}
            reclamation={selection}
            onFermer={() => setChoisie(null)}
            onTraitee={async (message) => {
              setConfirmation(message)
              setChoisie(null)
              await recharger()
            }}
          />
        )}
      </div>
    </>
  )
}

function Detail({
  reclamation: r,
  onFermer,
  onTraitee,
}: {
  reclamation: Reclamation
  onFermer: () => void
  onTraitee: (message: string) => Promise<void>
}) {
  const { service } = useSession()
  const [decision, setDecision] = useState<'resolue' | 'rejetee' | null>(null)
  const [reponse, setReponse] = useState('')
  const [montant, setMontant] = useState('')
  const [erreurs, setErreurs] = useState<{ decision?: string; reponse?: string; montant?: string }>({})
  const [erreur, setErreur] = useState<string | null>(null)
  const [enCours, setEnCours] = useState(false)

  async function envoyer(e: FormEvent) {
    e.preventDefault()
    const v = validerTraitement(decision, reponse, montant, r.commande.total)
    setErreurs(v)
    if (v.decision || v.reponse || v.montant) return
    setEnCours(true)
    setErreur(null)
    try {
      await service.traiterReclamation(r.id, decision === 'resolue', reponse.trim(), v.valeur ?? null)
      await onTraitee(
        decision === 'resolue'
          ? `Réclamation sur la commande n° ${r.commande.numero} résolue${v.valeur ? ` : ${formaterPrix(v.valeur)} remboursés` : ''}. Le client est prévenu.`
          : `Réclamation sur la commande n° ${r.commande.numero} rejetée. Le client est prévenu.`,
      )
    } catch (err) {
      setErreur(messageErreur(err))
    } finally {
      setEnCours(false)
    }
  }

  return (
    <aside className="carte admin-detail" aria-label={`Réclamation sur la commande n° ${r.commande.numero}`}>
      <div className="admin-barre">
        <h2>Commande n° {r.commande.numero}</h2>
        <button type="button" className="lien-bouton" onClick={onFermer}>
          Fermer
        </button>
      </div>
      <dl className="admin-details">
        <dt>Client</dt>
        <dd>
          {r.client.nom} · {r.client.email}
          {r.client.telephone && ` · ${r.client.telephone}`}
        </dd>
        <dt>Restaurant</dt>
        <dd>{r.commande.restaurant}</dd>
        <dt>Total de la commande</dt>
        <dd>{formaterPrix(r.commande.total)}</dd>
        {r.commande.livreeLe && (
          <>
            <dt>Livrée le</dt>
            <dd>{formaterDateHeure(r.commande.livreeLe)}</dd>
          </>
        )}
        <dt>Motif</dt>
        <dd>{r.motif}</dd>
        <dt>Message du client</dt>
        <dd>{r.description ?? '—'}</dd>
      </dl>

      {aTraiter(r) ? (
        <form className="admin-traitement" onSubmit={(e) => void envoyer(e)} noValidate>
          <fieldset>
            <legend>Décision</legend>
            <label className="case">
              <input type="radio" name="decision" checked={decision === 'resolue'} onChange={() => setDecision('resolue')} />
              Réclamation fondée (résolue)
            </label>
            <label className="case">
              <input type="radio" name="decision" checked={decision === 'rejetee'} onChange={() => setDecision('rejetee')} />
              Réclamation non fondée (rejetée)
            </label>
            {erreurs.decision && <p className="erreur-champ">{erreurs.decision}</p>}
          </fieldset>
          {decision === 'resolue' && (
            <label className="champ">
              <span className="champ-etiquette">Montant remboursé (facultatif, DT)</span>
              <input
                className="saisie"
                inputMode="decimal"
                placeholder={`0 à ${formaterPrix(r.commande.total)}`}
                value={montant}
                onChange={(e) => setMontant(e.target.value)}
                aria-invalid={erreurs.montant ? true : undefined}
                aria-describedby={erreurs.montant ? 'erreur-montant' : undefined}
              />
            </label>
          )}
          {decision === 'resolue' && erreurs.montant && (
            <span id="erreur-montant" className="erreur-champ">
              {erreurs.montant}
            </span>
          )}
          <label className="champ">
            <span className="champ-etiquette">Réponse au client</span>
            <textarea
              className="saisie"
              rows={4}
              maxLength={1000}
              value={reponse}
              onChange={(e) => setReponse(e.target.value)}
              aria-invalid={erreurs.reponse ? true : undefined}
              aria-describedby={erreurs.reponse ? 'erreur-reponse' : undefined}
            />
          </label>
          {erreurs.reponse && (
            <span id="erreur-reponse" className="erreur-champ">
              {erreurs.reponse}
            </span>
          )}
          {erreur && <MessageErreur>{erreur}</MessageErreur>}
          <button type="submit" className="bouton bouton-bleu" disabled={enCours}>
            {enCours ? 'Envoi…' : 'Envoyer la décision'}
          </button>
        </form>
      ) : (
        <>
          <h3>Décision : {libellesReclamation[r.etat]}</h3>
          <p>{r.reponse}</p>
          {r.montantRembourse !== null && <p>Remboursement : {formaterPrix(r.montantRembourse)}</p>}
          {r.traiteeLe && <p className="texte-doux">Traitée le {formaterDateHeure(r.traiteeLe)}</p>}
        </>
      )}
    </aside>
  )
}
