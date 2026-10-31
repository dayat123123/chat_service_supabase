import { REALTIME_SUBSCRIBE_STATES, type RealtimeChannel } from '@supabase/supabase-js'
import { create } from 'zustand'

import { supabase } from '@/lib/supabase'

export type ConnectionState = 'connecting' | 'connected' | 'reconnecting' | 'offline'

export const useConnection = create<{ state: ConnectionState }>(() => ({ state: 'connecting' }))

export type TicketEvent = {
  type: 'ticket'
  event: string
  ticketId: string
  ticketNumber?: string
  roomId?: string
  status?: string
  priority?: string
  flags?: string[]
  topic?: string
  ownerId?: string | null
  ownerName?: string | null
}

export type QueueEvent =
  | TicketEvent
  | { type: 'message'; ticketId: string; roomId?: string; status?: string; messageId?: string }
  | {
      type: 'transfer'
      event: string
      ticketId: string
      ticketNumber?: string
      byName?: string
      reason?: string
    }
  | { type: 'alert'; event: string; ticketId: string; ticketNumber?: string; agentCode?: string }
  | { type: 'agent'; agentId: string; status: string }

export type RoomReceipt = { userId: string; lastReadAt: string; lastDeliveredAt: string }

export type RoomHandlers = {
  onMessage: (row: { id: string; client_id?: string | null }) => void
  onTyping: (user: { id: string; name: string }, typing: boolean) => void
  onReceipt: (receipt: RoomReceipt) => void
  onPresence: (userIds: string[]) => void
  onTicket: () => void
  onMessagesJoined: () => void
}

export type RoomHandle = { sendTyping: (typing: boolean) => void; close: () => void }

type Tracked = { channel: RealtimeChannel; joined: boolean; everJoined: boolean; core: boolean }
type Payload = Record<string, unknown>

const text = (value: unknown) => (typeof value === 'string' ? value : undefined)

export function parseQueueEvent(kind: string, payload: Payload): QueueEvent | null {
  const ticketId = text(payload.ticket_id)
  if (kind === 'agent') {
    const agentId = text(payload.agent_id)
    return agentId ? { type: 'agent', agentId, status: text(payload.status) ?? 'offline' } : null
  }
  if (!ticketId) return null
  if (kind === 'ticket' && payload.event === 'ticket_message') {
    return {
      type: 'message',
      ticketId,
      roomId: text(payload.room_id),
      status: text(payload.status),
      messageId: text(payload.message_id),
    }
  }
  if (kind === 'ticket') {
    return {
      type: 'ticket',
      event: text(payload.event) ?? 'ticket_updated',
      ticketId,
      ticketNumber: text(payload.ticket_number),
      roomId: text(payload.room_id),
      status: text(payload.status),
      priority: text(payload.priority),
      flags: Array.isArray(payload.flags)
        ? payload.flags.filter((f): f is string => typeof f === 'string')
        : undefined,
      topic: text(payload.topic),
      ownerId: text(payload.owner_id) ?? null,
      ownerName: text(payload.owner_name) ?? null,
    }
  }
  if (kind === 'transfer') {
    return {
      type: 'transfer',
      event: text(payload.event) ?? 'transfer_updated',
      ticketId,
      ticketNumber: text(payload.ticket_number),
      byName: text(payload.from_name) ?? text(payload.by_name),
      reason: text(payload.reason),
    }
  }
  if (kind === 'alert') {
    return {
      type: 'alert',
      event: text(payload.event) ?? 'alert',
      ticketId,
      ticketNumber: text(payload.ticket_number),
      agentCode: text(payload.agent_code),
    }
  }
  return null
}

class RealtimeManager {
  private readonly tracked = new Map<string, Tracked>()
  private readonly listeners = new Set<(event: QueueEvent) => void>()
  private readonly resyncListeners = new Set<() => void>()
  private resyncTimer: number | undefined
  private started = false

  start(agentId: string, viewsTickets: boolean) {
    this.stop()
    this.started = true
    window.addEventListener('online', this.onOnline)
    window.addEventListener('offline', this.recompute)
    if (viewsTickets) {
      this.open('cs:queue', true, (channel) =>
        channel
          .on('broadcast', { event: 'ticket' }, ({ payload }) => this.emit('ticket', payload as Payload))
          .on('broadcast', { event: 'alert' }, ({ payload }) => this.emit('alert', payload as Payload))
          .on('broadcast', { event: 'agent' }, ({ payload }) => this.emit('agent', payload as Payload)),
      )
      this.open(`cs:agent:${agentId}`, true, (channel) =>
        channel
          .on('broadcast', { event: 'ticket' }, ({ payload }) => this.emit('ticket', payload as Payload))
          .on('broadcast', { event: 'transfer' }, ({ payload }) => this.emit('transfer', payload as Payload)),
      )
    }
    this.recompute()
  }

