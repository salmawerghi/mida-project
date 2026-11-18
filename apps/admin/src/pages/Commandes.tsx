import { useState } from 'react'

import { Etat } from '../Cadre'
import { Chargement, MessageErreur } from '../composants'
import {
  formaterDateHeure,
  formaterPrix,
  libellesEtat,
  type CommandeAdmin,
  type EtatCommande,
  type FiltreCommandes,
} from '../service'
import { useDonnees, useSession } from '../session'

const libellesPaiement = { en_attente: 'En attente', paye: 'Payé', echoue: 'Échoué', rembourse: 'Remboursé' }

/** Maquette « Admin · Commandes » : filtres par état, restaurant et date ; détail avec le paiement (US36). */
export default function Commandes() {
  const { service } = useSession()
  const [filtre, setFiltre] = useState<FiltreCommandes>({ etat: '', restaurantId: '', date: '' })
  const { donnees, erreur } = useDonnees(() => service.commandes(filtre), [filtre.etat, filtre.restaurantId, filtre.date])
  const { donnees: restaurants } = useDonnees(() => service.restaurants())
  const [choisie, setChoisie] = useState<string | null>(null)
  const selection = donnees?.find((c) => c.id === choisie) ?? null

  return (
    <>
      <div className="admin-filtres" role="group" aria-label="Filtres">
        <select
          className="saisie"
          aria-label="État"
          value={filtre.etat}
          onChange={(e) => setFiltre({ ...filtre, etat: e.target.value as EtatCommande | '' })}
        >
          <option value="">Tous les états</option>
          {Object.entries(libellesEtat).map(([code, libelle]) => (
            <option key={code} value={code}>
              {libelle}
            </option>
          ))}
        </select>
        <select
          className="saisie"
          aria-label="Restaurant"
          value={filtre.restaurantId}
          onChange={(e) => setFiltre({ ...filtre, restaurantId: e.target.value })}
        >
          <option value="">Tous les restaurants</option>
          {(restaurants ?? []).map((r) => (
            <option key={r.id} value={r.id}>
              {r.nom}
            </option>
          ))}
        </select>
        <input
          className="saisie"
          type="date"
          aria-label="Date"
          value={filtre.date}
          onChange={(e) => setFiltre({ ...filtre, date: e.target.value })}
        />
      </div>
      {erreur ? (
        <MessageErreur>{erreur}</MessageErreur>
      ) : !donnees ? (
        <Chargement />
      ) : (
        <div className="admin-commandes">
          <table className="admin-table">
            <thead>
              <tr>
                <th>N°</th>
                <th>Restaurant · client</th>
                <th>Total</th>
                <th>Paiement</th>
                <th>État</th>
              </tr>
            </thead>
            <tbody>
              {donnees.map((c) => (
                <tr key={c.id} className={c.id === choisie ? 'admin-ligne-choisie' : undefined}>
                  <td>
                    <button
                      type="button"
                      className="lien-bouton"
                      aria-label={`Détail de la commande n° ${c.numero}`}
                      onClick={() => setChoisie(c.id)}
                    >
                      {c.numero}
                    </button>
                  </td>
                  <td>
                    {c.restaurant} → {c.client}
                    <div className="texte-doux">{formaterDateHeure(c.creeLe)}</div>
                  </td>
                  <td>{formaterPrix(c.total)}</td>
                  <td>
                    {c.paiement ? `${c.paiement.mode === 'carte' ? 'Carte' : 'Espèces'} · ${libellesPaiement[c.paiement.etat]}` : '—'}
                  </td>
                  <td>
                    <Etat etat={c.etat} libelle={libellesEtat[c.etat]} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {donnees.length === 0 && <p className="texte-doux">Aucune commande ne correspond aux filtres.</p>}
          {selection && <Detail commande={selection} onFermer={() => setChoisie(null)} />}
        </div>
      )}
    </>
  )
}

function Detail({ commande: c, onFermer }: { commande: CommandeAdmin; onFermer: () => void }) {
  return (
    <aside className="carte admin-detail" aria-label={`Commande n° ${c.numero}`}>
      <div className="admin-barre">
        <h2>Commande n° {c.numero}</h2>
        <button type="button" className="lien-bouton" onClick={onFermer}>
          Fermer
        </button>
      </div>
      <p className="texte-doux">
        {c.restaurant} → {c.client} · {formaterDateHeure(c.creeLe)}
        <br />
        {c.adresse}
      </p>
      <ul className="admin-lignes">
        {c.lignes.map((l, i) => (
          <li key={i}>
            <span>
              {l.quantite} × {l.nom}
            </span>
            <span>{formaterPrix(l.quantite * l.prixUnitaire)}</span>
          </li>
        ))}
        <li>
          <span>Livraison</span>
          <span>{formaterPrix(c.fraisLivraison)}</span>
        </li>
        <li className="admin-total">
          <span>Total</span>
          <span>{formaterPrix(c.total)}</span>
        </li>
      </ul>
      {c.remarque && <p className="texte-doux">Remarque : {c.remarque}</p>}
      {c.motifRefus && <p>Motif du refus : {c.motifRefus}</p>}
      <h3>Paiement</h3>
      {c.paiement ? (
        <dl className="admin-details">
          <dt>Mode de paiement</dt>
          <dd>{c.paiement.mode === 'carte' ? 'Carte' : 'Espèces à la livraison'}</dd>
          <dt>État du paiement</dt>
          <dd>{libellesPaiement[c.paiement.etat]}</dd>
          <dt>Montant</dt>
          <dd>{formaterPrix(c.paiement.montant)}</dd>
          <dt>Référence passerelle</dt>
          <dd>{c.paiement.reference ?? '—'}</dd>
          {c.paiement.payeLe && (
            <>
              <dt>Payé le</dt>
              <dd>{formaterDateHeure(c.paiement.payeLe)}</dd>
            </>
          )}
        </dl>
      ) : (
        <p className="texte-doux">Aucun paiement enregistré.</p>
      )}
      <h3>Livraison</h3>
      <p>{c.livreur ? `${c.livreur} (${c.etatCourse})` : c.etatCourse === 'proposee' ? 'Course proposée, sans livreur' : '—'}</p>
    </aside>
  )
}
