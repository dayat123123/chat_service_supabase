import {
  CLIENT,
  DEMO,
  type Approval,
  type ApprovalAction,
  type IncompleteField,
  type LoginType,
  type NasabahPermission,
  type OnlineUser,
  type OnlineUserForm,
  type Page,
  type UserFlag,
  type UserStatus,
  userFlags,
} from './types'

export type NasabahTab = 'users' | 'approvals' | 'opening'

export const has = (perms: readonly string[], ...wanted: NasabahPermission[]) =>
  wanted.some((perm) => perms.includes(perm))

export function nasabahTabs(perms: readonly string[]): NasabahTab[] {
  const tabs: NasabahTab[] = []
  if (
    has(
      perms,
      'online_user.view',
      'online_user.manage',
      'online_user.demo',
      'online_user.approve',
      'online_user.approve_own',
      'online_user.status',
    )
  )
    tabs.push('users')
  if (has(perms, 'online_user.approve', 'online_user.approve_own', 'online_user.manage', 'online_user.demo'))
    tabs.push('approvals')
  if (has(perms, 'opening_account.send')) tabs.push('opening')
  return tabs
}

export const canEditUser = (perms: readonly string[], user: Pick<OnlineUser, 'LoginType'> | null) =>
  has(perms, 'online_user.manage') ||
  (has(perms, 'online_user.demo') && (user === null || user.LoginType === DEMO))

export const canLinkAccounts = (perms: readonly string[], user: Pick<OnlineUser, 'LoginType'>) =>
  has(perms, 'online_user.manage') && user.LoginType === CLIENT

export const canResetCredentials = (perms: readonly string[]) => has(perms, 'online_user.manage')

export const canChangeStatus = (perms: readonly string[]) => has(perms, 'online_user.status')

export const statusReasonOk = (reason: string) => {
  const length = [...reason.trim()].length
  return length >= 10 && length <= 200
}

export function incompleteFields(
  user: Pick<OnlineUser, 'Email' | 'PhoneNumber' | 'BirthDate'>,
): IncompleteField[] {
  const missing: IncompleteField[] = []
  if (!(user.Email ?? '').trim()) missing.push('email')
  if (!(user.PhoneNumber ?? '').trim()) missing.push('phone')
  const birth = legacyDate(user.BirthDate)
  if (!birth || birth <= '1900-01-01') missing.push('birthDate')
  return missing
}

export const isSelfSubmitted = (approval: Pick<Approval, 'CreatedBy'>, agentCode: string) =>
  approval.CreatedBy.trim().toLowerCase() === agentCode.trim().toLowerCase()

export const canDecide = (
  perms: readonly string[],
  approval: Pick<Approval, 'Status' | 'CreatedBy'>,
  agentCode: string,
) =>
  approval.Status === 1 &&
  (isSelfSubmitted(approval, agentCode)
    ? has(perms, 'online_user.approve_own')
    : has(perms, 'online_user.approve'))

export function userSearch(query: string): Record<string, string> {
  const value = query.trim()
  if (!value) return {}
  return value.includes('@') ? { email: value } : { loginId: value }
}

type RawPage<T> = {
  data?: T[] | null
  pagination?: { current_page?: number; per_page?: number; total_items?: number; total_pages?: number }
}

export function toPage<T>(raw: RawPage<T> | null | undefined, page: number, perPage: number): Page<T> {
  const rows = Array.isArray(raw?.data) ? raw.data : []
  const p = raw?.pagination
  const total = p?.total_items ?? rows.length
  return {
    rows,
    total,
    page: p?.current_page ?? page,
    perPage: p?.per_page ?? perPage,
    totalPages: p?.total_pages ?? (total === 0 ? 0 : Math.ceil(total / perPage)),
  }
}

export function toList<T>(raw: { data?: T[] | null } | null | undefined): T[] {
  return Array.isArray(raw?.data) ? raw.data : []
}

const stamp = /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})/

export function legacyDate(value: string | null | undefined) {
  return /^\d{4}-\d{2}-\d{2}/.test(value ?? '') ? (value ?? '').slice(0, 10) : ''
}

export function legacyDateTimeInput(value: string | null | undefined) {
  const match = stamp.exec(value ?? '')
  return match ? `${match[1]}T${match[2]}` : ''
}

export function inputToLegacyDateTime(value: string) {
  const match = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(?::(\d{2}))?$/.exec(value.trim())
  return match ? `${match[1]} ${match[2]}:${match[3] ?? '00'}` : ''
}

export function flagsOf(permissions: number): UserFlag[] {
  return userFlags.filter((flag) => (permissions & flag.bit) !== 0).map((flag) => flag.key)
}

export function toggleFlag(permissions: number, bit: number, on: boolean) {
  return on ? permissions | bit : permissions & ~bit
}

export const needsSalesId = (type: number) => type === 2 || type === 3 || type === 5

export function emptyForm(loginType: LoginType = CLIENT): OnlineUserForm {
  return {
    loginId: '',
    loginType,
    email: '',
    phone: '',
    birthDate: '',
    salesId: '',
    status: 1,
    flags: 0,
    accountExpired: '',
    links: [],
  }
}

export function formFromUser(user: OnlineUser, links: string[]): OnlineUserForm {
  return {
    loginId: user.LoginId,
    loginType: (user.LoginType as LoginType) ?? CLIENT,
    email: user.Email ?? '',
    phone: user.PhoneNumber ?? '',
    birthDate: legacyDate(user.BirthDate),
    salesId: user.SalesId ?? '',
    status: (user.Status as UserStatus) ?? 1,
    flags: user.Permissions ?? 0,
    accountExpired: legacyDateTimeInput(user.AccountExpired),
    links: [...links],
  }
}

export type FormProblem = 'loginId' | 'salesId' | 'email' | 'demoOnly' | 'accountExpired'

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export function formProblems(form: OnlineUserForm, perms: readonly string[]): FormProblem[] {
  const problems: FormProblem[] = []
  if (!/^\S{3,50}$/.test(form.loginId.trim())) problems.push('loginId')
  if (form.email.trim() && !emailPattern.test(form.email.trim())) problems.push('email')
  if (needsSalesId(form.loginType) && !form.salesId.trim()) problems.push('salesId')
  if (form.loginType === DEMO && form.accountExpired && !inputToLegacyDateTime(form.accountExpired))
    problems.push('accountExpired')
  if (!has(perms, 'online_user.manage') && form.loginType !== DEMO) problems.push('demoOnly')
  return problems
}

export function approvalPayload(action: ApprovalAction, form: OnlineUserForm, previousLinks: string[]) {
  const links = form.loginType === CLIENT && action !== 3 ? form.links : []
  const base = {
    LoginId: form.loginId.trim(),
    LoginType: form.loginType,
    ActionType: action,
    Permissions: form.flags,
    SalesId: needsSalesId(form.loginType) ? form.salesId.trim() : '',
    Email: form.email.trim(),
    LoginStatus: form.status,
    AccountExpired: form.loginType === DEMO ? inputToLegacyDateTime(form.accountExpired) : '',
    ArrayAccountLink: links.filter((id) => !previousLinks.includes(id)),
    ArrayAccountUnLink: previousLinks.filter((id) => !links.includes(id)),
  }
  if (action === 3) return base
  return { ...base, BirthDate: form.birthDate, HandphoneNo: form.phone.trim() }
}
