import { useState, type FormEvent } from 'react'
import { Link, useNavigate } from 'react-router'

import { messageErreur } from '../auth/erreurs'
import { useSession } from '../auth/session'
import { validerEmail, validerMotDePasseInscription } from '../auth/validation'
import { Bouton, Champ, MessageErreur, MessageInfo, Marque, SaisieMotDePasse } from '../composants'

/**
 * Mot de passe oublié (US06, espace restaurant) : 1) e-mail → un code à
 * 6 chiffres est envoyé ; 2) code + nouveau mot de passe → session ouverte,
 * retour à l'espace restaurant. Même parcours que l'appli client.
 */
export default function MotDePasseOublie() {
  const { service } = useSession()
  const navigate = useNavigate()
  const [etape, setEtape] = useState<'email' | 'code'>('email')
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [motDePasse, setMotDePasse] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [erreurs, setErreurs] = useState<{ email?: string | null; code?: string | null; motDePasse?: string | null; confirmation?: string | null }>({})
  const [erreur, setErreur] = useState<string | null>(null)
  const [info, setInfo] = useState<string | null>(null)
  const [enCours, setEnCours] = useState(false)
  /** Un code ne sert qu'une fois : après sa vérification, on ne le renvoie plus. */
  const [codeVerifie, setCodeVerifie] = useState(false)

  async function envoyerCode(e?: FormEvent) {
    e?.preventDefault()
    const erreurEmail = validerEmail(email)
    setErreurs({ email: erreurEmail })
    if (erreurEmail) return
    setEnCours(true)
    setErreur(null)
    try {
      await service.demanderReinitialisation(email)
      setEtape('code')
      setCodeVerifie(false)
      setInfo(`Si un compte existe pour ${email.trim()}, un code à 6 chiffres vient d'y être envoyé. Pensez aux courriers indésirables.`)
    } catch (err) {
      setErreur(messageErreur(err))
    } finally {
      setEnCours(false)
    }
  }

  async function changer(e: FormEvent) {
    e.preventDefault()
    const nouvelles = {
      code: codeVerifie || /^\d{6}$/.test(code.replace(/\s/g, '')) ? null : 'Saisissez les 6 chiffres reçus par e-mail.',
      motDePasse: validerMotDePasseInscription(motDePasse),
      confirmation: confirmation === motDePasse ? null : 'Les deux mots de passe ne sont pas identiques.',
    }
    setErreurs(nouvelles)
    if (nouvelles.code || nouvelles.motDePasse || nouvelles.confirmation) return
    setEnCours(true)
    setErreur(null)
    try {
      if (!codeVerifie) {
        await service.verifierCodeReinitialisation(email, code)
        setCodeVerifie(true)
      }
      await service.changerMotDePasse(motDePasse)
      navigate('/', { replace: true })
    } catch (err) {
      setErreur(messageErreur(err))
    } finally {
      setEnCours(false)
    }
  }

  return (
    <main className="page-centree">
      <div className="conteneur" style={{ maxWidth: 480 }}>
        <Marque />
        {etape === 'email' ? (
          <form className="carte" onSubmit={(e) => void envoyerCode(e)} noValidate>
            <h1>Mot de passe oublié</h1>
            <p className="texte-doux">Indiquez l'e-mail de votre compte : nous vous envoyons un code pour choisir un nouveau mot de passe.</p>
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
            {erreur && <MessageErreur>{erreur}</MessageErreur>}
            <Bouton type="submit" plein enCours={enCours}>
              Recevoir un code
            </Bouton>
            <p className="texte-doux" style={{ textAlign: 'center' }}>
              <Link to="/connexion">Retour à la connexion</Link>
            </p>
          </form>
        ) : (
          <form className="carte" onSubmit={(e) => void changer(e)} noValidate>
            <h1>Nouveau mot de passe</h1>
            {info && <MessageInfo>{info}</MessageInfo>}
            {!codeVerifie && (
              <Champ
                etiquette="Code reçu par e-mail"
                erreur={erreurs.code}
                enfant={(p) => (
                  <input
                    {...p}
                    className="saisie"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    maxLength={7}
                    value={code}
                    onChange={(e) => setCode(e.target.value)}
                  />
                )}
              />
            )}
            <Champ
              etiquette="Nouveau mot de passe"
              erreur={erreurs.motDePasse}
              enfant={(p) => (
                <SaisieMotDePasse
                  {...p}
                  autoComplete="new-password"
                  value={motDePasse}
                  onChange={(e) => setMotDePasse(e.target.value)}
                />
              )}
            />
            <Champ
              etiquette="Confirmer le mot de passe"
              erreur={erreurs.confirmation}
              enfant={(p) => (
                <SaisieMotDePasse
                  {...p}
                  autoComplete="new-password"
                  value={confirmation}
                  onChange={(e) => setConfirmation(e.target.value)}
                />
              )}
            />
            {erreur && <MessageErreur>{erreur}</MessageErreur>}
            <Bouton type="submit" plein enCours={enCours}>
              Changer le mot de passe
            </Bouton>
            <p className="texte-doux" style={{ textAlign: 'center' }}>
              Pas reçu de code ?{' '}
              <button type="button" className="lien-bouton" disabled={enCours} onClick={() => void envoyerCode()}>
                Renvoyer le code
              </button>
            </p>
          </form>
        )}
      </div>
    </main>
  )
}
