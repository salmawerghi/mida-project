import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'

import { Routage } from './App'
import { bornesJour, correspond, formaterPrix, lireMontant, refusCompte } from './service'
import { FournisseurSession } from './session'
import { FauxService } from './test/faux-service'

function ouvrir(chemin: string, service = new FauxService()) {
  render(
    <FournisseurSession service={service}>
      <MemoryRouter initialEntries={[chemin]}>
        <Routage />
      </MemoryRouter>
    </FournisseurSession>,
  )
  return { service, user: userEvent.setup() }
}

describe('outils', () => {
  it('montants, recherche et dates', () => {
    expect(formaterPrix(1234.5)).toBe('1 234,500 DT')
    expect(lireMontant('2,5')).toBe(2.5)
    expect(lireMontant('2.500')).toBe(2.5)
    expect(lireMontant('-1')).toBeNull()
    expect(lireMontant('abc')).toBeNull()
    expect(correspond('Lella Béya Sidi Bou Saïd', 'beya said')).toBe(true)
    expect(correspond('Dar Zitouna', 'kanoun')).toBe(false)
    const [debut, fin] = bornesJour('2026-11-18')
    expect(new Date(fin).getTime() - new Date(debut).getTime()).toBe(24 * 3600 * 1000)
  })
})

describe('connexion réservée aux administrateurs (US32)', () => {
  it('un compte non administrateur est refusé', async () => {
    expect(refusCompte('client', 'actif')).toMatch(/pas le rôle administrateur/)
    expect(refusCompte('admin', 'actif')).toBeNull()
    const service = new FauxService()
    service.compte = null
    service.roleConnexion = 'responsable'
    const { user } = ouvrir('/tableau', service)
    expect(await screen.findByRole('heading', { name: 'Accès administrateur' })).toBeInTheDocument()
    await user.type(screen.getByLabelText('E-mail'), 'zitouna@mida.test')
    await user.type(screen.getByLabelText('Mot de passe'), 'Mida2026!')
    await user.click(screen.getByRole('button', { name: 'Se connecter' }))
    expect(await screen.findByText(/pas le rôle administrateur/)).toBeInTheDocument()
  })

  it('un administrateur entre et retrouve la page demandée', async () => {
    const service = new FauxService()
    service.compte = null
    const { user } = ouvrir('/clients', service)
    await user.type(await screen.findByLabelText('E-mail'), 'admin@mida.test')
    await user.type(screen.getByLabelText('Mot de passe'), 'Mida2026!')
    await user.click(screen.getByRole('button', { name: 'Se connecter' }))
    expect(await screen.findByRole('heading', { name: 'Clients', level: 1 })).toBeInTheDocument()
  })

  it('vue d\'ensemble : chiffres et demandes à traiter', async () => {
    ouvrir('/tableau')
    expect(await screen.findByText('1 234,500 DT')).toBeInTheDocument()
    expect(screen.getByText('5 %')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: '1 restaurant à valider' })).toHaveAttribute('href', '/restaurants')
    expect(screen.getByRole('link', { name: '1 livreur à valider' })).toBeInTheDocument()
  })
})