  stop() {
    for (const topic of [...this.tracked.keys()]) this.close(topic)
    window.removeEventListener('online', this.onOnline)
    window.removeEventListener('offline', this.recompute)
    window.clearTimeout(this.resyncTimer)
    this.started = false
    useConnection.setState({ state: 'connecting' })
  }

  subscribe(listener: (event: QueueEvent) => void) {
    this.listeners.add(listener)
    return () => {
      this.listeners.delete(listener)
    }
  }

  onResync(listener: () => void) {
    this.resyncListeners.add(listener)
    return () => {
      this.resyncListeners.delete(listener)
    }
  }

  room(
    roomId: string,
    me: { id: string; username: string; displayName: string },
    handlers: RoomHandlers,
  ): RoomHandle {
    const signals = `room:${roomId}`
    const messages = `room-messages:${roomId}`
    const status = `cs:room:${roomId}`
    const signalChannel = this.open(
      signals,
      false,
      (channel) =>
        channel
          .on('broadcast', { event: 'typing' }, ({ payload }) => {
            const data = payload as Payload
            const userId = text(data.user_id)
            if (!userId || userId === me.id) return
            handlers.onTyping(
              { id: userId, name: text(data.display_name) ?? text(data.username) ?? '' },
              data.typing === true,
            )
          })
          .on('broadcast', { event: 'receipt' }, ({ payload }) => {
            const data = payload as Payload
            const userId = text(data.user_id)
            const lastReadAt = text(data.last_read_at)
            const lastDeliveredAt = text(data.last_delivered_at)
            if (userId && lastReadAt && lastDeliveredAt && userId !== me.id) {
              handlers.onReceipt({ userId, lastReadAt, lastDeliveredAt })
            }
          })
          .on('presence', { event: 'sync' }, () => handlers.onPresence(Object.keys(channel.presenceState()))),
      { presenceKey: me.id, onJoined: (channel) => void channel.track({ user_id: me.id }) },
    )
    this.open(
      messages,
      false,
      (channel) =>
        channel.on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'messages', filter: `room_id=eq.${roomId}` },
          (change) => {
            const row = change.new as Payload | undefined
            const id = text(row?.id)
            if (id) handlers.onMessage({ id, client_id: text(row?.client_id) ?? null })
          },
        ),
      { private: false, onJoined: () => handlers.onMessagesJoined() },
    )
    this.open(status, false, (channel) =>
      channel.on('broadcast', { event: 'ticket' }, () => handlers.onTicket()),
    )
    return {
      sendTyping: (typing) => {
        void signalChannel.send({
          type: 'broadcast',
          event: 'typing',
          payload: { user_id: me.id, username: me.username, display_name: me.displayName, typing },
        })
      },
      close: () => {
        this.close(signals)
        this.close(messages)
        this.close(status)
      },
    }
  }

  private open(
    topic: string,
    core: boolean,
    setup: (channel: RealtimeChannel) => RealtimeChannel,
    options: { private?: boolean; presenceKey?: string; onJoined?: (channel: RealtimeChannel) => void } = {},
  ) {
    this.close(topic)
    const channel = supabase().channel(topic, {
      config: {
        private: options.private ?? true,
        ...(options.presenceKey ? { presence: { key: options.presenceKey } } : {}),
      },
    })
    setup(channel)
    const entry: Tracked = { channel, joined: false, everJoined: false, core }
    this.tracked.set(topic, entry)
    channel.subscribe((state) => {
      if (this.tracked.get(topic) !== entry) return
      if (state === REALTIME_SUBSCRIBE_STATES.SUBSCRIBED) {
        const recovered = entry.everJoined && !entry.joined
        entry.joined = true
        entry.everJoined = true
        options.onJoined?.(channel)
        if (recovered && entry.core) this.scheduleResync()
      } else {
        entry.joined = false
      }
      this.recompute()
    })
    return channel
  }

  private close(topic: string) {
    const entry = this.tracked.get(topic)
    if (!entry) return
    this.tracked.delete(topic)
    void supabase().removeChannel(entry.channel)
    this.recompute()
  }

  private emit(kind: string, payload: Payload) {
    const event = parseQueueEvent(kind, payload ?? {})
    if (event) this.listeners.forEach((listener) => listener(event))
  }

  private scheduleResync() {
    window.clearTimeout(this.resyncTimer)
    this.resyncTimer = window.setTimeout(() => this.resyncListeners.forEach((listener) => listener()), 400)
  }

  private readonly onOnline = () => {
    this.scheduleResync()
    this.recompute()
  }

  private readonly recompute = () => {
    if (!this.started) return
    const core = [...this.tracked.values()].filter((entry) => entry.core)
    let state: ConnectionState
    if (!navigator.onLine) state = 'offline'
    else if (core.every((entry) => entry.joined)) state = 'connected'
    else if (core.some((entry) => entry.everJoined)) state = 'reconnecting'
    else state = 'connecting'
    if (useConnection.getState().state !== state) useConnection.setState({ state })
  }
}

export const realtime = new RealtimeManager()
