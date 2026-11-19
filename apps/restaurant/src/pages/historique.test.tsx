import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'

import { Routage } from '../App'
import type { Compte } from '../auth/service'
import { FournisseurSession } from '../auth/session'
import type { AvisClient, CommandeHistorique } from '../historique/historique'
import { FauxService } from '../test/faux-service'

const lecteur = { jouer: () => true, debloquer: () => {}, bloque: () => false }

function ouvrir(service: FauxService, chemin: string) {
  render(
    <FournisseurSession service={service}>
      <MemoryRouter initialEntries={[chemin]}>
        <Routage lecteur={lecteur} />
      </MemoryRouter>
    </FournisseurSession>,
  )
}

const valide: Compte = {
  email: 'contact@darzitouna.tn',
  nom: 'Mehdi Ben Salem',
  restaurant: { id: 'r1', nom: 'Dar Zitouna', ville: 'Tunis', etat: 'actif', motif_rejet: null, ouvert: true },
}
const enAttente: Compte = { ...valide, restaurant: { ...valide.restaurant!, etat: 'en_attente', ouvert: false } }

function commande(numero: number, etat: CommandeHistorique['etat'], extra: Partial<CommandeHistorique> = {}): CommandeHistorique {
  const date = new Date(2026, 10, 19, 20, 15)
  return {
    id: `k${numero}`,
    numero,
    etat,
    client: 'Leïla M.',
    total: 25.5,
    remarque: null,
    creeeLe: date,
    depuisLe: date,
    lignes: [{ nomPlat: 'Couscous à l’agneau', quantite: 1, remarque: 'Piquant : moyen' }],
    paiement: { mode: 'especes', etat: etat === 'livree' ? 'paye' : 'en_attente' },
    motifRefus: null,
    livreeLe: etat === 'livree' ? new Date(2026, 10, 19, 20, 50) : null,
    annuleeLe: null,
    ...extra,
  }
}

function service(): FauxService {
  const s = new FauxService(valide)
  s.historique = [
    commande(1050, 'livree'),
    commande(1049, 'refusee', { motifRefus: 'Un plat est épuisé — Plus de merguez ce soir.' }),
    commande(1048, 'annulee'),
    commande(1047, 'livree', { total: 33.5 }),
  ]
  return s
}

