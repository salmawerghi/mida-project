import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'

import { Routage } from '../App'
import { ErreurMida } from '../auth/erreurs'
import type { Compte } from '../auth/service'
import { FournisseurSession } from '../auth/session'
import { FauxService } from '../test/faux-service'

function ouvrir(chemin: string, service: FauxService) {
  render(
    <FournisseurSession service={service}>
      <MemoryRouter initialEntries={[chemin]}>
        <Routage />
      </MemoryRouter>
    </FournisseurSession>,
  )
}

const enAttente: Compte = {
  email: 'contact@darzitouna.tn',
  nom: 'Mehdi Ben Salem',
  restaurant: { id: 'r1', nom: 'Dar Zitouna', ville: 'Tunis', etat: 'en_attente', motif_rejet: null },
}

async function remplirEtape1(u: ReturnType<typeof userEvent.setup>) {
  await u.type(await screen.findByLabelText('Nom et prénom'), 'Mehdi Ben Salem') // après le chargement de la session
  await u.type(screen.getByLabelText('E-mail professionnel'), 'contact@darzitouna.tn')
  await u.type(screen.getByLabelText('Téléphone'), '22 145 870')
  await u.type(screen.getByLabelText('Mot de passe'), 'Mida2026!')
}

async function remplirEtape2(u: ReturnType<typeof userEvent.setup>) {
  await u.type(screen.getByLabelText('Nom du restaurant'), 'Dar Zitouna')
  await u.selectOptions(screen.getByLabelText(/Catégorie/), 'Couscous et tajines')
  await u.type(screen.getByLabelText('Téléphone du restaurant'), '71 744 210')
  await u.type(screen.getByLabelText('Adresse'), '34, avenue Habib Bourguiba, La Marsa')
  await u.selectOptions(screen.getByLabelText('Ville'), 'Tunis')
}

describe('accès aux pages', () => {
  it.each(['/attente', '/tableau', '/', '/nimporte-quoi'])('sans session, %s renvoie à la connexion', async (chemin) => {
    ouvrir(chemin, new FauxService(null))
    expect(await screen.findByRole('heading', { name: 'Connexion' })).toBeInTheDocument()
  })

  it('restaurant en attente : le tableau de bord renvoie vers la page d’attente', async () => {
    ouvrir('/tableau', new FauxService(enAttente))
    expect(await screen.findByText('En attente de validation')).toBeInTheDocument()
    expect(screen.getByText('Dar Zitouna')).toBeInTheDocument()
  })

  it('restaurant validé : accès au tableau de bord', async () => {
    ouvrir('/attente', new FauxService({ ...enAttente, restaurant: { ...enAttente.restaurant!, etat: 'actif' } }))
    expect(await screen.findByRole('heading', { name: 'Bienvenue, Dar Zitouna' })).toBeInTheDocument()
  })

  it('demande refusée : le motif est affiché', async () => {
    const refuse = { ...enAttente.restaurant!, etat: 'rejete' as const, motif_rejet: 'Adresse introuvable.' }
    ouvrir('/attente', new FauxService({ ...enAttente, restaurant: refuse }))
    expect(await screen.findByText('Demande refusée')).toBeInTheDocument()
    expect(screen.getByText('Adresse introuvable.')).toBeInTheDocument()
  })

  it('compte refusé (client, bloqué…) : message sur la page de connexion', async () => {
    const service = new FauxService(null)
    service.erreurCompte = new ErreurMida("Ce compte n'est pas un compte restaurant. Utilisez l'application mobile Mida.")
    ouvrir('/attente', service)
    expect(await screen.findByRole('alert')).toHaveTextContent("n'est pas un compte restaurant")
  })

  it('déconnexion depuis la page d’attente', async () => {
    const u = userEvent.setup()
    const service = new FauxService(enAttente)
    ouvrir('/attente', service)
    await u.click(await screen.findByRole('button', { name: 'Se déconnecter' }))
    expect(await screen.findByRole('heading', { name: 'Connexion' })).toBeInTheDocument()
  })
})

