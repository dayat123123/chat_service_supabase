import { rpc } from '@/lib/supabase'

import type {
  AlertChannel,
  AlertChannels,
  BackupConfig,
  BackupOverview,
  BackupRequestKind,
  BackupScheduleInput,
  BackupTargetInput,
  EmailInput,
  HealthBadge,
  SystemHealth,
  TelegramInput,
} from './types'

const blank = (value: string) => value.trim() || null

export const systemApi = {
  health: async (): Promise<SystemHealth> => {
    const raw = await rpc<SystemHealth>('system_health')
    return {
      ...raw,
      checks: raw.checks ?? [],
      alerts: { open: raw.alerts?.open ?? [], recent: raw.alerts?.recent ?? [] },
      services: raw.services ?? [],
      probes: raw.probes ?? [],
      disks: raw.disks ?? [],
      database: { ...raw.database, slots: raw.database?.slots ?? [] },
      cron: raw.cron ?? [],
    }
  },
  badge: () => rpc<HealthBadge>('system_health_badge'),
  acknowledge: (alertId: number) => rpc<null>('health_acknowledge', { p_alert_id: alertId }),
  backup: async (): Promise<BackupOverview> => {
    const raw = await rpc<BackupOverview>('backup_overview')
    return { ...raw, requests: raw.requests ?? [], runs: raw.runs ?? [] }
  },
  setBackupTarget: (input: BackupTargetInput) =>
    input.kind === 'local'
      ? rpc<BackupConfig>('backup_set_target', { p_kind: 'local', p_password: input.password || null })
      : rpc<BackupConfig>('backup_set_target', {
          p_kind: 's3',
          p_endpoint: input.endpoint.trim(),
          p_bucket: input.bucket.trim(),
          p_prefix: blank(input.prefix),
          p_region: blank(input.region),
          p_access_key_id: input.accessKeyId.trim(),
          p_secret_access_key: input.secretAccessKey || null,
          p_password: input.password || null,
        }),
  setBackupSchedule: (input: BackupScheduleInput) =>
    rpc<BackupConfig>('backup_set_schedule', {
      p_base_time: input.baseTime,
      p_offsite_minutes: input.offsiteMinutes,
      p_retention_daily: input.retentionDaily,
      p_retention_weekly: input.retentionWeekly,
      p_retention_monthly: input.retentionMonthly,
      p_wal_days: input.walDays,
      p_restore_test: input.restoreTest,
      p_restore_test_weekday: input.restoreTestWeekday,
      p_restore_test_time: input.restoreTestTime,
    }),
  requestBackup: (kind: BackupRequestKind) => rpc<BackupOverview>('backup_request', { p_kind: kind }),
  channels: () => rpc<AlertChannels>('alert_channels_view'),
  setOptions: (label: string, consoleUrl: string) =>
    rpc<AlertChannels>('alert_set_options', { p_label: label.trim(), p_console_url: blank(consoleUrl) }),
  setTelegram: (input: TelegramInput) =>
    rpc<AlertChannels>('alert_set_telegram', {
      p_enabled: input.enabled,
      p_chat_ids: input.chatIds,
      p_bot_token: input.botToken.trim() || null,
    }),
  setEmail: (input: EmailInput) =>
    rpc<AlertChannels>('alert_set_email', {
      p_enabled: input.enabled,
      p_host: blank(input.host),
      p_port: input.port,
      p_security: input.security,
      p_username: blank(input.username),
      p_from: blank(input.from),
      p_to: input.to,
      p_password: input.password,
    }),
  sendTest: (channel: AlertChannel) => rpc<AlertChannels>('alert_send_test', { p_channel: channel }),
}
