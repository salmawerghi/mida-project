import { useEffect, useRef, useState, type FormEvent } from 'react'

import { messageErreur } from '../auth/erreurs'
import type { Compte } from '../auth/service'
import { useSession } from '../auth/session'
import Cadre from '../Cadre'
import {
  colonnes,
  composerMotif,
  duree,
  ilYa,
  libelleATraiter,
  libellePaiement,
  longueurMaxMessageRefus,
  motifsRefus,
  resumePlats,
  validerRefus,
  type Commande,
  type MotifRefus,
} from '../commandes/commandes'
import { useCommandes } from '../commandes/suivi'
import { Bouton, Chargement, MessageErreur, MessageInfo } from '../composants'
import { formaterPrix } from '../menu/plats'

/** Temps pendant lequel une commande arrivée en temps réel reste mise en avant. */
const dureeMiseEnAvant = 15_000

/**
 * Commandes en cours (maquette « Restaurant · Commandes en cours ») : les
 * nouvelles commandes arrivent en temps réel, avec une alerte sonore et
 * visuelle (US12) ; le responsable les accepte ou les refuse avec un motif
 * (US13). « Prête » : US14.
 */
export default function Commandes({ compte }: { compte: Compte }) {
  const { service } = useSession()
  const { commandes, erreur, aTraiter, nouvelles, marquerVues, recharger, son, sonBloque, changerSon } = useCommandes()
  const [instant, setInstant] = useState(() => new Date())
  /** Commande en cours de décision (bouton en attente de la réponse de Supabase). */
  const [enCours, setEnCours] = useState<string | null>(null)
  const [confirmation, setConfirmation] = useState<string | null>(null)
  const [erreurAction, setErreurAction] = useState<string | null>(null)
  const [aRefuser, setARefuser] = useState<Commande | null>(null)

  // « il y a 3 min » se met à jour tout seul
  useEffect(() => {
    const minuterie = setInterval(() => setInstant(new Date()), 30_000)
    return () => clearInterval(minuterie)
  }, [])

  // Les nouvelles commandes sont vues : la mise en avant s'efface après quelques secondes,
  // ou quand on quitte la page.
  useEffect(() => {
    if (nouvelles.length === 0) return
    const minuterie = setTimeout(marquerVues, dureeMiseEnAvant)
    return () => clearTimeout(minuterie)
  }, [nouvelles, marquerVues])
  useEffect(() => marquerVues, [marquerVues])

  const restaurant = compte.restaurant!
  const date = instant.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })

  /** Envoie la décision ; dans tous les cas la liste est relue (la commande a pu changer entre-temps). */
  async function decider(commande: Commande, action: () => Promise<void>, message: string): Promise<boolean> {
    setEnCours(commande.id)
    setErreurAction(null)
    setConfirmation(null)
    try {
      await action()
      setConfirmation(message)
      return true
    } catch (e) {
      setErreurAction(messageErreur(e))
      return false
    } finally {
      setEnCours(null)
      await recharger()
    }
  }

  function accepter(commande: Commande) {
    void decider(
      commande,
      () => service.accepterCommande(commande.id),
      `Commande n° ${commande.numero} acceptée : le client est prévenu. Elle passe en préparation.`,
    )
  }

  async function refuser(commande: Commande, motif: string) {
    const rembourse = commande.paiement?.mode === 'carte' && commande.paiement.etat === 'paye'
    const fait = await decider(
      commande,
      () => service.refuserCommande(commande.id, motif),
      `Commande n° ${commande.numero} refusée : le client est prévenu${rembourse ? ' et sera remboursé' : ''}.`,
    )
    if (fait) setARefuser(null)
  }

  return (
    <Cadre compte={compte}>
      <div className="barre">
        <div>
          <h1>Commandes en cours</h1>
          <p className="texte-doux">
            <span className="commandes-date">{date}</span> · mise à jour en temps réel
          </p>
        </div>
        <div className="commandes-entete-actions">
          {aTraiter > 0 && (
            <div className="commandes-alerte" role="status">
              <IconeCloche />
              {libelleATraiter(aTraiter)}
            </div>
          )}
          <button
            type="button"
            className="bouton bouton-blanc bouton-petit commandes-son"
            aria-pressed={son}
            onClick={() => changerSon(!son)}
          >
            {son ? 'Alerte sonore activée' : 'Alerte sonore désactivée'}
          </button>
        </div>
      </div>

      {son && sonBloque && (
        <p className="message message-note">
          Votre navigateur bloque le son tant que vous n'avez pas cliqué dans la page.{' '}
          <button type="button" className="lien-bouton" onClick={() => changerSon(true)}>
            Cliquez ici pour activer l'alerte sonore
          </button>
          .
        </p>
      )}
      {!restaurant.ouvert && (
        <p className="message message-note">
          Votre restaurant est <strong>fermé</strong> : vous ne recevrez pas de nouvelle commande avant de l'ouvrir.
        </p>
      )}
      {confirmation && <MessageInfo>{confirmation}</MessageInfo>}
      {erreurAction && !aRefuser && <MessageErreur>{erreurAction}</MessageErreur>}

      {erreur && (
        <div className="commandes-erreur">
          <MessageErreur>{erreur}</MessageErreur>
          <Bouton variante="blanc" className="bouton-petit" onClick={() => void recharger()}>
            Réessayer
          </Bouton>
        </div>
      )}

      {commandes === null ? (
        !erreur && <Chargement />
      ) : (
        <div className="commandes-colonnes">
          {colonnes.map((colonne) => {
            const liste = commandes.filter((c) => colonne.etats.includes(c.etat))
            return (
              <section key={colonne.titre} className="commandes-colonne" aria-label={colonne.titre}>
                <h2>
                  {colonne.titre} <span className="commandes-compte">{liste.length}</span>
                </h2>
                {liste.length === 0 ? (
                  <p className="texte-doux commandes-vide">{colonne.vide}</p>
                ) : (
                  liste.map((c) => (
                    <CarteCommande
                      key={c.id}
                      commande={c}
                      nouvelle={nouvelles.includes(c.id)}
                      maintenant={instant}
                      enCours={enCours === c.id}
                      bloque={enCours !== null}
                      onAccepter={() => accepter(c)}
                      onRefuser={() => {
                        setErreurAction(null)
                        setConfirmation(null)
                        setARefuser(c)
                      }}
                    />
                  ))
                )}
              </section>
            )
          })}
        </div>
      )}

      {aRefuser && (
        <FenetreRefus
          commande={aRefuser}
          enCours={enCours === aRefuser.id}
          erreur={erreurAction}
          onAnnuler={() => {
            setARefuser(null)
            setErreurAction(null)
          }}
          onConfirmer={(motif) => void refuser(aRefuser, motif)}
        />
      )}
    </Cadre>
  )
}

