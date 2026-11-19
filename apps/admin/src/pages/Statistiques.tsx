import { useState } from 'react'
import { Link } from 'react-router'

import { Chargement, MessageErreur } from '../composants'
import GraphiqueBarres from '../GraphiqueBarres'
import { formaterPrix } from '../service'
import { useDonnees, useSession } from '../session'
import { jourCourt, jourLong, part, periodes, revenuMida } from '../statistiques'

/**
 * Statistiques globales de la plateforme (US45) : commandes, chiffre
 * d'affaires, revenu de Mida, inscriptions, restaurants qui vendent le plus,
 * sur 7, 30 ou 90 jours.
 */
export default function Statistiques() {
  const { service } = useSession()
  const [jours, setJours] = useState<number>(30)
  const { donnees: s, erreur } = useDonnees(() => service.statistiques(jours), [jours])
  const pluriel = (n: number, mot: string) => `${n} ${mot}${n > 1 ? 's' : ''}`

  return (
    <>
      <div className="admin-filtres" role="group" aria-label="Période">
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
      {erreur ? (
        <MessageErreur>{erreur}</MessageErreur>
      ) : !s ? (
        <Chargement />
      ) : (
        <>
          <div className="admin-chiffres">
            <Chiffre
              titre="Commandes"
              valeur={String(s.commandes)}
              detail={`${pluriel(s.livrees, 'livrée')} · refus ${part(s.refusees, s.commandes)} · annulation ${part(s.annulees, s.commandes)}`}
            />
            <Chiffre
              titre="Chiffre d'affaires"
              valeur={formaterPrix(s.chiffreAffaires)}
              detail={`commandes livrées · panier moyen ${formaterPrix(s.panierMoyen)}`}
            />
            <Chiffre
              titre="Revenu de Mida"
              valeur={formaterPrix(revenuMida(s))}
              detail={`commissions ${formaterPrix(s.commissions)} + livraisons ${formaterPrix(s.fraisLivraison)} − livreurs ${formaterPrix(s.gainsLivreurs)}`}
            />
            <Chiffre
              titre="Nouveaux inscrits"
              valeur={String(s.nouveauxClients)}
              detail={`clients · ${pluriel(s.nouveauxRestaurants, 'restaurant')} · ${pluriel(s.nouveauxLivreurs, 'livreur')}`}
            />
            <Chiffre
              titre="Satisfaction"
              valeur={s.noteMoyenne === null ? '—' : `★ ${s.noteMoyenne.toFixed(1).replace('.', ',')} / 5`}
              detail={`${pluriel(s.reclamationsOuvertes, 'réclamation')} à traiter`}
            />
          </div>

          <div className="admin-stats">
            <section className="carte">
              <GraphiqueBarres
                titre={`Commandes par jour (${s.jours} derniers jours)`}
                formater={(v) => pluriel(v, 'commande')}
                barres={s.parJour.map((j) => ({
                  cle: j.jour,
                  etiquette: jourCourt(j.jour),
                  detail: `${jourLong(j.jour)} · ${formaterPrix(j.chiffreAffaires)} livrés`,
                  valeur: j.commandes,
                }))}
              />
            </section>
            <section className="carte" aria-labelledby="top-restaurants">
              <h2 id="top-restaurants" className="graphique-titre">
                Restaurants qui vendent le plus
              </h2>
              {s.topRestaurants.length === 0 ? (
                <p className="texte-doux">Aucune commande livrée sur cette période.</p>
              ) : (
                <table className="admin-table">
                  <thead>
                    <tr>
                      <th scope="col">Restaurant</th>
                      <th scope="col">Livrées</th>
                      <th scope="col">Ventes</th>
                    </tr>
                  </thead>
                  <tbody>
                    {s.topRestaurants.map((r) => (
                      <tr key={r.nom}>
                        <th scope="row">{r.nom}</th>
                        <td>{r.commandes}</td>
                        <td>{formaterPrix(r.ventes)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
              {s.reclamationsOuvertes > 0 && (
                <p>
                  <Link to="/reclamations">Traiter les réclamations</Link>
                </p>
              )}
            </section>
          </div>
        </>
      )}
    </>
  )
}

function Chiffre({ titre, valeur, detail }: { titre: string; valeur: string; detail: string }) {
  return (
    <div className="carte admin-chiffre">
      <div className="texte-doux">{titre}</div>
      <div className="admin-chiffre-valeur">{valeur}</div>
      <div className="texte-doux">{detail}</div>
    </div>
  )
}
