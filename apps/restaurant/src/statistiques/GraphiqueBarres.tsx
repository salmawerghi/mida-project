import { useState } from 'react'

export interface Barre {
  cle: string
  /** Libellé de l'axe (« 19 nov. »), affiché pour quelques barres seulement. */
  etiquette: string
  /** Texte complet de l'info-bulle et du lecteur d'écran. */
  detail: string
  valeur: number
}

/**
 * Histogramme d'une seule série (une couleur, pas de légende : le titre la
 * nomme). Barres fines arrondies en haut, posées sur la ligne de base ;
 * info-bulle au survol et au clavier ; tableau des valeurs pour les
 * lecteurs d'écran.
 */
export default function GraphiqueBarres({
  titre,
  barres,
  formater,
}: {
  titre: string
  barres: Barre[]
  formater: (v: number) => string
}) {
  const [active, setActive] = useState<string | null>(null)
  const max = Math.max(0, ...barres.map((b) => b.valeur))
  // Une étiquette d'axe toutes les n barres, pour qu'elles ne se chevauchent pas.
  const pas = Math.max(1, Math.ceil(barres.length / 8))
  const barreActive = barres.find((b) => b.cle === active)

  return (
    <figure className="graphique">
      <figcaption className="graphique-titre">{titre}</figcaption>
      <div className="graphique-zone" aria-hidden="true" onMouseLeave={() => setActive(null)}>
        <div className="graphique-max">{max > 0 ? formater(max) : ''}</div>
        <div className="graphique-barres" style={{ gridTemplateColumns: `repeat(${barres.length}, minmax(0, 1fr))` }}>
          {barres.map((b) => (
            <div
              key={b.cle}
              className={`graphique-colonne${active === b.cle ? ' graphique-colonne-active' : ''}`}
              onMouseEnter={() => setActive(b.cle)}
            >
              <div
                className="graphique-barre"
                style={{ height: max > 0 ? `${Math.max(b.valeur > 0 ? 2 : 0, (b.valeur / max) * 100)}%` : 0 }}
              />
            </div>
          ))}
        </div>
        <div className="graphique-axe" style={{ gridTemplateColumns: `repeat(${barres.length}, minmax(0, 1fr))` }}>
          {barres.map((b, i) => (
            <span key={b.cle}>{i % pas === 0 || i === barres.length - 1 ? b.etiquette : ''}</span>
          ))}
        </div>
        {barreActive && (
          <div className="graphique-bulle">
            <strong>{formater(barreActive.valeur)}</strong>
            <span>{barreActive.detail}</span>
          </div>
        )}
      </div>
      <table className="visuellement-cache">
        <caption>{titre}</caption>
        <tbody>
          {barres.map((b) => (
            <tr key={b.cle}>
              <th scope="row">{b.detail}</th>
              <td>{formater(b.valeur)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </figure>
  )
}
