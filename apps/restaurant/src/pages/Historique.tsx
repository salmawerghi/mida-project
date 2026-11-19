import { useCallback, useEffect, useState, type FormEvent } from 'react'

import { messageErreur } from '../auth/erreurs'
import type { Compte } from '../auth/service'
import { useSession } from '../auth/session'
import Cadre from '../Cadre'
import { libellePaiement, resumePlats } from '../commandes/commandes'
import { Chargement, MessageErreur } from '../composants'
import {
  bornesDates,
  choixEtats,
  filtresParDefaut,
  formaterDateHeure,
  parPage,
  pastilleEtat,
  type CommandeHistorique,
  type FiltreEtat,
  type FiltresHistorique,
  type PageHistorique,
} from '../historique/historique'
import { formaterPrix } from '../menu/plats'

/**
 * Historique des commandes (US39) : toutes les commandes du restaurant, de la
 * plus récente à la plus ancienne, filtrées par état, période et numéro, avec
 * le chiffre d'affaires des commandes livrées. Un clic affiche le détail.
 */
export default function Historique({ compte }: { compte: Compte }) {
  const { service } = useSession()
  const restaurant = compte.restaurant!
  const [saisie, setSaisie] = useState<FiltresHistorique>(filtresParDefaut)
  const [filtres, setFiltres] = useState<FiltresHistorique>(filtresParDefaut)
  const [page, setPage] = useState(0)
  const [resultat, setResultat] = useState<PageHistorique | null>(null)
  const [erreur, setErreur] = useState<string | null>(null)
  const [erreurDates, setErreurDates] = useState<string | null>(null)
  const [ouverte, setOuverte] = useState<string | null>(null)
  /** Filtres et page de la dernière réponse : différents de la demande actuelle pendant le chargement. */
  const [chargeePour, setChargeePour] = useState<string | null>(null)
  const cle = JSON.stringify([filtres, page])
  const chargement = chargeePour !== cle

  const charger = useCallback(async () => {
    const demande = JSON.stringify([filtres, page])
    try {
      const r = await service.historiqueCommandes(restaurant.id, filtres, page)
      setResultat(r)
      setErreur(null)
    } catch (e) {
      setErreur(messageErreur(e))
    } finally {
      setChargeePour(demande)
    }
  }, [service, restaurant.id, filtres, page])

  useEffect(() => {
    // charger() ne change l'état qu'après l'appel réseau à Supabase
    // oxlint-disable-next-line react/set-state-in-effect
    void charger()
  }, [charger])

  function appliquer(e: FormEvent) {
    e.preventDefault()
    const { erreur: invalide } = bornesDates(saisie.du, saisie.au)
    setErreurDates(invalide)
    if (invalide) return
    setOuverte(null)
    setPage(0)
    setFiltres({ ...saisie })
  }

  function effacer() {
    setSaisie(filtresParDefaut)
    setErreurDates(null)
    setOuverte(null)
    setPage(0)
    setFiltres(filtresParDefaut)
  }

  const nbPages = resultat ? Math.max(1, Math.ceil(resultat.total / parPage)) : 1
  const filtre = JSON.stringify(filtres) !== JSON.stringify(filtresParDefaut)

  return (
    <Cadre compte={compte}>
      <div className="barre">
        <div>
          <h1>Historique des commandes</h1>
          <p className="texte-doux">Retrouvez une commande passée : filtrez par état, par période ou par numéro.</p>
        </div>
      </div>

      <form className="historique-filtres" onSubmit={appliquer} aria-label="Filtres de l'historique">
        <label className="champ">
          <span className="champ-etiquette">État</span>
          <select
            className="saisie"
            value={saisie.etat}
            onChange={(e) => setSaisie({ ...saisie, etat: e.target.value as FiltreEtat })}
          >
            {choixEtats.map((c) => (
              <option key={c.valeur} value={c.valeur}>
                {c.libelle}
              </option>
            ))}
          </select>
        </label>
        <label className="champ">
          <span className="champ-etiquette">Du</span>
          <input
            className="saisie"
            type="date"
            value={saisie.du}
            onChange={(e) => setSaisie({ ...saisie, du: e.target.value })}
            aria-invalid={erreurDates ? true : undefined}
          />
        </label>
        <label className="champ">
          <span className="champ-etiquette">Au</span>
          <input
            className="saisie"
            type="date"
            value={saisie.au}
            onChange={(e) => setSaisie({ ...saisie, au: e.target.value })}
            aria-invalid={erreurDates ? true : undefined}
          />
        </label>
        <label className="champ">
          <span className="champ-etiquette">N° de commande</span>
          <input
            className="saisie"
            inputMode="numeric"
            placeholder="ex. 1042"
            value={saisie.numero}
            onChange={(e) => setSaisie({ ...saisie, numero: e.target.value })}
          />
        </label>
        <div className="historique-boutons">
          <button type="submit" className="bouton bouton-bleu bouton-petit">
            Filtrer
          </button>
          <button type="button" className="bouton bouton-blanc bouton-petit" onClick={effacer}>
            Effacer les filtres
          </button>
        </div>
        {erreurDates && (
          <p className="erreur-champ pleine-largeur" role="alert">
            {erreurDates}
          </p>
        )}
      </form>

      {erreur && (
        <div className="historique-message">
          <MessageErreur>{erreur}</MessageErreur>
          <button type="button" className="lien-bouton" onClick={() => void charger()}>
            Réessayer
          </button>
        </div>
      )}

      {resultat && (
        <>
          <p className="historique-resume" role="status">
            {resultat.total === 0
              ? 'Aucune commande'
              : resultat.total === 1
                ? '1 commande'
                : `${resultat.total} commandes`}
            {(filtres.etat === 'toutes' || filtres.etat === 'livree') && (
              <>
                {' · '}
                {resultat.nbLivrees} livrée{resultat.nbLivrees > 1 ? 's' : ''} pour{' '}
                <strong>{formaterPrix(resultat.chiffreAffaires)}</strong>
              </>
            )}
          </p>

          {resultat.commandes.length === 0 ? (
            <div className="carte historique-vide">
              <p>{filtre ? 'Aucune commande ne correspond à ces filtres.' : 'Aucune commande pour le moment.'}</p>
              {filtre && (
                <button type="button" className="bouton bouton-blanc bouton-petit" onClick={effacer}>
                  Effacer les filtres
                </button>
              )}
            </div>
          ) : (
            <ul className="historique-liste" aria-busy={chargement}>
              {resultat.commandes.map((c) => (
                <LigneHistorique
                  key={c.id}
                  commande={c}
                  ouverte={ouverte === c.id}
                  basculer={() => setOuverte(ouverte === c.id ? null : c.id)}
                />
              ))}
            </ul>
          )}

          {nbPages > 1 && (
            <nav className="historique-pages" aria-label="Pages de l'historique">
              <button
                type="button"
                className="bouton bouton-blanc bouton-petit"
                disabled={page === 0 || chargement}
                onClick={() => setPage(page - 1)}
              >
                Plus récentes
              </button>
              <span>
                Page {page + 1} sur {nbPages}
              </span>
              <button
                type="button"
                className="bouton bouton-blanc bouton-petit"
                disabled={page + 1 >= nbPages || chargement}
                onClick={() => setPage(page + 1)}
              >
                Plus anciennes
              </button>
            </nav>
          )}
        </>
      )}
      {!resultat && !erreur && <Chargement />}
    </Cadre>
  )
}

