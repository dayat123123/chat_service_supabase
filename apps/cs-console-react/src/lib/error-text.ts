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

const isNasabahCode = (code: string): code is NasabahCode =>
  (nasabahCodes as readonly string[]).includes(code)

export function errorText(error: unknown): string {
  const e = toApiError(error)
  const t = i18n.t.bind(i18n)
  if (isNasabahCode(e.code)) return t(`nasabah.errors.${e.code}`)
  if (isBannedWordCode(e.code)) return t(`compliance.words.errors.${e.code}`)
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
