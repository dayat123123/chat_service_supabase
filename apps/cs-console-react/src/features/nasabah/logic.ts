import { format, isValid, parseISO, subYears } from 'date-fns'

import {
  CLIENT,
  DEMO,
  MAX_LINK_CHARS,
  SALES,
  type Approval,
  type ApprovalAction,
  type CatalogAccount,
  type FormContext,
  type IncompleteField,
  type LoginType,
  type NasabahPermission,
  type OnlineUser,
  type OnlineUserForm,
  type OpeningAccount,
  type Page,
  type SalesOption,
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

export const canViewProfiles = (perms: readonly string[]) =>
  has(
    perms,
    'online_user.view',
    'online_user.manage',
    'online_user.demo',
    'online_user.approve',
    'online_user.approve_own',
    'online_user.status',
  )

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

const stamp = /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})(?::(\d{2}))?/

export function legacyDate(value: string | null | undefined) {
  return /^\d{4}-\d{2}-\d{2}/.test(value ?? '') ? (value ?? '').slice(0, 10) : ''
}

function legacyDateTime(value: string) {
  const match = stamp.exec(value)
  return match ? `${match[1]} ${match[2]}:${match[3] ?? '00'}` : ''
}

export function flagsOf(permissions: number): UserFlag[] {
  return userFlags.filter((flag) => (permissions & flag.bit) !== 0).map((flag) => flag.key)
}

export function toggleFlag(permissions: number, bit: number, on: boolean) {
  return on ? permissions | bit : permissions & ~bit
}

export const needsSalesId = (type: number) => type === 2 || type === 3 || type === 5

const day = (date: Date) => format(date, 'yyyy-MM-dd')

const isDay = (value: string) =>
  /^\d{4}-\d{2}-\d{2}$/.test(value) && isValid(parseISO(value)) && day(parseISO(value)) === value

export function dateBounds(today = new Date()) {
  return {
    birthMin: day(subYears(today, 80)),
    birthMax: day(today),
    expiredMin: day(today),
    expiredMax: `${today.getFullYear() + 3}-01-01`,
  }
}

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
    neverExpired: loginType !== DEMO,
    accountExpired: '',
    expiredAt: '',
    links: [],
  }
}

export function formFromUser(user: OnlineUser, links: string[]): OnlineUserForm {
  const expiredAt = legacyDateTime(user.AccountExpired ?? '')
  return {
    loginId: user.LoginId,
    loginType: (user.LoginType as LoginType) ?? CLIENT,
    email: user.Email ?? '',
    phone: user.PhoneNumber ?? '',
    birthDate: legacyDate(user.BirthDate),
    salesId: user.SalesId ?? '',
    status: (user.Status as UserStatus) ?? 1,
    flags: user.Permissions ?? 0,
    neverExpired: expiredAt === '',
    accountExpired: legacyDate(expiredAt),
    expiredAt,
    links: [...links],
  }
}

export function withLoginType(
  form: OnlineUserForm,
  loginType: LoginType,
  previousLinks: string[],
): OnlineUserForm {
  return {
    ...form,
    loginType,
    salesId: '',
    neverExpired: loginType !== DEMO,
    accountExpired: '',
    links: [...previousLinks],
  }
}

export function salesOptions(catalog: CatalogAccount[] | undefined, loginType: number): SalesOption[] {
  if (!catalog || !needsSalesId(loginType)) return []
  const counts = new Map<string, number>()
  for (const account of catalog) {
    const id = (loginType === SALES ? account.StaffId : account.Branch).trim()
    if (id) counts.set(id, (counts.get(id) ?? 0) + 1)
  }
  return [...counts].map(([id, count]) => ({ id, count })).sort((a, b) => a.id.localeCompare(b.id))
}

export function linkChanges(action: ApprovalAction, form: OnlineUserForm, previousLinks: string[]) {
  if (action === 3) return { link: [], unlink: [...previousLinks] }
  if (form.loginType !== CLIENT) return { link: [], unlink: [] }
  return {
    link: form.links.filter((id) => !previousLinks.includes(id)),
    unlink: previousLinks.filter((id) => !form.links.includes(id)),
  }
}

