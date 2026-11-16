import { describe, expect, it } from 'vitest'

import {
  composerMotif,
  duree,
  etapeSuivante,
  ilYa,
  libelleATraiter,
  libellePaiement,
  nomCourt,
  validerRefus,
} from './commandes'

describe('étapes de la commande (US14)', () => {
  it('une seule étape suivante, dans l’ordre, jamais en arrière', () => {
    expect(etapeSuivante('acceptee')?.etat).toBe('en_preparation')
    expect(etapeSuivante('en_preparation')?.etat).toBe('prete')
    for (const etat of ['en_attente', 'prete', 'en_livraison', 'livree', 'refusee', 'annulee'] as const) {
      expect(etapeSuivante(etat)).toBeNull()
    }
  })
})

describe('refus d’une commande (US13)', () => {
  it('motif obligatoire, message obligatoire pour « Autre motif »', () => {
    expect(validerRefus(null, '')).toEqual({ motif: 'Choisissez le motif du refus.' })
    expect(validerRefus('Un plat est épuisé', '')).toEqual({})
    expect(validerRefus('Autre motif', '   ')).toEqual({ message: 'Précisez le motif pour le client.' })
    expect(validerRefus('Autre motif', 'x'.repeat(251))).toEqual({ message: '250 caractères maximum.' })
  })

  it('motif envoyé au client', () => {
    expect(composerMotif('Un plat est épuisé', '')).toBe('Un plat est épuisé')
    expect(composerMotif('Un plat est épuisé', '  Plus de merguez.  ')).toBe('Un plat est épuisé — Plus de merguez.')
    expect(composerMotif('Autre motif', ' Coupure de gaz ')).toBe('Coupure de gaz')
  })
})

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
