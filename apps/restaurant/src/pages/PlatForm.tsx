import { useCallback, useEffect, useState, type ChangeEvent, type FormEvent } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router'

import { messageErreur } from '../auth/erreurs'
import type { Compte } from '../auth/service'
import { useSession } from '../auth/session'
import Cadre from '../Cadre'
import { Bouton, Champ, Chargement, MessageErreur } from '../composants'
import type { CategorieMenu } from '../menu/categories'
import {
  formaterPrix,
  lirePrix,
  longueurMaxDescription,
  longueurMaxNomPlat,
  prixSaisi,
  validerCategoriePlat,
  validerNomPlat,
  validerPrix,
  type Plat,
} from '../menu/plats'
import { verifierImage } from '../profil/image'

/** Message transmis à la page « Menu » après l'enregistrement. */
export interface RetourMenu {
  message: string
  avertissement?: string
}

type Erreurs = Partial<Record<'nom' | 'prix' | 'categorie' | 'photo', string | null>>

/**
 * Ajouter (`/menu/plats/nouveau?categorie=…`) ou modifier (`/menu/plats/:id`)
 * un plat (US10, maquette « Restaurant · Plat »).
 */
export default function PlatForm({ compte }: { compte: Compte }) {
  const { service } = useSession()
  const restaurant = compte.restaurant!
  const { id } = useParams()
  const [parametres] = useSearchParams()
  const naviguer = useNavigate()

  const [categories, setCategories] = useState<CategorieMenu[] | null>(null)
  const [plat, setPlat] = useState<Plat | null>(null)
  const [erreurChargement, setErreurChargement] = useState<string | null>(null)

  const [nom, setNom] = useState('')
  const [description, setDescription] = useState('')
  const [prix, setPrix] = useState('')
  const [categorieId, setCategorieId] = useState('')
  const [photo, setPhoto] = useState<File | null>(null)
  const [apercu, setApercu] = useState<string | null>(null)

  const [erreurs, setErreurs] = useState<Erreurs>({})
  const [enCours, setEnCours] = useState(false)
  const [erreur, setErreur] = useState<string | null>(null)

  const charger = useCallback(async () => {
    setErreurChargement(null)
    try {
      const [liste, plats] = await Promise.all([service.categoriesMenu(restaurant.id), id ? service.platsMenu(restaurant.id) : []])
      const trouve = id ? plats.find((p) => p.id === id) : undefined
      if (id && !trouve) {
        setErreurChargement("Ce plat n'existe plus. Il a peut-être été supprimé.")
        return
      }
      setCategories(liste)
      if (trouve) {
        setPlat(trouve)
        setNom(trouve.nom)
        setDescription(trouve.description)
        setPrix(prixSaisi(trouve.prix))
        setCategorieId(trouve.categorieId)
      } else {
        const demandee = parametres.get('categorie')
        setCategorieId(liste.some((c) => c.id === demandee) ? demandee! : (liste[0]?.id ?? ''))
      }
    } catch (e) {
      setErreurChargement(messageErreur(e))
    }
  }, [service, restaurant.id, id, parametres])

  useEffect(() => {
    // charger() ne change l'état qu'après les appels réseau à Supabase
    // oxlint-disable-next-line react/set-state-in-effect
    void charger()
  }, [charger])

  // Libère l'aperçu local de la photo quand il change ou quand on quitte la page.
  useEffect(() => () => (apercu ? URL.revokeObjectURL(apercu) : undefined), [apercu])

  const titre = id ? 'Modifier le plat' : 'Ajouter un plat'

  if (erreurChargement) {
    return (
      <Cadre compte={compte}>
        <h1>{titre}</h1>
        <MessageErreur>{erreurChargement}</MessageErreur>
        <div>
          <Link to="/menu" className="bouton bouton-blanc">
            Retour au menu
          </Link>
        </div>
      </Cadre>
    )
  }
  if (!categories) {
    return (
      <Cadre compte={compte}>
        <Chargement />
      </Cadre>
    )
  }
  if (categories.length === 0) {
    return (
      <Cadre compte={compte}>
        <h1>{titre}</h1>
        <p className="message message-note">
          Créez d'abord une catégorie (Entrées, Couscous, Douceurs…) : chaque plat est rangé dans une catégorie du menu.
        </p>
        <div>
          <Link to="/menu" className="bouton bouton-bleu">
            Créer une catégorie
          </Link>
        </div>
      </Cadre>
    )
  }

  function choisirPhoto(e: ChangeEvent<HTMLInputElement>) {
    const fichier = e.target.files?.[0]
    e.target.value = '' // permet de rechoisir le même fichier après une erreur
    if (!fichier) return
    const refus = verifierImage(fichier)
    setErreurs((er) => ({ ...er, photo: refus }))
    if (refus) return
    setPhoto(fichier)
    setApercu(URL.createObjectURL(fichier))
  }

  async function enregistrer(e: FormEvent) {
    e.preventDefault()
    setErreur(null)
    const trouvees: Erreurs = {
      nom: validerNomPlat(nom),
      prix: validerPrix(prix),
      categorie: validerCategoriePlat(categorieId),
      photo: erreurs.photo,
    }
    setErreurs(trouvees)
    if (trouvees.nom || trouvees.prix || trouvees.categorie) {
      setErreur('Corrigez les informations signalées, puis enregistrez de nouveau.')
      return
    }

    setEnCours(true)
    try {
      const resultat = await service.enregistrerPlat(
        restaurant.id,
        id ?? null,
        { nom, description, prix: lirePrix(prix)!, categorieId },
        photo,
      )
      const retour: RetourMenu = {
        message: id ? `« ${resultat.plat.nom} » est modifié.` : `« ${resultat.plat.nom} » est ajouté au menu.`,
        avertissement: resultat.erreurPhoto
          ? `La photo n'a pas pu être envoyée (${resultat.erreurPhoto}) Modifiez le plat pour réessayer.`
          : undefined,
      }
      void naviguer('/menu', { state: retour })
    } catch (err) {
      setErreur(messageErreur(err))
      setEnCours(false)
    }
  }

  const prixApercu = lirePrix(prix)
  const imageApercu = apercu ?? plat?.imageUrl ?? null
  const nomCategorie = categories.find((c) => c.id === categorieId)?.nom

  return (
    <Cadre compte={compte}>
      <div className="plat-entete">
        <Link to="/menu" className="bouton-icone" aria-label="Retour au menu" title="Retour au menu">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M15 18l-6-6 6-6" />
          </svg>
        </Link>
        <div>
          <nav aria-label="Fil d'Ariane" className="texte-doux">
            <Link to="/menu">Menu</Link>
            {nomCategorie && ` / ${nomCategorie}`}
          </nav>
          <h1>{titre}</h1>
        </div>
      </div>

      {erreur && <MessageErreur>{erreur}</MessageErreur>}

      <form className="plat-formulaire" onSubmit={enregistrer} noValidate>
        <section className="carte profil-carte" aria-label="Informations du plat">
          <Champ
            etiquette="Nom du plat"
            erreur={erreurs.nom}
            enfant={(p) => (
              <input
                {...p}
                className="saisie"
                maxLength={longueurMaxNomPlat}
                placeholder="Couscous au poulet et raisins secs"
                value={nom}
                onChange={(e) => {
                  setNom(e.target.value)
                  setErreurs((er) => ({ ...er, nom: null }))
                }}
              />
            )}
          />
          <Champ
            etiquette="Description"
            facultatif
            enfant={(p) => (
              <>
                <textarea
                  {...p}
                  className="saisie"
                  rows={3}
                  maxLength={longueurMaxDescription}
                  placeholder="Poulet fermier, oignons caramélisés, raisins secs et cannelle."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
                <span className="compteur">
                  {description.length} / {longueurMaxDescription} caractères
                </span>
              </>
            )}
          />
          <div className="grille-champs plat-ligne">
            <Champ
              etiquette="Prix (DT)"
              erreur={erreurs.prix}
              enfant={(p) => (
                <input
                  {...p}
                  className="saisie"
                  inputMode="decimal"
                  placeholder="16,500"
                  value={prix}
                  onChange={(e) => {
                    setPrix(e.target.value)
                    setErreurs((er) => ({ ...er, prix: null }))
                  }}
                />
              )}
            />
            <Champ
              etiquette="Catégorie"
              erreur={erreurs.categorie}
              enfant={(p) => (
                <select {...p} className="saisie" value={categorieId} onChange={(e) => setCategorieId(e.target.value)}>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.nom}
                    </option>
                  ))}
                </select>
              )}
            />
          </div>
        </section>

        <div className="plat-colonne">
          <section className="carte profil-carte" aria-label="Photo du plat">
            <label className="plat-photo">
              {imageApercu ? (
                <img src={imageApercu} alt="Aperçu de la photo du plat" />
              ) : (
                <span className="plat-photo-vide" aria-hidden="true">
                  <svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="3" y="5" width="18" height="14" rx="3" />
                    <circle cx="9" cy="10" r="2" />
                    <path d="M21 16l-5-5-9 8" />
                  </svg>
                </span>
              )}
              <span className="lien-fichier">{imageApercu ? 'Changer la photo' : 'Ajouter une photo'}</span>
              <span className="compteur">JPEG, PNG ou WebP, 5 Mo maximum. Fond clair conseillé.</span>
              <input type="file" className="visuellement-cache" accept="image/jpeg,image/png,image/webp" onChange={choisirPhoto} />
            </label>
            {erreurs.photo && <MessageErreur>{erreurs.photo}</MessageErreur>}
          </section>

          <section className="carte profil-carte" aria-label="Aperçu côté client">
            <div className="champ-etiquette">Aperçu côté client</div>
            <div className="plat-apercu">
              <div className="plat-vignette">{imageApercu && <img src={imageApercu} alt="" />}</div>
              <div>
                <div className="plat-nom">{nom.trim() || 'Nom du plat'}</div>
                <div className="plat-prix">{prixApercu !== null && prixApercu > 0 ? formaterPrix(prixApercu) : '— DT'}</div>
              </div>
            </div>
          </section>

          <div className="actions">
            <Link to="/menu" className="bouton bouton-blanc">
              Annuler
            </Link>
            <Bouton type="submit" enCours={enCours}>
              Enregistrer
            </Bouton>
          </div>
        </div>
      </form>
    </Cadre>
  )
}
