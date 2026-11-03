import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { evidenceApi } from './api'
import type { EvidenceCursor, EvidenceDetail, EvidenceListFilter, EvidenceStatus } from './types'

export const evidenceKeys = {
  all: ['compliance', 'evidence'] as const,
  list: (filter: EvidenceListFilter) =>
    ['compliance', 'evidence', 'list', filter.query, filter.filter, filter.source] as const,
  detail: (id: string) => ['compliance', 'evidence', 'detail', id] as const,
}

export function useEvidenceList(filter: EvidenceListFilter) {
  return useInfiniteQuery({
    queryKey: evidenceKeys.list(filter),
    queryFn: ({ pageParam }) => evidenceApi.list(filter, pageParam),
    initialPageParam: null as EvidenceCursor | null,
    getNextPageParam: (page) => page.next,
    placeholderData: (previous) => previous,
    staleTime: 30_000,
  })
}

export function useEvidenceDetail(id: string | null) {
  return useQuery({
    queryKey: evidenceKeys.detail(id ?? ''),
    queryFn: () => evidenceApi.detail(id as string),
    enabled: Boolean(id),
    staleTime: Infinity,
    gcTime: 0,
    retry: false,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
  })
}

export function useApplyStatus() {
  const client = useQueryClient()
  return (status: EvidenceStatus) => {
    client.setQueryData<EvidenceDetail>(evidenceKeys.detail(status.id), (current) =>
      current ? { ...current, ...status } : current,
    )
    void client.invalidateQueries({ queryKey: [...evidenceKeys.all, 'list'] })
  }
}

export function useSetHold() {
  const apply = useApplyStatus()
  return useMutation({
    mutationFn: ({ id, hold, reason }: { id: string; hold: boolean; reason: string }) =>
      evidenceApi.setHold(id, hold, reason),
    onSuccess: apply,
  })
}

export function useVerifyEvidence() {
  const apply = useApplyStatus()
  return useMutation({
    mutationFn: (id: string) => evidenceApi.verify(id),
    onSuccess: (result) => apply(result.status),
  })
}
