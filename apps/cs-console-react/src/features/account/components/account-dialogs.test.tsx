import { AuthApiError } from '@supabase/supabase-js'
import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

import { useAuth } from '@/features/auth/hooks'
import type * as PresenceApiModule from '@/features/presence/api'
import { presenceApi } from '@/features/presence/api'
import { loadStrings } from '@/i18n'
import type * as SupabaseModule from '@/lib/supabase'
import { rpc } from '@/lib/supabase'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { findToast, Toaster } from '@/test/toast'

import { ChangePasswordDialog } from './change-password-dialog'
import { PerformanceDialog } from './performance-dialog'
import { ProfileDialog } from './profile-dialog'
import { SignOutEverywhereDialog } from './sign-out-everywhere-dialog'

const auth = vi.hoisted(() => ({
  getSession: vi.fn(),
  signInWithPassword: vi.fn(),
  updateUser: vi.fn(),
  signOut: vi.fn(),
}))

vi.mock('@/lib/supabase', async (importOriginal) => {
  const actual = await importOriginal<typeof SupabaseModule>()
  return { ...actual, supabase: () => ({ auth }), rpc: vi.fn() }
})

vi.mock('@/features/presence/api', async (importOriginal) => {
  const actual = await importOriginal<typeof PresenceApiModule>()
  return { ...actual, presenceApi: { ...actual.presenceApi, setStatus: vi.fn() } }
})

const rpcMock = vi.mocked(rpc)

beforeAll(async () => {
  await loadStrings('account')
})

beforeEach(() => {
  Object.values(auth).forEach((mock) => mock.mockReset())
  rpcMock.mockReset().mockResolvedValue({})
  vi.mocked(presenceApi.setStatus).mockReset().mockResolvedValue(agentFixture)
  auth.getSession.mockResolvedValue({
    data: { session: { access_token: 'token', user: { email: 'rina@cs.test' } } },
    error: null,
  })
  auth.signInWithPassword.mockResolvedValue({ data: { session: {}, user: {} }, error: null })
  auth.updateUser.mockResolvedValue({ data: { user: {} }, error: null })
  auth.signOut.mockResolvedValue({ error: null })
})

async function fillPassword(user: ReturnType<typeof userEvent.setup>, current: string, next: string) {
  await user.type(screen.getByLabelText('Password saat ini'), current)
  await user.type(screen.getByLabelText('Password baru'), next)
  await user.type(screen.getByLabelText('Ulangi password baru'), next)
  await user.click(screen.getByRole('button', { name: 'Ganti password' }))
}

describe('ChangePasswordDialog', () => {
  it('keeps the session and explains when the current password is wrong', async () => {
    const user = userEvent.setup()
    const onClose = vi.fn()
    auth.signInWithPassword.mockResolvedValue({
      data: { session: null, user: null },
      error: new AuthApiError('Invalid login credentials', 400, 'invalid_credentials'),
    })
    renderWithProviders(<ChangePasswordDialog open onClose={onClose} />)

    await fillPassword(user, 'salah-sekali-lama', 'password-baru-aman-1')

    expect(await screen.findByRole('alert')).toHaveTextContent('Password saat ini salah.')
    expect(auth.signInWithPassword).toHaveBeenCalledWith({
      email: 'rina@cs.test',
      password: 'salah-sekali-lama',
    })
    expect(auth.updateUser).not.toHaveBeenCalled()
    expect(auth.signOut).not.toHaveBeenCalled()
    expect(rpcMock).not.toHaveBeenCalled()
    expect(onClose).not.toHaveBeenCalled()
    expect(useAuth.getState().phase.kind).toBe('ready')
    expect(screen.getByLabelText('Password saat ini')).toHaveValue('')
  })

  it('checks the rules before calling the server', async () => {
    const user = userEvent.setup()
    renderWithProviders(<ChangePasswordDialog open onClose={vi.fn()} />)

    await fillPassword(user, 'password-lama-aman', 'password-lama-aman')
    expect(await screen.findByText('Password baru harus berbeda dari password saat ini')).toBeInTheDocument()

    await user.clear(screen.getByLabelText('Password baru'))
    await user.type(screen.getByLabelText('Password baru'), 'pendek')
    await user.click(screen.getByRole('button', { name: 'Ganti password' }))
    expect(await screen.findByText('Password minimal 12 karakter')).toBeInTheDocument()
    expect(auth.signInWithPassword).not.toHaveBeenCalled()
  })

  it('verifies, updates, signs out other sessions and records the audit in that order', async () => {
    const user = userEvent.setup()
    const onClose = vi.fn()
    renderWithProviders(
      <>
        <ChangePasswordDialog open onClose={onClose} />
        <Toaster />
      </>,
    )

    await fillPassword(user, 'password-lama-aman', 'password-baru-aman-1')

    await waitFor(() => expect(onClose).toHaveBeenCalled())
    expect(auth.updateUser).toHaveBeenCalledWith({ password: 'password-baru-aman-1' })
    expect(auth.signOut).toHaveBeenCalledWith({ scope: 'others' })
    expect(rpcMock).toHaveBeenCalledWith('agent_password_changed')
    const order = [
      auth.signInWithPassword.mock.invocationCallOrder[0],
      auth.updateUser.mock.invocationCallOrder[0],
      auth.signOut.mock.invocationCallOrder[0],
      rpcMock.mock.invocationCallOrder[0],
    ]
    expect(order).toEqual([...order].sort((a, b) => (a ?? 0) - (b ?? 0)))
    expect(JSON.stringify(rpcMock.mock.calls)).not.toContain('password-baru-aman-1')
    expect(useAuth.getState().phase.kind).toBe('ready')
    expect(
      await findToast('Password diganti. Sesi akun ini di perangkat lain sudah dikeluarkan.'),
    ).toBeTruthy()
  })

  it('warns when other sessions could not be signed out', async () => {
    const user = userEvent.setup()
    auth.signOut.mockResolvedValue({ error: new AuthApiError('gagal', 500, 'unexpected_failure') })
    renderWithProviders(
      <>
        <ChangePasswordDialog open onClose={vi.fn()} />
        <Toaster />
      </>,
    )
    vi.spyOn(console, 'warn').mockImplementation(() => undefined)

    await fillPassword(user, 'password-lama-aman', 'password-baru-aman-1')

    expect(await findToast(/sesi lain belum berhasil dikeluarkan/)).toBeTruthy()
    expect(rpcMock).toHaveBeenCalledWith('agent_password_changed')
  })

  it('explains a password GoTrue rejects as identical', async () => {
    const user = userEvent.setup()
    auth.updateUser.mockResolvedValue({
      data: { user: null },
      error: new AuthApiError('same', 422, 'same_password'),
    })
    renderWithProviders(<ChangePasswordDialog open onClose={vi.fn()} />)

    await fillPassword(user, 'password-lama-aman', 'password-baru-aman-1')

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'Password baru harus berbeda dari password saat ini.',
    )
    expect(auth.signOut).not.toHaveBeenCalled()
  })
})

