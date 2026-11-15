import { useCallback, useEffect, useState, type FormEvent, type ReactNode } from 'react'

import { messageErreur } from '../auth/erreurs'
import type { Compte } from '../auth/service'
import { useSession } from '../auth/session'
import Cadre from '../Cadre'
import { Bouton, Chargement, MessageErreur, MessageInfo } from '../composants'
import {
  deplacer,
  libellePlats,
  longueurMaxNomCategorie,
  ordreSuivant,
  resumeMenu,
  validerNomCategorie,
  type CategorieMenu,
} from '../menu/categories'

/** Action en cours sur une catégorie : une seule à la fois. */
type Action = { type: 'creation' } | { type: 'renommage'; id: string } | { type: 'suppression'; id: string } | null

/**
 * Menu du restaurant (maquette « Restaurant · Menu »). Pour l'instant :
 * les catégories (US09). Les plats arrivent avec US10.
 */
export default function Menu({ compte }: { compte: Compte }) {
  const { service } = useSession()
  const restaurant = compte.restaurant!

  const [categories, setCategories] = useState<CategorieMenu[] | null>(null)
  const [erreurChargement, setErreurChargement] = useState<string | null>(null)
  const [action, setAction] = useState<Action>(null)
  const [nom, setNom] = useState('')
  const [erreurNom, setErreurNom] = useState<string | null>(null)
  const [enCours, setEnCours] = useState(false)
  const [erreur, setErreur] = useState<string | null>(null)
  const [confirmation, setConfirmation] = useState<string | null>(null)

  const charger = useCallback(async () => {
    setErreurChargement(null)
    try {
      setCategories(await service.categoriesMenu(restaurant.id))
    } catch (e) {
      setErreurChargement(messageErreur(e))
    }
  }, [service, restaurant.id])

  useEffect(() => {
    // charger() ne change l'état qu'après l'appel réseau à Supabase
    // oxlint-disable-next-line react/set-state-in-effect
    void charger()
  }, [charger])

  if (erreurChargement) {
    return (
      <Cadre compte={compte}>
        <h1>Votre menu</h1>
        <MessageErreur>{erreurChargement}</MessageErreur>
        <div>
          <Bouton onClick={() => void charger()}>Réessayer</Bouton>
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

  function ouvrir(suivante: Action, nomInitial = '') {
    setAction(suivante)
    setNom(nomInitial)
    setErreurNom(null)
    setErreur(null)
    setConfirmation(null)
  }

  /** Exécute une modification, puis relit le menu ; garde le formulaire ouvert en cas d'erreur. */
  async function executer(modification: () => Promise<void>, message: string) {
    setEnCours(true)
    setErreur(null)
    try {
      await modification()
      setAction(null)
      setConfirmation(message)
      await charger()
    } catch (e) {
      setErreur(messageErreur(e))
    } finally {
      setEnCours(false)
    }
  }

  function enregistrerNom(e: FormEvent) {
    e.preventDefault()
    if (!categories || !action || action.type === 'suppression') return
    const renommee = action.type === 'renommage' ? action.id : undefined
    const refus = validerNomCategorie(nom, categories, renommee)
    setErreurNom(refus)
    if (refus) return
    const propre = nom.trim()
    if (renommee) {
      void executer(() => service.renommerCategorieMenu(renommee, propre), `Catégorie renommée en « ${propre} ».`)
    } else {
      void executer(
        () => service.creerCategorieMenu(restaurant.id, propre, ordreSuivant(categories)),
        `Catégorie « ${propre} » ajoutée à la fin du menu.`,
      )
    }
  }

  function bouger(categorie: CategorieMenu, sens: -1 | 1) {
    if (!categories) return
    const liste = deplacer(categories, categorie.id, sens)
    if (liste === categories) return
    setAction(null)
    setCategories(liste) // affiché tout de suite, confirmé par la relecture
    void executer(
      () => service.ordonnerCategoriesMenu(restaurant.id, liste),
      `« ${categorie.nom} » est maintenant en position ${liste.findIndex((c) => c.id === categorie.id) + 1}.`,
    )
  }

  function supprimer(categorie: CategorieMenu) {
    void executer(
      () => service.supprimerCategorieMenu(categorie.id),
      categorie.nbPlats > 0
        ? `Catégorie « ${categorie.nom} » supprimée, avec ses ${libellePlats(categorie.nbPlats)}.`
        : `Catégorie « ${categorie.nom} » supprimée.`,
    )
  }

  const formulaireNom = (etiquette: string, libelleBouton: string) => (
    <form className="menu-formulaire" onSubmit={enregistrerNom} noValidate>
      <div className="champ">
        <label htmlFor="nom-categorie">{etiquette}</label>
        <input
          id="nom-categorie"
          className="saisie"
          autoFocus
          maxLength={longueurMaxNomCategorie}
          placeholder="Entrées, Couscous, Douceurs…"
          aria-invalid={erreurNom ? true : undefined}
          aria-describedby={erreurNom ? 'nom-categorie-erreur' : undefined}
          value={nom}
          onChange={(e) => {
            setNom(e.target.value)
            setErreurNom(null)
          }}
        />
        {erreurNom && (
          <span id="nom-categorie-erreur" className="erreur-champ">
            {erreurNom}
          </span>
        )}
      </div>
      <div className="actions">
        <Bouton type="button" variante="blanc" className="bouton-petit" disabled={enCours} onClick={() => ouvrir(null)}>
          Annuler
        </Bouton>
        <Bouton type="submit" className="bouton-petit" enCours={enCours}>
          {libelleBouton}
        </Bouton>
      </div>
    </form>
  )

  return (
    <Cadre compte={compte}>
      <div className="barre">
        <div>
          <h1>Votre menu</h1>
          <p className="texte-doux">{resumeMenu(categories)}</p>
        </div>
        <Bouton onClick={() => ouvrir({ type: 'creation' })} disabled={enCours || action?.type === 'creation'}>
          Nouvelle catégorie
        </Bouton>
      </div>

      {erreur && <MessageErreur>{erreur}</MessageErreur>}
      {confirmation && <MessageInfo>{confirmation}</MessageInfo>}

      {action?.type === 'creation' && (
        <section className="carte menu-carte" aria-label="Nouvelle catégorie">
          {formulaireNom('Nom de la nouvelle catégorie', 'Ajouter la catégorie')}
        </section>
      )}

      <section className="carte menu-carte" aria-label="Catégories du menu">
        <h2>Catégories</h2>
        {categories.length === 0 ? (
          <p className="texte-doux">
            Aucune catégorie pour l'instant. Créez les rubriques de votre carte (Entrées, Couscous, Douceurs…) : vous y
            rangerez ensuite vos plats.
          </p>
        ) : (
          <>
            <p className="texte-doux">Les clients voient les catégories dans cet ordre.</p>
            <ol className="menu-liste">
              {categories.map((c, i) => (
                <li key={c.id} className="menu-ligne">
                  {action?.type === 'renommage' && action.id === c.id ? (
                    formulaireNom(`Nouveau nom de « ${c.nom} »`, 'Enregistrer le nom')
                  ) : (
                    <div className="menu-categorie">
                      <span className="menu-rang" aria-hidden="true">
                        {i + 1}
                      </span>
                      <span className="menu-nom">
                        {c.nom}
                        <span className="menu-plats">{libellePlats(c.nbPlats)}</span>
                      </span>
                      <span className="menu-boutons">
                        <BoutonIcone libelle={`Monter ${c.nom}`} disabled={enCours || i === 0} onClick={() => bouger(c, -1)}>
                          <path d="M12 19V5M5 12l7-7 7 7" />
                        </BoutonIcone>
                        <BoutonIcone
                          libelle={`Descendre ${c.nom}`}
                          disabled={enCours || i === categories.length - 1}
                          onClick={() => bouger(c, 1)}
                        >
                          <path d="M12 5v14M5 12l7 7 7-7" />
                        </BoutonIcone>
                        <BoutonIcone
                          libelle={`Renommer ${c.nom}`}
                          disabled={enCours}
                          onClick={() => ouvrir({ type: 'renommage', id: c.id }, c.nom)}
                        >
                          <path d="M4 20h4L19 9l-4-4L4 16z" />
                          <path d="M13 7l4 4" />
                        </BoutonIcone>
                        <BoutonIcone
                          libelle={`Supprimer ${c.nom}`}
                          danger
                          disabled={enCours}
                          onClick={() => ouvrir({ type: 'suppression', id: c.id })}
                        >
                          <path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3" />
                        </BoutonIcone>
                      </span>
                    </div>
                  )}
                  {action?.type === 'suppression' && action.id === c.id && (
                    <div className="menu-confirmation" role="alertdialog" aria-label={`Supprimer ${c.nom} ?`}>
                      <p>
                        {c.nbPlats > 0 ? (
                          <>
                            <strong>
                              « {c.nom} » contient {libellePlats(c.nbPlats)}.
                            </strong>{' '}
                            Si vous supprimez cette catégorie, {c.nbPlats === 1 ? 'ce plat sera supprimé' : 'ces plats seront supprimés'}{' '}
                            du menu en même temps. Cette action est définitive.
                          </>
                        ) : (
                          <>Supprimer la catégorie « {c.nom} » ? Elle ne contient aucun plat.</>
                        )}
                      </p>
                      <div className="actions">
                        <Bouton type="button" variante="blanc" className="bouton-petit" disabled={enCours} onClick={() => ouvrir(null)}>
                          Annuler
                        </Bouton>
                        <Bouton type="button" variante="harissa" className="bouton-petit" enCours={enCours} onClick={() => supprimer(c)}>
                          {c.nbPlats > 0 ? `Supprimer la catégorie et ses ${libellePlats(c.nbPlats)}` : 'Supprimer la catégorie'}
                        </Bouton>
                      </div>
                    </div>
                  )}
                </li>
              ))}
            </ol>
          </>
        )}
      </section>

      <p className="message message-note">
        L'ajout des plats (nom, prix, photo) arrive avec la prochaine version de l'espace restaurant.
      </p>
    </Cadre>
  )
}

function BoutonIcone({
  libelle,
  danger = false,
  disabled,
  onClick,
  children,
}: {
  libelle: string
  danger?: boolean
  disabled?: boolean
  onClick: () => void
  children: ReactNode
}) {
  return (
    <button
      type="button"
      className={danger ? 'bouton-icone bouton-icone-danger' : 'bouton-icone'}
      aria-label={libelle}
      title={libelle}
      disabled={disabled}
      onClick={onClick}
    >
      <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        {children}
      </svg>
    </button>
  )
}
