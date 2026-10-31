export const nasabahPermissions = [
  'online_user.view',
  'online_user.manage',
  'online_user.demo',
  'online_user.approve',
  'online_user.status',
  'opening_account.send',
  'cs_user.manage',
  'cs_log.view',
] as const
export type NasabahPermission = (typeof nasabahPermissions)[number]

export const loginTypes = [0, 1, 2, 3, 4, 5] as const
export type LoginType = (typeof loginTypes)[number]
export const DEMO = 0
export const CLIENT = 1

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

export const csFlags = [
  { bit: 0, key: 'createCsLogin' },
  { bit: 1, key: 'createOnlineUser' },
  { bit: 2, key: 'approveOnlineUser' },
  { bit: 3, key: 'createDemoAccount' },
  { bit: 4, key: 'viewCsLogs' },
  { bit: 5, key: 'approvalOpeningAccount' },
  { bit: 6, key: 'viewReports' },
  { bit: 7, key: 'sendOlUserDisclaimer' },
  { bit: 8, key: 'viewCustomerRatio' },
] as const
export type CsFlag = (typeof csFlags)[number]['key']
export const ALL_CS_FLAGS = 511

export const csUserStatuses = [1, 0] as const

export type CsUser = {
  LoginId: string
  EmployeeId: string
  Email: string
  Status: number
  Permissions: number
  Created: string
  LastModified: string
  LastLogin: string
  CreatedBy: string
  ModifiedBy: string
}

export type CsUserForm = {
  loginId: string
  employeeId: string
  email: string
  status: number
  permissions: number
}

export type CsUserFilter = { loginId: string; employeeId: string }

export type CreatedCsUser = { TemporaryPassword?: string; TemporaryPasswordError?: boolean }

export const csLogTypes = [
  'loginFailed',
  'loginSucceeded',
  'logout',
  'createCs',
  'editCs',
  'deleteCs',
  'createOnline',
  'editOnline',
  'deleteOnline',
  'approveOnline',
  'rejectOnline',
  'resetPin',
  'resetPassword',
  'resetPinPassword',
  'openingApprovalEmail',
  'linkAccount',
  'approveLink',
  'disclaimer',
  'customerRatio',
  'approveUnlink',
  'unlinkAccount',
  'openingEmail',
  'forgotEmail',
] as const
export type CsLogType = (typeof csLogTypes)[number]

export type CsLog = {
  LogId: number
  CSLoginId: string
  LoginId: string
  LogTime: string
  ApprovalId: number
  LogType: number
  LogDesc: string
}

export type CsLogFilter = { logType: number; csLoginId: string; loginId: string }

export type GatewayInfo = { configured: boolean; service_login_id: string; actor: string; actor_mode: string }

export type IncompleteField = 'email' | 'phone' | 'birthDate'

export type Page<T> = { rows: T[]; total: number; page: number; perPage: number; totalPages: number }

export const PAGE_SIZE = 30

export type OnlineUserForm = {
  loginId: string
  loginType: LoginType
  email: string
  phone: string
  birthDate: string
  salesId: string
  status: UserStatus
  flags: number
  accountExpired: string
  links: string[]
}

export type ApprovalFilter = { status: ApprovalStatus | -1; action: ApprovalAction | -1; query: string }

export type OpeningFilter = { loginId: string; custId: string }
