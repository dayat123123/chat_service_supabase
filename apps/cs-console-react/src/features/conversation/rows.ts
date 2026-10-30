import { dayLabel, jakartaDay } from '@/lib/time'

import { isSystemMessage, type ChatMessage, type PendingMessage } from './types'

const GROUP_WINDOW_MS = 5 * 60 * 1000

export type MessageRow =
  | { kind: 'day'; key: string; label: string }
  | { kind: 'message'; key: string; message: ChatMessage; first: boolean; last: boolean }
  | { kind: 'pending'; key: string; pending: PendingMessage }

function sameGroup(a: ChatMessage, b: ChatMessage) {
  if (isSystemMessage(a) || isSystemMessage(b)) return false
  if (a.sender_id !== b.sender_id) return false
  return Math.abs(Date.parse(b.created_at) - Date.parse(a.created_at)) < GROUP_WINDOW_MS
}

export function buildRows(
  messages: ChatMessage[],
  pending: PendingMessage[],
  now: Date = new Date(),
): MessageRow[] {
  const rows: MessageRow[] = []
  let day = ''
  let previous: ChatMessage | undefined
  let previousRow: Extract<MessageRow, { kind: 'message' }> | undefined
  for (const message of messages) {
    const messageDay = jakartaDay(message.created_at)
    if (messageDay !== day) {
      day = messageDay
      if (previousRow) previousRow.last = true
      rows.push({ kind: 'day', key: `day-${messageDay}`, label: dayLabel(message.created_at, now) })
      previous = undefined
      previousRow = undefined
    }
    const first = !previous || !sameGroup(previous, message)
    if (previousRow && first) previousRow.last = true
    const row = { kind: 'message' as const, key: message.id, message, first, last: false }
    rows.push(row)
    previous = message
    previousRow = row
  }
  if (previousRow) previousRow.last = true
  for (const item of pending) rows.push({ kind: 'pending', key: `pending-${item.clientId}`, pending: item })
  return rows
}