function CarteCommande({
  commande: c,
  nouvelle,
  maintenant,
  enCours,
  bloque,
  onAccepter,
  onRefuser,
}: {
  commande: Commande
  nouvelle: boolean
  maintenant: Date
  enCours: boolean
  bloque: boolean
  onAccepter: () => void
  onRefuser: () => void
}) {
  const temps = c.etat === 'en_attente' ? ilYa(c.creeeLe, maintenant) : duree(c.depuisLe, maintenant)
  return (
    <article className={nouvelle ? 'commande commande-nouvelle' : 'commande'} aria-label={`Commande n° ${c.numero}`}>
      <div className="commande-entete">
        <span className="commande-numero">
          N° {c.numero} · {c.client}
        </span>
        <span className="commande-temps">{nouvelle ? 'Nouvelle !' : temps}</span>
      </div>
      <ul className="commande-lignes">
        {c.lignes.map((l, i) => (
          <li key={i}>
            <strong>{l.quantite} ×</strong> {l.nomPlat}
            {l.remarque && <span className="commande-remarque-ligne">{l.remarque}</span>}
          </li>
        ))}
      </ul>
      {c.remarque && (
        <p className="commande-remarque">
          <span>Remarque du client :</span> {c.remarque}
        </p>
      )}
      <div className="commande-pied">
        <span className={c.paiement?.mode === 'carte' ? 'commande-paiement commande-carte' : 'commande-paiement'}>
          {libellePaiement(c.paiement)}
        </span>
        <span className="commande-total">{formaterPrix(c.total)}</span>
      </div>
      {c.etat === 'en_attente' && (
        <div className="commande-actions">
          <Bouton
            className="bouton-petit"
            enCours={enCours}
            disabled={bloque}
            onClick={onAccepter}
            aria-label={`Accepter la commande n° ${c.numero}`}
          >
            Accepter
          </Bouton>
          <Bouton
            variante="blanc"
            className="bouton-petit commande-refuser"
            disabled={bloque}
            onClick={onRefuser}
            aria-label={`Refuser la commande n° ${c.numero}`}
          >
            Refuser
          </Bouton>
        </div>
      )}
    </article>
  )
}

