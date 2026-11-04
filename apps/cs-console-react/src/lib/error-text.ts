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
  'invalid_audience',
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
  'invalid_backup_kind',
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

const platformCodes = [
  'invalid_name',
  'invalid_scopes',
  'invalid_cidr',
  'invalid_rate_limit',
  'official_required',
  'key_not_found',
  'key_revoked',
  'reason_required',
  'invalid_flag',
  'unknown_flag',
  'flag_not_deletable',
  'invalid_platform',
  'invalid_version',
  'invalid_kill_switch',
  'invalid_range',
] as const

const policyCodes = [
  'category_not_found',
  'invalid_action',
  'invalid_scope',
  'invalid_match',
  'invalid_domain',
  'invalid_category',
  'invalid_note',
  'domain_limit',
  'domain_not_found',
  'invalid_term',
  'term_exists',
  'term_limit',
  'term_not_found',
  'invalid_setting',
  'invalid_surface',
  'invalid_text',
  'invalid_image_thresholds',
  'policy_review_required',
  'policy_no_change',
  'policy_stale',
  'policy_limit',
  'policy_draft_not_found',
  'policy_change_not_found',
  'policy_change_decided',
  'policy_version_not_found',
  'invalid_policy_call',
  'invalid_reason',
  'note_required',
  'four_eyes',
  'invalid_decision',
] as const

const moderationCodes = [
  'invalid_action',
  'invalid_target',
  'reason_required',
  'note_required',
  'invalid_note',
  'invalid_decision',
  'invalid_status',
  'media_review_not_found',
  'media_review_decided',
  'appeal_not_found',
  'appeal_decided',
  'appeal_reviewer_conflict',
  'alert_not_found',
  'alert_reviewed',
  'invalid_slow_mode',
  'invalid_until',
  'room_not_found',
  'invalid_message',
  'invalid_stock_code',
  'user_not_found',
  'private_message_forbidden',
  'content_not_found',
  'invalid_target_type',
  'invalid_targets',
] as const

const among = <T extends string>(codes: readonly T[], code: string): code is T =>
  (codes as readonly string[]).includes(code)

export function platformErrorText(error: unknown): string {
  const code = toApiError(error).code
  return among(platformCodes, code) ? i18n.t(`platform.errors.${code}`) : errorText(error)
}

export function policyErrorText(error: unknown): string {
  const code = toApiError(error).code
  return among(policyCodes, code) ? i18n.t(`policy.errors.${code}`) : errorText(error)
}

export function moderationErrorText(error: unknown): string {
  const code = toApiError(error).code
  return among(moderationCodes, code) ? i18n.t(`moderation.errors.${code}`) : errorText(error)
}

const bannerCodes = [
  'invalid_title',
  'invalid_body',
  'invalid_link',
  'invalid_level',
  'invalid_platform',
  'invalid_version',
  'invalid_priority',
  'invalid_schedule',
  'banner_not_found',
] as const

export function bannerErrorText(error: unknown): string {
  const code = toApiError(error).code
  return among(bannerCodes, code) ? i18n.t(`platform.banners.errors.${code}`) : errorText(error)
}
