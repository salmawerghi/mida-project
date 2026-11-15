import { useCallback, useEffect, useState, type ChangeEvent, type FormEvent } from 'react'

import { messageErreur } from '../auth/erreurs'
import type { Categorie, Compte, EtatRestaurant, ProfilRestaurant } from '../auth/service'
import { useSession } from '../auth/session'
import {
  formaterTelephone,
  telephoneSaisi,
  validerAdresse,
  validerNomRestaurant,
  validerTelephone,
  validerVille,
  villes,
} from '../auth/validation'
import Cadre from '../Cadre'
import { Bouton, Champ, Chargement, MessageErreur, MessageInfo, SaisieTelephone } from '../composants'
import { fermeApresMinuit, nomJour, validerHoraire, type Horaire } from '../profil/horaires'
import { verifierImage } from '../profil/image'

interface Saisie {
  nom: string
  categorieId: string
  telephone: string
  adresse: string
  ville: string
  description: string
}

type ErreursSaisie = Partial<Record<'nom' | 'telephone' | 'adresse' | 'ville', string | null>>

const pastilles: Record<EtatRestaurant, { classe: string; libelle: string }> = {
  actif: { classe: 'pastille-actif', libelle: 'Compte validé' },
  en_attente: { classe: 'pastille-attente', libelle: 'En attente de validation' },
  rejete: { classe: 'pastille-refus', libelle: 'Demande refusée' },
  bloque: { classe: 'pastille-refus', libelle: 'Restaurant suspendu' },
}