/** Fenêtre de refus (maquette « Restaurant · Refus ») : motif obligatoire, message facultatif au client. */
function FenetreRefus({
  commande: c,
  enCours,
  erreur,
  onAnnuler,
  onConfirmer,
}: {
  commande: Commande
  enCours: boolean
  erreur: string | null
  onAnnuler: () => void
  onConfirmer: (motif: string) => void
}) {
  const [motif, setMotif] = useState<MotifRefus | null>(null)
  const [message, setMessage] = useState('')
  const [erreurs, setErreurs] = useState<{ motif?: string; message?: string }>({})
  const premierChoix = useRef<HTMLInputElement>(null)

  // focus sur le premier motif à l'ouverture seulement (pas à chaque relecture des commandes)
  useEffect(() => {
    premierChoix.current?.focus()
  }, [])

  useEffect(() => {
    const echap = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !enCours) onAnnuler()
    }
    window.addEventListener('keydown', echap)
    return () => window.removeEventListener('keydown', echap)
  }, [enCours, onAnnuler])

  function envoyer(e: FormEvent) {
    e.preventDefault()
    const refus = validerRefus(motif, message)
    setErreurs(refus)
    if (motif && !refus.motif && !refus.message) onConfirmer(composerMotif(motif, message))
  }

  const carte = c.paiement?.mode === 'carte' && c.paiement.etat === 'paye'
  return (
    <div className="fenetre-fond">
      <div className="fenetre" role="dialog" aria-modal="true" aria-labelledby="refus-titre">
        <h2 id="refus-titre">Refuser la commande n° {c.numero}</h2>
        <p className="texte-doux">
          {c.client} · {resumePlats(c)} · {formaterPrix(c.total)}
        </p>
        <form onSubmit={envoyer} noValidate className="fenetre-formulaire">
          <fieldset className="refus-motifs" aria-describedby={erreurs.motif ? 'refus-motif-erreur' : undefined}>
            <legend>
              Motif du refus <span className="texte-doux">(obligatoire)</span>
            </legend>
            {motifsRefus.map((m, i) => (
              <label key={m} className={motif === m ? 'refus-motif refus-motif-choisi' : 'refus-motif'}>
                <input
                  ref={i === 0 ? premierChoix : undefined}
                  type="radio"
                  name="motif"
                  value={m}
                  checked={motif === m}
                  onChange={() => {
                    setMotif(m)
                    setErreurs({})
                  }}
                />
                {m}
              </label>
            ))}
            {erreurs.motif && (
              <span id="refus-motif-erreur" className="erreur-champ">
                {erreurs.motif}
              </span>
            )}
          </fieldset>
          <div className="champ">
            <label htmlFor="refus-message">
              Message au client{' '}
              <span className="texte-doux">{motif === 'Autre motif' ? '(obligatoire)' : '(facultatif)'}</span>
            </label>
            <textarea
              id="refus-message"
              className="saisie"
              rows={3}
              maxLength={longueurMaxMessageRefus}
              placeholder="Désolés, nous n'avons plus de couscous ce soir. Nous espérons vous servir très bientôt."
              aria-invalid={erreurs.message ? true : undefined}
              aria-describedby={erreurs.message ? 'refus-message-erreur' : undefined}
              value={message}
              onChange={(e) => {
                setMessage(e.target.value)
                setErreurs({})
              }}
            />
            {erreurs.message && (
              <span id="refus-message-erreur" className="erreur-champ">
                {erreurs.message}
              </span>
            )}
          </div>
          <p className="message message-note">
            {carte
              ? `Le client a payé par carte : il sera remboursé de ${formaterPrix(c.total)}.`
              : c.paiement?.mode === 'especes'
                ? "Le client a choisi le paiement en espèces : aucun remboursement n'est nécessaire."
                : "Aucun paiement encaissé : aucun remboursement n'est nécessaire."}
          </p>
          {erreur && <MessageErreur>{erreur}</MessageErreur>}
          <div className="actions">
            <Bouton type="button" variante="blanc" disabled={enCours} onClick={onAnnuler}>
              Annuler
            </Bouton>
            <Bouton type="submit" variante="harissa" enCours={enCours}>
              Confirmer le refus
            </Bouton>
          </div>
        </form>
      </div>
    </div>
  )
}

export function IconeCloche() {
  return (
    <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M6 9a6 6 0 0 1 12 0c0 6 2.5 7 2.5 7h-17S6 15 6 9z" />
      <path d="M10 20a2 2 0 0 0 4 0" />
    </svg>
  )
}
