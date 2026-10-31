import { ApiError } from '@/lib/errors'
import { supabase } from '@/lib/supabase'

import { toList, toPage, userSearch } from './logic'
import {
  PAGE_SIZE,
  type Approval,
  type ApprovalFilter,
  type ApprovalLink,
  type CatalogAccount,
  type LinkedAccount,
  type OnlineUser,
  type OpeningAccount,
  type OpeningFilter,
  type Page,
} from './types'

const BASE = '/api-nasabah'

type Query = Record<string, string | number | undefined>

type Message = { message?: string }

type ErrorBody = { code?: unknown; message?: unknown }

function parseBody(text: string): ErrorBody | null {
  if (!text) return null
  try {
    return JSON.parse(text) as ErrorBody
  } catch {
    return null
  }
}

const statusCode: Record<number, string> = {
  400: 'bad_request',
  401: 'session_expired',
  403: 'permission_denied',
  404: 'not_found',
  409: 'conflict',
}

async function request<T>(
  method: 'GET' | 'POST' | 'PUT',
  path: string,
  query: Query = {},
  body?: unknown,
): Promise<T> {
  const { data } = await supabase().auth.getSession()
  const token = data.session?.access_token
  if (!token) throw new ApiError('session_expired', undefined, 401)
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== '') params.set(key, String(value))
  }
  const suffix = params.size > 0 ? `?${params.toString()}` : ''
  let response: Response
  try {
    response = await fetch(`${BASE}${path}${suffix}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new ApiError('network')
  }
  const json = parseBody(await response.text())
  if (!response.ok) {
    const code =
      typeof json?.code === 'string'
        ? json.code
        : (statusCode[response.status] ?? (response.status >= 500 ? 'upstream_error' : 'unknown'))
    throw new ApiError(code, typeof json?.message === 'string' ? json.message : undefined, response.status)
  }
  return json as T
}

export const nasabahApi = {
  users: async (page: number, query: string): Promise<Page<OnlineUser>> =>
    toPage(
      await request('GET', '/online/get-list-online-user', { page, size: PAGE_SIZE, ...userSearch(query) }),
      page,
      PAGE_SIZE,
    ),
  linkedAccounts: async (loginId: string) =>
    toList<LinkedAccount>(await request('GET', '/online/get-linked-account-online-user', { loginId })),
  catalog: async () => toList<CatalogAccount>(await request('GET', '/online/get-list-link-account')),
  submit: (payload: Record<string, unknown>) =>
    request<Message>('POST', '/online/create-approval-login', {}, payload),
  resetCredential: (loginId: string, kind: 'password' | 'pin') =>
    request<Message>(
      'POST',
      '/online/change-password-and-pin-online-user',
      {},
      {
        LoginId: loginId,
        ActionType: kind === 'password' ? 0 : 1,
      },
    ),
  approvals: async (page: number, filter: ApprovalFilter, submitter: string): Promise<Page<Approval>> =>
    toPage(
      await request('GET', '/online/get-list-approval-online-user', {
        page,
        size: PAGE_SIZE,
        status: filter.status,
        actionType: filter.action,
        loginId: filter.query.trim() || undefined,
        createdBy: submitter.trim() || undefined,
      }),
      page,
      PAGE_SIZE,
    ),
  approvalLinks: async (approvalId: number) =>
    toList<ApprovalLink>(
      await request('GET', '/online/get-approval-linked-account-online-user', { approvalId }),
    ),
  decide: (approval: Pick<Approval, 'ApprovalId' | 'LoginId'>, approve: boolean) =>
    request<Message>(
      'POST',
      '/online/approve-approval-login',
      {},
      {
        ApprovalId: approval.ApprovalId,
        LoginId: approval.LoginId,
        Status: approve ? 2 : 0,
      },
    ),
  openings: async (page: number, filter: OpeningFilter): Promise<Page<OpeningAccount>> =>
    toPage(
      await request('GET', '/online/get-list-opening-rekening-online-user', {
        page,
        size: PAGE_SIZE,
        loginId: filter.loginId.trim() || undefined,
        custId: filter.custId.trim() || undefined,
      }),
      page,
      PAGE_SIZE,
    ),
  sendOpeningEmail: (row: Pick<OpeningAccount, 'LoginId' | 'CustId'>) =>
    request<Message>(
      'POST',
      '/online/send-email-opening-account-with-rekening',
      {},
      {
        LoginId: row.LoginId.trim(),
        CustId: row.CustId.trim(),
      },
    ),
  setStatus: (loginId: string, status: number, reason: string) =>
    request<Message>(
      'PUT',
      '/online/update-status-online-user',
      {},
      { LoginId: loginId.trim(), Status: status, Reason: reason.trim() },
    ),
}
