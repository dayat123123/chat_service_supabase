import { differenceInMinutes } from 'date-fns'

import { bridgeStatuses, bridgeWarnings, type AppIntegrationOverview, type BridgeWarning } from './types'

export function prodConfig(apiUrl: string, anonKey: string) {
  return JSON.stringify({ SOCIAL_API_URL: apiUrl, SOCIAL_ANON_KEY: anonKey }, null, 2)
}

export function shortKey(key: string) {
  return key.length <= 24 ? key : `${key.slice(0, 12)}…${key.slice(-6)}`
}

export type Ago = { unit: 'now' | 'minutes' | 'hours' | 'days'; count: number }

export function ago(value: string, now: Date = new Date()): Ago {
  const minutes = Math.max(0, differenceInMinutes(now, new Date(value)))
  if (minutes < 1) return { unit: 'now', count: 0 }
  if (minutes < 60) return { unit: 'minutes', count: minutes }
  if (minutes < 1440) return { unit: 'hours', count: Math.floor(minutes / 60) }
  return { unit: 'days', count: Math.floor(minutes / 1440) }
}

const isWarning = (value: unknown): value is BridgeWarning =>
  (bridgeWarnings as readonly unknown[]).includes(value)

export function normalizeOverview(raw: AppIntegrationOverview): AppIntegrationOverview {
  const instances = (raw.instances ?? []).map((item) => ({ ...item, keys: item.keys ?? [] }))
  const warnings = (raw.warnings ?? []).filter(isWarning)
  const status = (bridgeStatuses as readonly string[]).includes(raw.status) ? raw.status : 'no_heartbeat'
  return {
    ...raw,
    status: instances.length === 0 ? 'no_heartbeat' : status,
    warnings,
    instances,
    logins: { last_login_at: raw.logins?.last_login_at ?? null, users_24h: raw.logins?.users_24h ?? 0 },
  }
}