describe('inscription', () => {
  it('étape 1 vide : messages sous les champs, on reste à l’étape 1', async () => {
    const u = userEvent.setup()
    ouvrir('/inscription', new FauxService(null))
    await u.click(await screen.findByRole('button', { name: 'Continuer' }))
    expect(screen.getByText('Indiquez votre nom et prénom.')).toBeInTheDocument()
    expect(screen.getByText('Indiquez votre adresse e-mail.')).toBeInTheDocument()
    expect(screen.getByText('Indiquez un numéro de téléphone.')).toBeInTheDocument()
    expect(screen.getByText('Choisissez un mot de passe.')).toBeInTheDocument()
    expect(screen.getByLabelText('Nom et prénom')).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByRole('heading', { name: 'Créez votre compte responsable' })).toBeInTheDocument()
  })

  it('étape 2 incomplète : pas d’envoi', async () => {
    const u = userEvent.setup()
    const service = new FauxService(null)
    ouvrir('/inscription', service)
    await remplirEtape1(u)
    await u.click(screen.getByRole('button', { name: 'Continuer' }))
    await u.click(await screen.findByRole('button', { name: 'Envoyer la demande' }))
    expect(screen.getByText('Indiquez le nom du restaurant.')).toBeInTheDocument()
    expect(screen.getByText('Choisissez la ville.')).toBeInTheDocument()
    expect(service.inscrire).not.toHaveBeenCalled()
  })

  it('étape précédente : les informations du responsable sont gardées', async () => {
    const u = userEvent.setup()
    ouvrir('/inscription', new FauxService(null))
    await remplirEtape1(u)
    await u.click(screen.getByRole('button', { name: 'Continuer' }))
    await u.click(await screen.findByRole('button', { name: 'Étape précédente' }))
    expect(screen.getByLabelText('Nom et prénom')).toHaveValue('Mehdi Ben Salem')
  })

  it('inscription complète : compte « responsable », restaurant envoyé, page « en attente »', async () => {
    const u = userEvent.setup()
    const service = new FauxService(null)
    ouvrir('/inscription', service)
    await remplirEtape1(u)
    await u.click(screen.getByRole('button', { name: 'Continuer' }))
    await remplirEtape2(u)
    await u.click(screen.getByRole('button', { name: 'Envoyer la demande' }))

    expect(await screen.findByText('En attente de validation')).toBeInTheDocument()
    expect(screen.getByText('Dar Zitouna')).toBeInTheDocument()
    expect(service.inscrire).toHaveBeenCalledWith(
      { nom: 'Mehdi Ben Salem', email: 'contact@darzitouna.tn', telephone: '+216 22 145 870', motDePasse: 'Mida2026!' },
      {
        nom: 'Dar Zitouna',
        categorieId: 'k1',
        telephone: '+216 71 744 210',
        adresse: '34, avenue Habib Bourguiba, La Marsa',
        ville: 'Tunis',
        description: '',
      },
    )
  })

  it('confirmation d’e-mail exigée : retour à la connexion avec le message', async () => {
    const u = userEvent.setup()
    const service = new FauxService(null)
    service.resultatInscription = 'confirmationEmail'
    ouvrir('/inscription', service)
    await remplirEtape1(u)
    await u.click(screen.getByRole('button', { name: 'Continuer' }))
    await remplirEtape2(u)
    await u.click(screen.getByRole('button', { name: 'Envoyer la demande' }))
    expect(await screen.findByRole('status')).toHaveTextContent('lien de confirmation à contact@darzitouna.tn')
  })

  it('adresse déjà utilisée : message clair, on reste sur le formulaire', async () => {
    const u = userEvent.setup()
    const service = new FauxService(null)
    service.erreurInscription = new ErreurMida('Un compte existe déjà avec cette adresse e-mail. Connectez-vous.')
    ouvrir('/inscription', service)
    await remplirEtape1(u)
    await u.click(screen.getByRole('button', { name: 'Continuer' }))
    await remplirEtape2(u)
    await u.click(screen.getByRole('button', { name: 'Envoyer la demande' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Un compte existe déjà')
    expect(screen.getByRole('button', { name: 'Envoyer la demande' })).toBeEnabled()
  })

  it('responsable connecté sans restaurant : reprise directe à l’étape 2', async () => {
    const u = userEvent.setup()
    const service = new FauxService({ ...enAttente, restaurant: null })
    ouvrir('/connexion', service)
    expect(await screen.findByRole('heading', { name: 'Présentez votre restaurant' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Étape précédente' })).not.toBeInTheDocument()
    await remplirEtape2(u)
    await u.click(screen.getByRole('button', { name: 'Envoyer la demande' }))
    await waitFor(() => expect(service.creerRestaurant).toHaveBeenCalledOnce())
    expect(await screen.findByText('En attente de validation')).toBeInTheDocument()
  })
})
