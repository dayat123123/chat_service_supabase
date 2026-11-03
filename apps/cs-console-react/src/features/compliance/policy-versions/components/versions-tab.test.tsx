import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { policyVersionsApi } from '../api'
import type { PolicyChange, PolicyState, PolicyVersion, Simulation } from '../types'
import { VersionsTab } from './versions-tab'

vi.mock('../api', () => ({
  policyVersionsApi: {
    state: vi.fn(),
    discard: vi.fn(),
    submit: vi.fn(),
    changes: vi.fn(),
    change: vi.fn(),
    decide: vi.fn(),
    withdraw: vi.fn(),
    versions: vi.fn(),
    version: vi.fn(),
    rollback: vi.fn(),
    simulate: vi.fn(),
    fourEyes: vi.fn(),
    setFourEyes: vi.fn(),
  },
}))

const kirana = { ...agentFixture, roles: ['compliance'], display_name: 'Kirana' }

const at = '2026-11-03T02:00:00.000Z'

const draftDiff = {
  total: 2,
  sections: {
    banned_words: {
      added: 1,
      removed: 0,
      changed: 0,
      items: [{ key: 'judol', op: 'added' as const, to: 'block' }],
    },
    content_rules: {
      added: 0,
      removed: 0,
      changed: 1,
      items: [
        {
          key: 'other_link',
          op: 'changed' as const,
          from: { action: 'allow', scope: 'public' },
          to: { action: 'hold', scope: 'public' },
        },
      ],
    },
  },
}

const current: PolicyVersion = {
  version: 4,
  source: 'change',
  reason: 'Ketatkan tautan',
  change_id: 3,
  restored_from: null,
  created_by: { id: 'laras', name: 'Laras' },
  created_at: at,
  summary: { total: 1, sections: { promo_phrases: { added: 1, removed: 0, changed: 0 } } },
  current: true,
}

const state: PolicyState = {
  four_eyes: true,
  current,
  draft: { id: 9, base_version: 4, created_at: at, updated_at: at, diff: draftDiff },
  pending: 1,
  pending_mine: 0,
  pending_to_review: 1,
}

const pending: PolicyChange = {
  id: 7,
  kind: 'edit',
  status: 'pending',
  base_version: 4,
  rollback_to: null,
  reason: 'Tambah frasa sinyal berbayar',
  created_by: { id: 'laras', name: 'Laras' },
  created_at: at,
  updated_at: at,
  submitted_at: at,
  decided_by: null,
  decided_at: null,
  decision_note: null,
  applied_version: null,
  mine: false,
  can_decide: true,
  stale: false,
  diff: { total: 1, sections: { promo_phrases: { added: 1, removed: 0, changed: 0 } } },
}

const older: PolicyVersion = {
  ...current,
  version: 1,
  source: 'baseline',
  reason: 'Versi awal',
  change_id: null,
  created_by: null,
  current: false,
}

const simulation: Simulation = {
  target: { kind: 'draft', id: 9, summary: draftDiff },
  sample: {
    surface: 'post',
    current: { action: 'allow', categories: [] },
    draft: { action: 'block', categories: ['banned_words'] },
  },
  content: {
    days: 7,
    limit: 300,
    scanned: 12,
    current: { allow: 12, censor: 0, hold: 0, block: 0 },
    draft: { allow: 10, censor: 0, hold: 1, block: 1 },
    changed: 2,
    stricter: 2,
    looser: 0,
    items: [
      {
        type: 'post',
        id: 'p1',
        surface: 'post',
        excerpt: 'main judol yuk',
        created_at: at,
        current: { action: 'allow', categories: [] },
        draft: { action: 'block', categories: ['banned_words'] },
      },
    ],
  },
  images: {
    scanned: 3,
    current: { allow: 0, hold: 3, block: 0 },
    draft: { allow: 1, hold: 2, block: 0 },
    changed: 1,
  },
}

function renderTab() {
  return renderWithProviders(
    <>
      <VersionsTab />
      <Toaster />
    </>,
    kirana,
  )
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(policyVersionsApi.state).mockResolvedValue(state)
  vi.mocked(policyVersionsApi.changes).mockImplementation((status) =>
    Promise.resolve(status === 'pending' ? [pending] : []),
  )
  vi.mocked(policyVersionsApi.versions).mockResolvedValue({ rows: [current, older], next: null })
})

