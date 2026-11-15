import { describe, expect, it } from 'vitest'

import { deplacer, libellePlats, ordreSuivant, resumeMenu, validerNomCategorie, type CategorieMenu } from './categories'

const menu: CategorieMenu[] = [
  { id: 'a', nom: 'Couscous', ordre: 1, nbPlats: 3 },
  { id: 'b', nom: 'Tajines', ordre: 2, nbPlats: 0 },
  { id: 'c', nom: 'Douceurs', ordre: 5, nbPlats: 1 },
]

describe('catégories du menu', () => {
  it('nom obligatoire, 40 caractères au plus', () => {
    expect(validerNomCategorie('   ', menu)).toBe('Indiquez le nom de la catégorie.')
    expect(validerNomCategorie('x'.repeat(41), menu)).toBe('40 caractères maximum.')
    expect(validerNomCategorie('Entrées', menu)).toBeNull()
  })

  it('pas deux catégories du même nom (sans tenir compte des majuscules ni des espaces)', () => {
    expect(validerNomCategorie(' couscous ', menu)).toBe('Une catégorie porte déjà ce nom.')
    // une catégorie renommée peut garder son nom (ou changer ses majuscules)
    expect(validerNomCategorie('COUSCOUS', menu, 'a')).toBeNull()
    expect(validerNomCategorie('Tajines', menu, 'a')).toBe('Une catégorie porte déjà ce nom.')
  })

  it('une nouvelle catégorie va à la fin du menu', () => {
    expect(ordreSuivant(menu)).toBe(6)
    expect(ordreSuivant([])).toBe(1)
  })

  it('monter et descendre d’un rang, sans sortir de la liste', () => {
    expect(deplacer(menu, 'b', -1).map((c) => c.id)).toEqual(['b', 'a', 'c'])
    expect(deplacer(menu, 'b', 1).map((c) => c.id)).toEqual(['a', 'c', 'b'])
    expect(deplacer(menu, 'a', -1)).toBe(menu)
    expect(deplacer(menu, 'c', 1)).toBe(menu)
    expect(menu.map((c) => c.id)).toEqual(['a', 'b', 'c']) // liste d'origine intacte
  })

  it('libellés', () => {
    expect(libellePlats(0)).toBe('aucun plat')
    expect(libellePlats(1)).toBe('1 plat')
    expect(libellePlats(14)).toBe('14 plats')
    expect(resumeMenu(menu)).toBe('3 catégories · 4 plats')
    expect(resumeMenu([])).toBe('0 catégories · aucun plat')
  })
})
