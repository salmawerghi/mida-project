import { useState, type FormEvent } from 'react'
import { Link, Navigate, useLocation, useNavigate } from 'react-router'

import mida from '../assets/illustrations/mida.svg'
import { messageErreur } from '../auth/erreurs'
import { pageDuCompte } from '../auth/service'
import { useSession } from '../auth/session'
import { validerEmail, validerMotDePasseConnexion } from '../auth/validation'
import { Bouton, Champ, Chargement, Logo, MessageErreur, MessageInfo, SaisieMotDePasse } from '../composants'

/** Maquette « Restaurant · Connexion ». */
export default function Connexion() {
  const { etat, service, rafraichir } = useSession()
  const navigate = useNavigate()
  const information = (useLocation().state as { information?: string } | null)?.information

  const [email, setEmail] = useState('')
  const [motDePasse, setMotDePasse] = useState('')
  const [resterConnecte, setResterConnecte] = useState(true)
  const [erreurs, setErreurs] = useState<{ email?: string | null; motDePasse?: string | null }>({})
  const [erreur, setErreur] = useState<string | null>(null)
  const [enCours, setEnCours] = useState(false)

  if (etat.statut === 'chargement') return <Chargement />
  if (etat.statut === 'connecte' && !enCours) return <Navigate to={pageDuCompte(etat.compte)} replace />

  // compte refusé à l'ouverture de session (rôle, compte ou restaurant bloqué)
  const messageSession = etat.statut === 'deconnecte' ? etat.message : undefined

  async function envoyer(e: FormEvent) {
    e.preventDefault()
    const nouvelles = { email: validerEmail(email), motDePasse: validerMotDePasseConnexion(motDePasse) }
    setErreurs(nouvelles)
    setErreur(null)
    if (nouvelles.email || nouvelles.motDePasse) return

    setEnCours(true)
    try {
      await service.connecter(email, motDePasse, resterConnecte)
      const suivant = await rafraichir()
      if (suivant.statut === 'connecte') navigate(pageDuCompte(suivant.compte), { replace: true })
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
            <div className="marque-sous">Espace restaurant</div>
          </div>
        </div>
        <div className="connexion-accroche">
          <div lang="ar" dir="rtl" className="arabe" style={{ textAlign: 'left' }}>
            مرحبا بيك في مطبخك
          </div>
          <h1>Vos commandes, votre menu, au même endroit</h1>
          <p>Recevez les commandes en temps réel, gérez votre menu et suivez vos ventes jour après jour.</p>
        </div>
        <img src={mida} alt="Une mida garnie de plats tunisiens" width={520} height={390} />
      </section>

      <section className="connexion-formulaire">
        <form className="carte" onSubmit={envoyer} noValidate>
          <h2>Connexion</h2>
          {information && <MessageInfo>{information}</MessageInfo>}
          {messageSession && !erreur && <MessageErreur>{messageSession}</MessageErreur>}
          <Champ
            etiquette="E-mail professionnel"
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
          <label className="case">
            <input type="checkbox" checked={resterConnecte} onChange={(e) => setResterConnecte(e.target.checked)} />
            Rester connecté
          </label>
          {erreur && <MessageErreur>{erreur}</MessageErreur>}
          <Bouton type="submit" plein enCours={enCours}>
            Se connecter
          </Bouton>
          <p className="texte-doux" style={{ textAlign: 'center' }}>
            Votre restaurant n'est pas encore sur Mida ? <Link to="/inscription">Inscrire mon restaurant</Link>
          </p>
        </form>
      </section>
    </main>
  )
}
