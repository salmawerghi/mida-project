import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router'

import mida from '../assets/illustrations/mida.svg'
import { messageErreur } from '../auth/erreurs'
import { Bouton, Champ, Chargement, Logo, MessageErreur, SaisieMotDePasse } from '../composants'
import { useSession } from '../session'

/** Maquette « Admin · Connexion » : accès réservé aux administrateurs (US32). */
export default function Connexion() {
  const { etat, service, rafraichir } = useSession()
  const navigate = useNavigate()
  const depuis = (useLocation().state as { depuis?: string } | null)?.depuis ?? '/tableau'
  const [email, setEmail] = useState('')
  const [motDePasse, setMotDePasse] = useState('')
  const [erreurs, setErreurs] = useState<{ email?: string; motDePasse?: string }>({})
  const [erreur, setErreur] = useState<string | null>(null)
  const [enCours, setEnCours] = useState(false)

  if (etat.statut === 'chargement') return <Chargement />
  if (etat.statut === 'connecte' && !enCours) return <Navigate to={depuis} replace />
  const messageSession = etat.statut === 'deconnecte' ? etat.message : undefined

  async function envoyer(e: FormEvent) {
    e.preventDefault()
    const nouvelles = {
      email: email.trim() ? undefined : 'Indiquez votre adresse e-mail.',
      motDePasse: motDePasse ? undefined : 'Indiquez votre mot de passe.',
    }
    setErreurs(nouvelles)
    setErreur(null)
    if (nouvelles.email || nouvelles.motDePasse) return
    setEnCours(true)
    try {
      await service.connecter(email, motDePasse)
      const suivant = await rafraichir()
      if (suivant.statut === 'connecte') navigate(depuis, { replace: true })
      else setErreur((suivant.statut === 'deconnecte' && suivant.message) || 'Connexion impossible. Réessayez.')
    } catch (err) {
      setErreur(messageErreur(err))
    } finally {
      setEnCours(false)
    }
  }

  return (
    <main className="connexion">
      <section className="connexion-vitrine motif-blanc" aria-label="Présentation">
        <div className="marque">
          <Logo taille={48} inverse />
          <div>
            <div className="marque-nom" style={{ fontSize: 32 }}>
              Mida
            </div>
            <div className="marque-sous">Administration de la plateforme</div>
          </div>
        </div>
        <div className="connexion-accroche">
          <h1>Restaurants, livreurs, commandes : toute la plateforme</h1>
          <p>Validez les inscriptions, suivez l'activité et réglez les paramètres de Mida.</p>
        </div>
        <img src={mida} alt="Une mida garnie de plats tunisiens" width={520} height={390} />
      </section>

      <section className="connexion-formulaire">
        <form className="carte" onSubmit={envoyer} noValidate>
          <h2>Accès administrateur</h2>
          {messageSession && !erreur && <MessageErreur>{messageSession}</MessageErreur>}
          <Champ
            etiquette="E-mail"
            erreur={erreurs.email}
            enfant={(p) => (
              <input
                {...p}
                className="saisie"
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            )}
          />
          <Champ
            etiquette="Mot de passe"
            erreur={erreurs.motDePasse}
            enfant={(p) => (
              <SaisieMotDePasse
                {...p}
                autoComplete="current-password"
                value={motDePasse}
                onChange={(e) => setMotDePasse(e.target.value)}
              />
            )}
          />
          {erreur && <MessageErreur>{erreur}</MessageErreur>}
          <Bouton type="submit" plein enCours={enCours}>
            Se connecter
          </Bouton>
          <p className="texte-doux" style={{ textAlign: 'center' }}>
            Accès réservé à l'équipe Mida.
          </p>
        </form>
      </section>
    </main>
  )
}