describe('historique des commandes (US39)', () => {
  it('liste toutes les commandes avec le chiffre d\'affaires des commandes livrées', async () => {
    ouvrir(service(), '/historique')
    expect(await screen.findByRole('heading', { name: 'Historique des commandes' })).toBeInTheDocument()
    expect(await screen.findByText(/4 commandes · 2 livrées pour/)).toHaveTextContent('59,000 DT')
    const lignes = screen.getAllByRole('button', { expanded: false })
    expect(lignes.map((b) => b.textContent)).toEqual([
      expect.stringContaining('N° 1050'),
      expect.stringContaining('N° 1049'),
      expect.stringContaining('N° 1048'),
      expect.stringContaining('N° 1047'),
    ])
    expect(lignes[1]).toHaveTextContent('Refusée')
    expect(lignes[2]).toHaveTextContent('Annulée')
  })

  it('un clic affiche le détail : plats, remarques, paiement, motif du refus', async () => {
    const user = userEvent.setup()
    ouvrir(service(), '/historique')
    const ligne = await screen.findByRole('button', { name: /N° 1049/ })
    await user.click(ligne)
    expect(ligne).toHaveAttribute('aria-expanded', 'true')
    const detail = document.getElementById(ligne.getAttribute('aria-controls')!)!
    expect(detail).toHaveTextContent('1 × Couscous à l’agneau')
    expect(detail).toHaveTextContent('Couscous à l’agneau : Piquant : moyen')
    expect(detail).toHaveTextContent('Paiement : Espèces à la livraison')
    expect(detail).toHaveTextContent('Motif du refus : Un plat est épuisé — Plus de merguez ce soir.')
  })

  it('filtre par état et par numéro ; « Effacer les filtres » revient à toutes les commandes', async () => {
    const user = userEvent.setup()
    const s = service()
    ouvrir(s, '/historique')
    await screen.findByText(/4 commandes/)

    await user.selectOptions(screen.getByLabelText('État'), 'Refusées')
    await user.click(screen.getByRole('button', { name: 'Filtrer' }))
    expect(await screen.findByText('1 commande')).toBeInTheDocument()
    expect(s.historiqueCommandes).toHaveBeenLastCalledWith('r1', expect.objectContaining({ etat: 'refusee' }), 0)

    await user.selectOptions(screen.getByLabelText('État'), 'Toutes')
    await user.type(screen.getByLabelText('N° de commande'), '9999')
    await user.click(screen.getByRole('button', { name: 'Filtrer' }))
    expect(await screen.findByText('Aucune commande ne correspond à ces filtres.')).toBeInTheDocument()

    await user.click(screen.getAllByRole('button', { name: 'Effacer les filtres' })[0])
    expect(await screen.findByText(/4 commandes/)).toBeInTheDocument()
    expect(screen.getByLabelText('N° de commande')).toHaveValue('')
  })

  it('une période à l\'envers est refusée sans appel au serveur', async () => {
    const user = userEvent.setup()
    const s = service()
    ouvrir(s, '/historique')
    await screen.findByText(/4 commandes/)
    const appels = s.historiqueCommandes.mock.calls.length
    await user.type(screen.getByLabelText('Du'), '2026-11-20')
    await user.type(screen.getByLabelText('Au'), '2026-11-19')
    await user.click(screen.getByRole('button', { name: 'Filtrer' }))
    expect(screen.getByRole('alert')).toHaveTextContent('La date de début doit précéder la date de fin.')
    expect(s.historiqueCommandes.mock.calls.length).toBe(appels)
  })

  it('pages de 20 commandes : « Plus anciennes » puis « Plus récentes »', async () => {
    const user = userEvent.setup()
    const s = new FauxService(valide)
    s.historique = Array.from({ length: 25 }, (_, i) => commande(1100 - i, 'livree'))
    ouvrir(s, '/historique')
    expect(await screen.findByText('Page 1 sur 2')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Plus anciennes' }))
    expect(await screen.findByText('Page 2 sur 2')).toBeInTheDocument()
    expect(screen.getAllByRole('button', { name: /^N° / })).toHaveLength(5)
    expect(screen.getByRole('button', { name: 'Plus anciennes' })).toBeDisabled()
  })

  it('réservé aux restaurants validés ; lien dans le menu latéral', async () => {
    ouvrir(new FauxService(enAttente), '/historique')
    expect(await screen.findByRole('heading', { name: 'Demande envoyée, le tajine mijote' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Historique' })).not.toBeInTheDocument()
  })
})

const avisTest: AvisClient[] = [
  { id: 'a1', note: 5, commentaire: 'Couscous généreux, merci !', creeLe: new Date(2026, 10, 19, 21), numero: 1050, client: 'Leïla M.' },
  { id: 'a2', note: 4, commentaire: null, creeLe: new Date(2026, 10, 18, 13), numero: 1047, client: 'Amine B.' },
  { id: 'a3', note: 2, commentaire: 'Arrivé froid.', creeLe: new Date(2026, 10, 17, 20), numero: 1040, client: 'Youssef K.' },
]

describe('avis des clients (US48)', () => {
  it('note moyenne, répartition et liste des avis', async () => {
    const s = new FauxService(valide)
    s.avis = avisTest
    ouvrir(s, '/avis')
    const resume = await screen.findByRole('region', { name: 'Résumé des avis' })
    expect(resume).toHaveTextContent('3,7/ 5')
    expect(resume).toHaveTextContent('3 avis · 2 avec commentaire')
    expect(within(resume).getByLabelText('5 étoiles : 1 avis')).toBeInTheDocument()
    expect(within(resume).getByLabelText('3 étoiles : 0 avis')).toBeInTheDocument()

    const items = screen.getAllByRole('listitem').filter((li) => li.classList.contains('avis'))
    expect(items).toHaveLength(3)
    expect(items[0]).toHaveTextContent('« Couscous généreux, merci ! »')
    expect(items[0]).toHaveTextContent('Leïla M. · commande n° 1050')
    expect(within(items[0]).getByRole('img', { name: '5 sur 5' })).toHaveTextContent('★★★★★')
    expect(items[1]).toHaveTextContent('Pas de commentaire.')
  })

  it('filtres : par note, avec commentaire', async () => {
    const user = userEvent.setup()
    const s = new FauxService(valide)
    s.avis = avisTest
    ouvrir(s, '/avis')
    await screen.findByRole('region', { name: 'Résumé des avis' })
    await user.click(screen.getByRole('button', { name: '2 ★' }))
    expect(screen.getByRole('button', { name: '2 ★' })).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getAllByText(/^« /).map((p) => p.textContent)).toEqual(['« Arrivé froid. »'])
    await user.click(screen.getByRole('button', { name: '3 ★' }))
    expect(screen.getByText('Aucun avis pour ce filtre.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Avec commentaire' }))
    expect(screen.getAllByText(/^« /)).toHaveLength(2)
  })

  it('pas encore d\'avis : message', async () => {
    ouvrir(new FauxService(valide), '/avis')
    expect(await screen.findByText(/Pas encore d'avis/)).toBeInTheDocument()
    expect(screen.queryByRole('group', { name: 'Filtrer les avis' })).not.toBeInTheDocument()
  })

  it('accès depuis le menu latéral', async () => {
    const user = userEvent.setup()
    ouvrir(new FauxService(valide), '/menu')
    await user.click(await screen.findByRole('link', { name: 'Avis des clients' }))
    expect(await screen.findByRole('heading', { name: 'Avis des clients' })).toBeInTheDocument()
  })
})
