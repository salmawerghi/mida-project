import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'

import { Routage } from './App'
import { FournisseurSession } from './session'
import { lireStatsPlateforme, part, revenuMida, validerTraitement } from './statistiques'
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

describe('statistiques globales (US45)', () => {
  it('lecture de la réponse de la base, revenu de Mida et pourcentages', () => {
    const s = lireStatsPlateforme({
      jours: 7,
      commandes: 6,
      chiffre_affaires: '49.000',
      commissions: '4.400',
      frais_livraison: '5.000',
      gains_livreurs: '4.000',
      par_jour: [{ jour: '2026-11-19', commandes: 2, chiffre_affaires: '15.500' }],
      top_restaurants: [{ nom: 'Dar Zitouna', commandes: 1, ventes: '31.000' }],
      note_moyenne: '4.50',
    })
    expect(s.chiffreAffaires).toBe(49)
    expect(s.parJour[0].chiffreAffaires).toBe(15.5)
    expect(s.noteMoyenne).toBe(4.5)
    expect(s.livrees).toBe(0)
    expect(revenuMida(s)).toBe(5.4)
    expect(part(1, 8)).toBe('12,5 %')
    expect(part(0, 0)).toBe('0 %')
  })

  it('page Statistiques : chiffres, graphique, restaurants qui vendent le plus ; changement de période', async () => {
    const { service, user } = ouvrir('/statistiques')
    expect(await screen.findByRole('heading', { name: 'Statistiques' })).toBeInTheDocument()
    const ca = (await screen.findByText("Chiffre d'affaires")).closest('.admin-chiffre')!
    expect(ca).toHaveTextContent('165,000 DT')
    expect(screen.getByText('Revenu de Mida').closest('.admin-chiffre')).toHaveTextContent('18,000 DT')
    expect(screen.getAllByText('Commandes').find((e) => e.closest('.admin-chiffre'))!.closest('.admin-chiffre')).toHaveTextContent('6 livrées · refus 10 % · annulation 10 %')

    const tableau = screen.getByRole('table', { name: /Commandes par jour/ })
    expect(within(tableau).getAllByRole('row')).toHaveLength(2)
    expect(within(tableau).getByRole('rowheader', { name: /19 novembre/ }).closest('tr')).toHaveTextContent('6 commandes')

    const top = screen.getByRole('region', { name: 'Restaurants qui vendent le plus' })
    expect(within(top).getAllByRole('rowheader').map((c) => c.textContent)).toEqual(['Dar Zitouna', 'El Kanoun'])

    await user.click(screen.getByRole('button', { name: '7 jours' }))
    expect(service.statistiques).toHaveBeenLastCalledWith(7)
    expect(await screen.findByRole('table', { name: /7 derniers jours/ })).toBeInTheDocument()
  })

  it('les rubriques Réclamations et Statistiques sont dans le menu', async () => {
    ouvrir('/tableau')
    const nav = await screen.findByRole('navigation', { name: 'Navigation principale' })
    expect(within(nav).getByRole('link', { name: 'Réclamations' })).toBeInTheDocument()
    expect(within(nav).getByRole('link', { name: 'Statistiques' })).toBeInTheDocument()
    expect(await screen.findByRole('link', { name: '1 réclamation à traiter' })).toBeInTheDocument()
  })
})

describe('réclamations (US49)', () => {
  it('vérification de la décision', () => {
    expect(validerTraitement(null, 'x', '', 10).decision).toBeTruthy()
    expect(validerTraitement('resolue', '  ', '', 10).reponse).toBeTruthy()
    expect(validerTraitement('resolue', 'ok', '12', 10).montant).toBe('Au plus le total de la commande.')
    expect(validerTraitement('resolue', 'ok', 'abc', 10).montant).toBe('Montant invalide.')
    expect(validerTraitement('resolue', 'ok', '2,5', 10)).toEqual({ valeur: 2.5 })
    expect(validerTraitement('resolue', 'ok', '0', 10)).toEqual({ valeur: null })
    expect(validerTraitement('rejetee', 'non', '5', 10)).toEqual({ valeur: null })
  })

  it('résoudre une réclamation avec un remboursement', async () => {
    const { service, user } = ouvrir('/reclamations')
    expect(await screen.findByRole('button', { name: 'À traiter (1)' })).toHaveAttribute('aria-pressed', 'true')
    await user.click(screen.getByRole('button', { name: 'Réclamation sur la commande n° 1040' }))
    const detail = screen.getByRole('complementary', { name: 'Réclamation sur la commande n° 1040' })
    expect(detail).toHaveTextContent('Il manquait un fricassé dans ma commande.')
    expect(detail).toHaveTextContent('Amine Belhadj · amine@mida.test · +216 22 145 870')

    await user.click(within(detail).getByRole('button', { name: 'Envoyer la décision' }))
    expect(within(detail).getByText('Choisissez : réclamation fondée ou non.')).toBeInTheDocument()

    await user.click(within(detail).getByLabelText('Réclamation fondée (résolue)'))
    await user.type(within(detail).getByLabelText('Montant remboursé (facultatif, DT)'), '20')
    await user.type(within(detail).getByLabelText('Réponse au client'), 'Désolés pour le fricassé manquant.')
    await user.click(within(detail).getByRole('button', { name: 'Envoyer la décision' }))
    expect(within(detail).getByText('Au plus le total de la commande.')).toBeInTheDocument()
    expect(service.traiterReclamation).not.toHaveBeenCalled()

    await user.clear(within(detail).getByLabelText('Montant remboursé (facultatif, DT)'))
    await user.type(within(detail).getByLabelText('Montant remboursé (facultatif, DT)'), '2,5')
    await user.click(within(detail).getByRole('button', { name: 'Envoyer la décision' }))
    expect(service.traiterReclamation).toHaveBeenCalledWith('rc1', true, 'Désolés pour le fricassé manquant.', 2.5)
    expect(
      await screen.findByText('Réclamation sur la commande n° 1040 résolue : 2,500 DT remboursés. Le client est prévenu.'),
    ).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'À traiter (0)' })).toBeInTheDocument()
    expect(screen.getByText('Aucune réclamation à traiter. 🎉')).toBeInTheDocument()
  })

  it('réclamations traitées : décision et réponse en lecture seule', async () => {
    const { user } = ouvrir('/reclamations')
    await user.click(await screen.findByRole('button', { name: 'Traitées (1)' }))
    await user.click(screen.getByRole('button', { name: 'Réclamation sur la commande n° 1030' }))
    const detail = screen.getByRole('complementary', { name: 'Réclamation sur la commande n° 1030' })
    expect(detail).toHaveTextContent('Décision : Rejetée')
    expect(detail).toHaveTextContent('La commande a été livrée dans le délai annoncé.')
    expect(within(detail).queryByRole('button', { name: 'Envoyer la décision' })).not.toBeInTheDocument()
  })

  it('refus du serveur : le message est affiché', async () => {
    const service = new FauxService()
    service.erreurAction = new Error('Cette réclamation a déjà été traitée')
    const { user } = ouvrir('/reclamations', service)
    await user.click(await screen.findByRole('button', { name: 'Réclamation sur la commande n° 1040' }))
    await user.click(screen.getByLabelText('Réclamation non fondée (rejetée)'))
    await user.type(screen.getByLabelText('Réponse au client'), 'Commande complète.')
    await user.click(screen.getByRole('button', { name: 'Envoyer la décision' }))
    expect(await screen.findByText(/déjà été traitée|réessayez/i)).toBeInTheDocument()
  })
})
