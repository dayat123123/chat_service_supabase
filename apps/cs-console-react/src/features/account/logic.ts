import { z } from 'zod'

import i18n from '@/i18n'
import { errorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'

import {
  ratingValues,
  statsPeriods,
  type MyProfile,
  type MyStats,
  type RatingRow,
  type StatsPeriod,
} from './types'

export const MIN_PASSWORD_LENGTH = 12

export const passwordSchema = z
  .object({
    current: z.string().min(1, 'account.password.currentRequired'),
    next: z.string().min(MIN_PASSWORD_LENGTH, 'auth.passwordTooShort'),
    confirm: z.string(),
  })
  .refine((values) => values.next === values.confirm, {
    path: ['confirm'],
    message: 'auth.passwordMismatch',
  })
  .refine((values) => values.current === '' || values.next !== values.current, {
    path: ['next'],
    message: 'account.password.sameAsCurrent',
  })

export function accountErrorText(error: unknown) {
  const code = toApiError(error).code
  if (code === 'wrong_current_password') return i18n.t('account.password.errors.wrongCurrent')
  if (code === 'same_password') return i18n.t('account.password.errors.same')
  return errorText(error)
}

const count = (value: unknown) => (typeof value === 'number' && Number.isFinite(value) ? value : 0)

const nullableNumber = (value: unknown) =>
  typeof value === 'number' && Number.isFinite(value) ? value : null

const strings = (value: unknown) =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : []

export const isStatsPeriod = (value: unknown): value is StatsPeriod =>
  (statsPeriods as readonly unknown[]).includes(value)

export function normalizeStats(raw: Partial<MyStats> | null, period: StatsPeriod): MyStats {
  const counts = (raw?.rating_counts ?? {}) as Partial<Record<string, unknown>>
  return {
    period: isStatsPeriod(raw?.period) ? raw.period : period,
    from: raw?.from ?? '',
    to: raw?.to ?? '',
    handled: count(raw?.handled),
    resolved: count(raw?.resolved),
    active_tickets: count(raw?.active_tickets),
    avg_first_response_minutes: nullableNumber(raw?.avg_first_response_minutes),
    avg_resolution_minutes: nullableNumber(raw?.avg_resolution_minutes),
    avg_rating: nullableNumber(raw?.avg_rating),
    ratings: count(raw?.ratings),
    rating_counts: {
      1: count(counts['1']),
      2: count(counts['2']),
      3: count(counts['3']),
      4: count(counts['4']),
      5: count(counts['5']),
    },
    complaints: count(raw?.complaints),
  }
}

export function normalizeProfile(raw: Partial<MyProfile> | null): MyProfile {
  const teamName = raw?.team_name
  return {
    id: raw?.id ?? '',
    agent_code: raw?.agent_code ?? '',
    display_name: raw?.display_name ?? '',
    email: raw?.email ?? null,
    roles: strings(raw?.roles),
    team: raw?.team ?? null,
    team_name: teamName && typeof teamName.id === 'string' ? teamName : null,
    languages: strings(raw?.languages),
    max_active_tickets: count(raw?.max_active_tickets),
    nasabah_permissions: strings(raw?.nasabah_permissions),
    community_permissions: strings(raw?.community_permissions),
    created_at: raw?.created_at ?? null,
    password_changed_at: raw?.password_changed_at ?? null,
  }
}

export function ratingRows(stats: Pick<MyStats, 'rating_counts'>): RatingRow[] {
  const total = ratingValues.reduce((sum, rating) => sum + stats.rating_counts[rating], 0)
  return ratingValues.map((rating) => {
    const value = stats.rating_counts[rating]
    return { rating, count: value, ratio: total > 0 ? value / total : 0 }
  })
}

export function teamLabel(profile: Pick<MyProfile, 'team' | 'team_name'>, language: string) {
  if (!profile.team) return null
  if (!profile.team_name) return profile.team
  return language === 'en' ? profile.team_name.en || profile.team_name.id : profile.team_name.id
}
