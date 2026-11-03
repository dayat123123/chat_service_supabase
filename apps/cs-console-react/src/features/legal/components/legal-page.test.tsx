import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/lib/errors'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { legalApi } from '../api'
import type { LegalDocument, LegalDraft, LegalOverview } from '../types'
import { LegalPage } from './legal-page'

vi.mock('../api', () => ({
  legalApi: {
    overview: vi.fn(),
    document: vi.fn(),
    draft: vi.fn(),
    save: vi.fn(),
    submit: vi.fn(),
    withdraw: vi.fn(),
    reject: vi.fn(),
    approve: vi.fn(),
    remove: vi.fn(),
    cancelScheduled: vi.fn(),
    setRequired: vi.fn(),
  },
}))

const kirana = { ...agentFixture, roles: ['compliance'], display_name: 'Kirana' }
const dewi = '99999999-9999-4999-8999-999999999999'
const body =
  'Pasal 1. Pengguna wajib menjaga kerahasiaan akun.\nPasal 2. Data pribadi dilindungi sesuai hukum.'

const termsV2: LegalDocument = {
  id: 'doc-terms-2',
  kind: 'terms',
  version: 2,
  title: 'Syarat dan Ketentuan Komunitas',
  effective_at: '2026-10-01T03:00:00.000Z',
  created_at: '2026-09-30T03:00:00.000Z',
  created_by: 'Kirana',
  approved_by: 'Dewi',
  in_effect: true,
  accepted: 750,
}

const privacyScheduled: LegalDocument = {
  id: 'doc-privacy-1',
  kind: 'privacy',
  version: 1,
  title: 'Kebijakan Privasi',
  effective_at: '2027-01-01T00:00:00.000Z',
  created_at: '2026-11-01T03:00:00.000Z',
  in_effect: false,
  accepted: 0,
}

const pendingDraft = (overrides: Partial<LegalDraft> = {}): LegalDraft => ({
  id: 'draft-1',
  kind: 'terms',
  title: 'Syarat dan Ketentuan v3',
  body,
  body_length: body.length,
  change_summary: 'Menambah pasal data pribadi',
  status: 'pending',
  created_by: 'Dewi',
  created_by_id: dewi,
  created_at: '2026-11-02T02:00:00.000Z',
  updated_by: 'Dewi',
  updated_by_id: dewi,
  updated_at: '2026-11-02T02:00:00.000Z',
  submitted_by: 'Dewi',
  submitted_at: '2026-11-02T03:00:00.000Z',
  ...overrides,
})

function overview(overrides: Partial<LegalOverview> = {}): LegalOverview {
  return {
    active_users: 1000,
    reviewers: 2,
    four_eyes: true,
    required_kinds: ['community_guidelines', 'terms'],
    kinds: [
      { kind: 'terms', required: true, current: termsV2, scheduled: null, history: [termsV2] },
      { kind: 'community_guidelines', required: true, current: null, scheduled: null, history: [] },
      {
        kind: 'privacy',
        required: false,
        current: null,
        scheduled: privacyScheduled,
        history: [privacyScheduled],
      },
    ],
    drafts: [],
    ...overrides,
  }
}

function renderPage() {
  return renderWithProviders(
    <>
      <LegalPage />
      <Toaster />
    </>,
    kirana,
  )
}

beforeEach(() => {
  vi.clearAllMocks()
})

