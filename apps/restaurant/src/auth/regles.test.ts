import { AuthApiError, AuthRetryableFetchError } from '@supabase/supabase-js'
import { describe, expect, it } from 'vitest'

import { lireBrouillon, sauverBrouillon } from './brouillon'
import { ErreurMida, messageErreur, messageHorsLigne, messageIdentifiantsIncorrects } from './erreurs'
import { pageDuCompte, refusCompte, type Compte } from './service'
import {
  formaterTelephone,
  validerAdresse,
  validerEmail,
  validerMotDePasseInscription,
  validerNom,
  validerNomRestaurant,
  validerTelephone,
  validerVille,
} from './validation'

describe('validation', () => {
  it('responsable : nom, e-mail, téléphone, mot de passe', () => {
    expect(validerNom('  ')).toBe('Indiquez votre nom et prénom.')
    expect(validerNom('Al')).toBe('Le nom est trop court.')
    expect(validerNom('Mehdi Ben Salem')).toBeNull()
    expect(validerEmail('contact@darzitouna')).toBe("Cette adresse e-mail n'est pas valide.")
    expect(validerEmail(' contact@darzitouna.tn ')).toBeNull()
    expect(validerTelephone('71 744 21')).toBe('Le numéro doit comporter 8 chiffres.')
    expect(validerTelephone('71.744-210')).toBeNull()
    expect(validerMotDePasseInscription('court')).toBe('8 caractères minimum.')
    expect(validerMotDePasseInscription('Mida2026!')).toBeNull()
  })

  it('restaurant : nom, adresse, ville obligatoires', () => {
    expect(validerNomRestaurant('')).toBe('Indiquez le nom du restaurant.')
    expect(validerNomRestaurant('Dar Zitouna')).toBeNull()
    expect(validerAdresse('rue')).toMatch(/trop courte/)
    expect(validerAdresse('34, avenue Habib Bourguiba')).toBeNull()
    expect(validerVille('')).toBe('Choisissez la ville.')
    expect(validerVille('Tunis')).toBeNull()
  })

  it('téléphone enregistré au format +216', () => {
    expect(formaterTelephone('71744210')).toBe('+216 71 744 210')
    expect(formaterTelephone('71 744 210')).toBe('+216 71 744 210')
  })
})

describe('messageErreur', () => {
  it('traduit les erreurs de connexion et le réseau', () => {
    expect(messageErreur(new AuthApiError('Invalid login credentials', 400, 'invalid_credentials'))).toBe(
      messageIdentifiantsIncorrects,
    )
    expect(messageErreur(new AuthApiError('User already registered', 422, 'user_already_exists'))).toMatch(/existe déjà/)
    expect(messageErreur(new AuthApiError('x', 429, 'over_request_rate_limit'))).toMatch(/Trop de tentatives/)
    expect(messageErreur(new AuthRetryableFetchError('Failed to fetch', 0))).toBe(messageHorsLigne)
    expect(messageErreur(new TypeError('Failed to fetch'))).toBe(messageHorsLigne)
  })

  it('traduit les erreurs de la base', () => {
    expect(messageErreur({ code: '23505', message: 'duplicate key' })).toBe('Ce compte a déjà inscrit un restaurant.')
    expect(messageErreur({ code: '42501', message: 'row-level security' })).toMatch(/pas le droit/)
  })

  it('ErreurMida telle quelle, sinon message générique', () => {
    expect(messageErreur(new ErreurMida('Bonjour'))).toBe('Bonjour')
    expect(messageErreur(new Error('?'))).toBe('Une erreur est survenue. Réessayez dans un instant.')
  })
})

describe('refusCompte', () => {
  it('accepte les responsables, en attente compris', () => {
    expect(refusCompte('responsable', 'en_attente')).toBeNull()
    expect(refusCompte('responsable', 'actif')).toBeNull()
  })
  it('renvoie les autres rôles vers leur application', () => {
    expect(refusCompte('client', 'actif')).toMatch(/application mobile Mida/)
    expect(refusCompte('livreur', 'actif')).toMatch(/Mida Livreur/)
    expect(refusCompte('admin', 'actif')).toMatch(/administration/)
  })
  it('refuse un compte bloqué', () => {
    expect(refusCompte('responsable', 'bloque')).toMatch(/suspendu/)
  })
})

describe('pageDuCompte', () => {
  const compte = (etat: 'en_attente' | 'actif' | 'rejete' | null): Compte => ({
    email: 'a@b.tn',
    nom: 'A',
    restaurant: etat ? { id: 'r', nom: 'R', ville: 'Tunis', etat, motif_rejet: null } : null,
  })
  it('selon l’état du restaurant', () => {
    expect(pageDuCompte(compte(null))).toBe('/inscription')
    expect(pageDuCompte(compte('en_attente'))).toBe('/attente')
    expect(pageDuCompte(compte('rejete'))).toBe('/attente')
    expect(pageDuCompte(compte('actif'))).toBe('/tableau')
  })
})

describe('brouillon', () => {
  it('relu seulement pour le même e-mail', () => {
    const r = { nom: 'Dar', categorieId: null, telephone: '+216 71 744 210', adresse: '1 rue X', ville: 'Tunis', description: '' }
    sauverBrouillon(' Contact@Dar.tn ', r)
    expect(lireBrouillon('contact@dar.tn')).toEqual(r)
    expect(lireBrouillon('autre@dar.tn')).toBeNull()
  })
})
