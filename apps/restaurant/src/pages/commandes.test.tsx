import { act, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { describe, expect, it, vi } from 'vitest'

import { Routage } from '../App'
import type { Compte } from '../auth/service'
import { FournisseurSession } from '../auth/session'
import type { Commande } from '../commandes/commandes'
import type { LecteurAlerte } from '../commandes/son'
import { FauxService } from '../test/faux-service'

function fauxLecteur(bloque = false): LecteurAlerte & { jouer: ReturnType<typeof vi.fn> } {
  return { jouer: vi.fn(() => !bloque), debloquer: vi.fn(), bloque: vi.fn(() => bloque) }
}

function ouvrir(service: FauxService, chemin = '/commandes', lecteur = fauxLecteur()) {
  render(
    <FournisseurSession service={service}>
      <MemoryRouter initialEntries={[chemin]}>
        <Routage lecteur={lecteur} />
      </MemoryRouter>
    </FournisseurSession>,
  )
  return lecteur
}

const valide: Compte = {
  email: 'contact@darzitouna.tn',
  nom: 'Mehdi Ben Salem',
  restaurant: { id: 'r1', nom: 'Dar Zitouna', ville: 'Tunis', etat: 'actif', motif_rejet: null, ouvert: true },
}

const nouvelle: Commande = {
  id: 'k1047',
  numero: 1047,
  etat: 'en_attente',
  client: 'Amira T.',
  total: 15.5,
  remarque: 'Sans oignons',
  creeeLe: new Date(),
  depuisLe: new Date(),
  lignes: [{ nomPlat: 'Brik à l’œuf', quantite: 2, remarque: null }],
  paiement: { mode: 'especes', etat: 'en_attente' },
}

describe('commandes en cours en temps réel (US12)', () => {
  it('affiche les commandes dans leur colonne, avec le détail : plats, quantités, remarques, paiement', async () => {
    ouvrir(new FauxService(valide))

    const attente = await screen.findByRole('region', { name: 'En attente' })
    const c1045 = within(attente).getByRole('article', { name: 'Commande n° 1045' })
    expect(c1045).toHaveTextContent('N° 1045 · Youssef K.')
    expect(within(c1045).getByText('Couscous à l’agneau').closest('li')).toHaveTextContent('1 × Couscous à l’agneau')
    expect(within(c1045).getByText('Piquant : moyen')).toBeInTheDocument()
    expect(within(c1045).getByText('2 ×').closest('li')).toHaveTextContent('Thé à la menthe')
    expect(within(c1045).getByText('Carte · payée')).toBeInTheDocument()
    expect(within(c1045).getByText('23,000 DT')).toBeInTheDocument()

    const preparation = screen.getByRole('region', { name: 'En préparation' })
    const c1044 = within(preparation).getByRole('article', { name: 'Commande n° 1044' })
    expect(c1044).toHaveTextContent('3 × Tajine de poulet aux olives')
    expect(c1044).toHaveTextContent('Remarque du client : Sonner deux fois')
    expect(within(c1044).getByText('Espèces à la livraison')).toBeInTheDocument()

    expect(within(screen.getByRole('region', { name: 'Prête' })).getByText('Aucune commande prête.')).toBeInTheDocument()
    expect(screen.getByText('1 nouvelle commande à traiter')).toBeInTheDocument()
    // le menu indique le nombre de commandes à traiter
    expect(screen.getByRole('link', { name: 'Commandes, 1 à traiter' })).toBeInTheDocument()
  })

  it('une nouvelle commande apparaît sans recharger la page, avec une alerte sonore et visuelle', async () => {
    const service = new FauxService(valide)
    const lecteur = ouvrir(service)
    await screen.findByRole('article', { name: 'Commande n° 1045' })
    expect(service.surCommandes).toHaveBeenCalledWith('r1', expect.any(Function), expect.any(Function))
    const lectures = service.commandesEnCours.mock.calls.length

    act(() => service.simulerCommande(nouvelle))

    const carte = await screen.findByRole('article', { name: 'Commande n° 1047' })
    expect(within(screen.getByRole('region', { name: 'En attente' })).getByRole('article', { name: 'Commande n° 1047' })).toBe(carte)
    expect(carte).toHaveClass('commande-nouvelle')
    expect(within(carte).getByText('Nouvelle !')).toBeInTheDocument()
    expect(carte).toHaveTextContent('2 × Brik à l’œuf')
    expect(carte).toHaveTextContent('Remarque du client : Sans oignons')
    expect(lecteur.jouer).toHaveBeenCalledTimes(1)
    expect(service.commandesEnCours.mock.calls.length).toBe(lectures + 1)
    expect(screen.getByText('2 nouvelles commandes à traiter')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Commandes, 2 à traiter' })).toBeInTheDocument()
    expect(document.title).toMatch(/^\(2\)/)
  })

  it('sur une autre page : alerte visuelle et sonore, avec un lien vers les commandes', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    const lecteur = ouvrir(service, '/menu')
    await screen.findByRole('region', { name: 'Catégories du menu' })
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()

    act(() => service.simulerCommande(nouvelle))

    const alerte = await screen.findByRole('alert')
    expect(alerte).toHaveTextContent('Nouvelle commande reçue !')
    expect(lecteur.jouer).toHaveBeenCalledTimes(1)
    expect(await screen.findByRole('link', { name: 'Commandes, 2 à traiter' })).toBeInTheDocument()

    await u.click(within(alerte).getByRole('link', { name: 'Voir les commandes' }))
    expect(await screen.findByRole('heading', { name: 'Commandes en cours' })).toBeInTheDocument()
    expect(await screen.findByRole('article', { name: 'Commande n° 1047' })).toHaveClass('commande-nouvelle')
    expect(screen.queryByRole('alert')).not.toBeInTheDocument()
  })

  it('un changement d’état déplace la commande dans la bonne colonne', async () => {
    const service = new FauxService(valide)
    const lecteur = ouvrir(service)
    await screen.findByRole('article', { name: 'Commande n° 1044' })

    act(() => service.simulerChangement('k1044', 'prete'))

    const prete = screen.getByRole('region', { name: 'Prête' })
    expect(await within(prete).findByRole('article', { name: 'Commande n° 1044' })).toBeInTheDocument()
    expect(within(screen.getByRole('region', { name: 'En préparation' })).getByText('Rien en préparation.')).toBeInTheDocument()
    // pas d'alerte : ce n'est pas une nouvelle commande
    expect(lecteur.jouer).not.toHaveBeenCalled()
  })

  it('alerte sonore désactivable, et choix gardé', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    const lecteur = ouvrir(service)

    const bouton = await screen.findByRole('button', { name: 'Alerte sonore activée' })
    expect(bouton).toHaveAttribute('aria-pressed', 'true')
    await u.click(bouton)
    expect(screen.getByRole('button', { name: 'Alerte sonore désactivée' })).toHaveAttribute('aria-pressed', 'false')
    expect(localStorage.getItem('mida.alerte-sonore')).toBe('non')

    act(() => service.simulerCommande(nouvelle))
    expect(await screen.findByRole('article', { name: 'Commande n° 1047' })).toBeInTheDocument()
    expect(lecteur.jouer).not.toHaveBeenCalled()

    // réactivée : une note d'essai confirme que le son marche
    await u.click(screen.getByRole('button', { name: 'Alerte sonore désactivée' }))
    expect(lecteur.debloquer).toHaveBeenCalled()
    expect(lecteur.jouer).toHaveBeenCalledTimes(1)
  })

  it('son bloqué par le navigateur (pas encore de clic) : invitation à l’activer', async () => {
    const u = userEvent.setup()
    const lecteur = fauxLecteur(true)
    ouvrir(new FauxService(valide), '/commandes', lecteur)

    const lien = await screen.findByRole('button', { name: "Cliquez ici pour activer l'alerte sonore" })
    await u.click(lien)
    expect(lecteur.debloquer).toHaveBeenCalled()
    expect(screen.queryByRole('button', { name: "Cliquez ici pour activer l'alerte sonore" })).not.toBeInTheDocument()
  })

  it('erreur de chargement : message et bouton pour réessayer', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    service.erreurCommandes = new Error('Failed to fetch')
    ouvrir(service)

    expect(await screen.findByRole('button', { name: 'Réessayer' })).toBeInTheDocument()
    service.erreurCommandes = null
    await u.click(screen.getByRole('button', { name: 'Réessayer' }))
    expect(await screen.findByRole('article', { name: 'Commande n° 1045' })).toBeInTheDocument()
  })

  it('se désabonne du temps réel à la déconnexion', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)
    await screen.findByRole('article', { name: 'Commande n° 1045' })
    expect(service.nbAbonnes).toBe(1)

    await u.click(screen.getByRole('button', { name: 'Se déconnecter' }))
    expect(await screen.findByRole('heading', { name: /Connexion|Bon retour/ })).toBeInTheDocument()
    expect(service.nbAbonnes).toBe(0)
  })

  it('restaurant pas encore validé : ni lien « Commandes », ni abonnement, ni accès à la page', async () => {
    const service = new FauxService({ ...valide, restaurant: { ...valide.restaurant!, etat: 'en_attente', ouvert: false } })
    ouvrir(service, '/commandes')

    // renvoyé vers l'écran d'attente
    expect(await screen.findByRole('heading', { name: 'Demande envoyée, le tajine mijote' })).toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: 'Commandes en cours' })).not.toBeInTheDocument()
    expect(service.surCommandes).not.toHaveBeenCalled()
  })

  it('restaurant en attente sur la page Menu : pas de lien « Commandes »', async () => {
    const service = new FauxService({ ...valide, restaurant: { ...valide.restaurant!, etat: 'en_attente', ouvert: false } })
    ouvrir(service, '/menu')

    expect(await screen.findByRole('link', { name: 'Ma demande' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /^Commandes/ })).not.toBeInTheDocument()
    expect(service.surCommandes).not.toHaveBeenCalled()
  })
})
