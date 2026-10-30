import { describe, expect, it } from 'vitest'

import { messageFixture } from '@/test/fixtures'

import { buildRows } from './rows'
import type { PendingMessage } from './types'

describe('buildRows', () => {
  const now = new Date('2026-10-30T05:00:00.000Z')

  it('adds a day separator per Jakarta day and groups messages within five minutes', () => {
    const rows = buildRows(
      [
        messageFixture({ id: 'y1', created_at: '2026-10-29T03:00:00.000Z' }),
        messageFixture({ id: 't1', created_at: '2026-10-30T02:00:00.000Z' }),
        messageFixture({ id: 't2', created_at: '2026-10-30T02:03:00.000Z' }),
        messageFixture({ id: 't3', created_at: '2026-10-30T02:20:00.000Z' }),
        messageFixture({
          id: 'a1',
          created_at: '2026-10-30T02:21:00.000Z',
          sender_id: 'agent',
          sender_role: 'agent',
        }),
      ],
      [],
      now,
    )
    expect(rows.map((row) => (row.kind === 'day' ? row.label : row.key))).toEqual([
      'Kemarin',
      'y1',
      'Hari ini',
      't1',
      't2',
      't3',
      'a1',
    ])
    const flags = Object.fromEntries(
      rows.flatMap((row) => (row.kind === 'message' ? [[row.key, [row.first, row.last]]] : [])),
    )
    expect(flags).toEqual({
      y1: [true, true],
      t1: [true, false],
      t2: [false, true],
      t3: [true, true],
      a1: [true, true],
    })
  })

  it('keeps system messages out of groups and appends pending rows last', () => {
    const pending: PendingMessage = {
      clientId: 'c1',
      roomId: 'r',
      ticketId: 't',
      body: 'Mengirim',
      files: [],
      replyTo: null,
      status: 'sending',
      createdAt: '2026-10-30T02:30:00.000Z',
    }
    const rows = buildRows(
      [
        messageFixture({
          id: 's1',
          created_at: '2026-10-30T02:00:00.000Z',
          kind: 'system',
          sender_role: 'system',
        }),
        messageFixture({
          id: 's2',
          created_at: '2026-10-30T02:01:00.000Z',
          kind: 'system',
          sender_role: 'system',
        }),
      ],
      [pending],
      now,
    )
    const messages = rows.filter((row) => row.kind === 'message')
    expect(messages.every((row) => row.kind === 'message' && row.first && row.last)).toBe(true)
    expect(rows.at(-1)).toMatchObject({ kind: 'pending', key: 'pending-c1' })
  })
})
