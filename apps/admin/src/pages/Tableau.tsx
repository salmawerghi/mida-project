import { Link } from 'react-router'

import { Chargement, MessageErreur } from '../composants'
import { formaterPrix } from '../service'
import { useDonnees, useSession } from '../session'

/** Maquette « Admin · Vue d'ensemble » : chiffres clés et demandes à traiter. */
export default function Tableau() {
  const { service } = useSession()
  const { donnees: r, erreur } = useDonnees(() => service.resume())
  if (erreur) return <MessageErreur>{erreur}</MessageErreur>
  if (!r) return <Chargement />
  const tauxRefus = r.commandes7j ? Math.round((r.refusees7j / r.commandes7j) * 1000) / 10 : 0
  return (
    <>
      <p className="texte-doux">Toute la plateforme · 7 derniers jours</p>
      <div className="admin-chiffres">
        <Chiffre titre="Commandes aujourd'hui" valeur={String(r.commandesAujourdhui)} detail={`${r.commandesEnCours} en cours`} />
        <Chiffre titre="Chiffre d'affaires (7 j)" valeur={formaterPrix(r.chiffreAffaires7j)} detail="commandes livrées" />
        <Chiffre
          titre="Utilisateurs"
          valeur={String(r.clients)}
          detail={`clients · ${r.restaurantsActifs} restaurants · ${r.livreursActifs} livreurs`}
        />
        <Chiffre
          titre="Taux de refus (7 j)"
          valeur={`${String(tauxRefus).replace('.', ',')} %`}
          detail={`${r.refusees7j} commande${r.refusees7j > 1 ? 's' : ''} refusée${r.refusees7j > 1 ? 's' : ''}`}
        />
      </div>
      <section className="carte admin-a-traiter" aria-labelledby="a-traiter">
        <h2 id="a-traiter">À traiter</h2>
        <ul>
          <li>
            <Link to="/restaurants">
              {r.restaurantsEnAttente} restaurant{r.restaurantsEnAttente > 1 ? 's' : ''} à valider
            </Link>
          </li>
          <li>
            <Link to="/livreurs">
              {r.livreursEnAttente} livreur{r.livreursEnAttente > 1 ? 's' : ''} à valider
            </Link>
          </li>
          <li>
            <Link to="/reclamations">
              {r.reclamationsOuvertes} réclamation{r.reclamationsOuvertes > 1 ? 's' : ''} à traiter
            </Link>
          </li>
          <li>
            <Link to="/commandes">
              {r.commandesEnCours} commande{r.commandesEnCours > 1 ? 's' : ''} en cours
            </Link>
          </li>
        </ul>
      </section>
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
