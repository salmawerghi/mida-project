import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router'

import { messageErreur } from '../auth/erreurs'
import type { Compte } from '../auth/service'
import { useSession } from '../auth/session'
import Cadre from '../Cadre'
import { Chargement, MessageErreur } from '../composants'
import { formaterNote } from '../historique/historique'
import { formaterPrix } from '../menu/plats'
import GraphiqueBarres from '../statistiques/GraphiqueBarres'
import {
  jourCourt,
  jourLong,
  periodes,
  pourcentage,
  tauxRefus,
  type StatsRestaurant,
} from '../statistiques/statistiques'

/**
 * Tableau de bord du restaurant validé (US44) : ventes, commandes, panier
 * moyen, commission de Mida, ventes par jour et plats les plus vendus, sur
 * 7, 30 ou 90 jours.
 */
export default function Tableau({ compte }: { compte: Compte }) {
  const { service } = useSession()
  const restaurant = compte.restaurant!
  const [jours, setJours] = useState<number>(30)
  const [stats, setStats] = useState<StatsRestaurant | null>(null)
  const [erreur, setErreur] = useState<string | null>(null)

  const charger = useCallback(async () => {
    try {
      setStats(await service.statistiques(restaurant.id, jours))
      setErreur(null)
    } catch (e) {
      setErreur(messageErreur(e))
    }
  }, [service, restaurant.id, jours])

  useEffect(() => {
    // charger() ne change l'état qu'après l'appel réseau à Supabase
    // oxlint-disable-next-line react/set-state-in-effect
    void charger()
  }, [charger])

  const net = stats ? Math.round((stats.ventes - stats.commission) * 1000) / 1000 : 0
  const pluriel = (n: number, mot: string) => `${n} ${mot}${n > 1 ? 's' : ''}`

  return (
    <Cadre compte={compte}>
      <div className="barre">
        <div>
          <h1>Bienvenue, {restaurant.nom}</h1>
          <p className="texte-doux">Vos ventes et vos commandes, mises à jour à chaque visite.</p>
        </div>
        <div className="stats-periodes" role="group" aria-label="Période">
          {periodes.map((p) => (
            <button
              key={p.jours}
              type="button"
              className={`bouton bouton-petit ${jours === p.jours ? 'bouton-bleu' : 'bouton-blanc'}`}
              aria-pressed={jours === p.jours}
              onClick={() => setJours(p.jours)}
            >
              {p.libelle}
            </button>
          ))}
        </div>
      </div>

      {!restaurant.ouvert && (
        <p className="message message-note">
          Votre restaurant est <strong>fermé</strong> : les clients ne peuvent pas commander. Ouvrez-le avec
          l'interrupteur « Restaurant fermé », dans le menu.
        </p>
      )}

      {erreur && (
        <div className="historique-message">
          <MessageErreur>{erreur}</MessageErreur>
          <button type="button" className="lien-bouton" onClick={() => void charger()}>
            Réessayer
          </button>
        </div>
      )}
      {!stats && !erreur && <Chargement />}

      {stats && (
        <>
          <div className="stats-tuiles">
            <Tuile titre="Ventes" valeur={formaterPrix(stats.ventes)} detail={stats.livrees > 1 ? `${stats.livrees} commandes livrées` : `${stats.livrees} commande livrée`} />
            <Tuile
              titre="Commandes reçues"
              valeur={String(stats.commandes)}
              detail={`${stats.refusees} refusée${stats.refusees > 1 ? 's' : ''} (${pourcentage(tauxRefus(stats))}) · ${stats.annulees} annulée${stats.annulees > 1 ? 's' : ''}`}
            />
            <Tuile titre="Panier moyen" valeur={formaterPrix(stats.panierMoyen)} detail="par commande livrée" />
            <Tuile
              titre="Après commission"
              valeur={formaterPrix(net)}
              detail={`commission Mida ${pourcentage(stats.commissionPct)} : ${formaterPrix(stats.commission)}`}
            />
            <Tuile
              titre="Note des clients"
              valeur={stats.noteMoyenne === null ? '—' : `★ ${formaterNote(stats.noteMoyenne)} / 5`}
              detail={stats.nbAvis ? `${stats.nbAvis} avis` : 'pas encore d’avis'}
              lien={stats.nbAvis ? '/avis' : undefined}
            />
          </div>

          <div className="stats-colonnes">
            <section className="carte">
              <GraphiqueBarres
                titre={`Ventes par jour (commandes livrées, ${stats.jours} derniers jours)`}
                formater={formaterPrix}
                barres={stats.parJour.map((j) => ({
                  cle: j.jour,
                  etiquette: jourCourt(j.jour),
                  detail: `${jourLong(j.jour)} · ${pluriel(j.commandes, 'commande')}`,
                  valeur: j.ventes,
                }))}
              />
            </section>
            <section className="carte" aria-labelledby="top-plats">
              <h2 id="top-plats" className="graphique-titre">
                Plats les plus vendus
              </h2>
              {stats.topPlats.length === 0 ? (
                <p className="texte-doux">Aucune commande livrée sur cette période.</p>
              ) : (
                <table className="stats-table">
                  <thead>
                    <tr>
                      <th scope="col">Plat</th>
                      <th scope="col">Vendus</th>
                      <th scope="col">Montant</th>
                    </tr>
                  </thead>
                  <tbody>
                    {stats.topPlats.map((p) => (
                      <tr key={p.nom}>
                        <th scope="row">{p.nom}</th>
                        <td>{p.quantite}</td>
                        <td>{formaterPrix(p.ventes)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </section>
          </div>

          <div className="actions" style={{ justifyContent: 'flex-start' }}>
            <Link to="/commandes" className="bouton bouton-bleu">
              Commandes en cours
            </Link>
            <Link to="/historique" className="bouton bouton-blanc">
              Historique
            </Link>
            <Link to="/menu" className="bouton bouton-blanc">
              Votre menu
            </Link>
          </div>
        </>
      )}
    </Cadre>
  )
}

function Tuile({ titre, valeur, detail, lien }: { titre: string; valeur: string; detail: string; lien?: string }) {
  return (
    <div className="carte stats-tuile">
      <div className="texte-doux">{titre}</div>
      <div className="stats-valeur">{valeur}</div>
      <div className="texte-doux stats-detail">
        {detail}
        {lien && (
          <>
            {' · '}
            <Link to={lien}>voir</Link>
          </>
        )}
      </div>
    </div>
  )
}