describe('SignOutEverywhereDialog', () => {
  it('records the audit, goes offline, signs out globally and returns to login', async () => {
    const user = userEvent.setup()
    renderWithProviders(<SignOutEverywhereDialog open onClose={vi.fn()} />)

    await user.click(screen.getByRole('button', { name: 'Keluar dari semua perangkat' }))

    await waitFor(() => expect(useAuth.getState().phase).toEqual({ kind: 'signedOut', reason: 'manual' }))
    expect(rpcMock).toHaveBeenCalledWith('agent_signed_out_everywhere')
    expect(auth.signOut).toHaveBeenCalledWith({ scope: 'global' })
    expect(presenceApi.setStatus).toHaveBeenCalledWith('offline')
    expect(rpcMock.mock.invocationCallOrder[0]).toBeLessThan(auth.signOut.mock.invocationCallOrder[0] ?? 0)
  })

  it('stays signed in and shows the problem when the global sign-out fails', async () => {
    const user = userEvent.setup()
    auth.signOut.mockResolvedValue({ error: new AuthApiError('down', 503, 'unexpected_failure') })
    renderWithProviders(<SignOutEverywhereDialog open onClose={vi.fn()} />)

    await user.click(screen.getByRole('button', { name: 'Keluar dari semua perangkat' }))

    expect(await screen.findByRole('alert')).toBeInTheDocument()
    expect(useAuth.getState().phase.kind).toBe('ready')
    expect(auth.signOut).toHaveBeenCalledTimes(1)
  })

  it('does not touch the status of staff who do not handle tickets', async () => {
    const user = userEvent.setup()
    renderWithProviders(<SignOutEverywhereDialog open onClose={vi.fn()} />, {
      ...agentFixture,
      roles: ['compliance'],
    })

    await user.click(screen.getByRole('button', { name: 'Keluar dari semua perangkat' }))

    await waitFor(() => expect(useAuth.getState().phase.kind).toBe('signedOut'))
    expect(presenceApi.setStatus).not.toHaveBeenCalled()
  })
})

