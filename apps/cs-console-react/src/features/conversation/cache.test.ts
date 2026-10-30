import { describe, expect, it } from 'vitest'

import { messageFixture } from '@/test/fixtures'

import {
  insertMessages,
  latestCustomerMessage,
  newestCursor,
  orderedMessages,
  type MessagePages,
} from './cache'

const at = (minute: number) => `2026-10-30T02:${String(minute).padStart(2, '0')}:00.000Z`

function pages(...lists: ReturnType<typeof messageFixture>[][]): MessagePages {
  return { pages: lists, pageParams: lists.map(() => undefined) }
}

describe('message cache', () => {
  const older = messageFixture({ id: 'a', created_at: at(1) })
  const newer = messageFixture({ id: 'b', created_at: at(2), sender_role: 'agent', sender_id: 'agent' })

  it('orders messages across pages and removes duplicates', () => {
    const data = pages([newer, older], [older])
    expect(orderedMessages(data).map((message) => message.id)).toEqual(['a', 'b'])
    expect(newestCursor(data)).toBe(at(2))
  })

  it('inserts realtime messages once even when the same row arrives twice', () => {
    const incoming = messageFixture({ id: 'c', created_at: at(3) })
    const once = insertMessages(pages([newer, older]), [incoming])
    const twice = insertMessages(once, [incoming])
    expect(orderedMessages(twice).map((message) => message.id)).toEqual(['a', 'b', 'c'])
  })

  it('replaces an existing message in place when it is updated', () => {
    const edited = { ...older, is_deleted: true, body: '' }
    const next = insertMessages(pages([newer, older]), [edited])
    expect(orderedMessages(next).find((message) => message.id === 'a')?.is_deleted).toBe(true)
    expect(orderedMessages(next)).toHaveLength(2)
  })

  it('leaves the cache untouched without data or rows', () => {
    expect(insertMessages(undefined, [older])).toBeUndefined()
    const data = pages([older])
    expect(insertMessages(data, [])).toBe(data)
  })

  it('finds the latest customer message', () => {
    expect(latestCustomerMessage([older, newer])?.id).toBe('a')
    expect(latestCustomerMessage([newer])).toBeUndefined()
  })
})
