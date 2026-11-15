import { fireEvent, render, screen, within } from '@testing-library/react'
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

const valide: Compte = {
  email: 'contact@darzitouna.tn',
  nom: 'Mehdi Ben Salem',
  restaurant: { id: 'r1', nom: 'Dar Zitouna', ville: 'Tunis', etat: 'actif', motif_rejet: null, ouvert: false },
}
const enAttente: Compte = { ...valide, restaurant: { ...valide.restaurant!, etat: 'en_attente' } }

const enregistrer = (u: ReturnType<typeof userEvent.setup>) =>
  u.click(screen.getByRole('button', { name: 'Enregistrer les modifications' }))

describe('accès au profil', () => {
  it('sans session : retour à la connexion', async () => {
    ouvrir('/profil', new FauxService(null))
    expect(await screen.findByRole('heading', { name: 'Connexion' })).toBeInTheDocument()
  })

  it('responsable sans restaurant : renvoyé à l’inscription du restaurant', async () => {
    ouvrir('/profil', new FauxService({ ...valide, restaurant: null }))
    expect(await screen.findByRole('heading', { name: 'Présentez votre restaurant' })).toBeInTheDocument()
  })

  it('restaurant en attente : le profil est déjà ouvert, depuis la page d’attente', async () => {
    const u = userEvent.setup()
    const service = new FauxService(enAttente)
    service.profil = { ...service.profil, etat: 'en_attente' }
    ouvrir('/attente', service)
    await u.click(await screen.findByRole('link', { name: 'Profil du restaurant' }))
    expect(await screen.findByRole('heading', { name: 'Profil du restaurant' })).toBeInTheDocument()
    expect(screen.getByText(/pas encore visible des clients/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Ma demande' })).toHaveAttribute('href', '/attente')
  })

  it('restaurant validé : le profil est dans le menu, à côté du tableau de bord', async () => {
    const u = userEvent.setup()
    ouvrir('/tableau', new FauxService(valide))
    const menu = within(await screen.findByRole('navigation', { name: 'Navigation principale' }))
    expect(menu.getByRole('link', { name: 'Tableau de bord' })).toHaveAttribute('aria-current', 'page')
    await u.click(menu.getByRole('link', { name: 'Profil du restaurant' }))
    expect(await screen.findByLabelText('Nom')).toHaveValue('Dar Zitouna')
  })
})

describe('profil du restaurant', () => {
  it('affiche les informations et les horaires enregistrés', async () => {
    ouvrir('/profil', new FauxService(valide))
    expect(await screen.findByLabelText('Nom')).toHaveValue('Dar Zitouna')
    expect(screen.getByLabelText('Adresse')).toHaveValue('34, avenue Habib Bourguiba, La Marsa')
    expect(screen.getByLabelText('Téléphone')).toHaveValue('71 744 210') // sans l'indicatif
    expect(screen.getByLabelText('Ville')).toHaveValue('Tunis')
    expect(screen.getByLabelText(/Catégorie/)).toHaveValue('k1')
    expect(screen.getByText('Compte validé')).toBeInTheDocument()
    // lundi fermé, les autres jours ouverts
    expect(screen.getByRole('checkbox', { name: /Lundi/ })).not.toBeChecked()
    expect(screen.getByText('Fermé')).toBeInTheDocument()
    expect(screen.getByRole('checkbox', { name: /Mardi/ })).toBeChecked()
    expect(screen.getByLabelText('Ouverture le mardi')).toHaveValue('11:00')
    expect(screen.queryByLabelText('Ouverture le lundi')).not.toBeInTheDocument()
  })

  it('enregistre les informations modifiées et les horaires', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir('/profil', service)

    const nom = await screen.findByLabelText('Nom')
    await u.clear(nom)
    await u.type(nom, '  Dar Zitouna Marsa ')
    const telephone = screen.getByLabelText('Téléphone')
    await u.clear(telephone)
    await u.type(telephone, '71 555 010')
    await u.selectOptions(screen.getByLabelText('Ville'), 'Ariana')
    // le lundi rouvre de 12:00 à 15:00, le dimanche ferme
    await u.click(screen.getByRole('checkbox', { name: /Lundi/ }))
    fireEvent.change(screen.getByLabelText('Ouverture le lundi'), { target: { value: '12:00' } })
    fireEvent.change(screen.getByLabelText('Fermeture le lundi'), { target: { value: '15:00' } })
    await u.click(screen.getByRole('checkbox', { name: /Dimanche/ }))
    await enregistrer(u)

    expect(await screen.findByRole('status')).toHaveTextContent('visibles tout de suite par les clients')
    expect(service.enregistrerProfil).toHaveBeenCalledTimes(1)
    const [id, infos, horaires] = service.enregistrerProfil.mock.calls[0]
    expect(id).toBe('r1')
    expect(infos).toMatchObject({
      nom: '  Dar Zitouna Marsa ', // nettoyé par le service
      categorieId: 'k1',
      telephone: '+216 71 555 010',
      ville: 'Ariana',
    })
    expect(horaires).toHaveLength(7)
    expect(horaires[0]).toEqual({ jour: 1, ferme: false, ouverture: '12:00', fermeture: '15:00' })
    expect(horaires[6]).toMatchObject({ jour: 7, ferme: true })
    // le nouveau nom est repris dans l'en-tête du profil et dans le menu
    expect(await screen.findAllByText('Dar Zitouna Marsa')).toHaveLength(2)
  })

  it('informations invalides : messages sous les champs, rien n’est envoyé', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir('/profil', service)

    await u.clear(await screen.findByLabelText('Nom'))
    await u.clear(screen.getByLabelText('Téléphone'))
    await u.type(screen.getByLabelText('Téléphone'), '71 55')
    fireEvent.change(screen.getByLabelText('Fermeture le mardi'), { target: { value: '' } })
    await enregistrer(u)

    expect(screen.getByText('Indiquez le nom du restaurant.')).toBeInTheDocument()
    expect(screen.getByText('Le numéro doit comporter 8 chiffres.')).toBeInTheDocument()
    expect(screen.getByText("Indiquez l'heure d'ouverture et l'heure de fermeture.")).toBeInTheDocument()
    expect(screen.getByRole('alert')).toHaveTextContent('Corrigez les informations signalées')
    expect(service.enregistrerProfil).not.toHaveBeenCalled()
  })

  it('refus de la base : message clair, la saisie est gardée', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    service.erreurProfil = new ErreurMida("Ce compte n'a pas le droit de modifier ce restaurant.")
    ouvrir('/profil', service)

    const nom = await screen.findByLabelText('Nom')
    await u.type(nom, ' 2')
    await enregistrer(u)

    expect(await screen.findByRole('alert')).toHaveTextContent("n'a pas le droit de modifier ce restaurant")
    expect(nom).toHaveValue('Dar Zitouna 2')
    expect(screen.queryByRole('status')).not.toBeInTheDocument()
  })

  it('horaires jamais enregistrés : une proposition est affichée', async () => {
    const service = new FauxService(valide)
    service.horairesEnregistres = false
    ouvrir('/profil', service)
    expect(await screen.findByText(/horaires ne sont pas encore enregistrés/)).toBeInTheDocument()
  })

  it('restaurant en attente : la confirmation annonce une visibilité après validation', async () => {
    const u = userEvent.setup()
    const service = new FauxService(enAttente)
    service.profil = { ...service.profil, etat: 'en_attente' }
    ouvrir('/profil', service)
    await screen.findByLabelText('Nom')
    await enregistrer(u)
    expect(await screen.findByRole('status')).toHaveTextContent('dès la validation du restaurant')
  })
})