/** Profil du restaurant : informations, logo et horaires (US07, maquette « Restaurant · Profil »). */
export default function Profil({ compte }: { compte: Compte }) {
  const { service, rafraichir } = useSession()

  const [profil, setProfil] = useState<ProfilRestaurant | null>(null)
  const [erreurChargement, setErreurChargement] = useState<string | null>(null)
  const [categories, setCategories] = useState<Categorie[]>([])
  const [saisie, setSaisie] = useState<Saisie | null>(null)
  const [horaires, setHoraires] = useState<Horaire[]>([])
  const [horairesEnregistres, setHorairesEnregistres] = useState(true)

  const [erreurs, setErreurs] = useState<ErreursSaisie>({})
  const [erreursHoraires, setErreursHoraires] = useState<Record<number, string>>({})
  const [enCours, setEnCours] = useState(false)
  const [erreur, setErreur] = useState<string | null>(null)
  const [confirmation, setConfirmation] = useState<string | null>(null)

  const [logoEnCours, setLogoEnCours] = useState(false)
  const [erreurLogo, setErreurLogo] = useState<string | null>(null)
  const [confirmationLogo, setConfirmationLogo] = useState<string | null>(null)

  const charger = useCallback(async () => {
    setErreurChargement(null)
    try {
      const [donnees, liste] = await Promise.all([service.profilRestaurant(), service.categories()])
      setProfil(donnees.profil)
      setSaisie({
        nom: donnees.profil.nom,
        categorieId: donnees.profil.categorieId ?? '',
        telephone: telephoneSaisi(donnees.profil.telephone),
        adresse: donnees.profil.adresse,
        ville: donnees.profil.ville,
        description: donnees.profil.description,
      })
      setHoraires(donnees.horaires)
      setHorairesEnregistres(donnees.horairesEnregistres)
      setCategories(liste)
    } catch (e) {
      setErreurChargement(messageErreur(e))
    }
  }, [service])

  useEffect(() => {
    // charger() ne change l'état qu'après les appels réseau à Supabase
    // oxlint-disable-next-line react/set-state-in-effect
    void charger()
  }, [charger])

  if (erreurChargement) {
    return (
      <Cadre compte={compte}>
        <h1>Profil du restaurant</h1>
        <MessageErreur>{erreurChargement}</MessageErreur>
        <div>
          <Bouton onClick={() => void charger()}>Réessayer</Bouton>
        </div>
      </Cadre>
    )
  }
  if (!profil || !saisie) {
    return (
      <Cadre compte={compte}>
        <Chargement />
      </Cadre>
    )
  }

  const changer = (cle: keyof Saisie) => (e: ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    setSaisie({ ...saisie, [cle]: e.target.value })
    setConfirmation(null)
  }

  const changerHoraire = (jour: number, modification: Partial<Horaire>) => {
    setHoraires((liste) => liste.map((h) => (h.jour === jour ? { ...h, ...modification } : h)))
    setErreursHoraires((e) => ({ ...e, [jour]: '' }))
    setConfirmation(null)
  }

  async function enregistrer(e: FormEvent) {
    e.preventDefault()
    if (!profil || !saisie) return
    setErreur(null)
    setConfirmation(null)

    const trouvees: ErreursSaisie = {
      nom: validerNomRestaurant(saisie.nom),
      telephone: validerTelephone(saisie.telephone),
      adresse: validerAdresse(saisie.adresse),
      ville: validerVille(saisie.ville),
    }
    const trouveesHoraires: Record<number, string> = {}
    for (const h of horaires) {
      const message = validerHoraire(h)
      if (message) trouveesHoraires[h.jour] = message
    }
    setErreurs(trouvees)
    setErreursHoraires(trouveesHoraires)
    if (Object.values(trouvees).some(Boolean) || Object.keys(trouveesHoraires).length > 0) {
      setErreur('Corrigez les informations signalées, puis enregistrez de nouveau.')
      return
    }

    setEnCours(true)
    try {
      await service.enregistrerProfil(
        profil.id,
        {
          nom: saisie.nom,
          categorieId: saisie.categorieId || null,
          telephone: formaterTelephone(saisie.telephone),
          adresse: saisie.adresse,
          ville: saisie.ville,
          description: saisie.description,
        },
        horaires,
      )
      setProfil({ ...profil, nom: saisie.nom.trim() })
      setHorairesEnregistres(true)
      setConfirmation(
        profil.etat === 'actif'
          ? 'Modifications enregistrées : elles sont visibles tout de suite par les clients.'
          : 'Modifications enregistrées. Elles seront visibles par les clients dès la validation du restaurant.',
      )
      // le nom du restaurant est aussi affiché ailleurs (tableau de bord, attente)
      void rafraichir()
    } catch (err) {
      setErreur(messageErreur(err))
    } finally {
      setEnCours(false)
    }
  }

  async function choisirLogo(e: ChangeEvent<HTMLInputElement>) {
    const fichier = e.target.files?.[0]
    e.target.value = '' // permet de rechoisir le même fichier après une erreur
    if (!fichier || !profil) return
    setConfirmationLogo(null)
    const refus = verifierImage(fichier)
    setErreurLogo(refus)
    if (refus) return

    setLogoEnCours(true)
    try {
      const url = await service.changerLogo(profil.id, fichier)
      setProfil((p) => (p ? { ...p, logoUrl: url } : p))
      setConfirmationLogo('Logo mis à jour.')
    } catch (err) {
      setErreurLogo(messageErreur(err))
    } finally {
      setLogoEnCours(false)
    }
  }

  const pastille = pastilles[profil.etat]
  // une ville enregistrée hors de la liste (ancienne saisie) reste proposée
  const listeVilles = villes.includes(saisie.ville as (typeof villes)[number]) || !saisie.ville ? villes : [saisie.ville, ...villes]

  return (
    <Cadre compte={compte}>
      <form className="profil" onSubmit={enregistrer} noValidate>
        <div className="barre">
          <h1>Profil du restaurant</h1>
          <Bouton type="submit" enCours={enCours}>
            Enregistrer les modifications
          </Bouton>
        </div>

        {profil.etat !== 'actif' && (
          <p className="message message-note">
            Votre restaurant n'est pas encore visible des clients. Vous pouvez déjà compléter son profil : il sera prêt
            dès la validation par l'équipe Mida.
          </p>
        )}
        {erreur && <MessageErreur>{erreur}</MessageErreur>}
        {confirmation && <MessageInfo>{confirmation}</MessageInfo>}

        <div className="profil-colonnes">
          <section className="carte profil-carte" aria-label="Informations du restaurant">
            <div className="profil-entete">
              <div className="profil-logo">
                {profil.logoUrl ? (
                  <img src={profil.logoUrl} alt={`Logo de ${profil.nom}`} />
                ) : (
                  <span aria-hidden="true">{profil.nom.trim().charAt(0).toUpperCase()}</span>
                )}
              </div>
              <div className="profil-identite">
                <div className="profil-nom">{profil.nom}</div>
                <span className={`pastille ${pastille.classe}`}>{pastille.libelle}</span>
                <label className="lien-fichier" aria-busy={logoEnCours || undefined}>
                  {logoEnCours ? 'Envoi du logo…' : profil.logoUrl ? 'Changer le logo' : 'Ajouter un logo'}
                  <input
                    type="file"
                    className="visuellement-cache"
                    accept="image/jpeg,image/png,image/webp"
                    disabled={logoEnCours}
                    onChange={(e) => void choisirLogo(e)}
                  />
                </label>
              </div>
            </div>
            {erreurLogo && <MessageErreur>{erreurLogo}</MessageErreur>}
            {confirmationLogo && <MessageInfo>{confirmationLogo}</MessageInfo>}

            <Champ
              etiquette="Nom"
              erreur={erreurs.nom}
              enfant={(p) => <input {...p} className="saisie" autoComplete="organization" value={saisie.nom} onChange={changer('nom')} />}
            />
            {categories.length > 0 && (
              <Champ
                etiquette="Catégorie"
                facultatif
                enfant={(p) => (
                  <select {...p} className="saisie" value={saisie.categorieId} onChange={changer('categorieId')}>
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
              etiquette="Adresse"
              erreur={erreurs.adresse}
              enfant={(p) => (
                <input {...p} className="saisie" autoComplete="street-address" value={saisie.adresse} onChange={changer('adresse')} />
              )}
            />
            <Champ
              etiquette="Ville"
              erreur={erreurs.ville}
              enfant={(p) => (
                <select {...p} className="saisie" value={saisie.ville} onChange={changer('ville')}>
                  <option value="">Choisir la ville…</option>
                  {listeVilles.map((v) => (
                    <option key={v} value={v}>
                      {v}
                    </option>
                  ))}
                </select>
              )}
            />
            <Champ
              etiquette="Téléphone"
              erreur={erreurs.telephone}
              enfant={(p) => (
                <SaisieTelephone
                  {...p}
                  value={saisie.telephone}
                  onChange={(e) => {
                    setSaisie({ ...saisie, telephone: e.target.value.replace(/[^\d ]/g, '') })
                    setConfirmation(null)
                  }}
                />
              )}
            />
            <Champ
              etiquette="Description"
              facultatif
              enfant={(p) => (
                <textarea {...p} className="saisie" rows={3} maxLength={500} value={saisie.description} onChange={changer('description')} />
              )}
            />
          </section>

          <section className="carte profil-carte" aria-label="Horaires d'ouverture">
            <h2>Horaires d'ouverture</h2>
            {!horairesEnregistres && (
              <p className="message message-note">
                Vos horaires ne sont pas encore enregistrés. Voici une proposition : ajustez-la, puis enregistrez.
              </p>
            )}
            <p className="texte-doux">Décochez un jour pour indiquer que le restaurant est fermé ce jour-là.</p>
            {horaires.map((h) => {
              const jour = nomJour(h.jour)
              const message = erreursHoraires[h.jour]
              return (
                <div className="horaire" key={h.jour}>
                  <label className="case horaire-jour">
                    <input type="checkbox" checked={!h.ferme} onChange={(e) => changerHoraire(h.jour, { ferme: !e.target.checked })} />
                    {jour}
                    <span className="visuellement-cache"> : ouvert ce jour</span>
                  </label>
                  {h.ferme ? (
                    <span className="pastille pastille-refus">Fermé</span>
                  ) : (
                    <span className="horaire-heures">
                      <input
                        type="time"
                        className="saisie saisie-heure"
                        aria-label={`Ouverture le ${jour.toLowerCase()}`}
                        aria-invalid={message ? true : undefined}
                        value={h.ouverture}
                        onChange={(e) => changerHoraire(h.jour, { ouverture: e.target.value })}
                      />
                      à
                      <input
                        type="time"
                        className="saisie saisie-heure"
                        aria-label={`Fermeture le ${jour.toLowerCase()}`}
                        aria-invalid={message ? true : undefined}
                        value={h.fermeture}
                        onChange={(e) => changerHoraire(h.jour, { fermeture: e.target.value })}
                      />
                      {fermeApresMinuit(h) && <span className="horaire-note">ferme après minuit</span>}
                    </span>
                  )}
                  {message && <span className="erreur-champ">{message}</span>}
                </div>
              )
            })}
          </section>
        </div>
      </form>
    </Cadre>
  )
}