describe('LegalPage', () => {
  it('shows the version in effect with its acceptance and cancels a scheduled version after confirming', async () => {
    const user = userEvent.setup()
    vi.mocked(legalApi.overview).mockResolvedValue(overview())
    vi.mocked(legalApi.cancelScheduled).mockResolvedValue({ draft: 'draft-9' })
    renderPage()

    const terms = await screen.findByRole('region', { name: 'Syarat & Ketentuan' })
    expect(within(terms).getByText('Syarat dan Ketentuan Komunitas')).toBeInTheDocument()
    expect(within(terms).getByText('Disetujui oleh Dewi')).toBeInTheDocument()
    expect(within(terms).getByRole('meter', { name: /Persetujuan pengguna/ })).toHaveAttribute(
      'aria-valuenow',
      '75',
    )
    expect(
      within(terms).getByText('750 dari 1.000 pengguna aktif sudah menyetujui (75%)'),
    ).toBeInTheDocument()
    expect(
      within(screen.getByRole('region', { name: 'Pedoman Komunitas' })).getByText(
        'Belum ada versi yang berlaku.',
      ),
    ).toBeInTheDocument()

    const privacy = screen.getByRole('region', { name: 'Kebijakan Privasi' })
    expect(within(privacy).getByText(/Terjadwal: versi 1/)).toBeInTheDocument()
    await user.click(within(privacy).getByRole('button', { name: 'Batalkan jadwal' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(dialog).toHaveTextContent('kembali menjadi draf')
    await user.click(within(dialog).getByRole('button', { name: 'Batalkan jadwal' }))

    await waitFor(() => expect(legalApi.cancelScheduled).toHaveBeenCalledWith('doc-privacy-1'))
    expect(await screen.findByText(/Jadwal dibatalkan/)).toBeInTheDocument()
  })

  it('confirms before making a document mandatory and sends the full set', async () => {
    const user = userEvent.setup()
    vi.mocked(legalApi.overview).mockResolvedValue(overview())
    vi.mocked(legalApi.setRequired).mockResolvedValue(['terms', 'community_guidelines', 'privacy'])
    renderPage()

    const privacy = await screen.findByRole('region', { name: 'Kebijakan Privasi' })
    await user.click(within(privacy).getByRole('switch', { name: 'Wajib disetujui' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(dialog).toHaveTextContent('Wajibkan Kebijakan Privasi?')
    expect(legalApi.setRequired).not.toHaveBeenCalled()
    await user.click(within(dialog).getByRole('button', { name: 'Wajibkan' }))

    await waitFor(() =>
      expect(legalApi.setRequired).toHaveBeenCalledWith(['terms', 'community_guidelines', 'privacy']),
    )
  })

  it('warns how many users would be blocked when a document with a current version becomes mandatory', async () => {
    const user = userEvent.setup()
    vi.mocked(legalApi.overview).mockResolvedValue(
      overview({
        required_kinds: ['community_guidelines'],
        kinds: overview().kinds.map((kind) => (kind.kind === 'terms' ? { ...kind, required: false } : kind)),
      }),
    )
    renderPage()

    const terms = await screen.findByRole('region', { name: 'Syarat & Ketentuan' })
    await user.click(within(terms).getByRole('switch', { name: 'Wajib disetujui' }))
    expect(await screen.findByRole('alertdialog')).toHaveTextContent(
      'Saat ini 250 pengguna aktif belum menyetujui',
    )
  })

  it('does not let the author approve their own draft while four eyes applies', async () => {
    const user = userEvent.setup()
    const mine = pendingDraft({ created_by: 'Kirana', created_by_id: kirana.id, updated_by_id: kirana.id })
    vi.mocked(legalApi.overview).mockResolvedValue(overview({ drafts: [mine] }))
    vi.mocked(legalApi.draft).mockResolvedValue(mine)
    renderPage()

    await user.click(await screen.findByRole('button', { name: 'Buka draf Syarat dan Ketentuan v3' }))
    const approve = await screen.findByRole('button', { name: 'Setujui & terbitkan' })
    expect(approve).toBeDisabled()
    expect(approve).toHaveAccessibleDescription(/staf kepatuhan lain yang harus menyetujuinya/)
    expect(screen.queryByRole('button', { name: 'Tolak' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Tarik kembali' })).toBeEnabled()
  })

  it('lets another officer approve after a confirmation that explains users must accept again', async () => {
    const user = userEvent.setup()
    vi.mocked(legalApi.overview).mockResolvedValue(overview({ drafts: [pendingDraft()] }))
    vi.mocked(legalApi.draft).mockResolvedValue(pendingDraft())
    vi.mocked(legalApi.approve).mockResolvedValue({ ...termsV2, id: 'doc-terms-3', version: 3 })
    renderPage()

    await user.click(await screen.findByRole('button', { name: 'Buka draf Syarat dan Ketentuan v3' }))
    const sheet = await screen.findByRole('dialog')
    expect(within(sheet).getByRole('region', { name: 'Pratinjau dokumen' })).toHaveTextContent('Pasal 2.')
    await user.click(within(sheet).getByRole('button', { name: 'Setujui & terbitkan' }))
    const dialog = await screen.findByRole('alertdialog')
    expect(dialog).toHaveTextContent('semua pengguna harus menyetujui versi baru')
    expect(dialog).not.toHaveTextContent('persetujuan sendiri')
    await user.click(within(dialog).getByRole('button', { name: 'Setujui & terbitkan' }))

    await waitFor(() => expect(legalApi.approve).toHaveBeenCalledWith('draft-1'))
    expect(await screen.findByText('Versi baru terbit dan langsung berlaku.')).toBeInTheDocument()
  })

  it('allows a lone compliance officer to self-approve with a clear audit warning', async () => {
    const user = userEvent.setup()
    const mine = pendingDraft({ created_by_id: kirana.id, updated_by_id: kirana.id })
    vi.mocked(legalApi.overview).mockResolvedValue(
      overview({ four_eyes: false, reviewers: 1, drafts: [mine] }),
    )
    vi.mocked(legalApi.draft).mockResolvedValue(mine)
    renderPage()

    expect(await screen.findByText(/Hanya ada 1 staf kepatuhan aktif/)).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Buka draf Syarat dan Ketentuan v3' }))
    await user.click(await screen.findByRole('button', { name: 'Setujui & terbitkan' }))
    expect(await screen.findByRole('alertdialog')).toHaveTextContent('persetujuan sendiri (self_approved)')
  })

  it('explains why a version cannot be approved while another is scheduled', async () => {
    const user = userEvent.setup()
    vi.mocked(legalApi.overview).mockResolvedValue(overview({ drafts: [pendingDraft()] }))
    vi.mocked(legalApi.draft).mockResolvedValue(pendingDraft())
    vi.mocked(legalApi.approve).mockRejectedValue(new ApiError('legal_scheduled_exists', 'Sudah ada', 409))
    renderPage()

    await user.click(await screen.findByRole('button', { name: 'Buka draf Syarat dan Ketentuan v3' }))
    await user.click(await screen.findByRole('button', { name: 'Setujui & terbitkan' }))
    await user.click(
      within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Setujui & terbitkan' }),
    )

    expect(
      await screen.findByText(/Batalkan jadwalnya dulu sebelum menyetujui versi lain/),
    ).toBeInTheDocument()
  })

  it('validates a new draft, previews line breaks, and saves the WIB date as UTC', async () => {
    const user = userEvent.setup()
    vi.mocked(legalApi.overview).mockResolvedValue(overview())
    vi.mocked(legalApi.save).mockImplementation((input) =>
      Promise.resolve({
        ...pendingDraft(),
        id: 'draft-new',
        status: 'draft',
        kind: input.kind,
        title: input.title,
        body: input.body,
        effective_at: input.effectiveAt ?? undefined,
        created_by_id: kirana.id,
        updated_by_id: kirana.id,
      }),
    )
    renderPage()

    await user.click(await screen.findByRole('button', { name: 'Draf baru' }))
    const sheet = await screen.findByRole('dialog')
    await user.click(within(sheet).getByRole('button', { name: 'Simpan draf' }))
    expect(within(sheet).getByText('Judul 3–150 karakter.')).toBeInTheDocument()
    expect(within(sheet).getByLabelText('Isi dokumen')).toHaveAttribute('aria-invalid', 'true')
    expect(legalApi.save).not.toHaveBeenCalled()

    await user.type(within(sheet).getByLabelText('Judul'), 'Syarat dan Ketentuan v3')
    await user.type(within(sheet).getByLabelText('Isi dokumen'), body)
    expect(within(sheet).getByText(`${body.length} karakter (min. 50, maks. 100.000)`)).toBeInTheDocument()
    await user.type(within(sheet).getByLabelText('Tanggal berlaku (WIB)'), '2030-01-01T09:00')

    await user.click(within(sheet).getByRole('radio', { name: 'Pratinjau' }))
    const preview = within(sheet).getByRole('region', { name: 'Pratinjau dokumen' })
    expect(preview.querySelector('p.whitespace-pre-wrap')?.textContent).toBe(body)

    await user.click(within(sheet).getByRole('button', { name: 'Simpan draf' }))
    await waitFor(() =>
      expect(legalApi.save).toHaveBeenCalledWith({
        id: null,
        kind: 'terms',
        title: 'Syarat dan Ketentuan v3',
        body,
        changeSummary: '',
        effectiveAt: '2030-01-01T02:00:00.000Z',
      }),
    )
    expect(await screen.findByText('Draf disimpan.')).toBeInTheDocument()
  })

  it('starts a new draft from the version in effect', async () => {
    const user = userEvent.setup()
    vi.mocked(legalApi.overview).mockResolvedValue(overview())
    vi.mocked(legalApi.document).mockResolvedValue({ ...termsV2, body })
    renderPage()

    const terms = await screen.findByRole('region', { name: 'Syarat & Ketentuan' })
    await user.click(within(terms).getByRole('button', { name: 'Buat dari versi berlaku' }))

    const sheet = await screen.findByRole('dialog')
    expect(within(sheet).getByLabelText('Judul')).toHaveValue('Syarat dan Ketentuan Komunitas')
    expect(within(sheet).getByLabelText('Isi dokumen')).toHaveValue(body)
    expect(legalApi.document).toHaveBeenCalledWith('doc-terms-2')
  })

  it('asks before throwing away unsaved edits', async () => {
    const user = userEvent.setup()
    vi.mocked(legalApi.overview).mockResolvedValue(overview())
    renderPage()

    await user.click(await screen.findByRole('button', { name: 'Draf baru' }))
    const sheet = await screen.findByRole('dialog')
    await user.type(within(sheet).getByLabelText('Judul'), 'Draf')
    await user.keyboard('{Escape}')

    const dialog = await screen.findByRole('alertdialog')
    expect(dialog).toHaveTextContent('Tutup tanpa menyimpan?')
    await user.click(within(dialog).getByRole('button', { name: 'Buang perubahan' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
  })
})
