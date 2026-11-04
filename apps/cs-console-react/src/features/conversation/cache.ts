import type { InfiniteData } from '@tanstack/react-query'

import type { ChatMessage } from './types'

export type CachedMessage = ChatMessage & { local?: boolean }

export type MessagePages = InfiniteData<CachedMessage[], unknown>

export function compareMessages(a: ChatMessage, b: ChatMessage) {
  const time = a.created_at.localeCompare(b.created_at)
  return time !== 0 ? time : a.id.localeCompare(b.id)
}

export function orderedMessages(data: MessagePages | undefined): CachedMessage[] {
  if (!data) return []
  const byId = new Map<string, CachedMessage>()
  for (const page of data.pages) for (const message of page) byId.set(message.id, message)
  return [...byId.values()].sort(compareMessages)
}

export function newestCursor(data: MessagePages | undefined) {
  const synced = orderedMessages(data).filter((message) => !message.local)
  return synced[synced.length - 1]?.cursor
}

export const AFTER_LIMIT = 100

export const GAP_OVERLAP_MS = 10_000

const ZERO_ID = '00000000-0000-0000-0000-000000000000'

export function overlapCursor(cursor: string, overlapMs = GAP_OVERLAP_MS) {
  const at = Date.parse(cursor.split('|')[0] ?? '')
  if (Number.isNaN(at)) return cursor
  return `${new Date(at - overlapMs).toISOString()}|${ZERO_ID}`
}

export async function collectAfter(
  fetchAfter: (cursor: string) => Promise<ChatMessage[]>,
  cursor: string,
  maxPages = 5,
) {
  const messages: ChatMessage[] = []
  let next = cursor
  for (let page = 0; page < maxPages; page += 1) {
    const batch = await fetchAfter(next)
    messages.push(...batch)
    const newest = [...batch].sort(compareMessages).at(-1)
    if (batch.length < AFTER_LIMIT || !newest?.cursor) return { messages, complete: true }
    next = newest.cursor
  }
  return { messages, complete: false }
}

export function insertMessages(
  data: MessagePages | undefined,
  incoming: CachedMessage[],
): MessagePages | undefined {
  if (!data || incoming.length === 0) return data
  const updates = new Map(incoming.map((message) => [message.id, message]))
  const pages = data.pages.map((page) =>
    page.map((message) => {
      const update = updates.get(message.id)
      if (!update) return message
      updates.delete(message.id)
      return update
    }),
  )
  const fresh = [...updates.values()].sort((a, b) => compareMessages(b, a))
  if (fresh.length > 0) pages[0] = [...fresh, ...(pages[0] ?? [])]
  return { ...data, pages }
}

export function latestCustomerMessage(messages: ChatMessage[]) {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    const message = messages[i]
    if (message?.sender_role === 'customer') return message
  }
  return undefined
}
