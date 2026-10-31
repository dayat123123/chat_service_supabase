import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { nasabahApi } from './api'
import type {
  Approval,
  ApprovalFilter,
  CsLogFilter,
  CsUserFilter,
  CsUserForm,
  OpeningAccount,
  OpeningFilter,
} from './types'

export const nasabahKeys = {
  all: ['nasabah'] as const,
  users: (page: number, query: string) => ['nasabah', 'users', page, query] as const,
  links: (loginId: string) => ['nasabah', 'links', loginId] as const,
  catalog: ['nasabah', 'catalog'] as const,
  approvals: (page: number, filter: ApprovalFilter, submitter: string) =>
    ['nasabah', 'approvals', page, filter.status, filter.action, filter.query, submitter] as const,
  approvalLinks: (approvalId: number) => ['nasabah', 'approval-links', approvalId] as const,
  openings: (page: number, filter: OpeningFilter) =>
    ['nasabah', 'openings', page, filter.loginId, filter.custId] as const,
  info: ['nasabah', 'info'] as const,
  csUsers: (page: number, filter: CsUserFilter) =>
    ['nasabah', 'cs-users', page, filter.loginId, filter.employeeId] as const,
  csLogs: (page: number, filter: CsLogFilter) =>
    ['nasabah', 'cs-logs', page, filter.logType, filter.csLoginId, filter.loginId] as const,
}

export function useOnlineUsers(page: number, query: string, enabled = true) {
  return useQuery({
    queryKey: nasabahKeys.users(page, query),
    queryFn: () => nasabahApi.users(page, query),
    enabled,
    placeholderData: (previous) => previous,
    staleTime: 15_000,
  })
}

export function useLinkedAccounts(loginId: string | undefined) {
  return useQuery({
    queryKey: nasabahKeys.links(loginId ?? ''),
    queryFn: () => nasabahApi.linkedAccounts(loginId ?? ''),
    enabled: Boolean(loginId),
    staleTime: 15_000,
  })
}

export function useAccountCatalog(enabled: boolean) {
  return useQuery({
    queryKey: nasabahKeys.catalog,
    queryFn: nasabahApi.catalog,
    enabled,
    staleTime: 5 * 60_000,
  })
}

export function useApprovals(page: number, filter: ApprovalFilter, submitter: string, enabled: boolean) {
  return useQuery({
    queryKey: nasabahKeys.approvals(page, filter, submitter),
    queryFn: () => nasabahApi.approvals(page, filter, submitter),
    enabled,
    placeholderData: (previous) => previous,
    staleTime: 10_000,
  })
}

export function useApprovalLinks(approvalId: number | undefined) {
  return useQuery({
    queryKey: nasabahKeys.approvalLinks(approvalId ?? 0),
    queryFn: () => nasabahApi.approvalLinks(approvalId ?? 0),
    enabled: approvalId !== undefined,
  })
}

export function useOpenings(page: number, filter: OpeningFilter, enabled: boolean) {
  return useQuery({
    queryKey: nasabahKeys.openings(page, filter),
    queryFn: () => nasabahApi.openings(page, filter),
    enabled,
    placeholderData: (previous) => previous,
    staleTime: 15_000,
  })
}

function useRefresh() {
  const client = useQueryClient()
  return () => void client.invalidateQueries({ queryKey: nasabahKeys.all })
}

export function useSubmitApproval() {
  const refresh = useRefresh()
  return useMutation({ mutationFn: nasabahApi.submit, onSuccess: refresh })
}

export function useResetCredential() {
  return useMutation({
    mutationFn: ({ loginId, kind }: { loginId: string; kind: 'password' | 'pin' }) =>
      nasabahApi.resetCredential(loginId, kind),
  })
}

export function useDecideApproval() {
  const refresh = useRefresh()
  return useMutation({
    mutationFn: ({ approval, approve }: { approval: Approval; approve: boolean }) =>
      nasabahApi.decide(approval, approve),
    onSuccess: refresh,
    onError: refresh,
  })
}

export function useSendOpeningEmail() {
  return useMutation({ mutationFn: (row: OpeningAccount) => nasabahApi.sendOpeningEmail(row) })
}

export function useChangeStatus() {
  const refresh = useRefresh()
  return useMutation({
    mutationFn: ({ loginId, status, reason }: { loginId: string; status: number; reason: string }) =>
      nasabahApi.setStatus(loginId, status, reason),
    onSuccess: refresh,
  })
}

export function useGatewayInfo() {
  return useQuery({ queryKey: nasabahKeys.info, queryFn: nasabahApi.info, staleTime: 5 * 60_000 })
}

export function useCsUsers(page: number, filter: CsUserFilter, enabled: boolean) {
  return useQuery({
    queryKey: nasabahKeys.csUsers(page, filter),
    queryFn: () => nasabahApi.csUsers(page, filter),
    enabled,
    placeholderData: (previous) => previous,
    staleTime: 15_000,
  })
}

export function useCsLogs(page: number, filter: CsLogFilter, enabled: boolean) {
  return useQuery({
    queryKey: nasabahKeys.csLogs(page, filter),
    queryFn: () => nasabahApi.csLogs(page, filter),
    enabled,
    placeholderData: (previous) => previous,
    staleTime: 10_000,
  })
}

export function useSaveCsUser() {
  const refresh = useRefresh()
  return useMutation({
    mutationFn: ({ form, create }: { form: CsUserForm; create: boolean }) =>
      create ? nasabahApi.createCsUser(form) : nasabahApi.updateCsUser(form).then(() => ({})),
    onSuccess: refresh,
  })
}

export function useSetCsPassword() {
  return useMutation({
    mutationFn: ({ loginId, password }: { loginId: string; password: string }) =>
      nasabahApi.setCsPassword(loginId, password),
  })
}

export function useDeleteCsUser() {
  const refresh = useRefresh()
  return useMutation({ mutationFn: nasabahApi.deleteCsUser, onSuccess: refresh })
}
