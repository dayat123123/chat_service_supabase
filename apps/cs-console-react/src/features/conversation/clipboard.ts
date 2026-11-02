import { IMAGE_TYPES } from './types'

const attempts = [
  { edge: 2560, quality: 0.85 },
  { edge: 1920, quality: 0.75 },
]

export function clipboardImages(data: DataTransfer | null) {
  if (!data) return []
  return Array.from(data.items)
    .filter((item) => item.kind === 'file' && IMAGE_TYPES.includes(item.type))
    .map((item) => item.getAsFile())
    .filter((file): file is File => file !== null)
}

export function pasteBelongsElsewhere(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) return false
  return (
    target.isContentEditable ||
    target.closest(
      'input, textarea, select, [contenteditable="true"], [role="dialog"], [role="alertdialog"]',
    ) !== null
  )
}

export function scaledSize(width: number, height: number, maxEdge: number) {
  const scale = Math.min(1, maxEdge / Math.max(width, height))
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) }
}

function encode(bitmap: ImageBitmap, edge: number, quality: number) {
  const size = scaledSize(bitmap.width, bitmap.height, edge)
  const canvas = document.createElement('canvas')
  canvas.width = size.width
  canvas.height = size.height
  const context = canvas.getContext('2d')
  if (!context) return Promise.resolve(null)
  context.fillStyle = 'white'
  context.fillRect(0, 0, size.width, size.height)
  context.drawImage(bitmap, 0, 0, size.width, size.height)
  return new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', quality))
}

export async function fitImage(file: File, limit: number) {
  if (file.size <= limit || file.type === 'image/gif') return file
  let bitmap: ImageBitmap
  try {
    bitmap = await createImageBitmap(file)
  } catch {
    return file
  }
  try {
    for (const attempt of attempts) {
      const blob = await encode(bitmap, attempt.edge, attempt.quality)
      if (blob && blob.size <= limit) {
        const name = `${file.name.replace(/\.[^.]*$/, '') || 'gambar'}.jpg`
        return new File([blob], name, { type: 'image/jpeg', lastModified: file.lastModified })
      }
    }
    return file
  } finally {
    bitmap.close()
  }
}
