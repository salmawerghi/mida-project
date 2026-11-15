import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'

import { Routage } from './App'
import type { Compte } from './auth/service'
import { FournisseurSession } from './auth/session'
import { FauxService } from './test/faux-service'

function ouvrir(chemin: string, service: FauxService) {
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
  restaurant: { id: 'r1', nom: 'Dar Zitouna', ville: 'Tunis', etat: 'actif', motif_rejet: null, ouvert: false },
}

describe('interrupteur ouvert / fermé (US08)', () => {
  it('restaurant validé et fermé : un clic l’ouvre', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir('/tableau', service)

    const interrupteur = await screen.findByRole('switch', { name: 'Restaurant fermé' })
    expect(interrupteur).toHaveAttribute('aria-checked', 'false')
    expect(screen.getByText('Les clients ne peuvent pas commander.')).toBeInTheDocument()
    expect(screen.getByText(/Votre restaurant est/)).toHaveTextContent('fermé')

    await u.click(interrupteur)

    expect(await screen.findByRole('switch', { name: 'Restaurant ouvert' })).toHaveAttribute('aria-checked', 'true')
    expect(service.changerOuverture).toHaveBeenCalledWith('r1', true)
    expect(screen.getByText('Les clients peuvent commander.')).toBeInTheDocument()
    expect(screen.queryByText(/Votre restaurant est/)).not.toBeInTheDocument() // rappel du tableau de bord retiré
  })

  it('restaurant ouvert : un clic le ferme, depuis n’importe quelle page', async () => {
    const u = userEvent.setup()
    const service = new FauxService({ ...valide, restaurant: { ...valide.restaurant!, ouvert: true } })
    ouvrir('/profil', service)

    await u.click(await screen.findByRole('switch', { name: 'Restaurant ouvert' }))

    expect(await screen.findByRole('switch', { name: 'Restaurant fermé' })).toBeEnabled()
    expect(service.changerOuverture).toHaveBeenCalledWith('r1', false)
  })

  it('refus de la base : l’interrupteur revient à sa position, avec le message', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    service.erreurOuverture = { code: '42501', message: 'Un restaurant doit être validé par Mida avant de pouvoir ouvrir' }
    ouvrir('/tableau', service)

    await u.click(await screen.findByRole('switch', { name: 'Restaurant fermé' }))

    expect(await screen.findByRole('alert')).toHaveTextContent('doit être validé')
    expect(screen.getByRole('switch', { name: 'Restaurant fermé' })).toHaveAttribute('aria-checked', 'false')
  })

  it('restaurant en attente : pas d’interrupteur', async () => {
    const service = new FauxService({ ...valide, restaurant: { ...valide.restaurant!, etat: 'en_attente' } })
    service.profil = { ...service.profil, etat: 'en_attente' }
    ouvrir('/profil', service)

    expect(await screen.findByText(/Vous pourrez ouvrir le restaurant une fois qu'il sera validé/)).toBeInTheDocument()
    expect(screen.queryByRole('switch')).not.toBeInTheDocument()
  })
})
