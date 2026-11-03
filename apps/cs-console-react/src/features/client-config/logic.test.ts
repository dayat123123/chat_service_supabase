import { describe, expect, it } from 'vitest'

import {
  flagDraft,
  flagProblems,
  killReasonValid,
  parseUserIds,
  phraseMatches,
  rolloutLabel,
  versionValid,
} from './logic'

const user = '7a6f1c2e-0b7d-4c55-9a51-2f1f0b6c9d10'

describe('flagProblems', () => {
  const options = { isNew: true, existing: ['search'], invalidUsers: [] }

  it('accepts a valid new flag', () => {
    expect(flagProblems({ ...flagDraft(null), key: 'chart.share' }, options)).toEqual({})
  })

  it('rejects reserved, malformed, duplicate, and empty keys', () => {
    expect(flagProblems({ ...flagDraft(null), key: 'social.enabled' }, options).key).toBe('reserved')
    expect(flagProblems({ ...flagDraft(null), key: '9lives' }, options).key).toBe('format')
    expect(flagProblems({ ...flagDraft(null), key: 'Search' }, options).key).toBe('exists')
    expect(flagProblems({ ...flagDraft(null), key: '' }, options).key).toBe('required')
  })

  it('does not check the key when editing', () => {
    expect(flagProblems({ ...flagDraft(null), key: 'search' }, { ...options, isNew: false })).toEqual({})
  })

  it('validates percentage, version, users, and description', () => {
    const base = { ...flagDraft(null), key: 'chart.share' }
    expect(flagProblems({ ...base, percentage: 101 }, options).percentage).toBe('range')
    expect(flagProblems({ ...base, percentage: Number.NaN }, options).percentage).toBe('range')
    expect(flagProblems({ ...base, min_app_version: '2.x' }, options).version).toBe('format')
    expect(flagProblems(base, { ...options, invalidUsers: ['budi'] }).users).toBe('invalid')
    expect(flagProblems({ ...base, description: 'x'.repeat(301) }, options).description).toBe('length')
  })
})

describe('parseUserIds', () => {
  it('separates valid profile ids from other text', () => {
    expect(parseUserIds(`${user}\n${user.toUpperCase()}, budi`)).toEqual({ ids: [user], invalid: ['budi'] })
  })
})

describe('versionValid', () => {
  it('accepts dotted numbers only', () => {
    expect(versionValid('2.10.0')).toBe(true)
    expect(versionValid('2')).toBe(true)
    expect(versionValid('2.4.1+57')).toBe(false)
    expect(versionValid('v2.4')).toBe(false)
  })
})

describe('kill switch confirmation', () => {
  it('needs 10–500 characters after collapsing spaces', () => {
    expect(killReasonValid('   spam   ')).toBe(false)
    expect(killReasonValid('Spam masif dari bot')).toBe(true)
    expect(killReasonValid('x'.repeat(501))).toBe(false)
  })

  it('matches the confirmation phrase regardless of case and spacing', () => {
    expect(phraseMatches(' matikan ', 'MATIKAN')).toBe(true)
    expect(phraseMatches('turn   off', 'TURN OFF')).toBe(true)
    expect(phraseMatches('MATIKAN!', 'MATIKAN')).toBe(false)
  })
})

describe('rolloutLabel', () => {
  it('describes how far a flag is rolled out', () => {
    expect(rolloutLabel({ enabled: false, percentage: 100, user_ids: [] })).toBe('off')
    expect(rolloutLabel({ enabled: true, percentage: 100, user_ids: [] })).toBe('all')
    expect(rolloutLabel({ enabled: true, percentage: 25, user_ids: [] })).toBe('partial')
    expect(rolloutLabel({ enabled: true, percentage: 0, user_ids: [user] })).toBe('users')
    expect(rolloutLabel({ enabled: true, percentage: 0, user_ids: [] })).toBe('none')
  })
})
