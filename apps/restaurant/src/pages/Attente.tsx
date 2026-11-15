import { Link } from 'react-router'

import tajine from '../assets/illustrations/tajine.svg'
import type { Compte } from '../auth/service'
import { useSession } from '../auth/session'
import { Bouton } from '../composants'

/** Étape 3 de l'inscription (maquette « Restaurant · Attente »), ou demande refusée. */
export default function Attente({ compte }: { compte: Compte }) {
  const { service } = useSession()
  const restaurant = compte.restaurant!
  const refuse = restaurant.etat === 'rejete'

  return (
    <main className="attente motif-bleu">
      <div className="carte">
        <div className="arche">
          <img src={tajine} alt="" width={200} height={200} />
        </div>
        <div className="attente-texte">
          {refuse ? (
            <>
              <span className="pastille pastille-refus">Demande refusée</span>
              <h1>Votre demande n'a pas été retenue</h1>
              <p>
                L'équipe Mida n'a pas validé l'inscription de <strong>{restaurant.nom}</strong>.
              </p>
              {restaurant.motif_rejet && (
                <p className="message message-note">
                  <strong>Motif :</strong> {restaurant.motif_rejet}
                </p>
              )}
              <p>Pour corriger vos informations ou en savoir plus, contactez le support Mida.</p>
            </>
          ) : (
            <>
              <span className="pastille pastille-attente">En attente de validation</span>
              <h1>Demande envoyée, le tajine mijote</h1>
              <p>
                L'équipe Mida examine les informations de <strong>{restaurant.nom}</strong>. Vous recevrez un e-mail à{' '}
                {compte.email} dès la validation, en général sous 48 heures.
              </p>
              <p className="message message-note">
                Votre restaurant restera invisible des clients jusqu'à la validation. En attendant, ajoutez votre logo
                et vos horaires dans le profil du restaurant, et préparez votre menu.
              </p>
            </>
          )}
          <div className="actions" style={{ justifyContent: 'flex-start', marginTop: 6 }}>
            <Link to="/profil" className="bouton bouton-bleu">
              Profil du restaurant
            </Link>
            <Link to="/menu" className="bouton bouton-blanc">
              Menu
            </Link>
            <Bouton variante="blanc" onClick={() => void service.deconnecter()}>
              Se déconnecter
            </Bouton>
          </div>
        </div>
      </div>
    </main>
  )
}
