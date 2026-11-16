import { describe, expect, it } from 'vitest'

import { duree, ilYa, libelleATraiter, libellePaiement, nomCourt } from './commandes'

const midi = new Date('2026-11-16T12:00:00')
const avant = (minutes: number) => new Date(midi.getTime() - minutes * 60_000)

describe('commandes en cours (US12)', () => {
  it('temps écoulé depuis la commande', () => {
    expect(ilYa(avant(0.5), midi)).toBe("à l'instant")
    expect(ilYa(avant(3), midi)).toBe('il y a 3 min')
    expect(ilYa(avant(65), midi)).toBe('il y a 1 h 05')
    // horloge du PC un peu en retard sur le serveur : jamais de temps négatif
    expect(ilYa(new Date(midi.getTime() + 20_000), midi)).toBe("à l'instant")
  })

  it('temps passé dans l’état actuel', () => {
    expect(duree(avant(9), midi)).toBe('depuis 9 min')
    expect(duree(avant(0), midi)).toBe("depuis moins d'1 min")
    expect(duree(avant(130), midi)).toBe('depuis 2 h 10')
  })

  it('mode de paiement', () => {
    expect(libellePaiement({ mode: 'especes', etat: 'en_attente' })).toBe('Espèces à la livraison')
    expect(libellePaiement({ mode: 'carte', etat: 'paye' })).toBe('Carte · payée')
    expect(libellePaiement({ mode: 'carte', etat: 'echoue' })).toBe('Carte · paiement échoué')
    expect(libellePaiement(null)).toBe('Paiement non indiqué')
  })

  it('nom du client : prénom et initiale', () => {
    expect(nomCourt('Leïla Mansour')).toBe('Leïla M.')
    expect(nomCourt('  Youssef  ben  kacem ')).toBe('Youssef K.')
    expect(nomCourt('Amira')).toBe('Amira')
    expect(nomCourt('')).toBe('Client')
  })

  it('bandeau des commandes à traiter', () => {
    expect(libelleATraiter(1)).toBe('1 nouvelle commande à traiter')
    expect(libelleATraiter(3)).toBe('3 nouvelles commandes à traiter')
  })
})
