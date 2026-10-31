import type { AgentNote } from '@/features/customer/types'
import { dayLabel, jakartaDay } from '@/lib/time'

import { isSystemMessage, type ChatMessage, type PendingMessage } from './types'

const GROUP_WINDOW_MS = 2 * 60 * 1000

export type MessageRow =
  | { kind: 'day'; key: string; label: string }
  | { kind: 'message'; key: string; message: ChatMessage; first: boolean; last: boolean }
  | { kind: 'note'; key: string; note: AgentNote }
  | { kind: 'pending'; key: string; pending: PendingMessage }

type Entry = { kind: 'message'; message: ChatMessage } | { kind: 'note'; note: AgentNote }

function sameGroup(a: ChatMessage, b: ChatMessage) {
  if (isSystemMessage(a) || isSystemMessage(b)) return false
  if (a.sender_id !== b.sender_id) return false
  return Math.abs(Date.parse(b.created_at) - Date.parse(a.created_at)) < GROUP_WINDOW_MS
}

function timeline(messages: ChatMessage[], notes: AgentNote[]): Entry[] {
  const entries: Entry[] = messages.map((message) => ({ kind: 'message', message }))
  if (notes.length === 0) return entries
  const at = (entry: Entry) => (entry.kind === 'message' ? entry.message.created_at : entry.note.created_at)
  return [...entries, ...notes.map((note): Entry => ({ kind: 'note', note }))].sort((a, b) =>
    at(a).localeCompare(at(b)),
  )
}

export function buildRows(
  messages: ChatMessage[],
  pending: PendingMessage[],
  { notes = [], now = new Date() }: { notes?: AgentNote[]; now?: Date } = {},
): MessageRow[] {
  const rows: MessageRow[] = []
  let day = ''
  let previous: ChatMessage | undefined
  let previousRow: Extract<MessageRow, { kind: 'message' }> | undefined
  for (const entry of timeline(messages, notes)) {
    const createdAt = entry.kind === 'message' ? entry.message.created_at : entry.note.created_at
    const entryDay = jakartaDay(createdAt)
    if (entryDay !== day) {
      day = entryDay
      if (previousRow) previousRow.last = true
      rows.push({ kind: 'day', key: `day-${entryDay}`, label: dayLabel(createdAt, now) })
      previous = undefined
      previousRow = undefined
    }
    if (entry.kind === 'note') {
      if (previousRow) previousRow.last = true
      rows.push({ kind: 'note', key: `note-${entry.note.id}`, note: entry.note })
      previous = undefined
      previousRow = undefined
      continue
    }
    const message = entry.message
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
