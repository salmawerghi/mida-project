import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'

import { Routage } from '../App'
import type { Compte } from '../auth/service'
import { FournisseurSession } from '../auth/session'
import { lireStats, tauxRefus } from '../statistiques/statistiques'
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

describe('statistiques de ventes (US44)', () => {
  it('lecture de la réponse de la base (montants en texte) et taux de refus', () => {
    const s = lireStats({
      jours: 7,
      commandes: 4,
      livrees: 1,
      refusees: 1,
      annulees: 0,
      ventes: '31.000',
      panier_moyen: '31.000',
      commission_pct: '10.00',
      commission: '3.100',
      par_jour: [{ jour: '2026-11-19', commandes: 4, ventes: '31.000' }],
      top_plats: [{ nom: 'Couscous', quantite: 2, ventes: '36.000' }],
      note_moyenne: null,
      nb_avis: 0,
    })
    expect(s.ventes).toBe(31)
    expect(s.commission).toBe(3.1)
    expect(s.parJour[0]).toEqual({ jour: '2026-11-19', commandes: 4, ventes: 31 })
    expect(s.noteMoyenne).toBeNull()
    expect(tauxRefus(s)).toBe(25)
    expect(tauxRefus({ commandes: 0, refusees: 0 })).toBe(0)
  })

  it('tableau de bord : chiffres clés, graphique des ventes et plats les plus vendus', async () => {
    ouvrir(new FauxService(valide), '/tableau')
    expect(await screen.findByRole('heading', { name: 'Bienvenue, Dar Zitouna' })).toBeInTheDocument()
    const ventes = (await screen.findByText('Ventes')).closest('.stats-tuile')!
    expect(ventes).toHaveTextContent('44,000 DT')
    expect(ventes).toHaveTextContent('2 commandes livrées')
    expect(screen.getByText('Commandes reçues').closest('.stats-tuile')).toHaveTextContent('1 refusée (20 %) · 1 annulée')
    expect(screen.getByText('Après commission').closest('.stats-tuile')).toHaveTextContent('39,600 DT')
    expect(screen.getByText('Note des clients').closest('.stats-tuile')).toHaveTextContent('★ 4,5 / 5')

    // le graphique a son tableau de valeurs pour les lecteurs d'écran
    const tableau = screen.getByRole('table', { name: /Ventes par jour/ })
    expect(within(tableau).getAllByRole('row')).toHaveLength(3)
    expect(within(tableau).getByRole('rowheader', { name: /19 novembre · 3 commandes/ }).closest('tr')).toHaveTextContent(
      '31,000 DT',
    )

    const plats = screen.getByRole('region', { name: 'Plats les plus vendus' })
    const ligne = within(plats).getByRole('rowheader', { name: 'Couscous à l’agneau' }).closest('tr')!
    expect(within(ligne).getAllByRole('cell').map((c) => c.textContent)).toEqual(['3', '54,000 DT'])
  })

  it('choix de la période : 7, 30 ou 90 jours', async () => {
    const user = userEvent.setup()
    const s = new FauxService(valide)
    ouvrir(s, '/tableau')
    await screen.findByText('Ventes')
    expect(s.statistiques).toHaveBeenLastCalledWith('r1', 30)
    await user.click(screen.getByRole('button', { name: '7 jours' }))
    expect(screen.getByRole('button', { name: '7 jours' })).toHaveAttribute('aria-pressed', 'true')
    expect(s.statistiques).toHaveBeenLastCalledWith('r1', 7)
    expect(await screen.findByRole('table', { name: /7 derniers jours/ })).toBeInTheDocument()
  })

  it('erreur de chargement : message et « Réessayer »', async () => {
    const user = userEvent.setup()
    const s = new FauxService(valide)
    s.erreurStats = new Error('Failed to fetch')
    ouvrir(s, '/tableau')
    await user.click(await screen.findByRole('button', { name: 'Réessayer' }))
    s.erreurStats = null
    await user.click(screen.getByRole('button', { name: 'Réessayer' }))
    expect(await screen.findByText('Ventes')).toBeInTheDocument()
  })
})

