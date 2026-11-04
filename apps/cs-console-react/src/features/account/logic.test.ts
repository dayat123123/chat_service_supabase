import { describe, expect, it } from 'vitest'

import { normalizeProfile, normalizeStats, passwordSchema, ratingRows, teamLabel } from './logic'

describe('account logic', () => {
  it('applies the same password rules as the required change, plus new differs from current', () => {
    const ok = passwordSchema.safeParse({
      current: 'lama-aman-sekali',
      next: 'baru-aman-sekali',
      confirm: 'baru-aman-sekali',
    })
    expect(ok.success).toBe(true)

    const issues = (values: { current: string; next: string; confirm: string }) => {
      const result = passwordSchema.safeParse(values)
      return result.success ? [] : result.error.issues.map((issue) => issue.message)
    }
    expect(issues({ current: '', next: 'baru-aman-sekali', confirm: 'baru-aman-sekali' })).toEqual([
      'account.password.currentRequired',
    ])
    expect(issues({ current: 'x', next: 'pendek', confirm: 'pendek' })).toContain('auth.passwordTooShort')
    expect(issues({ current: 'x', next: 'baru-aman-sekali', confirm: 'lain-aman-sekali' })).toContain(
      'auth.passwordMismatch',
    )
    expect(
      issues({ current: 'sama-aman-sekali', next: 'sama-aman-sekali', confirm: 'sama-aman-sekali' }),
    ).toEqual(['account.password.sameAsCurrent'])
  })

  it('fills missing stats with safe defaults', () => {
    const stats = normalizeStats({ handled: 3, avg_rating: null, rating_counts: { 5: 2 } as never }, '7d')
    expect(stats.period).toBe('7d')
    expect(stats.handled).toBe(3)
    expect(stats.resolved).toBe(0)
    expect(stats.avg_first_response_minutes).toBeNull()
    expect(stats.rating_counts).toEqual({ 1: 0, 2: 0, 3: 0, 4: 0, 5: 2 })
    expect(normalizeStats(null, 'today').period).toBe('today')
  })

  it('lists ratings from five to one with their share', () => {
    const rows = ratingRows({ rating_counts: { 1: 1, 2: 0, 3: 0, 4: 1, 5: 2 } })
    expect(rows.map((row) => row.rating)).toEqual([5, 4, 3, 2, 1])
    expect(rows[0]).toEqual({ rating: 5, count: 2, ratio: 0.5 })
    expect(
      ratingRows({ rating_counts: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 } }).every((row) => row.ratio === 0),
    ).toBe(true)
  })

  it('normalizes the profile and picks the team name for the language', () => {
    const profile = normalizeProfile({
      display_name: 'Rina',
      roles: ['cs_agent', 7 as never],
      team: 'vip',
      team_name: { id: 'Prioritas', en: 'Priority' },
    })
    expect(profile.roles).toEqual(['cs_agent'])
    expect(profile.email).toBeNull()
    expect(teamLabel(profile, 'id')).toBe('Prioritas')
    expect(teamLabel(profile, 'en')).toBe('Priority')
    expect(teamLabel({ team: 'x', team_name: null }, 'id')).toBe('x')
    expect(teamLabel({ team: null, team_name: null }, 'id')).toBeNull()
  })
})
