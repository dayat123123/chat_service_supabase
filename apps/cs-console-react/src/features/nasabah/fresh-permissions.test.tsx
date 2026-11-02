import { waitFor } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import { useAuth } from '@/features/auth/hooks'
import type * as PresenceApiModule from '@/features/presence/api'
import { presenceApi } from '@/features/presence/api'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { useFreshPermissions } from './hooks'

vi.mock('@/features/presence/api', async (importOriginal) => {
  const actual = await importOriginal<typeof PresenceApiModule>()
  return { ...actual, presenceApi: { ...actual.presenceApi, me: vi.fn() } }
})

function Probe() {
  useFreshPermissions()
  return null
}

describe('useFreshPermissions', () => {
  it('picks up permission changes made after sign-in', async () => {
    vi.mocked(presenceApi.me).mockResolvedValue({
      ...agentFixture,
      status: 'offline',
      nasabah_permissions: ['online_user.approve', 'online_user.approve_own'],
    })
    renderWithProviders(<Probe />, { ...agentFixture, nasabah_permissions: ['online_user.approve'] })

    await waitFor(() => {
      const phase = useAuth.getState().phase
      expect(phase.kind === 'ready' && phase.agent.nasabah_permissions).toEqual([
        'online_user.approve',
        'online_user.approve_own',
      ])
    })
    const phase = useAuth.getState().phase
    expect(phase.kind === 'ready' && phase.agent.status).toBe('online')
  })
})
