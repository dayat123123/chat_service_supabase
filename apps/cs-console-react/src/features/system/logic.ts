import type { WaitTone } from '@/lib/sla'

import type {
  AlertChannels,
  BackupConfig,
  BackupOverview,
  BackupRun,
  BackupScheduleInput,
  BackupTargetInput,
  BackupTargetKind,
  EmailInput,
  HealthBadge,
  OverallStatus,
  ServiceInstance,
  Severity,
  SystemHealth,
  TelegramInput,
} from './types'

export const DISK_WARN_RATIO = 0.8
export const DISK_CRITICAL_RATIO = 0.9
export const EVALUATION_STALE_MINUTES = 3
export const MAX_TELEGRAM_CHATS = 5
export const MAX_EMAIL_RECIPIENTS = 10
export const ALERT_LABEL_MAX = 40
export const BACKUP_PASSWORD_MIN = 16
export const BACKUP_PASSWORD_MAX = 200

const statusTones: Record<OverallStatus, WaitTone> = { ok: 'ok', warning: 'warn', critical: 'late' }

export const statusTone = (status: OverallStatus) => statusTones[status]
export const severityTone = (severity: Severity): WaitTone => (severity === 'critical' ? 'late' : 'warn')

export function usageTone(ratio: number | null | undefined): WaitTone {
  if (ratio === null || ratio === undefined) return 'ok'
  if (ratio >= DISK_CRITICAL_RATIO) return 'late'
  if (ratio >= DISK_WARN_RATIO) return 'warn'
  return 'ok'
}

export function evaluationStale(evaluatedAt: string | null, now: Date = new Date()) {
  if (!evaluatedAt) return true
  return now.getTime() - Date.parse(evaluatedAt) > EVALUATION_STALE_MINUTES * 60_000
}

export function sentinelLive(health: Pick<SystemHealth, 'services'>) {
  return health.services.some(
    (group) => group.service === 'sentinel' && group.instances.some((instance) => instance.live),
  )
}

export type InstanceState = 'ok' | 'degraded' | 'error' | 'stale'

export function instanceState(instance: Pick<ServiceInstance, 'live' | 'status'>): InstanceState {
  return instance.live ? instance.status : 'stale'
}

const instanceTones: Record<InstanceState, WaitTone | 'neutral'> = {
  ok: 'ok',
  degraded: 'warn',
  error: 'late',
  stale: 'neutral',
}

export const instanceTone = (state: InstanceState) => instanceTones[state]

export type BadgeView = { count: number; tone: 'late' | 'warn'; severity: Severity }

export function badgeView(badge: HealthBadge | undefined): BadgeView | null {
  if (!badge) return null
  if (badge.critical > 0) return { count: badge.critical, tone: 'late', severity: 'critical' }
  if (badge.warning > 0) return { count: badge.warning, tone: 'warn', severity: 'warning' }
  return null
}

export function durationMs(from: string | null | undefined, to: string | null | undefined) {
  if (!from || !to) return null
  const span = Date.parse(to) - Date.parse(from)
  return Number.isFinite(span) && span >= 0 ? span : null
}

export function runDuration(run: Pick<BackupRun, 'started_at' | 'finished_at'>) {
  return durationMs(run.started_at, run.finished_at)
}

const detailText = (detail: Record<string, unknown> | undefined, key: string) => {
  const value = detail?.[key]
  return typeof value === 'string' && value !== '' ? value : null
}

export function recoveredUntil(run: Pick<BackupRun, 'detail'>) {
  return detailText(run.detail, 'recovered_until')
}

function diskUsage(disk: { total_bytes?: number; avail_bytes?: number } | undefined) {
  if (!disk?.total_bytes || disk.total_bytes <= 0 || disk.avail_bytes === undefined) return null
  return {
    total: disk.total_bytes,
    avail: disk.avail_bytes,
    used: 1 - disk.avail_bytes / disk.total_bytes,
  }
}

export function stagingDisk(overview: Pick<BackupOverview, 'summary'>) {
  return diskUsage(overview.summary.state?.disk)
}

export function repositoryDisk(overview: Pick<BackupOverview, 'summary'>) {
  return diskUsage(overview.summary.state?.repository_disk)
}

export const targetKindOf = (value: { kind?: BackupTargetKind | null }): BackupTargetKind =>
  value.kind === 'local' ? 'local' : 's3'

export function backupBusy(overview: Pick<BackupOverview, 'summary'>) {
  const busy = overview.summary.state?.busy
  return typeof busy === 'string' ? busy : busy ? 'busy' : null
}

