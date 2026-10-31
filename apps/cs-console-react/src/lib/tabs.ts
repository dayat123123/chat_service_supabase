import { uuid } from '@/lib/utils'

type Envelope =
  | { kind: 'alive' | 'bye'; id: string; scope: string | null; startedAt: number }
  | { kind: 'event'; id: string; scope: string | null; startedAt: number; topic: string; data: unknown }

type Peer = { startedAt: number; seenAt: number }

const ALIVE_MS = 4_000
const STALE_MS = 12_000

export class TabCoordinator {
  readonly id = uuid()
  readonly startedAt = Date.now()
  private readonly peers = new Map<string, Peer>()
  private readonly leaderListeners = new Set<(leader: boolean) => void>()
  private readonly topicListeners = new Map<string, Set<(data: unknown) => void>>()
  private channel: BroadcastChannel | null = null
  private timer: number | undefined
  private leader = true
  private scope: string | null = null

  start() {
    if (this.channel || typeof BroadcastChannel === 'undefined') return
    this.channel = new BroadcastChannel('cs-console.tabs')
    this.channel.onmessage = (event: MessageEvent<Envelope>) => this.receive(event.data)
    this.announce('alive')
    this.timer = window.setInterval(() => {
      this.announce('alive')
      this.prune()
    }, ALIVE_MS)
    window.addEventListener('pagehide', this.onHide)
  }

  stop() {
    this.announce('bye')
    window.removeEventListener('pagehide', this.onHide)
    window.clearInterval(this.timer)
    this.channel?.close()
    this.channel = null
    this.peers.clear()
    this.updateLeader()
  }

  setScope(scope: string | null) {
    if (scope === this.scope) return
    this.announce('bye')
    this.scope = scope
    this.peers.clear()
    this.updateLeader()
    this.announce('alive')
  }

  isLeader() {
    return this.leader
  }

  otherTabs() {
    this.prune()
    return this.peers.size
  }

  onLeaderChange(listener: (leader: boolean) => void) {
    this.leaderListeners.add(listener)
    listener(this.leader)
    return () => {
      this.leaderListeners.delete(listener)
    }
  }

  send(topic: string, data: unknown) {
    this.post({ kind: 'event', id: this.id, scope: this.scope, startedAt: this.startedAt, topic, data })
  }

  listen(topic: string, listener: (data: unknown) => void) {
    const set = this.topicListeners.get(topic) ?? new Set()
    set.add(listener)
    this.topicListeners.set(topic, set)
    return () => {
      set.delete(listener)
    }
  }

  private readonly onHide = () => this.announce('bye')

  private announce(kind: 'alive' | 'bye') {
    this.post({ kind, id: this.id, scope: this.scope, startedAt: this.startedAt })
  }

  private post(message: Envelope) {
    this.channel?.postMessage(message)
  }

  private receive(message: Envelope) {
    if (message.id === this.id) return
    if (message.kind === 'bye' || message.scope !== this.scope) {
      if (this.peers.delete(message.id)) this.updateLeader()
      return
    }
    const known = this.peers.has(message.id)
    this.peers.set(message.id, { startedAt: message.startedAt, seenAt: Date.now() })
    if (!known) this.announce('alive')
    this.updateLeader()
    if (message.kind === 'event')
      this.topicListeners.get(message.topic)?.forEach((listener) => listener(message.data))
  }

  private prune() {
    const now = Date.now()
    for (const [id, peer] of this.peers) {
      if (now - peer.seenAt > STALE_MS) this.peers.delete(id)
    }
    this.updateLeader()
  }

  private updateLeader() {
    let leader = true
    for (const [id, peer] of this.peers) {
      if (peer.startedAt < this.startedAt || (peer.startedAt === this.startedAt && id < this.id))
        leader = false
    }
    if (leader === this.leader) return
    this.leader = leader
    this.leaderListeners.forEach((listener) => listener(leader))
  }
}

export const tabs = new TabCoordinator()
