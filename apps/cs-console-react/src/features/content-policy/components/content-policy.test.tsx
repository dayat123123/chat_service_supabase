import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import { contentPolicyApi } from '../api'
import type { ContentRules, ImageThresholds } from '../types'
import { DomainsTab } from './domains-tab'
import { ImagesTab } from './images-tab'
import { RulesTab } from './rules-tab'
import { TesterTab } from './tester-tab'

vi.mock('../api', () => ({
  contentPolicyApi: {
    rules: vi.fn(),
    setRule: vi.fn(),
    saveBlocked: vi.fn(),
    deleteBlocked: vi.fn(),
    saveAllowed: vi.fn(),
    deleteAllowed: vi.fn(),
    addTerm: vi.fn(),
    deleteTerm: vi.fn(),
    addPhrase: vi.fn(),
    deletePhrase: vi.fn(),
    setNewAccountDays: vi.fn(),
    test: vi.fn(),
    imageThresholds: vi.fn(),
    setImageThresholds: vi.fn(),
    manipulation: vi.fn(),
    setManipulation: vi.fn(),
  },
}))

const kirana = { ...agentFixture, roles: ['compliance'], display_name: 'Kirana' }

const rules: ContentRules = {
  categories: [
    {
      category: 'gambling',
      action: 'block',
      scope: 'all',
      updated_at: '2026-11-03T01:00:00.000Z',
      updated_by: null,
    },
    {
      category: 'shortener',
      action: 'hold',
      scope: 'public',
      updated_at: '2026-11-03T01:00:00.000Z',
      updated_by: null,
    },
  ],
  blocked_domains: [
    {
      domain: 'bit.ly',
      match: 'domain',
      category: 'shortener',
      action: null,
      note: null,
      created_at: '2026-11-03T01:00:00.000Z',
    },
  ],
  allowed_domains: [{ domain: 'idx.co.id', note: null, created_at: '2026-11-03T01:00:00.000Z' }],
  allowlist: [],
  promo_phrases: [{ phrase: 'grup vip', created_at: '2026-11-03T01:00:00.000Z' }],
  new_account_days: 3,
}

const thresholds: ImageThresholds = {
  revision: 4,
  thresholds: { porn: { hold: 0.5, block: 0.9 }, hentai: { hold: 0.6, block: 0.95 }, sexy: { hold: 0.85 } },
  categories: ['drawings', 'hentai', 'neutral', 'porn', 'sexy'],
  updated_at: '2026-11-03T01:00:00.000Z',
  updated_by: 'Kirana',
}

function renderWith(ui: React.ReactElement) {
  return renderWithProviders(
    <>
      {ui}
      <Toaster />
    </>,
    kirana,
  )
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(contentPolicyApi.rules).mockResolvedValue(rules)
  vi.mocked(contentPolicyApi.imageThresholds).mockResolvedValue(thresholds)
})

