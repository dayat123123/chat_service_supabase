export const LIBRARY_NAME = 'rendezvous_community'
export const LIBRARY_MIN_VERSION = '1.7.0'
export const INTEGRATION_GUIDE_URL =
  'https://github.com/dayat123123/rendezvous_community/blob/main/doc/integration.md'

export const bridgeStatuses = ['active', 'warning', 'no_heartbeat'] as const
export type BridgeStatus = (typeof bridgeStatuses)[number]

export const bridgeWarnings = ['dev_key', 'not_jwt', 'mismatch'] as const
export type BridgeWarning = (typeof bridgeWarnings)[number]

export type BridgeKey = { kid: string; alg: string | null }

export type BridgeInstance = {
  instance: string
  version: string | null
  started_at: string | null
  last_seen_at: string
  status: 'ok' | 'degraded' | 'error'
  error: string | null
  app_env: string | null
  olt_mode: string | null
  issuer: string | null
  audience: string | null
  max_ttl_seconds: number | null
  key_count: number | null
  keys: BridgeKey[]
}

export type CustomerLogins = { last_login_at: string | null; users_24h: number }

export type AppIntegrationOverview = {
  now: string
  status: BridgeStatus
  warnings: BridgeWarning[]
  instances: BridgeInstance[]
  last_seen_at: string | null
  logins: CustomerLogins
}
