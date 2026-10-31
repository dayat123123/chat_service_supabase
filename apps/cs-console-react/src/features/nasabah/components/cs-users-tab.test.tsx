import { screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { nasabahApi } from '../api'
import type { CsUser } from '../types'
import { CsUsersTab } from './cs-users-tab'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    nasabahApi: {
      ...actual.nasabahApi,
      info: vi.fn(),
      csUsers: vi.fn(),
      createCsUser: vi.fn(),
      deleteCsUser: vi.fn(),
    },
  }
})

function account(overrides: Partial<CsUser>): CsUser {
  return {
    LoginId: 'sinta',
    EmployeeId: 'E-01',
    Email: 'sinta@olt.test',
    Status: 1,
    Permissions: 5,
    Created: '2026-01-02 03:04:05',
    LastModified: '',
    LastLogin: '',
    CreatedBy: 'admin',
    ModifiedBy: '',
    ...overrides,
  }
}

describe('CsUsersTab', () => {
  beforeEach(() => {
    vi.mocked(nasabahApi.info).mockReset().mockResolvedValue({
      configured: true,
      service_login_id: 'gomi',
      actor: 'CS-0241',
      actor_mode: 'agent',
    })
    vi.mocked(nasabahApi.csUsers)
      .mockReset()
      .mockResolvedValue({
        rows: [account({ LoginId: 'gomi  ', Permissions: 511 }), account({})],
        total: 2,
        page: 1,
        perPage: 30,
        totalPages: 1,
      })
    vi.mocked(nasabahApi.createCsUser).mockReset()
    vi.mocked(nasabahApi.deleteCsUser).mockReset()
  })

  it('locks the gateway technical account and names the recorded actor for others', async () => {
    const user = userEvent.setup()
    renderWithProviders(<CsUsersTab />)

    const gomiRow = (await screen.findByRole('button', { name: 'Buka akun gomi' })).closest('tr')
    expect(gomiRow).not.toBeNull()
    expect(within(gomiRow as HTMLElement).getByText('Akun teknis gateway')).toBeInTheDocument()
    expect(within(gomiRow as HTMLElement).getByText('9 dari 9')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Buka akun gomi' }))
    const locked = await screen.findByRole('dialog')
    expect(within(locked).getByRole('button', { name: 'Ubah akun' })).toBeDisabled()
    expect(within(locked).getByRole('button', { name: 'Atur password' })).toBeDisabled()
    expect(within(locked).getByRole('button', { name: 'Hapus akun' })).toBeDisabled()
    expect(within(locked).getByText(/diatur lewat konfigurasi server/)).toBeInTheDocument()
    await user.keyboard('{Escape}')

    await user.click(screen.getByRole('button', { name: 'Buka akun sinta' }))
    const open = await screen.findByRole('dialog')
    expect(within(open).getByRole('button', { name: 'Hapus akun' })).toBeEnabled()
    expect(within(open).getByText(/atas nama CS-0241/)).toBeInTheDocument()
  })

  it('shows the generated temporary password once after creating an account', async () => {
    const user = userEvent.setup()
    vi.mocked(nasabahApi.createCsUser).mockResolvedValue({ TemporaryPassword: 'Tmp9xYzabcDEFg' })
    renderWithProviders(<CsUsersTab />)

    await user.click(await screen.findByRole('button', { name: 'Tambah akun CS' }))
    const form = screen.getByRole('dialog', { name: 'Tambah akun CS csAdmin' })
    await user.type(within(form).getByLabelText('LoginId'), 'rina.w')
    await user.type(within(form).getByLabelText('ID karyawan'), 'E-77')
    await user.type(within(form).getByLabelText('Email'), 'rina@olt.test')
    await user.click(within(form).getByRole('checkbox', { name: 'Buat Online ID' }))
    await user.click(within(form).getByRole('button', { name: 'Buat akun' }))

    expect(nasabahApi.createCsUser).toHaveBeenCalledWith({
      loginId: 'rina.w',
      employeeId: 'E-77',
      email: 'rina@olt.test',
      status: 1,
      permissions: 2,
    })
    const issued = await screen.findByRole('dialog', { name: 'Akun rina.w dibuat' })
    expect(within(issued).getByText('Tmp9xYzabcDEFg')).toBeInTheDocument()
    await user.click(within(issued).getByRole('button', { name: 'Sudah saya catat' }))
    expect(screen.queryByText('Tmp9xYzabcDEFg')).not.toBeInTheDocument()
  })
})
