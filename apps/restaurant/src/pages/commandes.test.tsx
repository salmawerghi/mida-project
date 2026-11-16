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

    const carte = await screen.findByRole('article', { name: 'Commande n° 1047' }, { timeout: 3000 })
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
    expect(await screen.findByRole('article', { name: 'Commande n° 1047' }, { timeout: 3000 })).toHaveClass('commande-nouvelle')
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
    expect(await screen.findByRole('article', { name: 'Commande n° 1047' }, { timeout: 3000 })).toBeInTheDocument()
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

describe('accepter ou refuser une commande (US13)', () => {
  it('accepte une commande en un clic : elle passe en préparation, le client est prévenu', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Accepter la commande n° 1045' }))

    expect(
      await screen.findByText('Commande n° 1045 acceptée : le client est prévenu. Elle passe en préparation.'),
    ).toBeInTheDocument()
    expect(service.accepterCommande).toHaveBeenCalledWith('k1045')
    const preparation = screen.getByRole('region', { name: 'En préparation' })
    expect(await within(preparation).findByRole('article', { name: 'Commande n° 1045' })).toBeInTheDocument()
    // plus de boutons une fois la décision prise
    expect(screen.queryByRole('button', { name: 'Accepter la commande n° 1045' })).not.toBeInTheDocument()
    expect(within(screen.getByRole('region', { name: 'En attente' })).getByText('Aucune nouvelle commande.')).toBeInTheDocument()
  })

  it('pas de boutons Accepter / Refuser sur les commandes déjà acceptées', async () => {
    ouvrir(new FauxService(valide))
    const c1044 = await screen.findByRole('article', { name: 'Commande n° 1044' })
    expect(within(c1044).queryByRole('button', { name: /^Accepter/ })).not.toBeInTheDocument()
    expect(within(c1044).queryByRole('button', { name: /^Refuser/ })).not.toBeInTheDocument()
  })

  it('refus : le motif est obligatoire, puis la commande quitte la page', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Refuser la commande n° 1045' }))
    const fenetre = screen.getByRole('dialog', { name: 'Refuser la commande n° 1045' })
    expect(fenetre).toHaveTextContent('Youssef K. · 1 × Couscous à l’agneau, 2 × Thé à la menthe · 23,000 DT')
    // payée par carte : le remboursement est annoncé
    expect(within(fenetre).getByText('Le client a payé par carte : il sera remboursé de 23,000 DT.')).toBeInTheDocument()

    await u.click(within(fenetre).getByRole('button', { name: 'Confirmer le refus' }))
    expect(within(fenetre).getByText('Choisissez le motif du refus.')).toBeInTheDocument()
    expect(service.refuserCommande).not.toHaveBeenCalled()

    await u.click(within(fenetre).getByRole('radio', { name: 'Un plat est épuisé' }))
    await u.type(within(fenetre).getByLabelText(/Message au client/), 'Plus de couscous ce soir.')
    await u.click(within(fenetre).getByRole('button', { name: 'Confirmer le refus' }))

    expect(await screen.findByText('Commande n° 1045 refusée : le client est prévenu et sera remboursé.')).toBeInTheDocument()
    expect(service.refuserCommande).toHaveBeenCalledWith('k1045', 'Un plat est épuisé — Plus de couscous ce soir.')
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(screen.queryByRole('article', { name: 'Commande n° 1045' })).not.toBeInTheDocument()
  })

  it('« Autre motif » : le message au client devient obligatoire', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    service.commandes = service.commandes.map((c) =>
      c.id === 'k1045' ? { ...c, paiement: { mode: 'especes', etat: 'en_attente' } } : c,
    )
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Refuser la commande n° 1045' }))
    const fenetre = screen.getByRole('dialog')
    expect(
      within(fenetre).getByText("Le client a choisi le paiement en espèces : aucun remboursement n'est nécessaire."),
    ).toBeInTheDocument()
    await u.click(within(fenetre).getByRole('radio', { name: 'Autre motif' }))
    await u.click(within(fenetre).getByRole('button', { name: 'Confirmer le refus' }))
    expect(within(fenetre).getByText('Précisez le motif pour le client.')).toBeInTheDocument()

    await u.type(within(fenetre).getByLabelText(/Message au client/), 'Coupure de gaz dans la cuisine')
    await u.click(within(fenetre).getByRole('button', { name: 'Confirmer le refus' }))
    expect(await screen.findByText('Commande n° 1045 refusée : le client est prévenu.')).toBeInTheDocument()
    expect(service.refuserCommande).toHaveBeenCalledWith('k1045', 'Coupure de gaz dans la cuisine')
  })

  it('Annuler (ou Échap) ferme la fenêtre sans rien envoyer', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Refuser la commande n° 1045' }))
    await u.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Annuler' }))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()

    await u.click(screen.getByRole('button', { name: 'Refuser la commande n° 1045' }))
    await u.keyboard('{Escape}')
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(service.refuserCommande).not.toHaveBeenCalled()
    expect(screen.getByRole('article', { name: 'Commande n° 1045' })).toBeInTheDocument()
  })

  it('commande déjà traitée ailleurs : message de la base, et la liste est relue', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    service.erreurDecision = { code: 'P0001', message: 'La commande n° 1045 a déjà été traitée' }
    ouvrir(service)
    await screen.findByRole('article', { name: 'Commande n° 1045' })
    const lectures = service.commandesEnCours.mock.calls.length

    await u.click(screen.getByRole('button', { name: 'Accepter la commande n° 1045' }))

    expect(await screen.findByText('La commande n° 1045 a déjà été traitée')).toBeInTheDocument()
    expect(service.commandesEnCours.mock.calls.length).toBeGreaterThan(lectures)
  })
})

