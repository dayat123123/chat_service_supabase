import { fireEvent, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { nasabahApi } from '../api'
import type { OnlineUser } from '../types'
import { UserDialog } from './user-dialog'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return { ...actual, nasabahApi: { ...actual.nasabahApi, catalog: vi.fn(), submit: vi.fn() } }
})

const manager = { ...agentFixture, nasabah_permissions: ['online_user.manage'] }
const demoAgent = { ...agentFixture, nasabah_permissions: ['online_user.demo'] }

const submitted = () => vi.mocked(nasabahApi.submit).mock.calls[0]?.[0]

async function fillIdentity(actor: ReturnType<typeof userEvent.setup>) {
  await actor.type(screen.getByLabelText('LoginId'), 'budi.s')
  await actor.type(screen.getByLabelText('Email'), 'budi@olt.test')
  await actor.type(screen.getByLabelText('Nomor HP'), '081234567')
  fireEvent.change(screen.getByLabelText('Tanggal lahir'), { target: { value: '1990-05-17' } })
}

describe('UserDialog', () => {
  beforeEach(() => {
    vi.mocked(nasabahApi.catalog)
      .mockReset()
      .mockResolvedValue([
        { CustId: 'C001', Name: 'Budi Santoso', StaffId: 'S01', Branch: 'JKT' },
        { CustId: 'C002', Name: 'Budi Lain', StaffId: 'S01', Branch: 'JKT' },
        { CustId: 'C003', Name: 'Citra', StaffId: 'S02', Branch: 'SBY' },
      ])
    vi.mocked(nasabahApi.submit).mockReset().mockResolvedValue({ message: 'ok' })
  })

  it('links accounts in the same submission that creates a client login', async () => {
    const actor = userEvent.setup()
    renderWithProviders(<UserDialog open user={null} links={[]} onClose={() => undefined} />, manager)

    await fillIdentity(actor)
    const picker = await screen.findByRole('region', { name: 'Tambah rekening' })
    await actor.click(await within(picker).findByRole('checkbox', { name: /C001/ }))
    await actor.click(within(picker).getByRole('checkbox', { name: /C003/ }))
    expect(screen.getByRole('region', { name: 'Akan ditautkan (2)' })).toBeInTheDocument()
    expect(screen.queryByLabelText('Status akun')).not.toBeInTheDocument()

    await actor.click(screen.getByRole('button', { name: 'Kirim pengajuan' }))
    const confirm = await screen.findByRole('alertdialog', { name: 'Kirim pengajuan budi.s?' })
    expect(confirm).toHaveTextContent('2 rekening akan ditautkan.')
    expect(nasabahApi.submit).not.toHaveBeenCalled()

    await actor.click(within(confirm).getByRole('button', { name: 'Kirim pengajuan' }))
    expect(submitted()).toEqual(
      expect.objectContaining({
        LoginId: 'budi.s',
        LoginType: 1,
        ActionType: 1,
        LoginStatus: 1,
        Email: 'budi@olt.test',
        HandphoneNo: '081234567',
        BirthDate: '1990-05-17',
        AccountExpired: '',
        ArrayAccountLink: ['C001', 'C003'],
        ArrayAccountUnLink: [],
      }),
    )
  })

  it('applies the csAdmin form rules before asking for confirmation', async () => {
    const actor = userEvent.setup()
    renderWithProviders(<UserDialog open user={null} links={[]} onClose={() => undefined} />, manager)

    await actor.type(screen.getByLabelText('LoginId'), 'budi s')
    await actor.type(screen.getByLabelText('Email'), 'budi@olt')
    await actor.click(screen.getByRole('button', { name: 'Kirim pengajuan' }))

    expect(screen.getByText('LoginId 3–50 karakter: huruf, angka, titik, _, @, atau -')).toBeInTheDocument()
    expect(screen.getByText('Email wajib diisi dengan format yang valid')).toBeInTheDocument()
    expect(screen.queryByLabelText('Ulangi email')).not.toBeInTheDocument()
    expect(screen.getByText('Nomor HP wajib, 7–20 digit angka (boleh diawali +)')).toBeInTheDocument()
    expect(screen.getByLabelText('Tanggal lahir')).toHaveAttribute('aria-invalid', 'true')
    expect(screen.queryByRole('alertdialog')).not.toBeInTheDocument()

    await actor.type(screen.getByLabelText('Email'), '.test')
    expect(screen.queryByText('Email wajib diisi dengan format yang valid')).not.toBeInTheDocument()
  })

  it('takes sales codes from the account data', async () => {
    const actor = userEvent.setup()
    renderWithProviders(<UserDialog open user={null} links={[]} onClose={() => undefined} />, manager)

    await fillIdentity(actor)
    await actor.click(screen.getByRole('combobox', { name: 'Tipe akun' }))
    await actor.click(await screen.findByRole('option', { name: 'Sales' }))
    expect(screen.queryByRole('region', { name: 'Tambah rekening' })).not.toBeInTheDocument()

    const code = screen.getByLabelText('Kode sales')
    await actor.type(code, 'S99')
    await actor.click(screen.getByRole('button', { name: 'Kirim pengajuan' }))
    expect(await screen.findByText('Kode tidak ada di data rekening, pilih dari daftar')).toBeInTheDocument()

    await actor.clear(code)
    await actor.type(code, 'S02')
    await actor.click(screen.getByRole('button', { name: 'Kirim pengajuan' }))
    await actor.click(
      within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Kirim pengajuan' }),
    )
    expect(submitted()).toEqual(
      expect.objectContaining({ LoginType: 2, SalesId: 'S02', ArrayAccountLink: [], ArrayAccountUnLink: [] }),
    )
  })

  it('keeps demo-only agents on demo logins that may never expire', async () => {
    const actor = userEvent.setup()
    renderWithProviders(<UserDialog open user={null} links={[]} onClose={() => undefined} />, demoAgent)

    await fillIdentity(actor)
    expect(screen.getByRole('combobox', { name: 'Tipe akun' })).toHaveTextContent('Demo')
    expect(screen.queryByRole('region', { name: 'Tambah rekening' })).not.toBeInTheDocument()
    expect(nasabahApi.catalog).not.toHaveBeenCalled()

    await actor.click(screen.getByRole('button', { name: 'Kirim pengajuan' }))
    expect(
      screen.getByText(
        'Pilih tanggal mulai hari ini hingga paling lambat 1 Januari tiga tahun lagi, atau centang Tidak pernah kedaluwarsa',
      ),
    ).toBeInTheDocument()

    await actor.click(screen.getByRole('checkbox', { name: 'Tidak pernah kedaluwarsa' }))
    expect(screen.getByLabelText('Berlaku sampai (akun demo)')).toBeDisabled()
    await actor.click(screen.getByRole('button', { name: 'Kirim pengajuan' }))
    await actor.click(
      within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Kirim pengajuan' }),
    )
    expect(submitted()).toEqual(expect.objectContaining({ LoginType: 0, AccountExpired: '' }))
  })

  it('submits changes to an existing login with its current links', async () => {
    const actor = userEvent.setup()
    const user = {
      LoginId: 'budi',
      LoginType: 1,
      Email: 'budi@olt.test',
      Status: 3,
      Permissions: 0,
      SalesId: '',
      BirthDate: '1990-01-01 00:00:00',
      PhoneNumber: '081234567',
      AccountExpired: '',
    } as OnlineUser
    renderWithProviders(<UserDialog open user={user} links={['C001']} onClose={() => undefined} />, manager)

    expect(screen.getByLabelText('LoginId')).toBeDisabled()
    expect(await screen.findByRole('region', { name: 'Sudah tertaut (1)' })).toBeInTheDocument()
    await actor.clear(screen.getByLabelText('Email'))
    await actor.type(screen.getByLabelText('Email'), 'budi.baru@olt.test')

    await actor.click(screen.getByRole('button', { name: 'Kirim pengajuan' }))
    await actor.click(
      within(await screen.findByRole('alertdialog')).getByRole('button', { name: 'Kirim pengajuan' }),
    )
    expect(submitted()).toEqual(
      expect.objectContaining({
        ActionType: 2,
        LoginStatus: 3,
        Email: 'budi.baru@olt.test',
        ArrayAccountLink: [],
        ArrayAccountUnLink: [],
      }),
    )
  })
})
