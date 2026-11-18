import { useEffect, useState, type FormEvent } from 'react'

import { messageErreur } from '../auth/erreurs'
import { Bouton, Chargement, MessageErreur, MessageInfo } from '../composants'
import { lireMontant, type CategorieAdmin } from '../service'
import { useDonnees, useSession } from '../session'

/** Maquette « Admin · Paramètres » : frais, commission, gain du livreur et catégories (US37). */
export default function Parametres() {
  return (
    <div className="admin-parametres">
      <Frais />
      <Categories />
    </div>
  )
}

function Frais() {
  const { service } = useSession()
  const { donnees, erreur } = useDonnees(() => service.parametres())
  const [saisie, setSaisie] = useState({ frais: '', commission: '', gain: '' })
  const [erreurs, setErreurs] = useState<Record<string, string>>({})
  const [message, setMessage] = useState<string | null>(null)
  const [erreurEnvoi, setErreurEnvoi] = useState<string | null>(null)
  const [enCours, setEnCours] = useState(false)

  useEffect(() => {
    if (!donnees) return
    const t = (n: number, d: number) => n.toFixed(d).replace('.', ',')
    // oxlint-disable-next-line react/set-state-in-effect -- formulaire rempli une fois les valeurs lues
    setSaisie({ frais: t(donnees.fraisLivraison, 3), commission: t(donnees.commissionPct, 2), gain: t(donnees.gainLivreur, 3) })
  }, [donnees])

  if (erreur) return <MessageErreur>{erreur}</MessageErreur>
  if (!donnees) return <Chargement />

  async function enregistrer(e: FormEvent) {
    e.preventDefault()
    setMessage(null)
    setErreurEnvoi(null)
    const frais = lireMontant(saisie.frais)
    const commission = lireMontant(saisie.commission)
    const gain = lireMontant(saisie.gain)
    const nouvelles: Record<string, string> = {}
    if (frais === null || frais > 50) nouvelles.frais = 'Montant en dinars, entre 0 et 50 (ex. 2,500).'
    if (commission === null || commission > 100) nouvelles.commission = 'Pourcentage entre 0 et 100.'
    if (gain === null || gain > 50) nouvelles.gain = 'Montant en dinars, entre 0 et 50.'
    setErreurs(nouvelles)
    if (Object.keys(nouvelles).length) return
    setEnCours(true)
    try {
      await service.enregistrerParametres({ fraisLivraison: frais!, commissionPct: commission!, gainLivreur: gain! })
      setMessage('Paramètres enregistrés. Ils s\'appliquent aux commandes suivantes, jamais aux commandes en cours.')
    } catch (err) {
      setErreurEnvoi(messageErreur(err))
    } finally {
      setEnCours(false)
    }
  }

  const champ = (cle: 'frais' | 'commission' | 'gain', etiquette: string) => (
    <div className="champ">
      <label htmlFor={`p-${cle}`}>{etiquette}</label>
      <input
        id={`p-${cle}`}
        className="saisie"
        inputMode="decimal"
        value={saisie[cle]}
        aria-invalid={erreurs[cle] ? true : undefined}
        onChange={(e) => setSaisie({ ...saisie, [cle]: e.target.value })}
      />
      {erreurs[cle] && <span className="erreur-champ">{erreurs[cle]}</span>}
    </div>
  )

  return (
    <form className="carte" onSubmit={enregistrer} noValidate aria-labelledby="frais-titre">
      <h2 id="frais-titre">Frais et commission</h2>
      {champ('frais', 'Frais de livraison (DT)')}
      {champ('commission', 'Commission de la plateforme (%)')}
      {champ('gain', 'Gain du livreur par course (DT)')}
      {message && <MessageInfo>{message}</MessageInfo>}
      {erreurEnvoi && <MessageErreur>{erreurEnvoi}</MessageErreur>}
      <Bouton type="submit" enCours={enCours}>
        Enregistrer
      </Bouton>
    </form>
  )
}

