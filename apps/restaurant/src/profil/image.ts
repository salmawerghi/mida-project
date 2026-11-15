/** Images envoyées dans le stockage `restaurants` (mêmes limites que le bucket, migration US03). */

export const formatsImage = ['image/jpeg', 'image/png', 'image/webp']
export const tailleMaxImage = 5 * 1024 * 1024

/** `null` si le fichier peut être envoyé, sinon le message à afficher. */
export function verifierImage(fichier: { type: string; size: number }): string | null {
  if (!formatsImage.includes(fichier.type)) return 'Format non accepté : choisissez une image JPEG, PNG ou WebP.'
  if (fichier.size > tailleMaxImage) return 'Image trop lourde : 5 Mo maximum.'
  return null
}

/**
 * Réduit l'image (plus grand côté : `cote` pixels) et la convertit en WebP,
 * pour un chargement rapide côté client. Si le navigateur ne sait pas le
 * faire, l'image d'origine est envoyée telle quelle.
 */
export async function reduireImage(fichier: File, cote = 512): Promise<Blob> {
  try {
    const image = await createImageBitmap(fichier)
    const echelle = Math.min(1, cote / Math.max(image.width, image.height))
    const toile = document.createElement('canvas')
    toile.width = Math.max(1, Math.round(image.width * echelle))
    toile.height = Math.max(1, Math.round(image.height * echelle))
    toile.getContext('2d')?.drawImage(image, 0, 0, toile.width, toile.height)
    image.close()
    const webp = await new Promise<Blob | null>((fin) => toile.toBlob(fin, 'image/webp', 0.85))
    if (webp?.type === 'image/webp') return webp
  } catch {
    // navigateur sans createImageBitmap ou image illisible : on envoie l'original
  }
  return fichier
}
