import { describe, expect, it } from 'vitest'

import { parseQueueEvent } from './realtime'
import { reconnectDelay } from './supabase'

describe('parseQueueEvent', () => {
  it('parses ticket broadcasts', () => {
    expect(
      parseQueueEvent('ticket', {
        event: 'ticket_claimed',
        ticket_id: 't1',
        ticket_number: 'CS-1',
        room_id: 'r1',
        status: 'claimed',
        priority: 'P2',
        flags: ['vip', 3],
        topic: 'order',
        owner_id: 'a1',
        owner_name: 'Rina',
      }),
    ).toEqual({
      type: 'ticket',
      event: 'ticket_claimed',
      ticketId: 't1',
      ticketNumber: 'CS-1',
      roomId: 'r1',
      status: 'claimed',
      priority: 'P2',
      flags: ['vip'],
      topic: 'order',
      ownerId: 'a1',
      ownerName: 'Rina',
    })
  })

  it('parses customer message notifications separately', () => {
    expect(
      parseQueueEvent('ticket', {
        event: 'ticket_message',
        ticket_id: 't1',
        room_id: 'r1',
        status: 'open',
        message_id: 'm1',
      }),
    ).toEqual({
      type: 'message',
      ticketId: 't1',
      roomId: 'r1',
      status: 'open',
      messageId: 'm1',
    })
  })

  it('parses transfers, alerts and agent status', () => {
    expect(
      parseQueueEvent('transfer', { event: 'transfer_requested', ticket_id: 't1', from_name: 'Sari' }),
    ).toMatchObject({
      type: 'transfer',
      byName: 'Sari',
    })
    expect(
      parseQueueEvent('alert', { event: 'fake_cs_report', ticket_id: 't1', agent_code: 'CS9' }),
    ).toMatchObject({
      type: 'alert',
      agentCode: 'CS9',
    })
    expect(parseQueueEvent('agent', { agent_id: 'a1', status: 'busy' })).toEqual({
      type: 'agent',
      agentId: 'a1',
      status: 'busy',
    })
  })

  it('rejects payloads without the required ids', () => {
    expect(parseQueueEvent('ticket', { event: 'ticket_claimed' })).toBeNull()
    expect(parseQueueEvent('agent', { status: 'online' })).toBeNull()
    expect(parseQueueEvent('unknown', { ticket_id: 't1' })).toBeNull()
  })
})

describe('reconnectDelay', () => {
  it('backs off exponentially with jitter and a 30 second cap', () => {
    for (let tries = 1; tries <= 10; tries += 1) {
      const base = Math.min(30_000, 1_000 * 2 ** (tries - 1))
      const delay = reconnectDelay(tries)
      expect(delay).toBeGreaterThanOrEqual(base * 0.5)
      expect(delay).toBeLessThanOrEqual(base)
    }
  })
})
