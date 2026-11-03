import type * as RouterModule from '@tanstack/react-router'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

import { loadStrings } from '@/i18n'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { evidenceApi } from '../api'
import type { EvidenceDetail, EvidencePage as Page, EvidenceRow } from '../types'
import { EvidencePage } from './evidence-page'

const route = vi.hoisted(() => {
  const search: { id?: string } = {}
  return { search, navigate: vi.fn() }
})

vi.mock('@tanstack/react-router', async (importOriginal) => {
  const actual = await importOriginal<typeof RouterModule>()
  return {
    ...actual,
    getRouteApi: () => ({ useSearch: () => route.search, useNavigate: () => route.navigate }),
  }
})

vi.mock('../api', () => ({
  evidenceApi: {
    list: vi.fn(),
    detail: vi.fn(),
    verify: vi.fn(),
    fileChecked: vi.fn(),
    setHold: vi.fn(),
    exportBundle: vi.fn(),
    signedUrl: vi.fn(),
    fileHash: vi.fn(),
  },
}))

const evidenceId = '11111111-1111-4111-8111-111111111111'
const hash = 'a'.repeat(64)

const row: EvidenceRow = {
  id: evidenceId,
  code: 'EV-000149',
  seq: 149,
  source: 'report',
  target_type: 'post',
  target_id: '22222222-2222-4222-8222-222222222222',
  author: { id: 'u1', username: 'budi', display_name: 'Budi' },
  captured_at: '2026-11-03T05:00:00.000Z',
  retain_until: '2028-11-02T05:00:00.000Z',
  legal_hold: false,
  hold: null,
  files: { total: 1, copied: 1, pending: 0, missing: 0, failed: 0 },
  links: 2,
}

const page = (canManage: boolean): Page => ({
  rows: [row],
  next: null,
  can_manage: canManage,
  summary: { total: 1, held: 0, expiring: 0, pending_files: 0, problem_files: 0, retention_days: 730 },
})

const detail = (canManage: boolean): EvidenceDetail => ({
  ...row,
  custody: [
    {
      id: 2,
      at: '2026-11-03T05:10:00.000Z',
      action: 'viewed',
      actor_type: 'agent',
      actor_roles: ['compliance'],
      actor: { id: 'k1', display_name: 'Kirana', agent_code: 'KP-01' },
      details: {},
      entry_sha256: 'b'.repeat(64),
    },
  ],
  content: {
    target_type: 'post',
    target_id: row.target_id,
    author_id: 'u1',
    body: 'Saham ABCD pasti naik 300%',
    attachments: [],
  },
  context: { post: { id: row.target_id } },
  content_sha256: hash,
  body_sha256: 'c'.repeat(64),
  record_sha256: 'd'.repeat(64),
  captured_by: null,
  files_detail: [
    {
      id: 9,
      position: 1,
      bucket: 'evidence',
      object_name: `${evidenceId}/01-bukti.png`,
      source_bucket: 'attachments',
      source_name: 'posts/u1/bukti.png',
      meta: {},
      status: 'copied',
      sha256: hash,
      size: 11,
      copied_at: '2026-11-03T05:01:00.000Z',
      failures: 0,
      error: null,
    },
  ],
  reports: [],
  can_manage: canManage,
})

beforeAll(async () => {
  await loadStrings('evidence')
})

beforeEach(() => {
  vi.clearAllMocks()
  delete route.search.id
})

describe('EvidencePage', () => {
  it('lists evidence with its retention and copied files, and opens the detail', async () => {
    vi.mocked(evidenceApi.list).mockResolvedValue(page(true))
    renderWithProviders(<EvidencePage />, { ...agentFixture, roles: ['compliance'] })

    expect(await screen.findByRole('button', { name: 'Buka bukti EV-000149' })).toBeInTheDocument()
    expect(screen.getByText('1/1 tersalin')).toBeInTheDocument()
    expect(screen.getByText('2 kejadian')).toBeInTheDocument()
    expect(screen.getByText('730 hari')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Buka bukti EV-000149' }))
    expect(route.navigate).toHaveBeenCalled()
  })

  it('shows the content, hashes, and custody, and lets Compliance place a legal hold', async () => {
    route.search.id = evidenceId
    vi.mocked(evidenceApi.list).mockResolvedValue(page(true))
    vi.mocked(evidenceApi.detail).mockResolvedValue(detail(true))
    vi.mocked(evidenceApi.setHold).mockResolvedValue({
      ...row,
      legal_hold: true,
      hold: { reason: 'Permintaan penyidik nomor 12', at: '2026-11-03T06:00:00.000Z', by: null },
      custody: detail(true).custody,
    })
    renderWithProviders(
      <>
        <EvidencePage />
        <Toaster />
      </>,
      { ...agentFixture, roles: ['compliance'] },
    )

    expect(await screen.findByText('Saham ABCD pasti naik 300%')).toBeInTheDocument()
    expect(evidenceApi.detail).toHaveBeenCalledTimes(1)
    expect(screen.getByText('Dibuka')).toBeInTheDocument()
    expect(screen.getAllByText(`SHA-256 ${hash}`)).toHaveLength(1)

    await userEvent.click(screen.getByRole('button', { name: 'Pasang legal hold' }))
    await userEvent.type(
      screen.getByLabelText('Alasan (mis. nomor surat permintaan penyidik)'),
      'Permintaan penyidik nomor 12',
    )
    const buttons = screen.getAllByRole('button', { name: 'Pasang legal hold' })
    await userEvent.click(buttons[buttons.length - 1] as HTMLElement)

    await waitFor(() =>
      expect(evidenceApi.setHold).toHaveBeenCalledWith(evidenceId, true, 'Permintaan penyidik nomor 12'),
    )
    expect(await screen.findByText('Legal hold dipasang')).toBeInTheDocument()
  })

  it('keeps Super Admin read-only', async () => {
    route.search.id = evidenceId
    vi.mocked(evidenceApi.list).mockResolvedValue(page(false))
    vi.mocked(evidenceApi.detail).mockResolvedValue(detail(false))
    renderWithProviders(<EvidencePage />, { ...agentFixture, roles: ['cs_super_admin'] })

    expect(await screen.findByText('Saham ABCD pasti naik 300%')).toBeInTheDocument()
    expect(screen.getByText(/Mode baca/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Periksa integritas' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Pasang legal hold' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Ekspor paket bukti' })).not.toBeInTheDocument()
  })
})
