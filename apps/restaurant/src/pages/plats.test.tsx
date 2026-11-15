import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { beforeAll, describe, expect, it } from 'vitest'

import { Routage } from '../App'
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

beforeAll(() => {
  // jsdom ne sait pas créer d'aperçu d'image
  URL.createObjectURL = () => 'blob:apercu'
  URL.revokeObjectURL = () => {}
})

/** Remplit le formulaire d'un plat (les champs déjà remplis sont effacés). */
async function remplir(u: ReturnType<typeof userEvent.setup>, champs: { nom?: string; description?: string; prix?: string }) {
  for (const [etiquette, valeur] of [
    ['Nom du plat', champs.nom],
    [/Description/, champs.description],
    ['Prix (DT)', champs.prix],
  ] as const) {
    if (valeur === undefined) continue
    const champ = await screen.findByLabelText(etiquette)
    await u.clear(champ)
    if (valeur) await u.type(champ, valeur)
  }
}

describe('plats du menu (US10)', () => {
  it('le menu affiche les plats de chaque catégorie, avec leur prix', async () => {
    ouvrir(new FauxService(valide))
    const couscous = await screen.findByRole('region', { name: 'Couscous' })
    expect(within(couscous).getAllByRole('article').map((a) => a.getAttribute('aria-label'))).toEqual([
      'Couscous à l’agneau',
      'Couscous aux légumes',
      'Couscous au poisson',
    ])
    expect(within(couscous).getByText('22,500 DT')).toBeInTheDocument()
    expect(within(screen.getByRole('region', { name: 'Tajines' })).getByText('Aucun plat dans cette catégorie.')).toBeInTheDocument()
  })

  it('ajoute un plat dans une catégorie, avec sa photo, puis revient au menu', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('link', { name: 'Ajouter un plat dans Tajines' }))
    expect(await screen.findByRole('heading', { name: 'Ajouter un plat' })).toBeInTheDocument()
    expect(screen.getByLabelText('Catégorie')).toHaveValue('c2') // catégorie choisie depuis le menu

    await remplir(u, { nom: 'Tajine malsouka', description: 'Poulet, œufs, fromage, feuilles de malsouka', prix: '14,5' })
    const photo = new File(['x'], 'tajine.png', { type: 'image/png' })
    await u.upload(screen.getByLabelText(/Ajouter une photo/), photo)
    // aperçu côté client mis à jour pendant la saisie
    const apercu = screen.getByRole('region', { name: 'Aperçu côté client' })
    expect(apercu).toHaveTextContent('Tajine malsouka')
    expect(apercu).toHaveTextContent('14,500 DT')

    await u.click(screen.getByRole('button', { name: 'Enregistrer' }))

    expect(await screen.findByText('« Tajine malsouka » est ajouté au menu.')).toBeInTheDocument()
    expect(service.enregistrerPlat).toHaveBeenCalledWith(
      'r1',
      null,
      { nom: 'Tajine malsouka', description: 'Poulet, œufs, fromage, feuilles de malsouka', prix: 14.5, categorieId: 'c2' },
      photo,
    )
    const tajines = screen.getByRole('region', { name: 'Tajines' })
    expect(within(tajines).getByRole('article', { name: 'Tajine malsouka' })).toHaveTextContent('14,500 DT')
  })

  it('prix négatif, nom vide : messages sous les champs, rien n’est envoyé', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service, '/menu/plats/nouveau')

    await remplir(u, { prix: '-16' })
    await u.click(screen.getByRole('button', { name: 'Enregistrer' }))

    expect(screen.getByText('Le prix doit être un nombre positif.')).toBeInTheDocument()
    expect(screen.getByText('Indiquez le nom du plat.')).toBeInTheDocument()
    expect(screen.getByRole('alert')).toHaveTextContent('Corrigez les informations signalées')
    expect(service.enregistrerPlat).not.toHaveBeenCalled()
  })

  it('modifie un plat : formulaire prérempli, changement de catégorie et de prix', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('link', { name: 'Modifier Couscous au poisson' }))
    expect(await screen.findByRole('heading', { name: 'Modifier le plat' })).toBeInTheDocument()
    expect(screen.getByLabelText('Nom du plat')).toHaveValue('Couscous au poisson')
    expect(screen.getByLabelText('Prix (DT)')).toHaveValue('22,500')

    await remplir(u, { prix: '24' })
    await u.selectOptions(screen.getByLabelText('Catégorie'), 'Douceurs et thé')
    await u.click(screen.getByRole('button', { name: 'Enregistrer' }))

    expect(await screen.findByText('« Couscous au poisson » est modifié.')).toBeInTheDocument()
    expect(service.enregistrerPlat).toHaveBeenCalledWith('r1', 'p3', expect.objectContaining({ prix: 24, categorieId: 'c3' }), null)
    expect(within(screen.getByRole('region', { name: 'Douceurs et thé' })).getByText('24,000 DT')).toBeInTheDocument()
  })

  it('photo refusée par le stockage : le plat est enregistré, avec un avertissement', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    service.erreurPhoto = 'Image trop lourde : 5 Mo maximum.'
    ouvrir(service, '/menu/plats/nouveau')

    await remplir(u, { nom: 'Brik à l’œuf', prix: '3' })
    await u.upload(screen.getByLabelText(/Ajouter une photo/), new File(['x'], 'brik.png', { type: 'image/png' }))
    await u.click(screen.getByRole('button', { name: 'Enregistrer' }))

    expect(await screen.findByText('« Brik à l’œuf » est ajouté au menu.')).toBeInTheDocument()
    expect(screen.getByRole('alert')).toHaveTextContent("La photo n'a pas pu être envoyée")
  })

  it('photo d’un format refusé : message, aucun envoi', async () => {
    ouvrir(new FauxService(valide), '/menu/plats/nouveau')
    const pdf = new File(['x'], 'menu.pdf', { type: 'application/pdf' })
    // (userEvent.upload respecte « accept » et ignorerait le fichier : on force le choix)
    fireEvent.change(await screen.findByLabelText(/Ajouter une photo/), { target: { files: [pdf] } })
    expect(await screen.findByRole('alert')).toHaveTextContent('Format non accepté')
  })

  it('supprime un plat après confirmation', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Supprimer Thé à la menthe' }))
    const confirmation = screen.getByRole('alertdialog', { name: 'Supprimer Thé à la menthe ?' })
    await u.click(within(confirmation).getByRole('button', { name: 'Supprimer le plat' }))

    expect(await screen.findByText('« Thé à la menthe » est retiré du menu.')).toBeInTheDocument()
    expect(service.supprimerPlat).toHaveBeenCalledWith('r1', expect.objectContaining({ id: 'p4' }))
    expect(screen.queryByRole('article', { name: 'Thé à la menthe' })).not.toBeInTheDocument()
  })

  it('menu sans catégorie : il faut d’abord en créer une', async () => {
    const service = new FauxService(valide)
    service.menu = []
    ouvrir(service, '/menu/plats/nouveau')
    expect(await screen.findByText(/Créez d'abord une catégorie/)).toBeInTheDocument()
    expect(screen.queryByLabelText('Nom du plat')).not.toBeInTheDocument()
  })

  it('plat introuvable (supprimé entre-temps) : message et retour au menu', async () => {
    ouvrir(new FauxService(valide), '/menu/plats/inconnu')
    expect(await screen.findByRole('alert')).toHaveTextContent("Ce plat n'existe plus")
    expect(screen.getByRole('link', { name: 'Retour au menu' })).toHaveAttribute('href', '/menu')
  })
})
