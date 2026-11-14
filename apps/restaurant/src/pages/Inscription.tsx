import { useEffect, useRef, useState, type FormEvent } from 'react'
import { Link, Navigate, useNavigate } from 'react-router'

import tajine from '../assets/illustrations/tajine.svg'
import { lireBrouillon } from '../auth/brouillon'
import { messageErreur } from '../auth/erreurs'
import { pageDuCompte, type Categorie, type InfosRestaurant } from '../auth/service'
import { useSession } from '../auth/session'
import {
  formaterTelephone,
  validerAdresse,
  validerEmail,
  validerMotDePasseInscription,
  validerNom,
  validerNomRestaurant,
  validerTelephone,
  validerVille,
  villes,
} from '../auth/validation'
import { Bouton, Champ, Chargement, Marque, MessageErreur, SaisieMotDePasse, SaisieTelephone } from '../composants'

type Erreurs = Record<string, string | null>

/** Étapes 1 (responsable) et 2 (restaurant) ; l'étape 3 est la page « En attente ». */
export default function Inscription() {
  const { etat, service, rafraichir } = useSession()
  const navigate = useNavigate()

  const [etape, setEtape] = useState<1 | 2>(1)
  // étape 1
  const [nom, setNom] = useState('')
  const [email, setEmail] = useState('')
  const [telephone, setTelephone] = useState('')
  const [motDePasse, setMotDePasse] = useState('')
  // étape 2
  const [resto, setResto] = useState({ nom: '', categorieId: '', telephone: '', adresse: '', ville: '', description: '' })
  const [categories, setCategories] = useState<Categorie[]>([])

  const [erreurs, setErreurs] = useState<Erreurs>({})
  const [erreur, setErreur] = useState<string | null>(null)
  const [enCours, setEnCours] = useState(false)
  const titre = useRef<HTMLHeadingElement>(null)

  const connecte = etat.statut === 'connecte'
  // Responsable déjà connecté sans restaurant (inscription interrompue,
  // ou e-mail confirmé entre-temps) : on reprend directement à l'étape 2.
  const etapeAffichee = connecte ? 2 : etape

  useEffect(() => {
    service.categories().then(setCategories, () => setCategories([]))
  }, [service])

  // Préremplit l'étape 2 avec le brouillon gardé avant la confirmation
  // d'e-mail, une seule fois par compte (mise à jour pendant le rendu).
  const emailCompte = etat.statut === 'connecte' ? etat.compte.email : null
  const [emailBrouillonLu, setEmailBrouillonLu] = useState<string | null>(null)
  if (emailCompte && emailCompte !== emailBrouillonLu) {
    setEmailBrouillonLu(emailCompte)
    const b = lireBrouillon(emailCompte)
    if (b) setResto({ ...b, categorieId: b.categorieId ?? '', telephone: b.telephone.replace(/^\+216\s*/, '') })
  }

  useEffect(() => {
    titre.current?.focus()
  }, [etapeAffichee])

  if (etat.statut === 'chargement') return <Chargement />
  if (etat.statut === 'connecte' && etat.compte.restaurant) {
    return <Navigate to={pageDuCompte(etat.compte)} replace />
  }

  function validerEtape1(): boolean {
    const e: Erreurs = {
      nom: validerNom(nom),
      email: validerEmail(email),
      telephone: validerTelephone(telephone),
      motDePasse: validerMotDePasseInscription(motDePasse),
    }
    setErreurs(e)
    return Object.values(e).every((v) => !v)
  }

  function validerEtape2(): boolean {
    const e: Erreurs = {
      restoNom: validerNomRestaurant(resto.nom),
      restoTelephone: validerTelephone(resto.telephone),
      restoAdresse: validerAdresse(resto.adresse),
      restoVille: validerVille(resto.ville),
    }
    setErreurs(e)
    return Object.values(e).every((v) => !v)
  }

  function continuer(e: FormEvent) {
    e.preventDefault()
    setErreur(null)
    if (validerEtape1()) setEtape(2)
  }

  async function envoyer(e: FormEvent) {
    e.preventDefault()
    setErreur(null)
    if (!validerEtape2()) return

    const restaurant: InfosRestaurant = {
      nom: resto.nom,
      categorieId: resto.categorieId || null,
      telephone: formaterTelephone(resto.telephone),
      adresse: resto.adresse,
      ville: resto.ville,
      description: resto.description,
    }
    setEnCours(true)
    try {
      if (connecte) {
        await service.creerRestaurant(restaurant)
      } else {
        const resultat = await service.inscrire(
          { nom, email, telephone: formaterTelephone(telephone), motDePasse },
          restaurant,
        )
        if (resultat === 'confirmationEmail') {
          navigate('/connexion', {
            state: {
              information:
                `Compte créé ! Nous avons envoyé un lien de confirmation à ${email.trim()}. ` +
                'Ouvrez-le, puis connectez-vous : votre restaurant sera enregistré à ce moment-là.',
            },
          })
          return
        }
      }
      const suivant = await rafraichir()
      navigate(suivant.statut === 'connecte' ? pageDuCompte(suivant.compte) : '/connexion', { replace: true })
    } catch (err) {
      setErreur(messageErreur(err))
    } finally {
      setEnCours(false)
    }
  }

  const changerResto = (champ: keyof typeof resto) => (e: { target: { value: string } }) =>
    setResto((r) => ({ ...r, [champ]: e.target.value }))

  return (
    <main className="page-centree motif-bleu">
      <div className="conteneur">
        <div className="barre">
          <Marque />
          {connecte ? (
            <button type="button" className="bouton bouton-blanc" onClick={() => void service.deconnecter()}>
              Se déconnecter
            </button>
          ) : (
            <Link to="/connexion">J'ai déjà un compte</Link>
          )}
        </div>

        <ol className="etapes" aria-label="Étapes de l'inscription">
          <Etape numero={1} libelle="Responsable" courante={etapeAffichee === 1} faite={etapeAffichee > 1} />
          <Etape numero={2} libelle="Restaurant" courante={etapeAffichee === 2} faite={false} />
          <Etape numero={3} libelle="Validation" courante={false} faite={false} />
        </ol>

        {etapeAffichee === 1 ? (
          <form className="carte inscription" onSubmit={continuer} noValidate>
            <div className="inscription-intro">
              <h1 ref={titre} tabIndex={-1}>
                Créez votre compte responsable
              </h1>
              <p className="texte-doux">
                Vous vous connecterez avec cet e-mail pour recevoir les commandes et gérer votre menu.
              </p>
              <img src={tajine} alt="" width={220} height={220} />
            </div>
            <div className="grille-champs">
              <Champ
                className="pleine-largeur"
                etiquette="Nom et prénom"
                erreur={erreurs.nom}
                enfant={(p) => (
                  <input {...p} className="saisie" autoComplete="name" value={nom} onChange={(e) => setNom(e.target.value)} />
                )}
              />
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
                etiquette="Téléphone"
                erreur={erreurs.telephone}
                enfant={(p) => (
                  <SaisieTelephone
                    {...p}
                    autoComplete="tel-national"
                    placeholder="22 145 870"
                    value={telephone}
                    onChange={(e) => setTelephone(e.target.value.replace(/[^\d ]/g, ''))}
                  />
                )}
              />
              <Champ
                className="pleine-largeur"
                etiquette="Mot de passe"
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
              <div className="actions pleine-largeur">
                <Bouton type="submit">Continuer</Bouton>
              </div>
            </div>
          </form>
        ) : (
          <form className="carte inscription" onSubmit={envoyer} noValidate>
            <div className="inscription-intro">
              <h1 ref={titre} tabIndex={-1}>
                Présentez votre restaurant
              </h1>
              <p className="texte-doux">
                Ces informations seront visibles par les clients après validation par l'équipe Mida.
              </p>
              <div className="logo-a-venir">
                <strong>Logo et photo de couverture</strong>
                Vous pourrez les ajouter depuis votre profil, une fois la demande envoyée.
              </div>
            </div>
            <div className="grille-champs">
              <Champ
                className="pleine-largeur"
                etiquette="Nom du restaurant"
                erreur={erreurs.restoNom}
                enfant={(p) => (
                  <input {...p} className="saisie" autoComplete="organization" value={resto.nom} onChange={changerResto('nom')} />
                )}
              />
              {categories.length > 0 && (
                <Champ
                  etiquette="Catégorie"
                  facultatif
                  enfant={(p) => (
                    <select {...p} className="saisie" value={resto.categorieId} onChange={changerResto('categorieId')}>
                      <option value="">Choisir…</option>
                      {categories.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.nom}
                        </option>
                      ))}
                    </select>
                  )}
                />
              )}
              <Champ
                className={categories.length > 0 ? undefined : 'pleine-largeur'}
                etiquette="Téléphone du restaurant"
                erreur={erreurs.restoTelephone}
                enfant={(p) => (
                  <SaisieTelephone
                    {...p}
                    value={resto.telephone}
                    onChange={(e) => setResto((r) => ({ ...r, telephone: e.target.value.replace(/[^\d ]/g, '') }))}
                  />
                )}
              />
              <Champ
                className="pleine-largeur"
                etiquette="Adresse"
                erreur={erreurs.restoAdresse}
                enfant={(p) => (
                  <input
                    {...p}
                    className="saisie"
                    autoComplete="street-address"
                    placeholder="34, avenue Habib Bourguiba, La Marsa"
                    value={resto.adresse}
                    onChange={changerResto('adresse')}
                  />
                )}
              />
              <Champ
                className="pleine-largeur"
                etiquette="Ville"
                erreur={erreurs.restoVille}
                enfant={(p) => (
                  <select {...p} className="saisie" value={resto.ville} onChange={changerResto('ville')}>
                    <option value="">Choisir la ville…</option>
                    {villes.map((v) => (
                      <option key={v} value={v}>
                        {v}
                      </option>
                    ))}
                  </select>
                )}
              />
              <Champ
                className="pleine-largeur"
                etiquette="Description"
                facultatif
                enfant={(p) => (
                  <textarea
                    {...p}
                    className="saisie"
                    rows={3}
                    maxLength={500}
                    placeholder="Cuisine familiale de la médina : couscous du vendredi, tajines et briks préparés chaque matin."
                    value={resto.description}
                    onChange={changerResto('description')}
                  />
                )}
              />
              {erreur && (
                <div className="pleine-largeur">
                  <MessageErreur>{erreur}</MessageErreur>
                </div>
              )}
              <div className="actions pleine-largeur">
                {!connecte && (
                  <Bouton type="button" variante="blanc" onClick={() => setEtape(1)} disabled={enCours}>
                    Étape précédente
                  </Bouton>
                )}
                <Bouton type="submit" variante="harissa" enCours={enCours}>
                  Envoyer la demande
                </Bouton>
              </div>
            </div>
          </form>
        )}
      </div>
    </main>
  )
}

function Etape({ numero, libelle, courante, faite }: { numero: number; libelle: string; courante: boolean; faite: boolean }) {
  const classe = ['etape', courante ? 'etape-courante' : '', faite ? 'etape-faite' : ''].join(' ')
  return (
    <li className={classe} aria-current={courante ? 'step' : undefined}>
      <span className="etape-numero">
        {faite ? (
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#FFFFFF" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M5 12.5l4.5 4.5L19 7.5" />
          </svg>
        ) : (
          numero
        )}
      </span>
      <span>
        {libelle}
        {faite && <span className="visuellement-cache"> (terminée)</span>}
      </span>
    </li>
  )
}
