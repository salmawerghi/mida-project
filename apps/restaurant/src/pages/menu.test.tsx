import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'

import { Routage } from '../App'
import { ErreurMida } from '../auth/erreurs'
import type { Compte } from '../auth/service'
import { FournisseurSession } from '../auth/session'
import { FauxService } from '../test/faux-service'

function ouvrir(service: FauxService, chemin = '/menu') {
  render(
    <FournisseurSession service={service}>
      <MemoryRouter initialEntries={[chemin]}>
        <Routage />
      </MemoryRouter>
    </FournisseurSession>,
  )
}

const valide: Compte = {
  email: 'contact@darzitouna.tn',
  nom: 'Mehdi Ben Salem',
  restaurant: { id: 'r1', nom: 'Dar Zitouna', ville: 'Tunis', etat: 'actif', motif_rejet: null, ouvert: true },
}

/** Noms des catégories, dans l'ordre affiché. */
const nomsAffiches = () =>
  within(screen.getByRole('list'))
    .getAllByRole('listitem')
    .map((li) => li.querySelector('.menu-nom')?.firstChild?.textContent)

describe('menu : catégories (US09)', () => {
  it('affiche les catégories dans l’ordre, avec leur nombre de plats', async () => {
    ouvrir(new FauxService(valide))
    expect(await screen.findByRole('heading', { name: 'Votre menu' })).toBeInTheDocument()
    expect(nomsAffiches()).toEqual(['Couscous', 'Tajines', 'Douceurs et thé'])
    expect(screen.getByText('3 catégories · 4 plats')).toBeInTheDocument()
    expect(screen.getByText('aucun plat')).toBeInTheDocument()
    // la première ne monte pas, la dernière ne descend pas
    expect(screen.getByRole('button', { name: 'Monter Couscous' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Descendre Douceurs et thé' })).toBeDisabled()
  })

  it('crée une catégorie à la fin du menu', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Nouvelle catégorie' }))
    await u.type(screen.getByLabelText('Nom de la nouvelle catégorie'), '  Entrées et briks ')
    await u.click(screen.getByRole('button', { name: 'Ajouter la catégorie' }))

    expect(await screen.findByRole('status')).toHaveTextContent('Catégorie « Entrées et briks » ajoutée')
    expect(service.creerCategorieMenu).toHaveBeenCalledWith('r1', 'Entrées et briks', 4)
    expect(nomsAffiches()).toEqual(['Couscous', 'Tajines', 'Douceurs et thé', 'Entrées et briks'])
    expect(screen.queryByLabelText('Nom de la nouvelle catégorie')).not.toBeInTheDocument()
  })

  it('nom vide ou déjà pris : message, rien n’est envoyé', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Nouvelle catégorie' }))
    await u.click(screen.getByRole('button', { name: 'Ajouter la catégorie' }))
    expect(screen.getByText('Indiquez le nom de la catégorie.')).toBeInTheDocument()

    await u.type(screen.getByLabelText('Nom de la nouvelle catégorie'), 'tajines')
    await u.click(screen.getByRole('button', { name: 'Ajouter la catégorie' }))
    expect(screen.getByText('Une catégorie porte déjà ce nom.')).toBeInTheDocument()
    expect(service.creerCategorieMenu).not.toHaveBeenCalled()
  })

  it('renomme une catégorie', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Renommer Tajines' }))
    const champ = screen.getByLabelText('Nouveau nom de « Tajines »')
    expect(champ).toHaveValue('Tajines')
    await u.clear(champ)
    await u.type(champ, 'Tajines et ojjas')
    await u.click(screen.getByRole('button', { name: 'Enregistrer le nom' }))

    expect(await screen.findByRole('status')).toHaveTextContent('Catégorie renommée en « Tajines et ojjas »')
    expect(service.renommerCategorieMenu).toHaveBeenCalledWith('c2', 'Tajines et ojjas')
    expect(nomsAffiches()).toEqual(['Couscous', 'Tajines et ojjas', 'Douceurs et thé'])
  })

  it('change l’ordre d’affichage', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Monter Douceurs et thé' }))

    expect(await screen.findByRole('status')).toHaveTextContent('« Douceurs et thé » est maintenant en position 2')
    expect(service.ordonnerCategoriesMenu.mock.calls[0][1].map((c) => c.id)).toEqual(['c1', 'c3', 'c2'])
    expect(nomsAffiches()).toEqual(['Couscous', 'Douceurs et thé', 'Tajines'])
  })

  it('catégorie vide : supprimée après une simple confirmation', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Supprimer Tajines' }))
    const confirmation = screen.getByRole('alertdialog', { name: 'Supprimer Tajines ?' })
    expect(confirmation).toHaveTextContent('Elle ne contient aucun plat.')
    await u.click(within(confirmation).getByRole('button', { name: 'Supprimer la catégorie' }))

    expect(await screen.findByRole('status')).toHaveTextContent('Catégorie « Tajines » supprimée.')
    expect(service.supprimerCategorieMenu).toHaveBeenCalledWith('c2')
    expect(nomsAffiches()).toEqual(['Couscous', 'Douceurs et thé'])
  })

  it('catégorie avec des plats : la confirmation annonce les plats supprimés ; « Annuler » ne supprime rien', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Supprimer Couscous' }))
    const confirmation = screen.getByRole('alertdialog', { name: 'Supprimer Couscous ?' })
    expect(confirmation).toHaveTextContent('« Couscous » contient 3 plats.')
    expect(confirmation).toHaveTextContent('ces plats seront supprimés')
    await u.click(within(confirmation).getByRole('button', { name: 'Annuler' }))
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument()
    expect(service.supprimerCategorieMenu).not.toHaveBeenCalled()

    await u.click(screen.getByRole('button', { name: 'Supprimer Couscous' }))
    await u.click(screen.getByRole('button', { name: 'Supprimer la catégorie et ses 3 plats' }))
    expect(await screen.findByRole('status')).toHaveTextContent('supprimée, avec ses 3 plats')
    expect(service.supprimerCategorieMenu).toHaveBeenCalledWith('c1')
  })

  it('refus de la base : message, le formulaire reste ouvert avec la saisie', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    service.erreurMenu = new ErreurMida('Une catégorie porte déjà ce nom.')
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Nouvelle catégorie' }))
    await u.type(screen.getByLabelText('Nom de la nouvelle catégorie'), 'Boissons')
    await u.click(screen.getByRole('button', { name: 'Ajouter la catégorie' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('Une catégorie porte déjà ce nom.')
    expect(screen.getByLabelText('Nom de la nouvelle catégorie')).toHaveValue('Boissons')
  })

  it('menu vide : explication', async () => {
    const service = new FauxService(valide)
    service.menu = []
    ouvrir(service)
    expect(await screen.findByText(/Aucune catégorie pour l'instant/)).toBeInTheDocument()
    expect(screen.getByText('0 catégories · aucun plat')).toBeInTheDocument()
  })

  it('restaurant en attente : le menu se prépare déjà, depuis la page d’attente', async () => {
    const u = userEvent.setup()
    const enAttente = { ...valide, restaurant: { ...valide.restaurant!, etat: 'en_attente' as const, ouvert: false } }
    ouvrir(new FauxService(enAttente), '/attente')
    await u.click(await screen.findByRole('link', { name: 'Menu' }))
    expect(await screen.findByRole('heading', { name: 'Votre menu' })).toBeInTheDocument()
  })

  it('responsable sans restaurant : renvoyé à l’inscription', async () => {
    ouvrir(new FauxService({ ...valide, restaurant: null }))
    expect(await screen.findByRole('heading', { name: 'Présentez votre restaurant' })).toBeInTheDocument()
  })
})
