export const CROP_VIEWPORT = 240
export const AVATAR_OUTPUT = 512
export const MAX_ZOOM = 4
export const SMALL_PHOTO = 256
export const MAX_PHOTO_BYTES = 15 * 1024 * 1024
export const avatarTypes = ['image/jpeg', 'image/png', 'image/webp']

export type CropState = { zoom: number; x: number; y: number }

export const initialCrop: CropState = { zoom: 1, x: 0, y: 0 }

export function coverScale(width: number, height: number, viewport = CROP_VIEWPORT) {
  return Math.max(viewport / width, viewport / height)
}

export function clampCrop(
  state: CropState,
  width: number,
  height: number,
  viewport = CROP_VIEWPORT,
): CropState {
  const zoom = Math.min(MAX_ZOOM, Math.max(1, state.zoom))
  const scale = coverScale(width, height, viewport) * zoom
  const maxX = Math.max(0, (width * scale - viewport) / 2)
  const maxY = Math.max(0, (height * scale - viewport) / 2)
  return {
    zoom,
    x: Math.min(maxX, Math.max(-maxX, state.x)),
    y: Math.min(maxY, Math.max(-maxY, state.y)),
  }
}

export function cropSource(state: CropState, width: number, height: number, viewport = CROP_VIEWPORT) {
  const scale = coverScale(width, height, viewport) * state.zoom
  const size = viewport / scale
  return {
    sx: width / 2 - state.x / scale - size / 2,
    sy: height / 2 - state.y / scale - size / 2,
    size,
  }
}

export function avatarPath(url: string, accountId: string) {
  const marker = '/storage/v1/object/public/avatars/'
  const index = url.indexOf(marker)
  if (index < 0) return null
  const path = decodeURIComponent(url.slice(index + marker.length).split('?')[0] ?? '')
  return path.startsWith(`${accountId}/`) && !path.includes('..') ? path : null
}

export function renderAvatar(image: HTMLImageElement, crop: CropState): Promise<Blob> {
  const { sx, sy, size } = cropSource(crop, image.naturalWidth, image.naturalHeight)
  const canvas = document.createElement('canvas')
  canvas.width = AVATAR_OUTPUT
  canvas.height = AVATAR_OUTPUT
  const context = canvas.getContext('2d')
  if (!context) return Promise.reject(new Error('canvas_unavailable'))
  context.fillStyle = 'white'
  context.fillRect(0, 0, AVATAR_OUTPUT, AVATAR_OUTPUT)
  context.imageSmoothingQuality = 'high'
  context.drawImage(image, sx, sy, size, size, 0, 0, AVATAR_OUTPUT, AVATAR_OUTPUT)
  return new Promise((resolve, reject) =>
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('encode_failed'))), 'image/jpeg', 0.9),
  )
}
