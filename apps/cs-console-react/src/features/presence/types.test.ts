import { describe, expect, it } from 'vitest'

import { actionBlock, canViewTickets, isMonitor, isSuperAdmin, worksTickets, type AgentStatus } from './types'

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

describe('actionBlock', () => {
  const statuses: AgentStatus[] = ['online', 'busy', 'break', 'offline']
  const agent = (status: AgentStatus, active_tickets = 1) => ({
    status,
    active_tickets,
    max_active_tickets: 3,
  })

  it('requires Online status and a free slot to take tickets or accept transfers', () => {
    for (const action of ['claim', 'acceptTransfer'] as const) {
      expect(statuses.map((status) => actionBlock(agent(status), action))).toEqual([
        null,
        'needOnline',
        'needOnline',
        'needOnline',
      ])
      expect(actionBlock(agent('online', 3), action)).toBe('capacity')
      expect(actionBlock(agent('offline', 3), action)).toBe('needOnline')
    }
  })

  it('blocks replies to customers only while Offline', () => {
    expect(statuses.map((status) => actionBlock(agent(status), 'reply'))).toEqual([
      null,
      null,
      null,
      'offline',
    ])
    expect(actionBlock(agent('online', 3), 'reply')).toBeNull()
  })
})
