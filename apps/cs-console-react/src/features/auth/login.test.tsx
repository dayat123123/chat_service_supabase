import { AuthError } from '@supabase/supabase-js'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type * as PresenceApiModule from '@/features/presence/api'
import { presenceApi } from '@/features/presence/api'
import type * as SupabaseModule from '@/lib/supabase'
import { agentFixture } from '@/test/fixtures'

import { LoginPage } from './components/login-page'
import { PasswordPage } from './components/password-page'
import { useAuth } from './hooks'

const auth = vi.hoisted(() => ({
  signInWithPassword: vi.fn(),
  getSession: vi.fn(),
  updateUser: vi.fn(),
  signOut: vi.fn(),
}))

vi.mock('@/lib/supabase', async (importOriginal) => {
  const actual = await importOriginal<typeof SupabaseModule>()
  return { ...actual, supabase: () => ({ auth }) }
})

vi.mock('@/features/presence/api', async (importOriginal) => {
  const actual = await importOriginal<typeof PresenceApiModule>()
  return { ...actual, presenceApi: { ...actual.presenceApi, setStatus: vi.fn() } }
})

const session = (mustChange: boolean) => ({
  data: { session: { access_token: 'token', user: { user_metadata: { must_change_password: mustChange } } } },
  error: null,
})

function Gate() {
  const phase = useAuth((state) => state.phase)
  if (phase.kind === 'password') return <PasswordPage />
  if (phase.kind === 'ready') return <p>Ruang kerja {phase.agent.display_name}</p>
  return <LoginPage idleMinutes={30} />
}

async function signIn(user: ReturnType<typeof userEvent.setup>, password: string) {
  await user.type(screen.getByLabelText('Email'), ' rina@olt.test ')
  await user.type(screen.getByLabelText('Password'), password)
  await user.click(screen.getByRole('button', { name: 'Masuk' }))
}

describe('login without TOTP', () => {
  beforeEach(() => {
    useAuth.setState({ phase: { kind: 'signedOut' }, busy: false, error: null })
    Object.values(auth).forEach((mock) => mock.mockReset())
    vi.mocked(presenceApi.setStatus).mockReset().mockResolvedValue(agentFixture)
    auth.signInWithPassword.mockResolvedValue({ data: { session: {}, user: {} }, error: null })
  })

  it('goes from email and password straight to the workspace', async () => {
    const user = userEvent.setup()
    auth.getSession.mockResolvedValue(session(false))
    render(<Gate />)

    await signIn(user, 'rahasia-sekali')

    expect(await screen.findByText('Ruang kerja Rina')).toBeInTheDocument()
    expect(auth.signInWithPassword).toHaveBeenCalledWith({
      email: 'rina@olt.test',
      password: 'rahasia-sekali',
    })
    expect(presenceApi.setStatus).toHaveBeenCalledWith('offline')
  })

  it('asks for a new password first while the temporary one is still in use', async () => {
    const user = userEvent.setup()
    auth.getSession.mockResolvedValueOnce(session(true)).mockResolvedValue(session(false))
    auth.updateUser.mockResolvedValue({ data: { user: {} }, error: null })
    render(<Gate />)

    await signIn(user, 'Sementara-12345678')
    expect(await screen.findByRole('heading', { name: 'Ganti password' })).toBeInTheDocument()
    expect(presenceApi.setStatus).not.toHaveBeenCalled()
    await user.type(screen.getByLabelText('Password baru'), 'kata-sandi-baru-123')
    await user.type(screen.getByLabelText('Ulangi password baru'), 'kata-sandi-baru-123')
    await user.click(screen.getByRole('button', { name: 'Simpan password' }))

    expect(await screen.findByText('Ruang kerja Rina')).toBeInTheDocument()
    expect(auth.updateUser).toHaveBeenCalledWith({
      password: 'kata-sandi-baru-123',
      data: { must_change_password: false },
    })
  })

  it('rejects a wrong password and stays on the login form', async () => {
    const user = userEvent.setup()
    auth.signInWithPassword.mockResolvedValue({
      data: { session: null, user: null },
      error: new AuthError('Invalid login credentials', 400, 'invalid_credentials'),
    })
    render(<Gate />)

    await signIn(user, 'salah')

    expect(await screen.findByRole('alert')).toHaveTextContent('Email atau password salah.')
    expect(auth.getSession).not.toHaveBeenCalled()
    expect(screen.getByRole('button', { name: 'Masuk' })).toBeInTheDocument()
  })
})
