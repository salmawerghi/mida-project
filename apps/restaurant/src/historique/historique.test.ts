import { describe, expect, it } from 'vitest'

import {
  bornesDates,
  etatsDuFiltre,
  etoiles,
  filtrerAvis,
  formaterNote,
  lireNumero,
  pastilleEtat,
  resumerAvis,
  type AvisClient,
} from './historique'

describe('historique : filtres (US39)', () => {
  it('états lus pour chaque choix du filtre', () => {
    expect(etatsDuFiltre('toutes')).toBeNull()
    expect(etatsDuFiltre('livree')).toEqual(['livree'])
    expect(etatsDuFiltre('en_cours')).toEqual(['en_attente', 'acceptee', 'en_preparation', 'prete', 'en_livraison'])
  })

  it('période : du premier jour à 0 h jusqu\'au lendemain du dernier jour (exclu)', () => {
    const { depuis, avant, erreur } = bornesDates('2026-11-18', '2026-11-19')
    expect(erreur).toBeNull()
    expect(new Date(depuis!).getTime()).toBe(new Date(2026, 10, 18).getTime())
    expect(new Date(avant!).getTime()).toBe(new Date(2026, 10, 20).getTime())
    // un seul jour
    const jour = bornesDates('2026-11-19', '2026-11-19')
    expect(new Date(jour.avant!).getTime() - new Date(jour.depuis!).getTime()).toBe(24 * 3600 * 1000)
    // bornes facultatives
    expect(bornesDates('', '')).toEqual({ depuis: null, avant: null, erreur: null })
    expect(bornesDates('2026-11-18', '').avant).toBeNull()
  })

  it('période à l\'envers : refusée', () => {
    expect(bornesDates('2026-11-20', '2026-11-19').erreur).toBe('La date de début doit précéder la date de fin.')
  })

  it('numéro de commande : « 1042 », « n° 1042 », « #1042 » ; autre chose ne correspond à rien', () => {
    expect(lireNumero('1042')).toBe(1042)
    expect(lireNumero(' n° 1042 ')).toBe(1042)
    expect(lireNumero('#1042')).toBe(1042)
    expect(lireNumero('')).toBeNull()
    expect(lireNumero('abc')).toBeNaN()
  })

  it('pastilles : livrée en vert, refusée / annulée en rouge, en cours en doré', () => {
    expect(pastilleEtat('livree')).toEqual({ libelle: 'Livrée', classe: 'pastille-actif' })
    expect(pastilleEtat('annulee').classe).toBe('pastille-refus')
    expect(pastilleEtat('en_livraison')).toEqual({ libelle: 'En livraison', classe: 'pastille-attente' })
  })
})

const avis = (note: number, commentaire: string | null = null): AvisClient => ({
  id: `a${note}${commentaire ?? ''}`,
  note,
  commentaire,
  creeLe: new Date(2026, 10, 19, 20),
  numero: 1042,
  client: 'Leïla M.',
})

describe('avis des clients (US48)', () => {
  it('moyenne, nombre, répartition 5 → 1, avis avec commentaire', () => {
    const r = resumerAvis([avis(5, 'Parfait'), avis(4), avis(4, 'Bon'), avis(1, 'Froid')])
    expect(r.moyenne).toBe(3.5)
    expect(r.nombre).toBe(4)
    expect(r.repartition).toEqual([1, 2, 0, 0, 1])
    expect(r.avecCommentaire).toBe(3)
    expect(resumerAvis([]).moyenne).toBeNull()
  })

  it('affichage de la note et des étoiles', () => {
    expect(formaterNote(4.666)).toBe('4,7')
    expect(etoiles(4)).toBe('★★★★☆')
  })

  it('filtre par note ou avec commentaire seulement', () => {
    const liste = [avis(5, 'Parfait'), avis(4), avis(4, 'Bon')]
    expect(filtrerAvis(liste, 'tous')).toHaveLength(3)
    expect(filtrerAvis(liste, 4)).toHaveLength(2)
    expect(filtrerAvis(liste, 'commentaires').map((a) => a.commentaire)).toEqual(['Parfait', 'Bon'])
  })
})
