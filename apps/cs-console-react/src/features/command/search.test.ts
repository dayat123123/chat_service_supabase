import { describe, expect, it } from 'vitest'

import { matchesQuery } from './search'

describe('matchesQuery', () => {
  it('matches every word regardless of case and accents', () => {
    expect(matchesQuery('CS-000123 Budi Santoso order', 'budi 123')).toBe(true)
    expect(matchesQuery('Kafé Ñusantara', 'kafe nusantara')).toBe(true)
    expect(matchesQuery('CS-000123 Budi', 'budi rina')).toBe(false)
  })

  it('treats an empty query as a match', () => {
    expect(matchesQuery('apa saja', '   ')).toBe(true)
  })
})
