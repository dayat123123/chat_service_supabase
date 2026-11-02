import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { nasabahApi } from '../api'
import type { OpeningAccount, Page } from '../types'
import { OpeningTab } from './opening-tab'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return { ...actual, nasabahApi: { ...actual.nasabahApi, openings: vi.fn(), sendOpeningEmail: vi.fn() } }
})

const row = (LoginId: string, CustId: string, Email = `${LoginId}@contoh.test`): OpeningAccount => ({
  LoginId,
  CustId,
  Name: `NAMA ${CustId}`,
  RDNAccount: '123',
  RDNBank: 'BCA',
  InvestorNo: 'SID',
  KSEIID: '',
  Email,
})

const page = (rows: OpeningAccount[], total = rows.length): Page<OpeningAccount> => ({
  rows,
  total,
  page: 1,
  perPage: 100,
  totalPages: 1,
})

const sender = { ...agentFixture, nasabah_permissions: ['opening_account.send'] }

describe('OpeningTab', () => {
  beforeEach(() => {
    vi.mocked(nasabahApi.sendOpeningEmail).mockReset().mockResolvedValue({ message: 'ok' })
    vi.mocked(nasabahApi.openings)
      .mockReset()
      .mockResolvedValue(page([row('alam', 'C001'), row('alam', 'C002'), row('budi', 'C005')], 3))
  })

  it('groups the loaded page by LoginId and expands without asking the server again', async () => {
    const user = userEvent.setup()
    renderWithProviders(<OpeningTab />, sender)

    const alam = await screen.findByRole('button', { name: 'Tampilkan rekening alam' })
    expect(screen.getAllByRole('button', { name: /^Tampilkan rekening/ })).toHaveLength(2)
    expect(screen.queryByText('C001')).not.toBeInTheDocument()
    expect(nasabahApi.openings).toHaveBeenCalledTimes(1)
    expect(nasabahApi.openings).toHaveBeenCalledWith(1, { loginId: '', custId: '' }, 100)

    await user.click(alam)
    expect(alam).toHaveAttribute('aria-expanded', 'true')
    const accounts = screen.getByRole('table', { name: 'Rekening alam' })
    expect(within(accounts).getAllByRole('row')).toHaveLength(3)
    expect(screen.getByRole('row', { name: /alam.*2 rekening/ })).toBeInTheDocument()
    expect(nasabahApi.openings).toHaveBeenCalledTimes(1)

    await user.click(within(accounts).getByRole('checkbox', { name: 'Pilih alam C002' }))
    await user.click(screen.getByRole('button', { name: 'Kirim email (1)' }))
    await user.click(within(screen.getByRole('alertdialog')).getByRole('button', { name: 'Kirim email (1)' }))
    expect(vi.mocked(nasabahApi.sendOpeningEmail).mock.calls[0]?.[0]).toMatchObject({
      LoginId: 'alam',
      CustId: 'C002',
    })

    await user.click(alam)
    expect(screen.queryByRole('table', { name: 'Rekening alam' })).not.toBeInTheDocument()
  })

  it('notes LoginIds that may continue on a neighbouring page', async () => {
    const user = userEvent.setup()
    vi.mocked(nasabahApi.openings).mockResolvedValue({
      rows: [row('alam', 'C001'), row('budi', 'C005'), row('dedi', 'C007')],
      total: 250,
      page: 2,
      perPage: 100,
      totalPages: 3,
    })
    renderWithProviders(<OpeningTab />, sender)

    await user.click(await screen.findByRole('button', { name: 'Tampilkan rekening alam' }))
    expect(screen.getByText('Sebagian rekening alam mungkin ada di halaman sebelumnya.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Tampilkan rekening dedi' }))
    expect(screen.getByText('Sebagian rekening dedi mungkin ada di halaman berikutnya.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Tampilkan rekening budi' }))
    expect(screen.queryByText(/Sebagian rekening budi/)).not.toBeInTheDocument()
    expect(nasabahApi.openings).toHaveBeenCalledTimes(1)
  })
})
