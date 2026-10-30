import type { InfiniteData } from '@tanstack/react-query'

import type { ChatMessage } from './types'

export type MessagePages = InfiniteData<ChatMessage[], unknown>

export function compareMessages(a: ChatMessage, b: ChatMessage) {
  const time = a.created_at.localeCompare(b.created_at)
  return time !== 0 ? time : a.id.localeCompare(b.id)
}

export function orderedMessages(data: MessagePages | undefined): ChatMessage[] {
  if (!data) return []
  const byId = new Map<string, ChatMessage>()
  for (const page of data.pages) for (const message of page) byId.set(message.id, message)
  return [...byId.values()].sort(compareMessages)
}

export function newestCursor(data: MessagePages | undefined) {
  const ordered = orderedMessages(data)
  return ordered[ordered.length - 1]?.cursor
}

export function insertMessages(
  data: MessagePages | undefined,
  incoming: ChatMessage[],
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