function Categories() {
  const { service } = useSession()
  const { donnees, erreur, recharger } = useDonnees(() => service.categories())
  const [nom, setNom] = useState('')
  const [erreurAction, setErreurAction] = useState<string | null>(null)
  const [enCours, setEnCours] = useState(false)

  async function agir(action: () => Promise<void>) {
    setErreurAction(null)
    setEnCours(true)
    try {
      await action()
      await recharger()
    } catch (e) {
      setErreurAction(messageErreur(e))
    } finally {
      setEnCours(false)
    }
  }

  async function ajouter(e: FormEvent) {
    e.preventDefault()
    if (!nom.trim()) {
      setErreurAction('Indiquez le nom de la catégorie.')
      return
    }
    const ordre = Math.max(0, ...(donnees ?? []).map((c) => c.ordre)) + 1
    await agir(async () => {
      await service.ajouterCategorie(nom, ordre)
      setNom('')
    })
  }

  return (
    <section className="carte" aria-labelledby="categories-titre">
      <h2 id="categories-titre">Catégories de restaurants</h2>
      <p className="texte-doux">Elles servent au filtre du catalogue dans l'appli client.</p>
      <form className="admin-ajout" onSubmit={ajouter} noValidate>
        <input
          className="saisie"
          aria-label="Nouvelle catégorie"
          placeholder="Nouvelle catégorie"
          value={nom}
          onChange={(e) => setNom(e.target.value)}
        />
        <Bouton type="submit" disabled={enCours}>
          Ajouter
        </Bouton>
      </form>
      {erreurAction && <MessageErreur>{erreurAction}</MessageErreur>}
      {erreur && <MessageErreur>{erreur}</MessageErreur>}
      {!donnees ? (
        <Chargement />
      ) : (
        <ul className="admin-categories">
          {donnees.map((c) => (
            <LigneCategorie key={c.id} categorie={c} agir={agir} />
          ))}
        </ul>
      )}
    </section>
  )
}

function LigneCategorie({
  categorie: c,
  agir,
}: {
  categorie: CategorieAdmin
  agir: (action: () => Promise<void>) => Promise<void>
}) {
  const { service } = useSession()
  const [edition, setEdition] = useState<string | null>(null)
  const [suppression, setSuppression] = useState(false)
  return (
    <li className="admin-categorie">
      {edition === null ? (
        <span>
          <strong>{c.nom}</strong>{' '}
          <span className="texte-doux">
            {c.nbRestaurants} restaurant{c.nbRestaurants > 1 ? 's' : ''}
          </span>
        </span>
      ) : (
        <input
          className="saisie"
          aria-label={`Nouveau nom de ${c.nom}`}
          value={edition}
          onChange={(e) => setEdition(e.target.value)}
        />
      )}
      <span className="admin-categorie-actions">
        {edition === null ? (
          <button type="button" className="lien-bouton" aria-label={`Renommer ${c.nom}`} onClick={() => setEdition(c.nom)}>
            Renommer
          </button>
        ) : (
          <>
            <button
              type="button"
              className="lien-bouton"
              onClick={() =>
                void agir(async () => {
                  await service.renommerCategorie(c.id, edition)
                  setEdition(null)
                })
              }
            >
              Enregistrer
            </button>
            <button type="button" className="lien-bouton" onClick={() => setEdition(null)}>
              Annuler
            </button>
          </>
        )}
        {suppression ? (
          <>
            <span>
              Supprimer ?{c.nbRestaurants > 0 ? ` (${c.nbRestaurants} restaurant(s) n'auront plus de catégorie)` : ''}
            </span>
            <button
              type="button"
              className="lien-bouton lien-danger"
              onClick={() => void agir(() => service.supprimerCategorie(c.id))}
            >
              Oui, supprimer
            </button>
            <button type="button" className="lien-bouton" onClick={() => setSuppression(false)}>
              Non
            </button>
          </>
        ) : (
          <button
            type="button"
            className="lien-bouton lien-danger"
            aria-label={`Supprimer ${c.nom}`}
            onClick={() => setSuppression(true)}
          >
            Supprimer
          </button>
        )}
      </span>
    </li>
  )
}
