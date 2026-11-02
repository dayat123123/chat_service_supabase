import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { parseQueueEvent, realtime, useConnection, type QueueEvent, type RoomHandlers } from './realtime'
import type * as SupabaseModule from './supabase'
import { reconnectDelay } from './supabase'

type Binding = { type: string; event?: string; handler: (message: { payload: unknown }) => void }

class FakeChannel {
  state: 'closed' | 'joining' | 'joined' | 'leaving' = 'closed'
  readonly bindings: Binding[] = []
  readonly sent: unknown[] = []
  private readonly callbacks: ((state: string) => void)[] = []

  constructor(
    readonly topic: string,
    private readonly socket: FakeRealtime,
  ) {}

  on(type: string, filter: { event?: string }, handler: Binding['handler']) {
    this.bindings.push({ type, event: filter.event, handler })
    return this
  }

  subscribe(callback: (state: string) => void) {
    if (this.state !== 'closed') return this
    this.callbacks.push(callback)
    this.state = 'joining'
    queueMicrotask(() => {
      if (this.state !== 'joining') return
      this.state = 'joined'
      callback('SUBSCRIBED')
    })
    return this
  }

  send(message: unknown) {
    this.sent.push(message)
    return Promise.resolve('ok')
  }

  track() {
    return Promise.resolve('ok')
  }

  presenceState() {
    return {}
  }

  broadcast(event: string, payload: unknown) {
    this.bindings
      .filter((binding) => binding.type === 'broadcast' && binding.event === event)
      .forEach((binding) => binding.handler({ payload }))
  }

  closed() {
    this.state = 'closed'
    this.socket.forget(this)
    this.callbacks.forEach((callback) => callback('CLOSED'))
  }
}

class FakeRealtime {
  channels: FakeChannel[] = []
  private leaves: (() => void)[] = []

  channel(topic: string) {
    const existing = this.channels.find((channel) => channel.topic === topic)
    if (existing) return existing
    const created = new FakeChannel(topic, this)
    this.channels.push(created)
    return created
  }

  removeChannel(channel: FakeChannel) {
    channel.state = 'leaving'
    return new Promise<string>((resolve) => {
      this.leaves.push(() => {
        channel.closed()
        resolve('ok')
      })
    })
  }

  forget(channel: FakeChannel) {
    this.channels = this.channels.filter((item) => item !== channel)
  }

  finishLeaves() {
    const leaves = this.leaves
    this.leaves = []
    leaves.forEach((leave) => leave())
  }

  joined(topic: string) {
    return this.channels.find((channel) => channel.topic === topic && channel.state === 'joined')
  }
}

const fake = vi.hoisted(() => ({ client: undefined as FakeRealtime | undefined }))

vi.mock('@/lib/supabase', async (importOriginal) => ({
  ...(await importOriginal<typeof SupabaseModule>()),
  supabase: () => fake.client,
}))

const me = { id: 'a1', username: 'CS-0001', displayName: 'Nadia' }

function roomHandlers(): RoomHandlers {
  return {
    onMessage: vi.fn(),
    onTyping: vi.fn(),
    onReceipt: vi.fn(),
    onPresence: vi.fn(),
    onTicket: vi.fn(),
    onMessagesJoined: vi.fn(),
  }
}

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
        version: 4,
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
      version: 4,
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

describe('realtime manager', () => {
  let socket: FakeRealtime

  beforeEach(() => {
    vi.useFakeTimers()
    socket = new FakeRealtime()
    fake.client = socket
  })

  afterEach(() => {
    realtime.stop()
    socket.finishLeaves()
    vi.useRealTimers()
  })

  it('rejoins a core channel the server closed and keeps delivering its events', async () => {
    const events: QueueEvent[] = []
    const stop = realtime.subscribe((event) => events.push(event))
    realtime.start('a1', true)
    await vi.advanceTimersByTimeAsync(0)
    expect(useConnection.getState().state).toBe('connected')

    socket.joined('cs:agent:a1')!.closed()
    expect(useConnection.getState().state).toBe('reconnecting')

    await vi.advanceTimersByTimeAsync(30_000)
    expect(useConnection.getState().state).toBe('connected')
    socket.joined('cs:agent:a1')!.broadcast('transfer', { event: 'transfer_requested', ticket_id: 't1' })
    expect(events).toEqual([expect.objectContaining({ type: 'transfer', ticketId: 't1' })])
    stop()
  })

  it('leaves typing and presence out of rooms the agent only watches', async () => {
    const room = realtime.room('r1', me, roomHandlers(), { signals: false })
    await vi.advanceTimersByTimeAsync(0)

    expect(socket.channels.map((channel) => channel.topic).sort()).toEqual(['cs:room:r1', 'room-messages:r1'])
    room.sendTyping(true)
    expect(socket.channels.flatMap((channel) => channel.sent)).toEqual([])
  })

  it('joins a room again only after the previous channel for that room has left', async () => {
    const handlers = roomHandlers()
    realtime.room('r1', me, handlers, { signals: true }).close()
    const room = realtime.room('r1', me, handlers, { signals: true })
    await vi.advanceTimersByTimeAsync(0)

    socket.finishLeaves()
    await vi.advanceTimersByTimeAsync(0)

    expect(handlers.onMessagesJoined).toHaveBeenCalledTimes(1)
    room.sendTyping(true)
    expect(socket.joined('room:r1')!.sent).toHaveLength(1)
  })
})