const ENDPOINT = /^https?:\/\/[A-Za-z0-9.-]{1,253}(:[0-9]{1,5})?$/
const BUCKET = /^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/
const PREFIX = /^[A-Za-z0-9._-]{1,64}(\/[A-Za-z0-9._-]{1,64}){0,4}$/
const REGION = /^[a-z0-9-]{2,40}$/

export function normalizeTarget(input: Pick<BackupTargetInput, 'endpoint' | 'bucket' | 'prefix' | 'region'>) {
  return {
    endpoint: input.endpoint.trim().replace(/\/+$/, ''),
    bucket: input.bucket.trim().toLowerCase(),
    prefix: input.prefix.trim().replace(/^\/+|\/+$/g, ''),
    region: input.region.trim().toLowerCase(),
  }
}

type TargetPlace = Pick<BackupConfig, 'kind' | 'endpoint' | 'bucket' | 'prefix'>
type TargetPlaceInput = Pick<BackupTargetInput, 'kind' | 'endpoint' | 'bucket' | 'prefix' | 'region'>

export function targetMoved(config: TargetPlace, input: TargetPlaceInput) {
  if (targetKindOf(config) !== input.kind) return true
  if (input.kind === 'local') return false
  const next = normalizeTarget(input)
  return (
    (config.endpoint ?? '') !== next.endpoint ||
    (config.bucket ?? '') !== next.bucket ||
    (config.prefix ?? '') !== next.prefix
  )
}

export type PasswordMode = 'first' | 'locked' | 'new_repository'

export function passwordMode(
  config: Pick<BackupConfig, 'password_set'> & TargetPlace,
  input: TargetPlaceInput,
): PasswordMode {
  if (!config.password_set) return 'first'
  return targetMoved(config, input) ? 'new_repository' : 'locked'
}

export type TargetField =
  | 'endpoint'
  | 'bucket'
  | 'prefix'
  | 'region'
  | 'accessKeyId'
  | 'secretAccessKey'
  | 'password'
  | 'confirm'
  | 'acknowledged'

export type TargetProblem = 'required' | 'invalid' | 'length' | 'mismatch'

export function targetProblems(
  input: BackupTargetInput,
  extra: { confirm: string; acknowledged: boolean },
  config: Pick<BackupConfig, 'password_set' | 'secret_set'> & TargetPlace,
): Partial<Record<TargetField, TargetProblem>> {
  const problems: Partial<Record<TargetField, TargetProblem>> = {}
  if (input.kind === 's3') {
    const next = normalizeTarget(input)
    if (!next.endpoint) problems.endpoint = 'required'
    else if (!ENDPOINT.test(next.endpoint)) problems.endpoint = 'invalid'
    if (!next.bucket) problems.bucket = 'required'
    else if (!BUCKET.test(next.bucket)) problems.bucket = 'invalid'
    if (next.prefix && !PREFIX.test(next.prefix)) problems.prefix = 'invalid'
    if (next.region && !REGION.test(next.region)) problems.region = 'invalid'
    const keyId = input.accessKeyId.trim().length
    if (keyId === 0) problems.accessKeyId = 'required'
    else if (keyId < 3 || keyId > 200) problems.accessKeyId = 'length'
    const secret = input.secretAccessKey.trim().length
    const secretStored = config.secret_set && targetKindOf(config) === 's3'
    if (secret === 0 && !secretStored) problems.secretAccessKey = 'required'
    else if (secret > 500) problems.secretAccessKey = 'length'
  }
  if (passwordMode(config, input) !== 'locked') {
    const password = input.password.length
    if (password === 0) problems.password = 'required'
    else if (password < BACKUP_PASSWORD_MIN || password > BACKUP_PASSWORD_MAX) problems.password = 'length'
    if (input.password !== extra.confirm) problems.confirm = 'mismatch'
    if (!extra.acknowledged) problems.acknowledged = 'required'
  }
  return problems
}

const TIME = /^([01][0-9]|2[0-3]):[0-5][0-9]$/

const inRange = (value: number, min: number, max: number) =>
  Number.isInteger(value) && value >= min && value <= max

export type ScheduleField = keyof BackupScheduleInput

export function scheduleProblems(input: BackupScheduleInput): Partial<Record<ScheduleField, 'invalid'>> {
  const problems: Partial<Record<ScheduleField, 'invalid'>> = {}
  if (!TIME.test(input.baseTime)) problems.baseTime = 'invalid'
  if (!TIME.test(input.restoreTestTime)) problems.restoreTestTime = 'invalid'
  if (!inRange(input.offsiteMinutes, 1, 60)) problems.offsiteMinutes = 'invalid'
  if (!inRange(input.retentionDaily, 1, 60)) problems.retentionDaily = 'invalid'
  if (!inRange(input.retentionWeekly, 0, 52)) problems.retentionWeekly = 'invalid'
  if (!inRange(input.retentionMonthly, 0, 36)) problems.retentionMonthly = 'invalid'
  if (!inRange(input.walDays, 1, 35)) problems.walDays = 'invalid'
  if (!inRange(input.restoreTestWeekday, 0, 6)) problems.restoreTestWeekday = 'invalid'
  return problems
}

