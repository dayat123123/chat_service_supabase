import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'

import { useAuth } from '@/features/auth/hooks'
import { presenceApi } from '@/features/presence/api'
import { toApiError } from '@/lib/errors'

import { nasabahApi } from './api'
import {
  OPENING_PAGE_SIZE,
  type Approval,
  type ApprovalFilter,
  type OpeningAccount,
  type OpeningFilter,
} from './types'

export const nasabahKeys = {
  all: ['nasabah'] as const,
  users: (page: number, query: string) => ['nasabah', 'users', page, query] as const,
  links: (loginId: string) => ['nasabah', 'links', loginId] as const,
  catalog: ['nasabah', 'catalog'] as const,
  approvals: (page: number, filter: ApprovalFilter, submitter: string) =>
    ['nasabah', 'approvals', page, filter.status, filter.action, filter.query, submitter] as const,
  approvalLinks: (approvalId: number) => ['nasabah', 'approval-links', approvalId] as const,
  openings: (page: number, filter: OpeningFilter, size: number) =>
    ['nasabah', 'openings', page, filter.loginId, filter.custId, size] as const,
  me: ['nasabah', 'me'] as const,
  ticketLogin: (ticketId: string) => ['nasabah', 'ticket-login', ticketId] as const,
  profile: (loginId: string) => ['nasabah', 'profile', loginId.toLowerCase()] as const,
}

const sameSet = (a: readonly string[], b: readonly string[]) =>
  a.length === b.length && a.every((item) => b.includes(item))

export function useFreshPermissions(enabled = true) {
  const updateAgent = useAuth((state) => state.updateAgent)
  const me = useQuery({
    queryKey: nasabahKeys.me,
    queryFn: presenceApi.me,
    enabled,
    staleTime: 0,
    refetchInterval: 60_000,
    refetchOnWindowFocus: true,
  })
  useEffect(() => {
    const phase = useAuth.getState().phase
    if (!me.data || phase.kind !== 'ready') return
    const ready = me.data.settings.nasabah_ready
    const fourEyes = me.data.settings.community_four_eyes
    const pushReady = me.data.settings.community_push_ready
    if (
      sameSet(phase.agent.nasabah_permissions, me.data.nasabah_permissions) &&
      sameSet(phase.agent.community_permissions, me.data.community_permissions) &&
      phase.agent.settings.nasabah_ready === ready &&
      phase.agent.settings.community_four_eyes === fourEyes &&
      phase.agent.settings.community_push_ready === pushReady
    )
      return
    updateAgent({
      ...phase.agent,
      nasabah_permissions: me.data.nasabah_permissions,
      community_permissions: me.data.community_permissions,
      settings: {
        ...phase.agent.settings,
        nasabah_ready: ready,
        community_four_eyes: fourEyes,
        community_push_ready: pushReady,
      },
    })
  }, [me.data, updateAgent])
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

export function useOpenings(page: number, filter: OpeningFilter, enabled: boolean, size = OPENING_PAGE_SIZE) {
  return useQuery({
    queryKey: nasabahKeys.openings(page, filter, size),
    queryFn: () => nasabahApi.openings(page, filter, size),
    enabled,
    placeholderData: (previous) => previous,
    staleTime: 15_000,
  })
}

export function useTicketLogin(ticketId: string, enabled: boolean) {
  return useQuery({
    queryKey: nasabahKeys.ticketLogin(ticketId),
    queryFn: () => nasabahApi.ticketLogin(ticketId),
    enabled,
    staleTime: 5 * 60_000,
  })
}

export function useOnlineUserProfile(loginId: string | undefined) {
  return useQuery({
    queryKey: nasabahKeys.profile(loginId ?? ''),
    queryFn: () => nasabahApi.onlineUser(loginId ?? ''),
    enabled: Boolean(loginId),
    staleTime: 30_000,
    retry: (count, error) => toApiError(error).status !== 404 && count < 1,
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