describe('content policy', () => {
  it('changes a category action and scope', async () => {
    const user = userEvent.setup()
    vi.mocked(contentPolicyApi.setRule).mockResolvedValue(rules)
    renderWith(<RulesTab />)

    await user.click(await screen.findByRole('combobox', { name: 'Aksi untuk Pemendek tautan' }))
    await user.click(await screen.findByRole('option', { name: 'Blokir' }))
    await waitFor(() => expect(contentPolicyApi.setRule).toHaveBeenCalledWith('shortener', 'block', 'public'))
    expect(await screen.findByText('Pemendek tautan: Blokir, Publik saja')).toBeVisible()
  })

  it('keeps hold at or below block and requires a pornography threshold', async () => {
    const user = userEvent.setup()
    vi.mocked(contentPolicyApi.setImageThresholds).mockResolvedValue({ ...thresholds, revision: 5 })
    renderWith(<ImagesTab />)

    const hentaiHold = await screen.findByLabelText('Ambang tahan Hentai (%)')
    await user.clear(hentaiHold)
    await user.type(hentaiHold, '97')
    await user.clear(screen.getByLabelText('Ambang tahan Pornografi (%)'))
    await user.clear(screen.getByLabelText('Ambang blokir Pornografi (%)'))
    await user.click(screen.getByRole('button', { name: 'Simpan' }))

    expect(screen.getByText('Ambang tahan tidak boleh lebih tinggi dari ambang blokir.')).toBeVisible()
    expect(screen.getByText('Pornografi wajib punya ambang tahan atau blokir.')).toBeVisible()
    expect(contentPolicyApi.setImageThresholds).not.toHaveBeenCalled()

    await user.clear(hentaiHold)
    await user.type(hentaiHold, '70')
    await user.type(screen.getByLabelText('Ambang blokir Pornografi (%)'), '85')
    await user.type(screen.getByLabelText('Catatan perubahan'), 'Kurangi salah tahan')
    await user.click(screen.getByRole('button', { name: 'Simpan' }))

    await waitFor(() =>
      expect(contentPolicyApi.setImageThresholds).toHaveBeenCalledWith(
        { porn: { block: 0.85 }, hentai: { hold: 0.7, block: 0.95 }, sexy: { hold: 0.85 } },
        'Kurangi salah tahan',
      ),
    )
  })

  it('cleans a pasted link before blocking the domain', async () => {
    const user = userEvent.setup()
    vi.mocked(contentPolicyApi.saveBlocked).mockResolvedValue(rules)
    renderWith(<DomainsTab />)

    await user.click(await screen.findByRole('button', { name: 'Tambah domain' }))
    const dialog = screen.getByRole('dialog', { name: 'Tambah domain diblokir' })
    await user.type(within(dialog).getByLabelText('Domain'), 'bit.ly')
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))
    expect(within(dialog).getByText('Sudah ada di daftar.')).toBeVisible()

    await user.clear(within(dialog).getByLabelText('Domain'))
    await user.type(within(dialog).getByLabelText('Domain'), 'https://www.Judi-Baru.com/promo')
    expect(within(dialog).getByText('Disimpan sebagai judi-baru.com')).toBeVisible()
    await user.click(within(dialog).getByRole('combobox', { name: 'Kategori' }))
    await user.click(await screen.findByRole('option', { name: 'Judi' }))
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))

    await waitFor(() =>
      expect(contentPolicyApi.saveBlocked).toHaveBeenCalledWith({
        domain: 'judi-baru.com',
        match: 'domain',
        category: 'gambling',
        action: null,
        note: null,
      }),
    )
  })

  it('shows the tester result with action, categories, links, and normalized text', async () => {
    const user = userEvent.setup()
    vi.mocked(contentPolicyApi.test).mockResolvedValue({
      action: 'hold',
      categories: ['messenger', 'phone'],
      links: true,
      body: 'Gabung t.me/grup atau WA 0812 3456 7890',
      banned_words: 'censor',
      normalized: 'gabung t me grup atau wa',
    })
    renderWith(<TesterTab />)

    await user.click(screen.getByRole('button', { name: 'Uji' }))
    expect(screen.getByText('Isi teks 1–4000 karakter.')).toBeVisible()
    expect(contentPolicyApi.test).not.toHaveBeenCalled()

    await user.type(screen.getByLabelText('Teks'), 'Gabung t.me/grup atau WA 0812 3456 7890')
    await user.click(screen.getByRole('combobox', { name: 'Tempat' }))
    await user.click(await screen.findByRole('option', { name: 'Room saham' }))
    await user.click(screen.getByRole('button', { name: 'Uji' }))

    await waitFor(() =>
      expect(contentPolicyApi.test).toHaveBeenCalledWith('Gabung t.me/grup atau WA 0812 3456 7890', 'stock'),
    )
    const result = await screen.findByRole('region', { name: 'Hasil uji' })
    expect(within(result).getByText('Tahan')).toBeVisible()
    expect(within(result).getByText('Disensor')).toBeVisible()
    expect(within(result).getByText('Grup chat & messenger, Nomor HP')).toBeVisible()
    expect(within(result).getByText('Ada tautan tidak tepercaya')).toBeVisible()
    expect(within(result).getByText('gabung t me grup atau wa')).toBeVisible()
  })
})
