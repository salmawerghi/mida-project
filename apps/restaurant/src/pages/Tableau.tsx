import type { Compte } from '../auth/service'
import { useSession } from '../auth/session'
import { Bouton, Marque } from '../composants'

/** Tableau de bord provisoire : le vrai arrive avec les stories de gestion des commandes. */
export default function Tableau({ compte }: { compte: Compte }) {
  const { service } = useSession()
  return (
    <main className="page-centree motif-bleu">
      <div className="conteneur">
        <div className="barre">
          <Marque />
          <Bouton variante="blanc" onClick={() => void service.deconnecter()}>
            Se déconnecter
          </Bouton>
        </div>
        <section className="carte attente-texte">
          <span className="pastille pastille-actif">Restaurant validé</span>
          <h1>Bienvenue, {compte.restaurant?.nom}</h1>
          <p className="texte-doux">
            Connecté en tant que {compte.nom} ({compte.email}). Les commandes, le menu et les statistiques arrivent ici
            avec les prochaines versions.
          </p>
        </section>
      </div>
    </main>
  )
}
