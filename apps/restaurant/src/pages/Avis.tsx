import { useCallback, useEffect, useState } from 'react'

import { messageErreur } from '../auth/erreurs'
import type { Compte } from '../auth/service'
import { useSession } from '../auth/session'
import Cadre from '../Cadre'
import { Chargement, MessageErreur } from '../composants'
import {
  etoiles,
  filtrerAvis,
  formaterDateHeure,
  formaterNote,
  resumerAvis,
  type AvisClient,
  type FiltreAvis,
} from '../historique/historique'

const filtres: { valeur: FiltreAvis; libelle: string }[] = [
  { valeur: 'tous', libelle: 'Tous' },
  { valeur: 'commentaires', libelle: 'Avec commentaire' },
  { valeur: 5, libelle: '5 ★' },
  { valeur: 4, libelle: '4 ★' },
  { valeur: 3, libelle: '3 ★' },
  { valeur: 2, libelle: '2 ★' },
  { valeur: 1, libelle: '1 ★' },
]

/**
 * Avis des clients (US48) : note moyenne, répartition des notes et liste des
 * avis (note, commentaire, client, n° de commande), filtrable par note.
 */
export default function Avis({ compte }: { compte: Compte }) {
  const { service } = useSession()
  const restaurant = compte.restaurant!
  const [avis, setAvis] = useState<AvisClient[] | null>(null)
  const [erreur, setErreur] = useState<string | null>(null)
  const [filtre, setFiltre] = useState<FiltreAvis>('tous')

  const charger = useCallback(async () => {
    try {
      setAvis(await service.avisRestaurant(restaurant.id))
      setErreur(null)
    } catch (e) {
      setErreur(messageErreur(e))
    }
  }, [service, restaurant.id])

  useEffect(() => {
    // charger() ne change l'état qu'après l'appel réseau à Supabase
    // oxlint-disable-next-line react/set-state-in-effect
    void charger()
  }, [charger])

  const resume = avis ? resumerAvis(avis) : null
  const affiches = avis ? filtrerAvis(avis, filtre) : []

  return (
    <Cadre compte={compte}>
      <div className="barre">
        <div>
          <h1>Avis des clients</h1>
          <p className="texte-doux">Les clients notent votre restaurant après chaque livraison. Ces avis sont publics.</p>
        </div>
      </div>

      {erreur && (
        <div className="historique-message">
          <MessageErreur>{erreur}</MessageErreur>
          <button type="button" className="lien-bouton" onClick={() => void charger()}>
            Réessayer
          </button>
        </div>
      )}
      {!avis && !erreur && <Chargement />}

      {avis && resume && (
        <>
          <section className="avis-resume carte" aria-label="Résumé des avis">
            <div className="avis-moyenne">
              {resume.moyenne === null ? (
                <p>Pas encore d'avis. Ils apparaîtront ici dès qu'un client aura noté une commande livrée.</p>
              ) : (
                <>
                  <span className="avis-note">{formaterNote(resume.moyenne)}</span>
                  <span className="avis-sur">/ 5</span>
                  <p>
                    {resume.nombre} avis · {resume.avecCommentaire} avec commentaire
                  </p>
                </>
              )}
            </div>
            {resume.nombre > 0 && (
              <ul className="avis-repartition">
                {resume.repartition.map((n, i) => {
                  const note = 5 - i
                  const part = Math.round((n / resume.nombre) * 100)
                  return (
                    <li key={note} aria-label={`${note} étoiles : ${n} avis`}>
                      <span aria-hidden="true">{note} ★</span>
                      <span className="avis-barre" aria-hidden="true">
                        <span style={{ width: `${part}%` }} />
                      </span>
                      <span aria-hidden="true">{n}</span>
                    </li>
                  )
                })}
              </ul>
            )}
          </section>

          {resume.nombre > 0 && (
            <div className="avis-filtres" role="group" aria-label="Filtrer les avis">
              {filtres.map((f) => (
                <button
                  key={String(f.valeur)}
                  type="button"
                  className={`bouton bouton-petit ${filtre === f.valeur ? 'bouton-bleu' : 'bouton-blanc'}`}
                  aria-pressed={filtre === f.valeur}
                  onClick={() => setFiltre(f.valeur)}
                >
                  {f.libelle}
                </button>
              ))}
            </div>
          )}

          {resume.nombre > 0 && affiches.length === 0 && <p className="texte-doux">Aucun avis pour ce filtre.</p>}
          <ul className="avis-liste">
            {affiches.map((a) => (
              <li key={a.id} className="avis carte">
                <div className="avis-entete">
                  <span className="avis-etoiles" role="img" aria-label={`${a.note} sur 5`}>
                    {etoiles(a.note)}
                  </span>
                  <span className="texte-doux">
                    {a.client}
                    {a.numero !== null && ` · commande n° ${a.numero}`} · {formaterDateHeure(a.creeLe)}
                  </span>
                </div>
                {a.commentaire ? (
                  <p className="avis-commentaire">« {a.commentaire} »</p>
                ) : (
                  <p className="texte-doux">Pas de commentaire.</p>
                )}
              </li>
            ))}
          </ul>
        </>
      )}
    </Cadre>
  )
}
