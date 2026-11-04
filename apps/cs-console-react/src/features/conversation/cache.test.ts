import { describe, expect, it } from 'vitest'

import { messageFixture } from '@/test/fixtures'

import {
  collectAfter,
  GAP_OVERLAP_MS,
  insertMessages,
  latestCustomerMessage,
  newestCursor,
  orderedMessages,
  overlapCursor,
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

  it('keeps the sync cursor behind messages that were only inserted locally', () => {
    const sent = messageFixture({ id: 'd', created_at: at(4), sender_role: 'agent', sender_id: 'agent' })
    const local = insertMessages(pages([newer, older]), [{ ...sent, local: true }])
    expect(orderedMessages(local).map((message) => message.id)).toEqual(['a', 'b', 'd'])
    expect(newestCursor(local)).toBe(at(2))
    const synced = insertMessages(local, [messageFixture({ id: 'c', created_at: at(3) }), sent])
    expect(orderedMessages(synced).map((message) => message.id)).toEqual(['a', 'b', 'c', 'd'])
    expect(newestCursor(synced)).toBe(at(4))
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

describe('collectAfter', () => {
  const stamp = (n: number) => new Date(Date.UTC(2026, 9, 30, 3, 0, n)).toISOString()
  const batch = (from: number, count: number) =>
    Array.from({ length: count }, (_, i) =>
      messageFixture({ id: `n-${from + i}`, created_at: stamp(from + i) }),
    ).reverse()

  it('keeps fetching after the newest message of each full page until a short page arrives', async () => {
    const replies = [batch(1, 100), batch(101, 100), batch(201, 20)]
    const cursors: string[] = []

    const result = await collectAfter((cursor) => {
      cursors.push(cursor)
      return Promise.resolve(replies.shift() ?? [])
    }, 'start')

    expect(cursors).toEqual(['start', stamp(100), stamp(200)])
    expect(result.messages).toHaveLength(220)
    expect(result.complete).toBe(true)
  })

  it('stops at the page budget and reports the gap as incomplete', async () => {
    let calls = 0

    const result = await collectAfter(
      () => {
        calls += 1
        return Promise.resolve(batch(calls * 100, 100))
      },
      'start',
      2,
    )

    expect(calls).toBe(2)
    expect(result.messages).toHaveLength(200)
    expect(result.complete).toBe(false)
  })
})

describe('overlapCursor', () => {
  it('steps back ten seconds so a message committed late with an earlier time is still fetched', () => {
    expect(GAP_OVERLAP_MS).toBe(10_000)
    expect(overlapCursor('2026-11-03T09:00:05.123456Z|8f0c2a8e-0000-4000-8000-000000000001')).toBe(
      '2026-11-03T08:59:55.123Z|00000000-0000-0000-0000-000000000000',
    )
  })

  it('keeps an unreadable cursor untouched', () => {
    expect(overlapCursor('bukan-cursor')).toBe('bukan-cursor')
  })
})

describe('horizon catch-up', () => {
  const stamp = (second: number) => new Date(Date.UTC(2026, 10, 4, 9, 0, second)).toISOString()
  const row = (id: string, second: number) =>
    messageFixture({ id, created_at: stamp(second), cursor: `${stamp(second)}|${id}` })
  const server = [row('a', 0), row('b', 20), row('c', 60)]
  const fetchAfter = (cursor: string) => {
    const from = cursor.split('|')[0] ?? ''
    return Promise.resolve(server.filter((message) => message.created_at > from).reverse())
  }

  it('starts from the newest fetched row, so a message far older than the newest one shown is not skipped', async () => {
    const sent = { ...row('c', 60), local: true }
    const data = insertMessages({ pages: [[row('a', 0)]], pageParams: [undefined] }, [sent])
    const horizon = newestCursor(data)
    expect(horizon).toBe(`${stamp(0)}|a`)

    const { messages, complete } = await collectAfter(fetchAfter, overlapCursor(horizon!))
    const synced = insertMessages(data, messages)

    expect(complete).toBe(true)
    expect(orderedMessages(synced).map((message) => message.id)).toEqual(['a', 'b', 'c'])
    expect(orderedMessages(synced).some((message) => message.local)).toBe(false)
    expect(newestCursor(synced)).toBe(`${stamp(60)}|c`)
  })
})
