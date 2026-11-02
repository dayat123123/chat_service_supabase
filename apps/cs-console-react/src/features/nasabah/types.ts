export const nasabahPermissions = [
  'online_user.view',
  'online_user.manage',
  'online_user.demo',
  'online_user.approve',
  'online_user.approve_own',
  'online_user.status',
  'opening_account.send',
] as const
export type NasabahPermission = (typeof nasabahPermissions)[number]

export const loginTypes = [0, 1, 2, 3, 4, 5] as const
export type LoginType = (typeof loginTypes)[number]
export const DEMO = 0
export const CLIENT = 1
export const SALES = 2

export const MAX_LINK_CHARS = 255

export const userStatuses = [0, 1, 2, 3] as const
export type UserStatus = (typeof userStatuses)[number]

export const userFlags = [
  { bit: 1, key: 'viewOnly' },
  { bit: 2, key: 'syariah' },
  { bit: 4, key: 'delayed' },
  { bit: 8, key: 'vip' },
  { bit: 16, key: 'research' },
  { bit: 32, key: 'announcement' },
] as const
export type UserFlag = (typeof userFlags)[number]['key']

export const approvalActions = [1, 2, 3] as const
export type ApprovalAction = (typeof approvalActions)[number]

export const approvalStatuses = [1, 2, 0] as const
export type ApprovalStatus = (typeof approvalStatuses)[number]

export type OnlineUser = {
  LoginId: string
  LoginType: number
  Email: string
  Status: number
  ErrorPwdRetry: number
  ErrorPinRetry: number
  AccountExpired: string
  SalesId: string
  Permissions: number
  Created: string
  BirthDate: string
  PhoneNumber: string
  IsPhoneNumberApproved: number
  PhoneNumberApprovedAt: string
  IsEmailApproved: number
  EmailApprovedAt: string
}

export type LinkedAccount = { AccountId: string; AccountName: string; Created: string; CreatedBy: string }

export type ProfileAccount = LinkedAccount & {
  Branch: string
  RDNAccount: string
  RDNBank: string
  InvestorNo: string
  KSEIId: string
}

export type OnlineUserProfile = OnlineUser & { Accounts: ProfileAccount[] }

export type TicketLogin = { login_id: string; source: 'olt' | 'profile' }

export type ApprovalLink = LinkedAccount & { ActionType: number }

export type CatalogAccount = { CustId: string; Name: string; StaffId: string; Branch: string }

export type Approval = {
  ApprovalId: number
  ActionType: number
  Status: number
  LoginId: string
  Email: string
  LoginType: number
  AccountExpired: string
  SalesId: string
  Permissions: number
  Created: string
  CreatedBy: string
  Approved: string
  ApprovedBy: string
  BirthDate: string
  PhoneNumber: string
}

export type OpeningAccount = {
  LoginId: string
  CustId: string
  Name: string
  RDNAccount: string
  RDNBank: string
  InvestorNo: string
  KSEIID: string
  Email: string
}

export type IncompleteField = 'email' | 'phone' | 'birthDate'

export type Page<T> = { rows: T[]; total: number; page: number; perPage: number; totalPages: number }

export const PAGE_SIZE = 30
export const OPENING_PAGE_SIZE = 100

export type OnlineUserForm = {
  loginId: string
  loginType: LoginType
  email: string
  phone: string
  birthDate: string
  salesId: string
  status: UserStatus
  flags: number
  neverExpired: boolean
  accountExpired: string
  expiredAt: string
  links: string[]
}

export type FormContext = {
  previous: OnlineUser | null
  previousLinks: string[]
  catalog: CatalogAccount[] | undefined
  today?: Date
}

export type SalesOption = { id: string; count: number }

export type ApprovalFilter = { status: ApprovalStatus | -1; action: ApprovalAction | -1; query: string }

export type OpeningFilter = { loginId: string; custId: string }
