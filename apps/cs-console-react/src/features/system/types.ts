export const systemTabs = ['status', 'healer', 'backup', 'alerts'] as const
export type SystemTab = (typeof systemTabs)[number]

export type Severity = 'warning' | 'critical'
export type OverallStatus = 'ok' | 'warning' | 'critical'

export type HealthCheck = {
  key: string
  severity: Severity
  title: string
  detail: string | null
  failing_since: string
}

export type OpenAlert = {
  id: number
  key: string
  severity: Severity
  title: string
  detail: string | null
  opened_at: string
  acknowledged_by: string | null
  acknowledged_at: string | null
}

export type ResolvedAlert = {
  id: number
  key: string
  severity: Severity
  title: string
  opened_at: string
  resolved_at: string
}

export type ServiceInstance = {
  instance: string
  version: string | null
  started_at: string | null
  last_seen_at: string
  status: 'ok' | 'degraded' | 'error'
  error: string | null
  detail: Record<string, unknown> | null
  live: boolean
}

export type ServiceGroup = { service: string; label: string; instances: ServiceInstance[] }

export type Probe = {
  name: string
  label: string
  target: string | null
  ok: boolean
  status: number | null
  latency_ms: number | null
  error: string | null
  checked_at: string
  last_ok_at: string | null
  stale: boolean
}

export type Disk = {
  name: string
  total_bytes: number
  avail_bytes: number
  used_ratio: number | null
  checked_at: string
}

export type ReplicationSlot = {
  name: string
  type: string
  active: boolean
  wal_status: string | null
  retained_bytes: number | null
}

export type DatabaseInfo = {
  size_bytes: number
  connections: number
  max_connections: number
  slots: ReplicationSlot[]
}

export type Queues = {
  push: { queued: number; oldest_at: string | null }
  storage_cleanup: { pending: number; failing: number; oldest_at: string | null }
  alerts: { pending: number; failed_24h: number }
}

export type CronJob = {
  job: string
  schedule: string
  active: boolean
  last_status: string | null
  last_start: string | null
  last_message: string | null
}

export type SystemHealth = {
  status: OverallStatus
  now: string
  evaluated_at: string | null
  checks: HealthCheck[]
  alerts: { open: OpenAlert[]; recent: ResolvedAlert[] }
  services: ServiceGroup[]
  probes: Probe[]
  disks: Disk[]
  database: DatabaseInfo
  queues: Queues
  cron: CronJob[]
}

export type HealthBadge = { critical: number; warning: number; open: number }

export const backupRunKinds = ['base', 'files', 'wal', 'prune', 'check', 'restore_test'] as const
export type BackupRunKind = (typeof backupRunKinds)[number]
export type BackupRequestKind = 'base' | 'restore_test'
export const backupTargetKinds = ['s3', 'local'] as const
export type BackupTargetKind = (typeof backupTargetKinds)[number]

export type BackupRun = {
  id: number
  kind: BackupRunKind
  status: 'ok' | 'failed'
  started_at?: string
  finished_at: string
  bytes?: number
  snapshot_id?: string
  detail?: Record<string, unknown>
  error?: string
}

export type BackupState = {
  busy?: string | boolean | null
  error?: string | null
  repository_ready?: boolean
  wal?: { streaming?: boolean; slot_lost?: boolean; error?: string | null }
  offsite?: { last_ok_at?: string | null; last_error?: string | null }
  disk?: { total_bytes?: number; avail_bytes?: number }
  repository_disk?: { total_bytes?: number; avail_bytes?: number }
}

export type BackupConfig = {
  configured: boolean
  revision: number
  kind?: BackupTargetKind
  local_repository?: string
  endpoint: string | null
  bucket: string | null
  prefix: string | null
  region: string | null
  access_key_id: string | null
  secret_set: boolean
  password_set: boolean
  password_set_at: string | null
  configured_at: string | null
  base_time: string
  offsite_minutes: number
  retention_daily: number
  retention_weekly: number
  retention_monthly: number
  wal_days: number
  restore_test: boolean
  restore_test_weekday: number
  restore_test_time: string
  updated_at: string
  updated_by: string | null
}

