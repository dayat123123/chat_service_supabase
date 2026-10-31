import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/lib/errors'
import { monitorFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { settingsApi } from '../api'
import type { StaffAccount } from '../types'
import { AccountsSection } from './accounts-section'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return { ...actual, settingsApi: { ...actual.settingsApi, accounts: vi.fn(), resetPassword: vi.fn() } }
})

function staff(overrides: Partial<StaffAccount>): StaffAccount {
  return {
    id: 'nadia',
    agent_code: 'CS-0045',
    display_name: 'Nadia',
    email: 'nadia@olt.test',
    roles: ['cs_agent'],
    team: 'general',
    max_active_tickets: 5,
    disabled_at: null,
    status: 'online',
    active_tickets: 1,
    nasabah_permissions: [],
    created_at: '2026-10-01T02:00:00.000Z',
    ...overrides,
  }
}

const nadia = staff({})
const laras = staff({
  id: 'laras',
  agent_code: 'CS-0047',
  display_name: 'Laras',
  email: 'laras@olt.test',
  disabled_at: '2026-10-30T02:00:00.000Z',
  status: 'offline',
})
const sinta = staff({
  id: monitorFixture.id,
  agent_code: 'SA01',
  display_name: 'Sinta',
  email: 'sinta@olt.test',
  roles: ['cs_super_admin'],
})

async function confirmReset(user: ReturnType<typeof userEvent.setup>) {
  await user.click(await screen.findByRole('button', { name: 'Reset password Nadia' }))
  const confirm = screen.getByRole('alertdialog', { name: 'Reset password Nadia?' })
  await user.click(within(confirm).getByRole('button', { name: 'Reset password' }))
  return confirm
}

describe('AccountsSection', () => {
  beforeEach(() => {
    vi.mocked(settingsApi.accounts).mockReset().mockResolvedValue([sinta, nadia, laras])
    vi.mocked(settingsApi.resetPassword).mockReset()
  })

  it('offers a password reset only for other active accounts', async () => {
    renderWithProviders(<AccountsSection />, monitorFixture)

    expect(await screen.findByRole('button', { name: 'Reset password Nadia' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Reset password Laras' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Reset password Sinta' })).not.toBeInTheDocument()
    expect(screen.getByRole('cell', { name: 'Super Admin' })).toBeInTheDocument()
    expect(screen.queryByRole('columnheader', { name: '2FA' })).not.toBeInTheDocument()
  })

  it('confirms first, then shows the temporary password once with a copy button', async () => {
    const user = userEvent.setup()
    vi.mocked(settingsApi.resetPassword).mockResolvedValue({
      agent: nadia,
      temporary_password: 'Sementara-12345678',
    })
    renderWithProviders(<AccountsSection />, monitorFixture)

    await user.click(await screen.findByRole('button', { name: 'Reset password Nadia' }))
    expect(screen.getByRole('alertdialog', { name: 'Reset password Nadia?' })).toBeInTheDocument()
    expect(settingsApi.resetPassword).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Reset password' }))

    const dialog = await screen.findByRole('dialog', { name: 'Password direset' })
    expect(settingsApi.resetPassword).toHaveBeenCalledWith('nadia')
    expect(within(dialog).getByText('Sementara-12345678')).toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'Salin' }))
    expect(await navigator.clipboard.readText()).toBe('Sementara-12345678')
    expect(within(dialog).getByRole('button', { name: 'Disalin' })).toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'Selesai' }))
    expect(screen.queryByText('Sementara-12345678')).not.toBeInTheDocument()
  })

  it.each([
    ['agent_disabled', 409, 'Akun ini nonaktif. Aktifkan akun dulu, lalu reset password.'],
    ['agent_not_found', 404, 'Akun tidak ditemukan. Daftar akun dimuat ulang.'],
    ['role_forbidden', 403, 'Hanya Super Admin yang bisa mereset password.'],
  ])('explains a refused reset (%s)', async (code, status, message) => {
    const user = userEvent.setup()
    vi.mocked(settingsApi.resetPassword).mockRejectedValue(new ApiError(code, 'Pesan server', status))
    renderWithProviders(<AccountsSection />, monitorFixture)

    const confirm = await confirmReset(user)

    expect(await within(confirm).findByRole('alert')).toHaveTextContent(message)
    expect(screen.queryByRole('dialog', { name: 'Password direset' })).not.toBeInTheDocument()
    await waitFor(() => expect(settingsApi.accounts).toHaveBeenCalledTimes(2))
  })
})