export const scheduleLimits = {
  offsiteMinutes: [1, 60],
  retentionDaily: [1, 60],
  retentionWeekly: [0, 52],
  retentionMonthly: [0, 36],
  walDays: [1, 35],
} as const

export function scheduleOf(config: BackupConfig): BackupScheduleInput {
  return {
    baseTime: config.base_time,
    offsiteMinutes: config.offsite_minutes,
    retentionDaily: config.retention_daily,
    retentionWeekly: config.retention_weekly,
    retentionMonthly: config.retention_monthly,
    walDays: config.wal_days,
    restoreTest: config.restore_test,
    restoreTestWeekday: config.restore_test_weekday,
    restoreTestTime: config.restore_test_time,
  }
}

export function parseList(text: string) {
  return [
    ...new Set(
      text
        .split(/[\s,;]+/)
        .map((item) => item.trim())
        .filter(Boolean),
    ),
  ]
}

const TELEGRAM_TOKEN = /^[0-9]{5,16}:[A-Za-z0-9_-]{30,80}$/
const TELEGRAM_CHAT = /^(-?[0-9]{1,20}|@[A-Za-z0-9_]{5,32})$/
const EMAIL = /^[^@\s]{1,64}@[A-Za-z0-9.-]{1,253}$/
const SMTP_HOST = /^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$/
const CONSOLE_URL = /^https?:\/\/\S{1,200}$/

export type ChannelProblem = 'invalid' | 'too_many' | 'incomplete' | 'length' | 'required'

export function telegramProblems(input: TelegramInput, tokenSet: boolean) {
  const problems: Partial<Record<'botToken' | 'chatIds' | 'enabled', ChannelProblem>> = {}
  const token = input.botToken.trim()
  if (token && !TELEGRAM_TOKEN.test(token)) problems.botToken = 'invalid'
  if (input.chatIds.length > MAX_TELEGRAM_CHATS) problems.chatIds = 'too_many'
  else if (input.chatIds.some((chat) => !TELEGRAM_CHAT.test(chat))) problems.chatIds = 'invalid'
  if (input.enabled && ((!token && !tokenSet) || input.chatIds.length === 0)) problems.enabled = 'incomplete'
  return problems
}

export type EmailField = 'host' | 'port' | 'username' | 'password' | 'from' | 'to' | 'enabled'

export function emailProblems(input: EmailInput) {
  const problems: Partial<Record<EmailField, ChannelProblem>> = {}
  const host = input.host.trim().toLowerCase()
  if (host && !SMTP_HOST.test(host)) problems.host = 'invalid'
  if (input.port !== null && !inRange(input.port, 1, 65535)) problems.port = 'invalid'
  if (input.username.trim().length > 200) problems.username = 'length'
  if (input.password !== null && input.password.length > 500) problems.password = 'length'
  const from = input.from.trim()
  if (from && !EMAIL.test(from)) problems.from = 'invalid'
  if (input.to.length > MAX_EMAIL_RECIPIENTS) problems.to = 'too_many'
  else if (input.to.some((address) => !EMAIL.test(address))) problems.to = 'invalid'
  if (input.enabled && (!host || input.port === null || !from || input.to.length === 0)) {
    problems.enabled = 'incomplete'
  }
  return problems
}

export function optionsProblems(label: string, consoleUrl: string) {
  const problems: Partial<Record<'label' | 'consoleUrl', ChannelProblem>> = {}
  const text = label.trim()
  if (text.length < 1 || text.length > ALERT_LABEL_MAX) problems.label = 'length'
  const url = consoleUrl.trim().replace(/\/+$/, '')
  if (url && !CONSOLE_URL.test(url)) problems.consoleUrl = 'invalid'
  return problems
}

export function deliveryPending(channels: Pick<AlertChannels, 'last'> | undefined) {
  return channels?.last.telegram?.status === 'pending' || channels?.last.email?.status === 'pending'
}

export function parsePort(text: string) {
  const trimmed = text.trim()
  if (!trimmed) return null
  return /^\d+$/.test(trimmed) ? Number(trimmed) : Number.NaN
}

export const weekdays = [1, 2, 3, 4, 5, 6, 0] as const
