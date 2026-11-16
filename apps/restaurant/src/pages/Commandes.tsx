import { useEffect, useState } from 'react'

import type { Compte } from '../auth/service'
import Cadre from '../Cadre'
import {
  colonnes,
  duree,
  ilYa,
  libelleATraiter,
  libellePaiement,
  type Commande,
} from '../commandes/commandes'
import { useCommandes } from '../commandes/suivi'
import { Bouton, Chargement, MessageErreur } from '../composants'
import { formaterPrix } from '../menu/plats'

/** Temps pendant lequel une commande arrivée en temps réel reste mise en avant. */
const dureeMiseEnAvant = 15_000

/**
 * Commandes en cours (maquette « Restaurant · Commandes en cours ») : les
 * nouvelles commandes arrivent en temps réel, avec une alerte sonore et
 * visuelle (US12). Accepter / refuser : US13 ; « prête » : US14.
 */
export default function Commandes({ compte }: { compte: Compte }) {
  const { commandes, erreur, aTraiter, nouvelles, marquerVues, recharger, son, sonBloque, changerSon } = useCommandes()
  const [instant, setInstant] = useState(() => new Date())

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
                    <CarteCommande key={c.id} commande={c} nouvelle={nouvelles.includes(c.id)} maintenant={instant} />
                  ))
                )}
              </section>
            )
          })}
        </div>
      )}
    </Cadre>
  )
}

function CarteCommande({ commande: c, nouvelle, maintenant }: { commande: Commande; nouvelle: boolean; maintenant: Date }) {
  const temps = c.etat === 'en_attente' ? ilYa(c.creeeLe, maintenant) : duree(c.depuisLe, maintenant)
  return (
    <article
      className={nouvelle ? 'commande commande-nouvelle' : 'commande'}
      aria-label={`Commande n° ${c.numero}`}
    >
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
    </article>
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