describe('restaurants (US33)', () => {
  it('liste des demandes en attente, puis validation', async () => {
    const { service, user } = ouvrir('/restaurants')
    await user.click(await screen.findByRole('link', { name: /Examiner la demande de Lella Béya/ }))
    expect(await screen.findByRole('heading', { name: 'Lella Béya' })).toBeInTheDocument()
    expect(screen.getByText('lellabeya@mida.test')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Valider le restaurant' }))
    await waitFor(() => expect(service.deciderRestaurant).toHaveBeenCalledWith('r4', true, undefined))
    expect(await screen.findByText('Aucune demande à examiner.')).toBeInTheDocument()
  })

  it('rejet : motif obligatoire', async () => {
    const { service, user } = ouvrir('/restaurants/r4')
    await user.click(await screen.findByRole('button', { name: 'Rejeter la demande' }))
    expect(screen.getByText(/Indiquez le motif du rejet/)).toBeInTheDocument()
    expect(service.deciderRestaurant).not.toHaveBeenCalled()
    await user.type(screen.getByLabelText('Motif en cas de rejet'), 'Adresse hors zone')
    await user.click(screen.getByRole('button', { name: 'Rejeter la demande' }))
    await waitFor(() => expect(service.deciderRestaurant).toHaveBeenCalledWith('r4', false, 'Adresse hors zone'))
  })

  it('bloquer un restaurant (son responsable), avec confirmation', async () => {
    const { service, user } = ouvrir('/restaurants')
    await user.click(await screen.findByRole('button', { name: 'Bloquer Dar Zitouna' }))
    await user.click(screen.getByRole('button', { name: 'Oui, bloquer' }))
    await waitFor(() => expect(service.bloquerCompte).toHaveBeenCalledWith('u1', true))
    expect(await screen.findByRole('button', { name: 'Réactiver Dar Zitouna' })).toBeInTheDocument()
  })
})

describe('livreurs (US34)', () => {
  it('les documents déposés sont consultables, puis le livreur est validé', async () => {
    const { service, user } = ouvrir('/livreurs')
    const candidature = await screen.findByRole('article', { name: 'Candidature de Yassine Mejri' })
    expect(within(candidature).getByText('250 TU 0912', { exact: false })).toBeInTheDocument()
    expect(await within(candidature).findByRole('link', { name: /Ouvrir : Carte d'identité/ })).toHaveAttribute(
      'href',
      'https://stockage.test/l3/cin.jpg?jeton=x',
    )
    expect(within(candidature).getByRole('img', { name: 'Permis de conduire' })).toBeInTheDocument()
    await user.click(within(candidature).getByRole('button', { name: 'Valider le livreur' }))
    await waitFor(() => expect(service.deciderLivreur).toHaveBeenCalledWith('l3', true, undefined))
    expect(await screen.findByText('Aucune candidature à examiner.')).toBeInTheDocument()
  })

  it('rejet d\'un livreur : motif obligatoire ; refus du serveur affiché', async () => {
    const service = new FauxService()
    service.erreurAction = { code: 'P0001', message: 'La candidature de Yassine Mejri a déjà été traitée' }
    const { user } = ouvrir('/livreurs', service)
    await user.click(await screen.findByRole('button', { name: 'Rejeter la candidature' }))
    expect(screen.getByText(/Indiquez le motif du rejet/)).toBeInTheDocument()
    await user.type(screen.getByLabelText('Motif en cas de rejet'), 'Photo illisible')
    await user.click(screen.getByRole('button', { name: 'Rejeter la candidature' }))
    expect(await screen.findByText('La candidature de Yassine Mejri a déjà été traitée')).toBeInTheDocument()
  })
})

describe('clients (US35)', () => {
  it('recherche, filtre, blocage et réactivation', async () => {
    const { service, user } = ouvrir('/clients')
    expect(await screen.findByText('2 comptes · 1 bloqué')).toBeInTheDocument()
    await user.selectOptions(screen.getByLabelText('Filtrer par état'), 'bloque')
    expect(screen.queryByText('Amine Belhadj')).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Réactiver Leïla Mansour' }))
    await user.click(screen.getByRole('button', { name: 'Oui, réactiver' }))
    await waitFor(() => expect(service.bloquerCompte).toHaveBeenCalledWith('c2', false))
    await user.selectOptions(screen.getByLabelText('Filtrer par état'), '')
    await user.type(screen.getByLabelText('Rechercher un client'), 'amine')
    expect(screen.queryByText('Leïla Mansour')).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Bloquer Amine Belhadj' }))
    await user.click(screen.getByRole('button', { name: 'Non' }))
    expect(service.bloquerCompte).toHaveBeenCalledTimes(1)
  })
})

describe('commandes (US36)', () => {
  it('filtres par état, restaurant et date ; détail du paiement', async () => {
    const { service, user } = ouvrir('/commandes')
    expect(await screen.findByRole('button', { name: 'Détail de la commande n° 1043' })).toBeInTheDocument()
    await user.selectOptions(screen.getByLabelText('État'), 'en_livraison')
    await waitFor(() => expect(screen.queryByRole('button', { name: /n° 1043/ })).not.toBeInTheDocument())
    expect(service.commandes).toHaveBeenLastCalledWith({ etat: 'en_livraison', restaurantId: '', date: '' })
    await user.selectOptions(screen.getByLabelText('État'), '')
    await screen.findByRole('option', { name: 'Dar Zitouna' })
    await user.selectOptions(screen.getByLabelText('Restaurant'), 'r1')
    await waitFor(() => expect(service.commandes).toHaveBeenLastCalledWith({ etat: '', restaurantId: 'r1', date: '' }))
    await user.selectOptions(screen.getByLabelText('Restaurant'), '')
    await user.type(screen.getByLabelText('Date'), '2026-11-18')
    await waitFor(() => expect(screen.queryByRole('button', { name: /n° 1046/ })).not.toBeInTheDocument())

    await user.click(screen.getByRole('button', { name: 'Détail de la commande n° 1043' }))
    const detail = screen.getByRole('complementary', { name: 'Commande n° 1043' })
    expect(within(detail).getByText('Carte')).toBeInTheDocument()
    expect(within(detail).getByText('Remboursé')).toBeInTheDocument()
    expect(within(detail).getByText('pi_test_1043')).toBeInTheDocument()
    expect(within(detail).getByText('Motif du refus : Plus de merguez ce soir')).toBeInTheDocument()
  })
})

describe('paramètres (US37)', () => {
  it('frais, commission et gain du livreur', async () => {
    const { service, user } = ouvrir('/parametres')
    const frais = await screen.findByLabelText('Frais de livraison (DT)')
    await waitFor(() => expect(frais).toHaveValue('2,500'))
    await user.clear(frais)
    await user.type(frais, '999')
    await user.click(screen.getByRole('button', { name: 'Enregistrer' }))
    expect(screen.getByText(/entre 0 et 50/)).toBeInTheDocument()
    expect(service.enregistrerParametres).not.toHaveBeenCalled()
    await user.clear(frais)
    await user.type(frais, '3')
    await user.click(screen.getByRole('button', { name: 'Enregistrer' }))
    await waitFor(() =>
      expect(service.enregistrerParametres).toHaveBeenCalledWith({ fraisLivraison: 3, commissionPct: 10, gainLivreur: 2 }),
    )
    expect(await screen.findByText(/s'appliquent aux commandes suivantes/)).toBeInTheDocument()
  })

  it('catégories : ajouter, renommer, supprimer', async () => {
    const { service, user } = ouvrir('/parametres')
    await user.type(await screen.findByLabelText('Nouvelle catégorie'), 'Pizzas')
    await user.click(screen.getByRole('button', { name: 'Ajouter' }))
    expect(await screen.findByText('Pizzas')).toBeInTheDocument()
    expect(service.ajouterCategorie).toHaveBeenCalledWith('Pizzas', 3)

    await user.click(screen.getByRole('button', { name: 'Renommer Poissons' }))
    const saisie = screen.getByLabelText('Nouveau nom de Poissons')
    await user.clear(saisie)
    await user.type(saisie, 'Poissons et fruits de mer')
    const categories = screen.getByRole('region', { name: 'Catégories de restaurants' })
    await user.click(within(categories).getByRole('button', { name: 'Enregistrer' }))
    await waitFor(() => expect(service.renommerCategorie).toHaveBeenCalledWith('k2', 'Poissons et fruits de mer'))

    await user.click(await screen.findByRole('button', { name: 'Supprimer Pizzas' }))
    await user.click(screen.getByRole('button', { name: 'Oui, supprimer' }))
    await waitFor(() => expect(screen.queryByText('Pizzas')).not.toBeInTheDocument())

    service.erreurAction = { code: '23505', message: 'duplicate key' }
    await user.type(screen.getByLabelText('Nouvelle catégorie'), 'Poissons et fruits de mer')
    await user.click(screen.getByRole('button', { name: 'Ajouter' }))
    expect(await screen.findByText('Cette catégorie existe déjà.')).toBeInTheDocument()
  })
})
