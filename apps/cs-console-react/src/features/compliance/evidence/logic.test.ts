import { describe, expect, it } from 'vitest'

import {
  bundleFileName,
  bundleWithLinks,
  copiedFiles,
  custodyDetails,
  fileProblem,
  formatBytes,
  normalizeQuery,
  retentionState,
  sha256Bytes,
  shortHash,
} from './logic'
import type { EvidenceBundle } from './types'

const now = Date.parse('2026-11-03T00:00:00Z')

describe('retentionState', () => {
  it('puts legal hold before the retention date', () => {
    expect(retentionState({ legal_hold: true, retain_until: '2026-11-04T00:00:00Z' }, now)).toBe('held')
  })

  it('flags evidence that expires within 30 days', () => {
    expect(retentionState({ legal_hold: false, retain_until: '2026-11-20T00:00:00Z' }, now)).toBe('expiring')
    expect(retentionState({ legal_hold: false, retain_until: '2027-11-20T00:00:00Z' }, now)).toBe('active')
  })
})

describe('files', () => {
  it('counts missing and failed copies as a problem', () => {
    expect(fileProblem({ files: { total: 2, copied: 1, pending: 0, missing: 1, failed: 0 } })).toBe(true)
    expect(fileProblem({ files: { total: 2, copied: 1, pending: 1, missing: 0, failed: 0 } })).toBe(false)
  })

  it('formats sizes', () => {
    expect(formatBytes(null)).toBe('–')
    expect(formatBytes(512)).toBe('512 B')
    expect(formatBytes(854361)).toBe('834.3 KB')
    expect(formatBytes(10 * 1024 * 1024)).toBe('10.0 MB')
  })

  it('hashes raw bytes with SHA-256', async () => {
    const bytes = new TextEncoder().encode('abc')
    expect(await sha256Bytes(bytes.buffer)).toBe(
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    )
    expect(shortHash('ba7816bf8f01cfea414140de')).toBe('ba7816bf8f01')
    expect(shortHash(null)).toBe('–')
  })
})

describe('export bundle', () => {
  const bundle: EvidenceBundle = {
    format: 'olt-evidence-bundle/1',
    manifest_sha256: 'f'.repeat(64),
    evidence: { id: 'e1', code: 'EV-000149' },
    files: [
      {
        position: 1,
        bucket: 'evidence',
        object_name: 'e1/01-a.png',
        status: 'copied',
        sha256: 'a'.repeat(64),
        size: 3,
      },
      {
        position: 2,
        bucket: 'evidence',
        object_name: 'e1/02-b.png',
        status: 'missing',
        sha256: null,
        size: null,
      },
    ],
  }

  it('names the file after the code and manifest hash', () => {
    expect(bundleFileName('EV-000149', 'f'.repeat(64))).toBe('bukti-EV-000149-ffffffffffff.json')
  })

  it('links only the copied files and keeps the manifest untouched', () => {
    expect(copiedFiles(bundle.files).map((file) => file.position)).toEqual([1])
    const result = bundleWithLinks(
      bundle,
      [{ object_name: 'e1/01-a.png', url: 'https://cs/x?token=1' }],
      '2026-11-03T01:00:00Z',
    )
    expect(result.manifest_sha256).toBe(bundle.manifest_sha256)
    expect(result.files).toBe(bundle.files)
    expect(result.download_links.files).toEqual([
      { position: 1, object_name: 'e1/01-a.png', sha256: 'a'.repeat(64), url: 'https://cs/x?token=1' },
    ])
    expect(result.download_links.expires_at).toBe('2026-11-03T01:00:00Z')
  })
})

describe('custodyDetails', () => {
  it('lists details without empty or internal values', () => {
    expect(custodyDetails({ source: 'report', report_id: 'r1', backfill: true, note: '', files: 1 })).toBe(
      'source: report · report_id: r1 · files: 1',
    )
    expect(custodyDetails({ match: false, extra: { a: 1 } })).toBe('match: false · extra: {"a":1}')
  })

  it('normalizes the search text', () => {
    expect(normalizeQuery('  EV-000149   x ')).toBe('EV-000149 x')
  })
})
