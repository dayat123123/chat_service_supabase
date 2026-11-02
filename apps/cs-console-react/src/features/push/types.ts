export const pushStates = ['active', 'not_configured', 'error', 'offline'] as const
export type PushState = (typeof pushStates)[number]

export type PushInstance = {
  instance: string
  version: string | null
  configured: boolean
  project_id: string | null
  error: string | null
  started_at: string
  seen_at: string
  live: boolean
}

export type PushStatus = {
  state: PushState
  instances: PushInstance[]
  devices: { total: number; users: number; android: number; ios: number; web: number; active_30d: number }
  queue: { queued: number; oldest_at: string | null }
  last_24h: { sent: number; failed: number; invalid: number; expired: number }
  last_sent_at: string | null
  last_error: { at: string; kind: string; error: string } | null
  ttl_hours: number
  max_attempts: number
}

export type PushPlatform = 'android' | 'ios' | 'web'

export type PushDevice = { platform: PushPlatform; app_version: string | null; last_seen_at: string }

export type PushUser = {
  id: string
  username: string
  display_name: string | null
  avatar_url: string | null
  devices: PushDevice[]
}

export type PushDelivery = {
  state: PushState
  sent: number
  failed: number
  invalid: number
  expired: number
  cancelled: number
  queued: number
}