describe('logo', () => {
  it('envoie l’image choisie et affiche le nouveau logo', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir('/profil', service)

    const image = new File(['x'], 'logo.png', { type: 'image/png' })
    await u.upload(await screen.findByLabelText('Ajouter un logo'), image)

    expect(await screen.findByRole('status')).toHaveTextContent('Logo mis à jour.')
    expect(service.changerLogo).toHaveBeenCalledWith('r1', image)
    expect(screen.getByRole('img', { name: 'Logo de Dar Zitouna' })).toHaveAttribute(
      'src',
      'https://exemple.test/restaurants/r1/logo.png',
    )
    expect(screen.getByLabelText('Changer le logo')).toBeInTheDocument()
  })

  it('format refusé : message, aucun envoi', async () => {
    const service = new FauxService(valide)
    ouvrir('/profil', service)

    const pdf = new File(['x'], 'menu.pdf', { type: 'application/pdf' })
    // (userEvent.upload respecte « accept » et ignorerait le fichier : on force le choix)
    fireEvent.change(await screen.findByLabelText('Ajouter un logo'), { target: { files: [pdf] } })

    expect(await screen.findByRole('alert')).toHaveTextContent('Format non accepté')
    expect(service.changerLogo).not.toHaveBeenCalled()
  })
})
