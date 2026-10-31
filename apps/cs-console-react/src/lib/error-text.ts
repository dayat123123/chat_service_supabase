import i18n from '@/i18n'
import { toApiError } from '@/lib/errors'

const nasabahCodes = [
  'no_access',
  'permission_denied',
  'not_configured',
  'integration_refused',
  'upstream_unavailable',
  'upstream_error',
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
] as const

type NasabahCode = (typeof nasabahCodes)[number]

const isNasabahCode = (code: string): code is NasabahCode =>
  (nasabahCodes as readonly string[]).includes(code)

export function errorText(error: unknown): string {
  const e = toApiError(error)
  const t = i18n.t.bind(i18n)
  if (isNasabahCode(e.code)) return t(`nasabah.errors.${e.code}`)
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
