import { describe, expect, it } from 'vitest'

import { telephoneSaisi } from '../auth/validation'
import { completerHoraires, fermeApresMinuit, heureCourte, horairesParDefaut, nomJour, validerHoraire } from './horaires'
import { tailleMaxImage, verifierImage } from './image'

describe('horaires', () => {
  it('proposition de départ : 7 jours ouverts, du lundi au dimanche', () => {
    const h = horairesParDefaut()
    expect(h.map((j) => j.jour)).toEqual([1, 2, 3, 4, 5, 6, 7])
    expect(h.every((j) => !j.ferme && j.ouverture === '11:00' && j.fermeture === '23:00')).toBe(true)
    expect(nomJour(1)).toBe('Lundi')
    expect(nomJour(7)).toBe('Dimanche')
  })

  it('complète les jours absents de la base et remet les jours dans l’ordre', () => {
    const h = completerHoraires([
      { jour: 5, ferme: false, ouverture: '12:00', fermeture: '23:30' },
      { jour: 1, ferme: true, ouverture: '', fermeture: '' },
    ])
    expect(h).toHaveLength(7)
    expect(h[0]).toEqual({ jour: 1, ferme: true, ouverture: '', fermeture: '' })
    expect(h[4].ouverture).toBe('12:00')
    expect(h[1]).toEqual({ jour: 2, ferme: false, ouverture: '11:00', fermeture: '23:00' })
  })

  it('heure de la base (avec secondes) ramenée à HH:MM', () => {
    expect(heureCourte('11:30:00')).toBe('11:30')
    expect(heureCourte(null)).toBe('')
  })

  it('jour ouvert : les deux heures sont obligatoires et différentes', () => {
    expect(validerHoraire({ jour: 2, ferme: false, ouverture: '11:30', fermeture: '23:00' })).toBeNull()
    expect(validerHoraire({ jour: 2, ferme: false, ouverture: '', fermeture: '23:00' })).toMatch(/heure d'ouverture/)
    expect(validerHoraire({ jour: 2, ferme: false, ouverture: '11:30', fermeture: '25:00' })).toMatch(/heure d'ouverture/)
    expect(validerHoraire({ jour: 2, ferme: false, ouverture: '12:00', fermeture: '12:00' })).toMatch(/même heure/)
  })

  it('jour fermé : aucune heure exigée', () => {
    expect(validerHoraire({ jour: 1, ferme: true, ouverture: '', fermeture: '' })).toBeNull()
  })

  it('fermeture après minuit acceptée et signalée', () => {
    const nuit = { jour: 6, ferme: false, ouverture: '18:00', fermeture: '02:00' }
    expect(validerHoraire(nuit)).toBeNull()
    expect(fermeApresMinuit(nuit)).toBe(true)
    expect(fermeApresMinuit({ ...nuit, fermeture: '23:00' })).toBe(false)
    expect(fermeApresMinuit({ ...nuit, ferme: true })).toBe(false)
  })
})

describe('image du logo', () => {
  it('JPEG, PNG et WebP acceptés jusqu’à 5 Mo', () => {
    expect(verifierImage({ type: 'image/png', size: 200_000 })).toBeNull()
    expect(verifierImage({ type: 'image/jpeg', size: tailleMaxImage })).toBeNull()
    expect(verifierImage({ type: 'image/webp', size: 1 })).toBeNull()
  })
  it('autre format ou image trop lourde refusés', () => {
    expect(verifierImage({ type: 'application/pdf', size: 1000 })).toMatch(/Format non accepté/)
    expect(verifierImage({ type: 'image/gif', size: 1000 })).toMatch(/Format non accepté/)
    expect(verifierImage({ type: 'image/png', size: tailleMaxImage + 1 })).toMatch(/5 Mo/)
  })
})

describe('téléphone enregistré → champ de saisie', () => {
  it('retire l’indicatif +216', () => {
    expect(telephoneSaisi('+216 71 744 210')).toBe('71 744 210')
    expect(telephoneSaisi('71 744 210')).toBe('71 744 210')
    expect(telephoneSaisi(null)).toBe('')
  })
})