export type BackupSummary = {
  configured: boolean
  kind?: BackupTargetKind
  target: string | null
  live: boolean
  state: BackupState | null
  last_base: BackupRun | null
  last_files: BackupRun | null
  last_restore_test: BackupRun | null
}

export type BackupRequest = { kind: BackupRequestKind; requested_at: string; requested_by: string | null }

export type BackupOverview = {
  config: BackupConfig
  summary: BackupSummary
  requests: BackupRequest[]
  runs: BackupRun[]
}

export type BackupTargetInput = {
  kind: BackupTargetKind
  endpoint: string
  bucket: string
  prefix: string
  region: string
  accessKeyId: string
  secretAccessKey: string
  password: string
}

export type BackupScheduleInput = {
  baseTime: string
  offsiteMinutes: number
  retentionDaily: number
  retentionWeekly: number
  retentionMonthly: number
  walDays: number
  restoreTest: boolean
  restoreTestWeekday: number
  restoreTestTime: string
}

export type SmtpSecurity = 'tls' | 'starttls' | 'none'
export type AlertChannel = 'telegram' | 'email'

export type Delivery = {
  kind: 'opened' | 'escalated' | 'resolved' | 'test'
  status: 'pending' | 'sent' | 'failed'
  at: string
  error: string | null
}

export type AlertChannels = {
  revision: number
  label: string
  console_url: string | null
  updated_at: string
  updated_by: string | null
  telegram: { enabled: boolean; token_set: boolean; chat_ids: string[] }
  email: {
    enabled: boolean
    host: string | null
    port: number | null
    security: SmtpSecurity | null
    username: string | null
    password_set: boolean
    from: string | null
    to: string[]
  }
  last: { telegram: Delivery | null; email: Delivery | null }
}

export type TelegramInput = { enabled: boolean; chatIds: string[]; botToken: string }

export type EmailInput = {
  enabled: boolean
  host: string
  port: number | null
  security: SmtpSecurity
  username: string
  from: string
  to: string[]
  password: string | null
}

export const healerActions = ['restart', 'report', 'give_up', 'skip'] as const
export type HealerAction = (typeof healerActions)[number]
export const healerReasons = [
  'unhealthy',
  'restart_limit',
  'db_unhealthy',
  'pgbouncer_unhealthy',
  'systemic',
] as const
export type HealerReason = (typeof healerReasons)[number]

export type HealerEvent = {
  id: string
  at: string
  service: string
  label: string
  container: string
  action: HealerAction
  reason: string
  result: string
  detail: string | null
  error: string | null
}

export type HealerGaveUp = { service: string; label?: string; since: string; until: string; restarts: number }

export type HealerSkip = { reason: string; since: string; services: string[] | null }

export type HealerUnhealthy = { service: string; container: string; since: string }

export type HealerRules = {
  unhealthy_seconds: number
  min_uptime_seconds: number
  max_restarts_per_hour: number
  global_cooldown_seconds: number
  systemic_fraction: number
  interval_seconds: number
}

export type HealerState = {
  reported_at: string
  live: boolean
  fresh: boolean
  read_error: string | null
  version: string | null
  project: string | null
  enabled: boolean | null
  started_at: string | null
  checked_at: string | null
  rules: Partial<HealerRules> | null
  watched: number
  unhealthy: HealerUnhealthy[] | null
  skip: HealerSkip | null
  gave_up: HealerGaveUp[] | null
  error: string | null
}

export type HealerCounts = {
  restarts_24h: number
  failed_24h: number
  gave_up_24h: number
  skipped_24h: number
}

export type HealerOverview = {
  now: string
  state: HealerState | null
  events: HealerEvent[]
  counts: HealerCounts
}