function LigneHistorique({
  commande: c,
  ouverte,
  basculer,
}: {
  commande: CommandeHistorique
  ouverte: boolean
  basculer: () => void
}) {
  const pastille = pastilleEtat(c.etat)
  const idDetail = `detail-${c.id}`
  return (
    <li className="historique-ligne">
      <button
        type="button"
        className="historique-entete"
        aria-expanded={ouverte}
        aria-controls={idDetail}
        onClick={basculer}
      >
        <span className="historique-numero">N° {c.numero}</span>
        <span className="historique-date">{formaterDateHeure(c.creeeLe)}</span>
        <span className="historique-client">{c.client}</span>
        <span className={`pastille ${pastille.classe}`}>{pastille.libelle}</span>
        <span className="historique-total">{formaterPrix(c.total)}</span>
      </button>
      {ouverte && (
        <div id={idDetail} className="historique-detail">
          <p>{resumePlats(c)}</p>
          {c.lignes.some((l) => l.remarque) && (
            <ul>
              {c.lignes
                .filter((l) => l.remarque)
                .map((l, i) => (
                  <li key={i}>
                    {l.nomPlat} : {l.remarque}
                  </li>
                ))}
            </ul>
          )}
          {c.remarque && <p>Remarque du client : {c.remarque}</p>}
          <p>Paiement : {libellePaiement(c.paiement)}</p>
          {c.etat === 'livree' && c.livreeLe && <p>Livrée le {formaterDateHeure(c.livreeLe)}</p>}
          {c.etat === 'annulee' && <p>Annulée par le client{c.annuleeLe ? ` le ${formaterDateHeure(c.annuleeLe)}` : ''}.</p>}
          {c.etat === 'refusee' && <p>Motif du refus : {c.motifRefus ?? 'non précisé'}</p>}
        </div>
      )}
    </li>
  )
}