export const fitsLinkParameter = (ids: string[]) => ids.join(',').length <= MAX_LINK_CHARS

export type FormProblem =
  | 'loginId'
  | 'email'
  | 'phone'
  | 'birthDate'
  | 'salesId'
  | 'salesUnknown'
  | 'accountExpired'
  | 'links'
  | 'demoOnly'

const loginIdPattern = /^[A-Za-z0-9._@-]{3,50}$/

const emailPattern = /^[A-Za-z0-9._+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/

const phonePattern = /^\+?[0-9]{7,20}$/

export function formProblems(
  form: OnlineUserForm,
  perms: readonly string[],
  context: FormContext,
): FormProblem[] {
  const problems: FormProblem[] = []
  const { previous } = context
  const bounds = dateBounds(context.today)
  const email = form.email.trim()
  if (!previous && !loginIdPattern.test(form.loginId.trim())) problems.push('loginId')
  if (email.length > 100 || !emailPattern.test(email)) problems.push('email')
  if (!phonePattern.test(form.phone.trim())) problems.push('phone')
  const keptBirth =
    previous !== null && form.birthDate === legacyDate(previous.BirthDate) && form.birthDate > '1900-01-01'
  if (
    !keptBirth &&
    !(isDay(form.birthDate) && form.birthDate >= bounds.birthMin && form.birthDate <= bounds.birthMax)
  )
    problems.push('birthDate')
  if (needsSalesId(form.loginType)) {
    const salesId = form.salesId.trim()
    if (!salesId) problems.push('salesId')
    else if (!salesOptions(context.catalog, form.loginType).some((option) => option.id === salesId))
      problems.push('salesUnknown')
  }
  if (form.loginType === DEMO && !form.neverExpired) {
    const kept = form.expiredAt !== '' && form.accountExpired === legacyDate(form.expiredAt)
    if (
      !kept &&
      !(
        isDay(form.accountExpired) &&
        form.accountExpired >= bounds.expiredMin &&
        form.accountExpired <= bounds.expiredMax
      )
    )
      problems.push('accountExpired')
  }
  const changes = linkChanges(previous ? 2 : 1, form, context.previousLinks)
  if (!fitsLinkParameter(changes.link) || !fitsLinkParameter(changes.unlink)) problems.push('links')
  if (!has(perms, 'online_user.manage') && form.loginType !== DEMO) problems.push('demoOnly')
  return problems
}

function expiryValue(form: OnlineUserForm) {
  if (form.loginType !== DEMO || form.neverExpired || !isDay(form.accountExpired)) return ''
  return form.expiredAt && form.accountExpired === legacyDate(form.expiredAt)
    ? form.expiredAt
    : `${form.accountExpired} 00:00:00`
}

export function approvalPayload(action: ApprovalAction, form: OnlineUserForm, previousLinks: string[]) {
  const changes = linkChanges(action, form, previousLinks)
  const base = {
    LoginId: form.loginId.trim(),
    LoginType: form.loginType,
    ActionType: action,
    Permissions: form.flags,
    SalesId: needsSalesId(form.loginType) ? form.salesId.trim() : '',
    Email: form.email.trim(),
    LoginStatus: form.status,
    AccountExpired: expiryValue(form),
    ArrayAccountLink: changes.link,
    ArrayAccountUnLink: changes.unlink,
  }
  if (action === 3) return base
  return { ...base, BirthDate: form.birthDate, HandphoneNo: form.phone.trim() }
}

export type OpeningGroup<T> = { key: string; loginId: string; rows: T[]; emails: string[] }

export function groupOpenings<T extends Pick<OpeningAccount, 'LoginId' | 'Email'>>(
  rows: T[],
): OpeningGroup<T>[] {
  const groups = new Map<string, OpeningGroup<T>>()
  for (const row of rows) {
    const loginId = row.LoginId.trim()
    const key = loginId.toLowerCase()
    const group = groups.get(key) ?? { key, loginId, rows: [], emails: [] }
    groups.set(key, group)
    group.rows.push(row)
    const email = (row.Email ?? '').trim()
    if (email && !group.emails.includes(email)) group.emails.push(email)
  }
  return [...groups.values()]
}
