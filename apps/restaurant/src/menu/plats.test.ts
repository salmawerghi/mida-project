import { describe, expect, it } from 'vitest'

import { formaterPrix, lirePrix, prixSaisi, validerCategoriePlat, validerNomPlat, validerPrix } from './plats'

describe('prix d’un plat', () => {
  it('lit les écritures courantes', () => {
    expect(lirePrix('16')).toBe(16)
    expect(lirePrix('16,5')).toBe(16.5)
    expect(lirePrix(' 16.500 ')).toBe(16.5)
    expect(lirePrix('16,000 DT')).toBe(16)
    expect(lirePrix('1 200,250')).toBe(1200.25)
    expect(lirePrix('-16')).toBe(-16)
  })

  it('refuse ce qui n’est pas un prix', () => {
    expect(lirePrix('seize')).toBeNull()
    expect(lirePrix('16,5555')).toBeNull() // pas plus de 3 décimales (millimes)
    expect(lirePrix('16,5,5')).toBeNull()
    expect(lirePrix('')).toBeNull()
  })

  it('le prix doit être un nombre positif', () => {
    expect(validerPrix('')).toBe('Indiquez le prix.')
    expect(validerPrix('abc')).toMatch(/Prix invalide/)
    expect(validerPrix('-16')).toBe('Le prix doit être un nombre positif.')
    expect(validerPrix('0')).toBe('Le prix doit être un nombre positif.')
    expect(validerPrix('1000,001')).toMatch(/dépasser 1000 DT/)
    expect(validerPrix('0,500')).toBeNull()
    expect(validerPrix('16,500')).toBeNull()
  })

  it('affichage tunisien à 3 décimales', () => {
    expect(formaterPrix(16.5)).toBe('16,500 DT')
    expect(formaterPrix(2.5)).toBe('2,500 DT')
    expect(formaterPrix(1200)).toBe('1 200,000 DT')
    expect(prixSaisi(18)).toBe('18,000')
  })
})

describe('nom et catégorie d’un plat', () => {
  it('nom obligatoire, 2 à 60 caractères', () => {
    expect(validerNomPlat('  ')).toBe('Indiquez le nom du plat.')
    expect(validerNomPlat('A')).toBe('Le nom est trop court.')
    expect(validerNomPlat('x'.repeat(61))).toBe('60 caractères maximum.')
    expect(validerNomPlat('Brik à l’œuf')).toBeNull()
  })

  it('catégorie obligatoire', () => {
    expect(validerCategoriePlat('')).toBe('Choisissez la catégorie du plat.')
    expect(validerCategoriePlat('c1')).toBeNull()
  })
})
