import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { complianceApi } from './api'
import {
  AUDIT_PAGE_SIZE,
  type AuditFilter,
  type CaseFilter,
  type PolicyBook,
  type PolicyKey,
  type Verdict,
} from './types'

export const complianceKeys = {
  all: ['compliance'] as const,
  overview: ['compliance', 'overview'] as const,
  cases: (filter: CaseFilter) =>
    [
      'compliance',
      'cases',
      filter.kind,
      filter.state,
      filter.range?.from,
      filter.range?.to,
      filter.query,
    ] as const,
  detail: (ticketId: string) => ['compliance', 'case', ticketId] as const,
  messages: (ticketId: string) => ['compliance', 'case-messages', ticketId] as const,
  audit: (filter: AuditFilter) =>
    ['compliance', 'audit', filter.range.from, filter.range.to, filter.action, filter.query] as const,
  policies: ['compliance', 'policies'] as const,
}

export function useComplianceOverview(enabled: boolean) {
  return useQuery({
    queryKey: complianceKeys.overview,
    queryFn: complianceApi.overview,
    enabled,
    refetchInterval: 60_000,
    placeholderData: (previous) => previous,
  })
}

export function useCases(filter: CaseFilter) {
  return useQuery({
    queryKey: complianceKeys.cases(filter),
    queryFn: () => complianceApi.cases(filter),
    placeholderData: (previous) => previous,
    staleTime: 30_000,
  })
}

export function useCaseDetail(ticketId: string | undefined) {
  return useQuery({
    queryKey: complianceKeys.detail(ticketId ?? ''),
    queryFn: () => complianceApi.detail(ticketId ?? ''),
    enabled: Boolean(ticketId),
    staleTime: 5 * 60_000,
    refetchOnWindowFocus: false,
  })
}

export function useCaseMessages(ticketId: string | undefined) {
  return useQuery({
    queryKey: complianceKeys.messages(ticketId ?? ''),
    queryFn: () => complianceApi.messages(ticketId ?? ''),
    enabled: Boolean(ticketId),
    staleTime: 60_000,
  })
}

function useRefreshCases() {
  const client = useQueryClient()
  return (ticketId: string) => {
    void client.invalidateQueries({ queryKey: complianceKeys.detail(ticketId) })
    void client.invalidateQueries({ queryKey: ['compliance', 'cases'] })
    void client.invalidateQueries({ queryKey: complianceKeys.overview })
  }
}

export function useReviewCase(ticketId: string) {
  const refresh = useRefreshCases()
  return useMutation({
    mutationFn: ({ verdict, note }: { verdict: Verdict; note: string }) =>
      complianceApi.review(ticketId, verdict, note),
    onSuccess: () => refresh(ticketId),
  })
}

export function useExtendDeadline(ticketId: string) {
  const client = useQueryClient()
  const refresh = useRefreshCases()
  return useMutation({
    mutationFn: ({ reason, version }: { reason: string; version: number }) =>
      complianceApi.extend(ticketId, reason, version),
    onSuccess: () => {
      refresh(ticketId)
      void client.invalidateQueries({ queryKey: complianceKeys.messages(ticketId) })
    },
    onError: () => refresh(ticketId),
  })
}

export function useAuditLog(filter: AuditFilter) {
  return useInfiniteQuery({
    queryKey: complianceKeys.audit(filter),
    queryFn: ({ pageParam }) => complianceApi.audit(filter, pageParam, AUDIT_PAGE_SIZE),
    initialPageParam: null as Parameters<typeof complianceApi.audit>[1],
    getNextPageParam: (page) => page.next,
    placeholderData: (previous) => previous,
    staleTime: 30_000,
  })
}

export function usePolicies() {
  return useQuery({ queryKey: complianceKeys.policies, queryFn: complianceApi.policies })
}

export function useConfirmPolicy() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: ({ key, value, note }: { key: PolicyKey; value: number; note: string }) =>
      complianceApi.confirmPolicy(key, value, note),
    onSuccess: (policy) => {
      client.setQueryData<PolicyBook>(complianceKeys.policies, (book) =>
        book
          ? { ...book, policies: book.policies.map((item) => (item.key === policy.key ? policy : item)) }
          : book,
      )
      void client.invalidateQueries({ queryKey: complianceKeys.policies })
      void client.invalidateQueries({ queryKey: complianceKeys.overview })
    },
  })
}
