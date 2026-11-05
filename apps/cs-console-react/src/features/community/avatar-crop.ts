export const CROP_VIEWPORT = 240
export const AVATAR_OUTPUT = 512
export const MAX_ZOOM = 4
export const SMALL_PHOTO = 256
export const MAX_PHOTO_BYTES = 15 * 1024 * 1024
export const avatarTypes = ['image/jpeg', 'image/png', 'image/webp']

export type CropState = { zoom: number; x: number; y: number }
export type CropFrame = { width: number; height: number }

export const initialCrop: CropState = { zoom: 1, x: 0, y: 0 }
export const avatarFrame: CropFrame = { width: CROP_VIEWPORT, height: CROP_VIEWPORT }

const square = (viewport: number): CropFrame => ({ width: viewport, height: viewport })

export function frameScale(width: number, height: number, frame: CropFrame) {
  return Math.max(frame.width / width, frame.height / height)
}

export function clampFrameCrop(state: CropState, width: number, height: number, frame: CropFrame): CropState {
  const zoom = Math.min(MAX_ZOOM, Math.max(1, state.zoom))
  const scale = frameScale(width, height, frame) * zoom
  const maxX = Math.max(0, (width * scale - frame.width) / 2)
  const maxY = Math.max(0, (height * scale - frame.height) / 2)
  return {
    zoom,
    x: Math.min(maxX, Math.max(-maxX, state.x)),
    y: Math.min(maxY, Math.max(-maxY, state.y)),
  }
}

export function frameSource(state: CropState, width: number, height: number, frame: CropFrame) {
  const scale = frameScale(width, height, frame) * state.zoom
  const sw = frame.width / scale
  const sh = frame.height / scale
  return {
    sx: width / 2 - state.x / scale - sw / 2,
    sy: height / 2 - state.y / scale - sh / 2,
    sw,
    sh,
  }
}

export function coverScale(width: number, height: number, viewport = CROP_VIEWPORT) {
  return frameScale(width, height, square(viewport))
}

export function clampCrop(
  state: CropState,
  width: number,
  height: number,
  viewport = CROP_VIEWPORT,
): CropState {
  return clampFrameCrop(state, width, height, square(viewport))
}

export function cropSource(state: CropState, width: number, height: number, viewport = CROP_VIEWPORT) {
  const { sx, sy, sw } = frameSource(state, width, height, square(viewport))
  return { sx, sy, size: sw }
}

export function avatarPath(url: string, accountId: string) {
  const marker = '/storage/v1/object/public/avatars/'
  const index = url.indexOf(marker)
  if (index < 0) return null
  const path = decodeURIComponent(url.slice(index + marker.length).split('?')[0] ?? '')
  return path.startsWith(`${accountId}/`) && !path.includes('..') ? path : null
}

export function renderCrop(
  image: HTMLImageElement,
  crop: CropState,
  frame: CropFrame,
  output: CropFrame,
): Promise<Blob> {
  const { sx, sy, sw, sh } = frameSource(crop, image.naturalWidth, image.naturalHeight, frame)
  const canvas = document.createElement('canvas')
  canvas.width = output.width
  canvas.height = output.height
  const context = canvas.getContext('2d')
  if (!context) return Promise.reject(new Error('canvas_unavailable'))
  context.fillStyle = 'white'
  context.fillRect(0, 0, output.width, output.height)
  context.imageSmoothingQuality = 'high'
  context.drawImage(image, sx, sy, sw, sh, 0, 0, output.width, output.height)
  return new Promise((resolve, reject) =>
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('encode_failed'))), 'image/jpeg', 0.9),
  )
}
