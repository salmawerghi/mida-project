/**
 * Alerte sonore d'une nouvelle commande (US12) : deux notes courtes jouées
 * avec Web Audio, sans fichier son.
 *
 * Les navigateurs bloquent le son tant que la personne n'a pas cliqué dans
 * la page (règle « autoplay ») : après un F5, le son reste bloqué jusqu'au
 * premier clic. `debloquer()` doit donc être appelé pendant un clic.
 */
export interface LecteurAlerte {
  /** Joue l'alerte ; renvoie `false` si le navigateur la bloque encore. */
  jouer(): boolean
  /** À appeler pendant un clic : autorise le son pour la suite. */
  debloquer(): void
  /** Le navigateur bloque-t-il encore le son (aucun clic depuis le chargement) ? */
  bloque(): boolean
}

type AudioContextConstructeur = typeof AudioContext

export function lecteurWebAudio(): LecteurAlerte {
  const Contexte: AudioContextConstructeur | undefined =
    typeof window === 'undefined'
      ? undefined
      : (window.AudioContext ?? (window as unknown as { webkitAudioContext?: AudioContextConstructeur }).webkitAudioContext)
  let contexte: AudioContext | null = null

  function obtenir(): AudioContext | null {
    if (!Contexte) return null
    contexte ??= new Contexte()
    if (contexte.state === 'suspended') void contexte.resume().catch(() => {})
    return contexte
  }

  return {
    jouer() {
      const ctx = obtenir()
      if (!ctx || ctx.state !== 'running') return false
      // deux notes montantes (la5 puis mi6), courtes et douces
      for (const [frequence, debut] of [
        [880, 0],
        [1318.5, 0.18],
      ] as const) {
        const osc = ctx.createOscillator()
        const volume = ctx.createGain()
        osc.type = 'sine'
        osc.frequency.value = frequence
        const t = ctx.currentTime + debut
        volume.gain.setValueAtTime(0.0001, t)
        volume.gain.exponentialRampToValueAtTime(0.3, t + 0.02)
        volume.gain.exponentialRampToValueAtTime(0.0001, t + 0.35)
        osc.connect(volume).connect(ctx.destination)
        osc.start(t)
        osc.stop(t + 0.4)
      }
      return true
    },
    debloquer() {
      obtenir()
    },
    bloque() {
      if (!Contexte) return false
      if (contexte) return contexte.state !== 'running'
      // pas encore de contexte : bloqué tant que la page n'a reçu aucun clic
      const activation = (navigator as Navigator & { userActivation?: { hasBeenActive: boolean } }).userActivation
      return activation ? !activation.hasBeenActive : false
    },
  }
}

/** Préférence « alerte sonore » gardée dans le navigateur (activée par défaut). */
const cleSon = 'mida.alerte-sonore'

export function sonPrefere(): boolean {
  try {
    return localStorage.getItem(cleSon) !== 'non'
  } catch {
    return true
  }
}

export function enregistrerSonPrefere(actif: boolean): void {
  try {
    localStorage.setItem(cleSon, actif ? 'oui' : 'non')
  } catch {
    // stockage indisponible (navigation privée) : la préférence vaut pour cette visite
  }
}
