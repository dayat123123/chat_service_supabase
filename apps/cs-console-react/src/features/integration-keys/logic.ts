import { addDays, parseISO } from 'date-fns'

import { isoDay } from '@/lib/time'

import {
  KEY_NAME_MAX,
  KEY_NAME_MIN,
  MAX_CIDRS,
  DEFAULT_RATE_LIMIT,
  RATE_LIMIT_MAX,
  type DailyIntegration,
  type KeyDailyRow,
  keyScopes,
  type IntegrationBroadcast,
  type IntegrationKey,
  type KeyDraft,
  type KeyScope,
  type LocalizedText,
} from './types'

export type KeyField = 'name' | 'scopes' | 'official' | 'rate' | 'cidrs'
export type KeyProblem = 'required' | 'length' | 'range' | 'invalid' | 'tooMany'
export type KeyProblems = Partial<Record<KeyField, KeyProblem>>

const ipv4 = /^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$/
const ipv6 = /^[0-9a-f:]+$/i

function validIpv6(value: string) {
  if (!ipv6.test(value) || !value.includes(':')) return false
  const halves = value.split('::')
  if (halves.length > 2) return false
  const groups = halves.flatMap((half) => (half === '' ? [] : half.split(':')))
  if (groups.some((group) => group.length === 0 || group.length > 4)) return false
  return halves.length === 2 ? groups.length < 8 : groups.length === 8
}

export function validCidr(value: string) {
  const [address = '', prefix, extra] = value.split('/')
  if (extra !== undefined) return false
  const v4 = ipv4.test(address)
  if (!v4 && !validIpv6(address)) return false
  if (prefix === undefined) return true
  if (!/^\d{1,3}$/.test(prefix)) return false
  return Number(prefix) <= (v4 ? 32 : 128)
}

export function parseCidrs(text: string) {
  return [
    ...new Set(
      text
        .split(/[\s,;]+/)
        .map((item) => item.trim())
        .filter(Boolean),
    ),
  ]
}

export function keyProblems(draft: KeyDraft): KeyProblems {
  const problems: KeyProblems = {}
  const name = draft.name.trim()
  if (name === '') problems.name = 'required'
  else if (name.length < KEY_NAME_MIN || name.length > KEY_NAME_MAX) problems.name = 'length'
  if (draft.scopes.length === 0) problems.scopes = 'required'
  else if (draft.scopes.includes('notify_broadcast') && !draft.scopes.includes('notify'))
    problems.scopes = 'invalid'
  if (draft.scopes.includes('bot_post') && !draft.official_account_id) problems.official = 'required'
  if (
    !Number.isInteger(draft.rate_limit_per_minute) ||
    draft.rate_limit_per_minute < 1 ||
    draft.rate_limit_per_minute > RATE_LIMIT_MAX
  )
    problems.rate = 'range'
  if (draft.allowed_cidrs.length > MAX_CIDRS) problems.cidrs = 'tooMany'
  else if (draft.allowed_cidrs.some((item) => !validCidr(item))) problems.cidrs = 'invalid'
  return problems
}

export function invalidCidrs(cidrs: string[]) {
  return cidrs.filter((item) => !validCidr(item))
}

export function draftFrom(key: IntegrationKey | null): KeyDraft {
  if (!key) {
    return {
      name: '',
      scopes: ['notify'],
      official_account_id: null,
      allowed_cidrs: [],
      rate_limit_per_minute: DEFAULT_RATE_LIMIT,
      enabled: true,
    }
  }
  return {
    name: key.name,
    scopes: key.scopes,
    official_account_id: key.official_account?.id ?? null,
    allowed_cidrs: key.allowed_cidrs,
    rate_limit_per_minute: key.rate_limit_per_minute,
    enabled: key.status === 'active',
  }
}

const scopeNeeds: Partial<Record<KeyScope, KeyScope>> = { notify_broadcast: 'notify' }

export function toggleScope(scopes: KeyScope[], scope: KeyScope, on: boolean): KeyScope[] {
  const next = new Set(scopes)
  if (on) next.add(scope)
  else next.delete(scope)
  for (const item of keyScopes) {
    const needed = scopeNeeds[item]
    if (!needed || !next.has(item) || next.has(needed)) continue
    if (on) next.add(needed)
    else next.delete(item)
  }
  return keyScopes.filter((item) => next.has(item))
}

export function broadcastTitle(title: LocalizedText | null, language: 'id' | 'en') {
  if (title === null) return ''
  const text = typeof title === 'string' ? title : (title[language] ?? title[language === 'id' ? 'en' : 'id'])
  return text?.trim() ?? ''
}

export function hasActiveBroadcast(broadcasts: IntegrationBroadcast[]) {
  return broadcasts.some((item) => item.status === 'queued' || item.status === 'sending')
}

export function dailySeries(daily: DailyIntegration[], from: string, days: number): DailyIntegration[] {
  const byDay = new Map(daily.map((row) => [row.day, row]))
  const start = parseISO(from)
  return Array.from({ length: days }, (_, index) => {
    const day = isoDay(addDays(start, index))
    return byDay.get(day) ?? { day, received: 0, queued: 0, no_recipient: 0, posts: 0 }
  })
}

export function keyDailySeries(rows: KeyDailyRow[], from: string, days: number) {
  return dailySeries(
    rows.map((row) => ({
      day: row.day,
      received: row.received,
      queued: row.queued,
      no_recipient: row.no_recipient,
      posts: row.posts,
    })),
    from,
    days,
  )
}

export function deliveryRatio(sent: number, failed: number) {
  const total = sent + failed
  return total === 0 ? null : sent / total
}

export const curlExample = (baseUrl: string) =>
  [
    `curl -sS -X POST "${baseUrl}/integration/v1/notify/messages" \\`,
    '  -H "apikey: $ANON_KEY" \\',
    '  -H "Authorization: Bearer $OLT_INTEGRATION_KEY" \\',
    '  -H "Content-Type: application/json" \\',
    '  -H "X-Request-Id: notif-batch-000123" \\',
    `  -d '{"messages":[{"id":"trade-20261103-000123","cust_id":"W137","title":"Order BBCA match","body":"Beli 10 lot BBCA @ 9.250","ttl_seconds":3600}]}'`,
  ].join('\n')