describe('en préparation, puis prête (US14)', () => {
  it('acceptée → « Commencer la préparation » → « Marquer comme prête » : une étape par clic', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Accepter la commande n° 1045' }))
    const preparation = screen.getByRole('region', { name: 'En préparation' })
    const c1045 = await within(preparation).findByRole('article', { name: 'Commande n° 1045' }, { timeout: 3000 })
    expect(within(c1045).getByText('Acceptée · à préparer')).toBeInTheDocument()

    await u.click(within(c1045).getByRole('button', { name: 'Commencer la préparation : commande n° 1045' }))
    expect(await screen.findByText('Commande n° 1045 : préparation commencée.')).toBeInTheDocument()
    expect(service.avancerCommande).toHaveBeenLastCalledWith('k1045', 'en_preparation')
    const enCuisine = await within(preparation).findByRole('button', { name: 'Marquer comme prête : commande n° 1045' }, { timeout: 3000 })
    expect(within(screen.getByRole('article', { name: 'Commande n° 1045' })).getByText('En cuisine')).toBeInTheDocument()

    await u.click(enCuisine)
    expect(await screen.findByText('Commande n° 1045 prête : le client est prévenu.')).toBeInTheDocument()
    expect(service.avancerCommande).toHaveBeenLastCalledWith('k1045', 'prete')
    const prete = screen.getByRole('region', { name: 'Prête' })
    const carte = await within(prete).findByRole('article', { name: 'Commande n° 1045' }, { timeout: 3000 })
    // prête : la suite appartient au livreur, plus aucun bouton
    expect(within(carte).queryByRole('button')).not.toBeInTheDocument()
  })

  it('commande déjà en préparation : un seul bouton, « Marquer comme prête »', async () => {
    ouvrir(new FauxService(valide))
    const c1044 = await screen.findByRole('article', { name: 'Commande n° 1044' })
    expect(within(c1044).getAllByRole('button').map((b) => b.textContent)).toEqual(['Marquer comme prête'])
  })

  it('refus de la base (déjà prête ailleurs) : message affiché, la liste est relue', async () => {
    const u = userEvent.setup()
    const service = new FauxService(valide)
    service.erreurDecision = { code: 'P0001', message: 'La commande n° 1044 est déjà prête' }
    ouvrir(service)

    await u.click(await screen.findByRole('button', { name: 'Marquer comme prête : commande n° 1044' }))
    expect(await screen.findByText('La commande n° 1044 est déjà prête')).toBeInTheDocument()
  })
})
