import { describe, expect, it } from 'vitest'

import { canViewTickets, isMonitor, isSuperAdmin, worksTickets } from './types'

describe('staff roles', () => {
  it('lets only agents work tickets while Super Admins watch them', () => {
    const agent = { roles: ['cs_agent'] }
    const monitor = { roles: ['cs_super_admin'] }
    const both = { roles: ['cs_agent', 'cs_super_admin'] }
    const compliance = { roles: ['compliance'] }

    expect([agent, monitor, both, compliance].map(worksTickets)).toEqual([true, false, true, false])
    expect([agent, monitor, both, compliance].map(canViewTickets)).toEqual([true, true, true, false])
    expect([agent, monitor, both, compliance].map(isMonitor)).toEqual([false, true, false, false])
    expect([agent, monitor, both, compliance].map(isSuperAdmin)).toEqual([false, true, true, false])
  })
})
