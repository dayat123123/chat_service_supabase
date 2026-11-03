import type { BundleFile, EvidenceBundle, EvidenceRow, SignedLink } from './types'

export type RetentionState = 'held' | 'expiring' | 'active'

const DAY = 86_400_000

export function retentionState(
  row: Pick<EvidenceRow, 'legal_hold' | 'retain_until'>,
  now = Date.now(),
): RetentionState {
  if (row.legal_hold) return 'held'
  return new Date(row.retain_until).getTime() - now < 30 * DAY ? 'expiring' : 'active'
}

export function fileProblem(row: Pick<EvidenceRow, 'files'>) {
  return row.files.missing + row.files.failed > 0
}

export async function sha256Bytes(data: ArrayBuffer) {
  const digest = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('')
}

export function shortHash(hash: string | null | undefined, length = 12) {
  return hash ? hash.slice(0, length) : '–'
}

export function formatBytes(size: number | null | undefined) {
  if (size === null || size === undefined) return '–'
  if (size < 1024) return `${size} B`
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`
  return `${(size / (1024 * 1024)).toFixed(1)} MB`
}

export function bundleFileName(code: string, manifestSha256: string) {
  return `bukti-${code}-${manifestSha256.slice(0, 12)}.json`
}

export function copiedFiles(files: BundleFile[]) {
  return files.filter((file) => file.status === 'copied')
}

export function bundleWithLinks(bundle: EvidenceBundle, links: SignedLink[], expiresAt: string) {
  const byObject = new Map(links.map((link) => [link.object_name, link.url]))
  return {
    ...bundle,
    download_links: {
      expires_at: expiresAt,
      note: 'URL bertanda tangan tidak termasuk dalam manifest_sha256',
      files: bundle.files
        .filter((file) => byObject.has(file.object_name))
        .map((file) => ({
          position: file.position,
          object_name: file.object_name,
          sha256: file.sha256,
          url: byObject.get(file.object_name),
        })),
    },
  }
}

export function contextText(context: Record<string, unknown>) {
  return JSON.stringify(context, null, 2)
}

export function detailValue(value: unknown): string {
  if (value === null || value === undefined) return ''
  if (typeof value === 'string') return value
  if (typeof value === 'number' || typeof value === 'boolean') return String(value)
  return JSON.stringify(value)
}

const hiddenDetails = new Set(['backfill'])

export function custodyDetails(details: Record<string, unknown>) {
  return Object.entries(details)
    .filter(
      ([key, value]) => !hiddenDetails.has(key) && value !== null && value !== undefined && value !== '',
    )
    .map(([key, value]) => `${key}: ${detailValue(value)}`)
    .join(' · ')
}

export function normalizeQuery(query: string) {
  return query.trim().replace(/\s+/g, ' ')
}
