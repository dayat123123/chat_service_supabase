import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { dismissToasts, findToast, Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { complianceApi } from '../api'
import { readWordTable, saveWorkbook } from '../banned-words-file'
import type { BannedWordList } from '../types'
import { BannedWordsPage } from './banned-words-page'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    complianceApi: {
      ...actual.complianceApi,
      bannedWords: vi.fn(),
      addBannedWord: vi.fn(),
      deleteBannedWord: vi.fn(),
      importBannedWords: vi.fn(),
    },
  }
})

vi.mock('../banned-words-file', () => ({ readWordTable: vi.fn(), saveWorkbook: vi.fn() }))

const kirana = { ...monitorFixture, display_name: 'Kirana', roles: ['compliance'] }

const list: BannedWordList = {
  limit: 2000,
  words: [
    { word: 'goblok', action: 'mask', created_at: '2026-11-01T02:00:00.000Z' },
    { word: 'jaminan profit', action: 'block', created_at: '2026-11-01T02:00:00.000Z' },
  ],
}

beforeEach(() => {
  vi.mocked(complianceApi.bannedWords).mockResolvedValue(list)
})

afterEach(dismissToasts)

function rows() {
  return screen
    .getAllByRole('row')
    .slice(1)
    .map((row) => within(row).getAllByRole('cell')[0]?.textContent)
}

describe('BannedWordsPage', () => {
  it('lists words with their count and filters by action and search', async () => {
    const user = userEvent.setup()
    renderWithProviders(<BannedWordsPage />, kirana)

    expect(await screen.findByText('2 dari maks 2.000 kata')).toBeVisible()
    expect(rows()).toEqual(['goblok', 'jaminan profit'])

    await user.click(screen.getByRole('radio', { name: 'Blokir' }))
    expect(rows()).toEqual(['jaminan profit'])

    await user.click(screen.getByRole('radio', { name: 'Semua' }))
    await user.type(screen.getByRole('searchbox', { name: 'Cari kata' }), 'GOB')
    expect(rows()).toEqual(['goblok'])
  })

  it('adds a normalized word and refuses one that already exists', async () => {
    const user = userEvent.setup()
    vi.mocked(complianceApi.addBannedWord).mockResolvedValue({
      ...list,
      words: [...list.words, { word: 'penipu', action: 'block', created_at: '2026-11-02T02:00:00.000Z' }],
    })
    renderWithProviders(<BannedWordsPage />, kirana)

    await user.click(await screen.findByRole('button', { name: 'Tambah kata' }))
    const dialog = screen.getByRole('dialog', { name: 'Tambah kata terlarang' })
    const field = within(dialog).getByLabelText('Kata atau frasa')
    await user.type(field, 'Goblok')
    expect(within(dialog).getByText('Kata ini sudah ada di daftar.')).toBeVisible()

    await user.clear(field)
    await user.type(field, 'anj*ng')
    await user.click(within(dialog).getByRole('button', { name: 'Tambah kata' }))
    expect(within(dialog).getByText('Hanya huruf, angka, dan spasi')).toBeVisible()
    expect(complianceApi.addBannedWord).not.toHaveBeenCalled()

    await user.clear(field)
    await user.type(field, '  Penipu ')
    await user.click(within(dialog).getByRole('radio', { name: /^Blokir/ }))
    await user.click(within(dialog).getByRole('button', { name: 'Tambah kata' }))
    await waitFor(() => expect(complianceApi.addBannedWord).toHaveBeenCalledWith('penipu', 'block'))
    expect(await screen.findByRole('cell', { name: 'penipu' })).toBeVisible()
  })

  it('deletes a word after confirmation', async () => {
    const user = userEvent.setup()
    vi.mocked(complianceApi.deleteBannedWord).mockResolvedValue({ ...list, words: [list.words[1]!] })
    renderWithProviders(<BannedWordsPage />, kirana)

    await user.click(await screen.findByRole('button', { name: 'Hapus goblok' }))
    const confirm = screen.getByRole('alertdialog', { name: 'Hapus “goblok”?' })
    await user.click(within(confirm).getByRole('button', { name: 'Hapus' }))
    await waitFor(() => expect(complianceApi.deleteBannedWord).toHaveBeenCalledWith('goblok'))
    await waitFor(() => expect(rows()).toEqual(['jaminan profit']))
  })

  it('previews an Excel file and imports only new words and action changes', async () => {
    const user = userEvent.setup()
    vi.mocked(readWordTable).mockResolvedValue([
      ['Kata', 'Aksi'],
      ['Penipu', 'blokir'],
      ['goblok', 'blokir'],
      ['jaminan profit', 'blokir'],
      ['x', ''],
    ])
    vi.mocked(complianceApi.importBannedWords).mockResolvedValue({
      ...list,
      added: 1,
      updated: 1,
      unchanged: 0,
    })
    renderWithProviders(
      <>
        <BannedWordsPage />
        <Toaster />
      </>,
      kirana,
    )

    await user.click(await screen.findByRole('button', { name: 'Import Excel' }))
    const dialog = screen.getByRole('dialog', { name: 'Import kata dari Excel' })
    const file = new File(['x'], 'kata.xlsx')
    await user.upload(within(dialog).getByLabelText('Pilih file'), file)

    expect(readWordTable).toHaveBeenCalledWith(file)
    expect(await within(dialog).findByRole('status')).toHaveTextContent(
      'Baru 1Aksi berubah 1Sudah ada 1Duplikat 0Tidak valid 1',
    )
    expect(within(dialog).getByText('Tidak valid · Isi 2–50 karakter')).toBeVisible()
    expect(within(dialog).getByText('Aksi berubah · sebelumnya Sensor')).toBeVisible()

    await user.click(within(dialog).getByRole('button', { name: 'Import 2 kata' }))
    await waitFor(() =>
      expect(complianceApi.importBannedWords).toHaveBeenCalledWith([
        { word: 'penipu', action: 'block' },
        { word: 'goblok', action: 'block' },
      ]),
    )
    expect(await findToast('Import selesai: 1 kata baru, 1 aksi berubah')).toBeVisible()
  })

  it('offers a template with a guide sheet', async () => {
    const user = userEvent.setup()
    vi.mocked(saveWorkbook).mockResolvedValue()
    renderWithProviders(<BannedWordsPage />, kirana)

    await user.click(await screen.findByRole('button', { name: 'Import Excel' }))
    await user.click(screen.getByRole('button', { name: 'Unduh template' }))
    const [name, workbook] = vi.mocked(saveWorkbook).mock.calls[0]!
    expect(name).toBe('template-kata-terlarang.xlsx')
    expect(workbook.map((sheet) => sheet.sheet)).toEqual(['Kata terlarang', 'Petunjuk'])
    expect(workbook[0]?.data).toEqual([['Kata', 'Aksi']])
  })
})