describe('ProfileDialog', () => {
  it('shows the read-only account details and who can change them', async () => {
    rpcMock.mockResolvedValue({
      id: agentFixture.id,
      agent_code: 'CS-0007',
      display_name: 'Rina',
      email: 'rina@cs.test',
      roles: ['cs_agent', 'community'],
      team: 'general',
      team_name: { id: 'Umum', en: 'General' },
      languages: ['id', 'en'],
      max_active_tickets: 5,
      nasabah_permissions: ['online_user.view'],
      community_permissions: ['community.post', 'unknown.code'],
      created_at: '2026-01-15T03:00:00Z',
      password_changed_at: '2026-11-02T02:53:24Z',
    })
    renderWithProviders(<ProfileDialog open onClose={vi.fn()} />)

    expect(await screen.findByText('rina@cs.test')).toBeInTheDocument()
    expect(rpcMock).toHaveBeenCalledWith('agent_my_profile')
    expect(screen.getByText('CS-0007')).toBeInTheDocument()
    expect(screen.getByText('CS · Komunitas')).toBeInTheDocument()
    expect(screen.getByText('Umum')).toBeInTheDocument()
    expect(screen.getByText('5 tiket')).toBeInTheDocument()
    expect(screen.getByText('Bahasa Indonesia, English')).toBeInTheDocument()
    expect(screen.getByText('Tulis postingan resmi')).toBeInTheDocument()
    expect(screen.getByText('Lihat nasabah online')).toBeInTheDocument()
    expect(screen.queryByText('unknown.code')).not.toBeInTheDocument()
    expect(screen.getByText('15 Jan 2026')).toBeInTheDocument()
    expect(screen.getByText('2 Nov 2026, 09.53 WIB')).toBeInTheDocument()
    expect(screen.getByText('Untuk mengubah data ini, hubungi Super Admin.')).toBeInTheDocument()
    expect(screen.queryByRole('textbox')).not.toBeInTheDocument()
  })

  it('says when the password change has not been recorded yet', async () => {
    rpcMock.mockResolvedValue({
      agent_code: 'CS-0008',
      display_name: 'Kirana',
      email: null,
      roles: ['compliance'],
      team: null,
      max_active_tickets: 0,
      password_changed_at: null,
    })
    renderWithProviders(<ProfileDialog open onClose={vi.fn()} />)

    expect(await screen.findByText('Belum tercatat')).toBeInTheDocument()
    expect(screen.getByText('Tanpa tim')).toBeInTheDocument()
    expect(screen.getAllByText('Tidak ada').length).toBeGreaterThanOrEqual(2)
  })
})

const statsFor = (period: string) =>
  period === '7d'
    ? {
        period: '7d',
        from: '2026-10-29',
        to: '2026-11-04',
        handled: 30,
        resolved: 27,
        active_tickets: 2,
        avg_first_response_minutes: 3.3,
        avg_resolution_minutes: 95,
        avg_rating: 4.5,
        ratings: 10,
        rating_counts: { '1': 0, '2': 1, '3': 0, '4': 2, '5': 7 },
        complaints: 1,
      }
    : {
        period: 'today',
        from: '2026-11-04',
        to: '2026-11-04',
        handled: 4,
        resolved: 3,
        active_tickets: 2,
        avg_first_response_minutes: 2,
        avg_resolution_minutes: 20,
        avg_rating: 4,
        ratings: 2,
        rating_counts: { '1': 0, '2': 0, '3': 1, '4': 0, '5': 1 },
        complaints: 0,
      }

describe('PerformanceDialog', () => {
  it('shows my numbers for today and switches period', async () => {
    const user = userEvent.setup()
    rpcMock.mockImplementation((_name, args) =>
      Promise.resolve(statsFor(String((args as { p_period?: string } | undefined)?.p_period))),
    )
    renderWithProviders(<PerformanceDialog open onClose={vi.fn()} />)

    const resolved = await screen.findByText('Tiket diselesaikan')
    const tile = (label: string) => screen.getByText(label).closest('div') as HTMLElement
    expect(rpcMock).toHaveBeenCalledWith('agent_my_stats', { p_period: 'today' })
    expect(within(resolved.closest('div') as HTMLElement).getByText('3')).toBeInTheDocument()
    expect(screen.getByText('dari 4 tiket ditangani')).toBeInTheDocument()
    expect(within(tile('Rata-rata respons pertama')).getByText('2 mnt')).toBeInTheDocument()
    expect(within(tile('Rata-rata waktu selesai')).getByText('20 mnt')).toBeInTheDocument()
    expect(within(tile('Rating rata-rata')).getByText('4,0/5')).toBeInTheDocument()
    expect(screen.getByText('2 rating')).toBeInTheDocument()
    expect(screen.getByRole('meter', { name: '5 bintang' })).toHaveAttribute(
      'aria-valuetext',
      '1 rating (50%)',
    )

    await user.click(screen.getByRole('radio', { name: '7 hari' }))

    expect(await screen.findByText('dari 30 tiket ditangani')).toBeInTheDocument()
    expect(rpcMock).toHaveBeenCalledWith('agent_my_stats', { p_period: '7d' })
    expect(within(tile('Rata-rata respons pertama')).getByText('3,3 mnt')).toBeInTheDocument()
    expect(within(tile('Rata-rata waktu selesai')).getByText('1 j 35 mnt')).toBeInTheDocument()
    expect(within(tile('Pengaduan')).getByText('1')).toBeInTheDocument()
    expect(screen.getByRole('meter', { name: '5 bintang' })).toHaveAttribute(
      'aria-valuetext',
      '7 rating (70%)',
    )
  })

  it('says so when there are no ratings yet', async () => {
    rpcMock.mockResolvedValue({ ...statsFor('today'), ratings: 0, avg_rating: null, rating_counts: {} })
    renderWithProviders(<PerformanceDialog open onClose={vi.fn()} />)

    expect(await screen.findByText('Belum ada rating di periode ini.')).toBeInTheDocument()
    expect(
      within(screen.getByText('Rating rata-rata').closest('div') as HTMLElement).getByText('–'),
    ).toBeInTheDocument()
  })
})