describe('mot de passe oublié, espace restaurant (US06)', () => {
  it('lien masqué par défaut (tant que l’envoi des e-mails n’est pas réglé)', async () => {
    ouvrir(new FauxService(null), '/connexion')
    expect(await screen.findByRole('heading', { name: 'Connexion' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Mot de passe oublié ?' })).not.toBeInTheDocument()
  })

  it('e-mail → code → nouveau mot de passe', async () => {
    const user = userEvent.setup()
    const s = new FauxService(null)
    ouvrir(s, '/mot-de-passe-oublie')
    await user.click(await screen.findByRole('button', { name: 'Recevoir un code' }))
    expect(screen.getByText('Indiquez votre adresse e-mail.')).toBeInTheDocument()
    expect(s.demanderReinitialisation).not.toHaveBeenCalled()
    await user.type(screen.getByLabelText('E-mail professionnel'), 'contact@darzitouna.tn')
    await user.click(screen.getByRole('button', { name: 'Recevoir un code' }))
    expect(s.demanderReinitialisation).toHaveBeenCalledWith('contact@darzitouna.tn')
    expect(await screen.findByRole('heading', { name: 'Nouveau mot de passe' })).toBeInTheDocument()

    await user.type(screen.getByLabelText('Code reçu par e-mail'), '654321')
    await user.type(screen.getByLabelText('Nouveau mot de passe'), 'Zitouna2026')
    await user.type(screen.getByLabelText('Confirmer le mot de passe'), 'Zitouna2026')
    await user.click(screen.getByRole('button', { name: 'Changer le mot de passe' }))
    expect(await screen.findByText(/Code incorrect ou expiré/)).toBeInTheDocument()
    expect(s.changerMotDePasse).not.toHaveBeenCalled()

    await user.clear(screen.getByLabelText('Code reçu par e-mail'))
    await user.type(screen.getByLabelText('Code reçu par e-mail'), '123 456')
    await user.click(screen.getByRole('button', { name: 'Changer le mot de passe' }))
    expect(s.changerMotDePasse).toHaveBeenCalledWith('Zitouna2026')
    // retour à l'accueil (ici : connexion, le faux service n'a pas de session)
    expect(await screen.findByRole('heading', { name: 'Connexion' })).toBeInTheDocument()
  })

  it('mot de passe refusé après un code valide : on ne redemande pas le code', async () => {
    const user = userEvent.setup()
    const s = new FauxService(null)
    s.erreurChangement = Object.assign(new Error('same'), { __isAuthError: true, code: 'same_password', status: 422 })
    ouvrir(s, '/mot-de-passe-oublie')
    await user.type(await screen.findByLabelText('E-mail professionnel'), 'contact@darzitouna.tn')
    await user.click(screen.getByRole('button', { name: 'Recevoir un code' }))
    await user.type(await screen.findByLabelText('Code reçu par e-mail'), '123456')
    await user.type(screen.getByLabelText('Nouveau mot de passe'), 'Zitouna2026')
    await user.type(screen.getByLabelText('Confirmer le mot de passe'), 'Zitouna2026')
    await user.click(screen.getByRole('button', { name: 'Changer le mot de passe' }))
    expect(await screen.findByText("Choisissez un mot de passe différent de l'ancien.")).toBeInTheDocument()
    expect(screen.queryByLabelText('Code reçu par e-mail')).not.toBeInTheDocument()
    await user.clear(screen.getByLabelText('Nouveau mot de passe'))
    await user.type(screen.getByLabelText('Nouveau mot de passe'), 'Zitouna2027')
    await user.clear(screen.getByLabelText('Confirmer le mot de passe'))
    await user.type(screen.getByLabelText('Confirmer le mot de passe'), 'Zitouna2027')
    await user.click(screen.getByRole('button', { name: 'Changer le mot de passe' }))
    expect(s.verifierCodeReinitialisation).toHaveBeenCalledTimes(1)
    expect(s.changerMotDePasse).toHaveBeenLastCalledWith('Zitouna2027')
  })
})
