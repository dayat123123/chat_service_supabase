import { formatNumber } from '@/lib/time'

import { IMAGE_TYPES, MAX_FILE_BYTES, type Attachment } from './types'

export const DOCUMENT_BUCKET = 'cs-documents'
export const DOCUMENT_TYPES = ['application/pdf']
export const MAX_DOCUMENT_BYTES = 10 * 1024 * 1024
export const ATTACHMENT_TYPES = [...IMAGE_TYPES, ...DOCUMENT_TYPES]

export type MediaProblem = 'badType' | 'tooLarge'

export const isDocumentFile = (file: File) => DOCUMENT_TYPES.includes(file.type)

export const isDocument = (attachment: Pick<Attachment, 'bucket' | 'mime'>) =>
  attachment.bucket === DOCUMENT_BUCKET || attachment.mime === 'application/pdf'

export function mediaLimit(file: File) {
  if (IMAGE_TYPES.includes(file.type)) return MAX_FILE_BYTES
  return isDocumentFile(file) ? MAX_DOCUMENT_BYTES : null
}

export function mediaProblem(file: File): MediaProblem | null {
  const limit = mediaLimit(file)
  if (limit === null) return 'badType'
  return file.size > limit ? 'tooLarge' : null
}

const units = ['B', 'KB', 'MB']

export function fileSize(bytes: number | null | undefined) {
  if (bytes === null || bytes === undefined) return ''
  let value = bytes
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit += 1
  }
  return `${formatNumber(value, unit === 0 || value >= 10 ? 0 : 1)} ${units[unit]}`
}
