import { useId, useState, type ButtonHTMLAttributes, type InputHTMLAttributes, type ReactNode } from 'react'

/** Étoile à 8 branches de Mida. */
export function Logo({ taille = 44, inverse = false }: { taille?: number; inverse?: boolean }) {
  const fond = inverse ? '#FFFFFF' : '#1554C0'
  const etoile = inverse ? '#1554C0' : '#FFFFFF'
  return (
    <svg viewBox="0 0 40 40" width={taille} height={taille} aria-hidden="true">
      <circle cx="20" cy="20" r="20" fill={fond} />
      <polygon points="20,5 35,20 20,35 5,20" fill={etoile} />
      <polygon points="9.4,9.4 30.6,9.4 30.6,30.6 9.4,30.6" fill={etoile} />
      <circle cx="20" cy="20" r="6" fill="#C93A22" />
    </svg>
  )
}

export function Marque() {
  return (
    <div className="marque">
      <Logo />
      <div className="marque-nom">
        Mida <span className="marque-sous">· Administration</span>
      </div>
    </div>
  )
}

type VarianteBouton = 'bleu' | 'harissa' | 'blanc'

export function Bouton({
  variante = 'bleu',
  enCours = false,
  plein = false,
  children,
  className,
  ...reste
}: ButtonHTMLAttributes<HTMLButtonElement> & { variante?: VarianteBouton; enCours?: boolean; plein?: boolean }) {
  const classes = ['bouton', `bouton-${variante}`, plein ? 'bouton-plein' : '', className ?? ''].join(' ').trim()
  return (
    <button className={classes} disabled={enCours || reste.disabled} aria-busy={enCours || undefined} {...reste}>
      {enCours && <span className="roue" aria-hidden="true" />}
      {children}
    </button>
  )
}

/**
 * Champ avec son étiquette et son message d'erreur, reliés pour les
 * lecteurs d'écran (aria-invalid, aria-describedby).
 */
export function Champ({
  etiquette,
  erreur,
  facultatif = false,
  className,
  enfant,
}: {
  etiquette: string
  erreur?: string | null
  facultatif?: boolean
  className?: string
  enfant: (props: { id: string; 'aria-invalid'?: boolean; 'aria-describedby'?: string }) => ReactNode
}) {
  const id = useId()
  const idErreur = `${id}-erreur`
  return (
    <div className={`champ ${className ?? ''}`.trim()}>
      <label htmlFor={id}>
        {etiquette}
        {facultatif && <span className="champ-facultatif"> (facultatif)</span>}
      </label>
      {enfant({ id, 'aria-invalid': erreur ? true : undefined, 'aria-describedby': erreur ? idErreur : undefined })}
      {erreur && (
        <span id={idErreur} className="erreur-champ">
          {erreur}
        </span>
      )}
    </div>
  )
}

/** Saisie du téléphone avec l'indicatif +216 affiché devant. */
export function SaisieTelephone(props: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className="saisie-groupe">
      <span className="prefixe" aria-hidden="true">
        +216
      </span>
      <input
        type="tel"
        inputMode="tel"
        placeholder="71 744 210"
        maxLength={11}
        className="saisie avec-prefixe"
        {...props}
      />
    </div>
  )
}

export function SaisieMotDePasse(props: InputHTMLAttributes<HTMLInputElement>) {
  const [visible, setVisible] = useState(false)
  return (
    <div className="saisie-groupe">
      <input {...props} type={visible ? 'text' : 'password'} className="saisie avec-bouton" />
      <button
        type="button"
        className="bouton-oeil"
        aria-label={visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}
        aria-pressed={visible}
        onClick={() => setVisible((v) => !v)}
      >
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
          <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z" />
          <circle cx="12" cy="12" r="3" />
          {visible && <path d="M4 4l16 16" />}
        </svg>
      </button>
    </div>
  )
}

export function MessageErreur({ children }: { children: ReactNode }) {
  return (
    <p className="message message-erreur" role="alert">
      {children}
    </p>
  )
}

export function MessageInfo({ children }: { children: ReactNode }) {
  return (
    <p className="message message-info" role="status">
      {children}
    </p>
  )
}

export function Chargement() {
  return (
    <div className="chargement" role="status">
      Chargement…
    </div>
  )
}
