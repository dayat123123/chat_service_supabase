import { createMemoryHistory } from '@tanstack/react-router'
import { describe, expect, it } from 'vitest'

import type { AgentProfile } from '@/features/presence/types'
import { agentFixture, monitorFixture } from '@/test/fixtures'

import { createAppRouter } from './router'

async function open(path: string, agent: AgentProfile) {
  const router = createAppRouter(agent)
  router.update({ ...router.options, history: createMemoryHistory({ initialEntries: [path] }) })
  await router.load()
  return router.state.location
}

describe('router', () => {
  it('sends Super Admins from /analytics to the Analitik tab of Komunitas', async () => {
    const location = await open('/analytics', monitorFixture)

    expect(location.pathname).toBe('/community')
    expect(location.search).toEqual({ tab: 'analytics' })
  })

  it('keeps /analytics closed to accounts without Super Admin access', async () => {
    expect((await open('/analytics', agentFixture)).pathname).toBe('/')
  })

  it('opens Komunitas to Super Admins without community permissions, but not to plain agents', async () => {
    expect((await open('/community', monitorFixture)).pathname).toBe('/community')
    expect((await open('/community', agentFixture)).pathname).toBe('/')
  })

  it('keeps /system reachable by Super Admins while it is hidden from navigation', async () => {
    expect((await open('/system', monitorFixture)).pathname).toBe('/system')
    expect((await open('/system', agentFixture)).pathname).toBe('/')
  })
})
