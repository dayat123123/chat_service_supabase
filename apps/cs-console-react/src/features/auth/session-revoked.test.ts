import { waitFor } from '@testing-library/react'
import { createElement } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useFreshPermissions } from '@/features/nasabah/hooks'
import type * as PresenceApiModule from '@/features/presence/api'
import { presenceApi } from '@/features/presence/api'
import { errorText } from '@/lib/error-text'
import { ApiError } from '@/lib/errors'
import type * as SupabaseModule from '@/lib/supabase'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { useAuth } from './hooks'

const auth = vi.hoisted(() => ({
  getSession: vi.fn(),
  signOut: vi.fn(),
  onAuthStateChange: vi.fn(),
}))

vi.mock('@/lib/supabase', async (importOriginal) => {
  const actual = await importOriginal<typeof SupabaseModule>()
  return { ...actual, supabase: () => ({ auth }) }
})

vi.mock('@/features/presence/api', async (importOriginal) => {
  const actual = await importOriginal<typeof PresenceApiModule>()
  return { ...actual, presenceApi: { ...actual.presenceApi, me: vi.fn(), setStatus: vi.fn() } }
})

function Probe() {
  useFreshPermissions()
  return null
}

describe('revoked staff session', () => {
  beforeEach(() => {
    useAuth.setState({ phase: { kind: 'checking' }, busy: false, error: null })
    Object.values(auth).forEach((mock) => mock.mockReset())
    auth.signOut.mockResolvedValue({ error: null })
    auth.getSession.mockResolvedValue({
      data: { session: { access_token: 'token', user: { user_metadata: {} } } },
      error: null,
    })
  })

  it('clears the stored session of a tab signed out from elsewhere and shows the expired notice', async () => {
    vi.mocked(presenceApi.me).mockRejectedValue(new ApiError('session_revoked', undefined, 401))

    await useAuth.getState().start()

    expect(useAuth.getState().phase).toEqual({ kind: 'signedOut', reason: 'expired' })
    expect(auth.signOut).toHaveBeenCalledWith({ scope: 'local' })
  })

  it('sends an open tab back to login once its session was revoked elsewhere', async () => {
    vi.mocked(presenceApi.me).mockRejectedValue(new ApiError('session_revoked', undefined, 401))
    vi.mocked(presenceApi.setStatus).mockRejectedValue(new ApiError('session_revoked', undefined, 401))
    renderWithProviders(createElement(Probe), agentFixture)

    await waitFor(() => expect(useAuth.getState().phase).toEqual({ kind: 'signedOut', reason: 'expired' }))
  })

  it('describes the revoked session like an expired one', () => {
    expect(errorText(new ApiError('session_revoked', undefined, 401))).toBe(
      errorText(new ApiError('session_expired', undefined, 401)),
    )
  })
})
