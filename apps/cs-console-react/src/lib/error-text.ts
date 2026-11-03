import i18n from '@/i18n'
import { toApiError } from '@/lib/errors'

const nasabahCodes = [
  'no_access',
  'permission_denied',
  'not_configured',
  'integration_refused',
  'upstream_unavailable',
  'upstream_error',
  'upstream_outdated',
  'demo_only',
  'self_approval',
  'approval_not_found',
  'customer_not_found',
  'customer_email_missing',
  'opening_account_not_found',
  'route_not_found',
  'invalid_query',
  'invalid_user_status',
  'status_reason_required',
  'invalid_login_id',
  'too_many_accounts',
  'invalid_account_link',
  'links_client_only',
  'invalid_csadmin_url',
  'invalid_csadmin_client_id',
] as const

type NasabahCode = (typeof nasabahCodes)[number]

const bannedWordCodes = [
  'invalid_banned_word',
  'invalid_banned_action',
  'banned_word_exists',
  'banned_word_not_found',
  'banned_word_limit',
  'import_conflict',
  'import_too_large',
  'invalid_import',
  'unsupported_file',
  'unreadable_file',
] as const

type BannedWordCode = (typeof bannedWordCodes)[number]

const isBannedWordCode = (code: string): code is BannedWordCode =>
  (bannedWordCodes as readonly string[]).includes(code)

const communityCodes = [
  'community_forbidden',
  'four_eyes',
  'stale_version',
  'invalid_status',
  'username_taken',
  'official_inactive',
  'protected_account',
  'content_blocked',
  'no_push_devices',
  'invalid_avatar',
  'account_not_found',
] as const

type CommunityCode = (typeof communityCodes)[number]

const isCommunityCode = (code: string): code is CommunityCode =>
  (communityCodes as readonly string[]).includes(code)

const pushCodes = ['invalid_push_credentials', 'push_project_changed', 'push_credentials_missing'] as const

type PushCode = (typeof pushCodes)[number]

const isPushCode = (code: string): code is PushCode => (pushCodes as readonly string[]).includes(code)

const legalCodes = [
  'legal_scheduled_exists',
  'legal_draft_locked',
  'legal_draft_not_pending',
  'legal_note_required',
  'legal_effective_past',
  'legal_already_effective',
  'legal_draft_not_found',
  'document_not_found',
  'invalid_legal_kind',
  'invalid_legal_title',
  'invalid_legal_body',
  'invalid_legal_summary',
] as const

type LegalCode = (typeof legalCodes)[number]

const isLegalCode = (code: string): code is LegalCode => (legalCodes as readonly string[]).includes(code)

const systemCodes = [
  'alert_not_found',
  'invalid_telegram_token',
  'invalid_telegram_chat',
  'telegram_incomplete',
  'invalid_smtp',
  'invalid_email_address',
  'email_incomplete',
  'invalid_alert_label',
  'invalid_console_url',
  'alert_channel_disabled',
  'invalid_alert_channel',
  'invalid_backup_endpoint',
  'invalid_backup_bucket',
  'invalid_backup_prefix',
  'invalid_backup_region',
  'invalid_backup_credentials',
  'weak_backup_password',
  'backup_password_locked',
  'invalid_backup_schedule',
  'invalid_backup_request',
  'backup_not_configured',
] as const

type SystemCode = (typeof systemCodes)[number]

const isSystemCode = (code: string): code is SystemCode => (systemCodes as readonly string[]).includes(code)

const isNasabahCode = (code: string): code is NasabahCode =>
  (nasabahCodes as readonly string[]).includes(code)

export function errorText(error: unknown): string {
  const e = toApiError(error)
  const t = i18n.t.bind(i18n)
  if (isNasabahCode(e.code)) return t(`nasabah.errors.${e.code}`)
  if (isBannedWordCode(e.code)) return t(`compliance.words.errors.${e.code}`)
  if (isCommunityCode(e.code)) return t(`community.errorCodes.${e.code}`)
  if (isPushCode(e.code)) return t(`push.errorCodes.${e.code}`)
  if (isLegalCode(e.code)) return t(`legal.errors.${e.code}`)
  if (isSystemCode(e.code)) return t(`system.errors.${e.code}`)
  switch (e.code) {
    case 'invalid_credentials':
      return t('errors.invalidLogin')
    case 'over_request_rate_limit':
    case 'too_many_requests':
    case 'rate_limited':
      return t('errors.tooManyAttempts')
    case 'network':
      return t('errors.network')
    case 'session_expired':
      return t('errors.sessionExpired')
    case 'unavailable':
      return t('errors.unavailable')
    case 'same_password':
      return t('errors.samePassword')
    case 'weak_password':
      return t('errors.weakPassword')
    case 'stale_ticket':
      return t('errors.staleTicket')
    case 'agent_offline':
      return t('presence.blockedReply')
    case 'secret_request_blocked':
      return e.detail ?? t('errors.secretBlocked')
    default:
      return e.status !== undefined && e.detail ? e.detail : t('errors.generic')
  }
}

export function legalErrorText(error: unknown): string {
  return toApiError(error).code === 'four_eyes' ? i18n.t('legal.errors.four_eyes') : errorText(error)
}