describe('policy versions tab', () => {
  it('shows the draft diff and requires a reason before submitting', async () => {
    const user = userEvent.setup()
    vi.mocked(policyVersionsApi.submit).mockResolvedValue({
      ...pending,
      id: 9,
      mine: true,
      can_decide: false,
    })
    renderTab()

    const draft = (await screen.findByRole('heading', { name: 'Draf perubahan Anda' })).closest('section')!
    expect(within(draft).getByText('judol')).toBeVisible()
    expect(within(draft).getByText('Tautan lain')).toBeVisible()
    expect(within(draft).getByText(/Izinkan, Publik saja →/)).toBeVisible()

    await user.click(within(draft).getByRole('button', { name: 'Ajukan untuk persetujuan' }))
    expect(within(draft).getByText('Alasan minimal 5 karakter.')).toBeVisible()
    expect(policyVersionsApi.submit).not.toHaveBeenCalled()

    await user.type(within(draft).getByLabelText('Alasan perubahan'), 'Blokir judi online')
    await user.click(within(draft).getByRole('button', { name: 'Ajukan untuk persetujuan' }))
    await waitFor(() => expect(policyVersionsApi.submit).toHaveBeenCalledWith('Blokir judi online'))
    expect(await screen.findByText('Draf diajukan untuk persetujuan')).toBeVisible()
  })

  it('approves and rejects pending requests with notes', async () => {
    const user = userEvent.setup()
    vi.mocked(policyVersionsApi.decide).mockResolvedValue({
      ...pending,
      status: 'approved',
      applied_version: 5,
    })
    renderTab()

    await user.click(await screen.findByRole('button', { name: 'Tolak' }))
    const reject = screen.getByRole('dialog', { name: 'Tolak Perubahan #7?' })
    await user.click(within(reject).getByRole('button', { name: 'Tolak' }))
    expect(within(reject).getByText('Isi alasan 5–500 karakter.')).toBeVisible()
    expect(policyVersionsApi.decide).not.toHaveBeenCalled()
    await user.click(within(reject).getByRole('button', { name: 'Batal' }))

    await user.click(screen.getByRole('button', { name: 'Setujui' }))
    const approve = screen.getByRole('dialog', { name: 'Setujui Perubahan #7?' })
    await user.click(within(approve).getByRole('button', { name: 'Setujui' }))
    await waitFor(() => expect(policyVersionsApi.decide).toHaveBeenCalledWith(7, true, ''))
    expect(await screen.findByText('Perubahan #7 disetujui, berlaku sebagai v5')).toBeVisible()
  })

  it('restores an older version with a reason after showing what changes', async () => {
    const user = userEvent.setup()
    vi.mocked(policyVersionsApi.version).mockResolvedValue({
      ...older,
      diff: { total: 0, sections: {} },
      restore: {
        total: 1,
        sections: {
          banned_words: {
            added: 0,
            removed: 1,
            changed: 0,
            items: [{ key: 'judol', op: 'removed', from: 'block' }],
          },
        },
      },
      sizes: {
        banned_words: 0,
        content_rules: 9,
        blocked_domains: 0,
        allowed_domains: 0,
        allowlist: 0,
        promo_phrases: 0,
        settings: 0,
        image_thresholds: 0,
      },
    })
    vi.mocked(policyVersionsApi.rollback).mockResolvedValue({
      ...pending,
      id: 10,
      kind: 'rollback',
      rollback_to: 1,
      mine: true,
      can_decide: false,
    })
    renderTab()

    await user.click(await screen.findByRole('button', { name: 'Pulihkan v1' }))
    const dialog = screen.getByRole('dialog', { name: 'Pulihkan v1?' })
    expect(await within(dialog).findByText('judol')).toBeVisible()
    await user.click(within(dialog).getByRole('button', { name: 'Ajukan pemulihan' }))
    expect(within(dialog).getByText('Alasan minimal 5 karakter.')).toBeVisible()
    await user.type(within(dialog).getByLabelText('Alasan pemulihan'), 'Salah blokir massal')
    await user.click(within(dialog).getByRole('button', { name: 'Ajukan pemulihan' }))
    await waitFor(() => expect(policyVersionsApi.rollback).toHaveBeenCalledWith(1, 'Salah blokir massal'))
    expect(await screen.findByText('Pemulihan ke v1 diajukan')).toBeVisible()
  })

  it('simulates the draft against a sample and recent content', async () => {
    const user = userEvent.setup()
    vi.mocked(policyVersionsApi.simulate).mockResolvedValue(simulation)
    renderTab()

    const draft = (await screen.findByRole('heading', { name: 'Draf perubahan Anda' })).closest('section')!
    await user.click(within(draft).getByRole('button', { name: 'Simulasi' }))
    const dialog = screen.getByRole('dialog', { name: 'Simulasi kebijakan' })
    await user.type(within(dialog).getByLabelText('Contoh teks (opsional)'), 'main judol yuk')
    await user.click(within(dialog).getByRole('button', { name: 'Jalankan simulasi' }))

    await waitFor(() =>
      expect(policyVersionsApi.simulate).toHaveBeenCalledWith({
        target: { kind: 'draft' },
        text: 'main judol yuk',
        surface: 'post',
        days: 7,
      }),
    )
    const result = await within(dialog).findByRole('region', { name: 'Hasil simulasi' })
    expect(within(result).getByText('2 berubah perlakuan')).toBeVisible()
    expect(within(result).getAllByText('Kategori: kata terlarang').length).toBeGreaterThan(0)
    expect(within(result).getByText('Lebih ketat')).toBeVisible()
    expect(within(result).getByText('Tahan: 3 → 2')).toBeVisible()
  })
})
