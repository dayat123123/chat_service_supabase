import { randomUUID } from 'node:crypto'

import { anonKey, apiUrl, oltUrl } from './env'

export type CustomerTicket = { id: string; ticket_number: string; room_id: string; status: string }

export type CustomerMessage = {
  id: string
  body: string
  sender_id: string | null
  client_id: string | null
  attachments: unknown[]
  kind: string
}

type SupportHome = { room_id: string | null; active: boolean; ticket: CustomerTicket | null }

async function json<T>(response: Response, label: string): Promise<T> {
  const text = await response.text()
  if (!response.ok) throw new Error(`${label} failed (${response.status}): ${text.slice(0, 300)}`)
  return (text ? JSON.parse(text) : null) as T
}

export class Customer {
  roomId = ''

  private constructor(
    readonly username: string,
    readonly userId: string,
    private readonly token: string,
  ) {}

  static async login(username: string) {
    const olt = await json<{ social_token?: string }>(
      await fetch(`${oltUrl}/api/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password: 'olt12345' }),
      }),
      `login OLT dummy ${username}`,
    )
    if (!olt.social_token) throw new Error(`The dummy OLT returned no social token for ${username}`)
    const session = await json<{ access_token: string; user: { id: string } }>(
      await fetch(`${apiUrl}/bridge/v1/exchange`, {
        method: 'POST',
        headers: { apikey: anonKey, 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: olt.social_token }),
      }),
      `exchange auth-bridge ${username}`,
    )
    return new Customer(username, session.user.id, session.access_token)
  }

  rpc<T>(name: string, args: Record<string, unknown> = {}) {
    return fetch(`${apiUrl}/rest/v1/rpc/${name}`, {
      method: 'POST',
      headers: {
        apikey: anonKey,
        Authorization: `Bearer ${this.token}`,
        'Content-Type': 'application/json',
        'Content-Profile': 'cs_api',
        'Accept-Profile': 'cs_api',
      },
      body: JSON.stringify(args),
    }).then((response) => json<T>(response, `${this.username} ${name}`))
  }

  async closeActiveTicket() {
    const home = await this.rpc<SupportHome>('support_home')
    if (home.active && home.ticket) await this.rpc('close_ticket', { p_ticket_id: home.ticket.id })
    if (home.room_id) this.roomId = home.room_id
  }

  async openTicket(firstMessage: string) {
    await this.closeActiveTicket()
    const ticket = await this.rpc<CustomerTicket>('open_ticket', {
      p_topic: 'other',
      p_language: 'id',
      p_screen: 'help',
    })
    this.roomId = ticket.room_id
    await this.send(firstMessage)
    return ticket
  }

  send(body: string, attachments: Record<string, unknown>[] = []) {
    return this.rpc<CustomerMessage[]>('send_message', {
      p_room_id: this.roomId,
      p_body: body,
      p_client_id: randomUUID(),
      p_attachments: attachments,
    })
  }

  async upload(bucket: string, extension: string, type: string, body: Buffer) {
    const path = `rooms/${this.roomId}/${this.userId}/${randomUUID()}.${extension}`
    await json(
      await fetch(`${apiUrl}/storage/v1/object/${bucket}/${path}`, {
        method: 'POST',
        headers: { apikey: anonKey, Authorization: `Bearer ${this.token}`, 'Content-Type': type },
        body: new Uint8Array(body),
      }),
      `${this.username} upload ${bucket}`,
    )
    return path
  }

  messages() {
    return this.rpc<CustomerMessage[]>('get_messages', { p_room_id: this.roomId, p_limit: 100 })
  }

  markRead() {
    return this.rpc<null>('mark_read', { p_room_id: this.roomId })
  }
}
