import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { legalApi } from './api'
import type { DraftInput, LegalKind, LegalOverview } from './types'

export const legalKeys = {
  all: ['legal'] as const,
  overview: ['legal', 'overview'] as const,
  document: (id: string) => ['legal', 'document', id] as const,
  draft: (id: string) => ['legal', 'draft', id] as const,
}

export function useLegalOverview() {
  return useQuery({
    queryKey: legalKeys.overview,
    queryFn: legalApi.overview,
    refetchInterval: 60_000,
    placeholderData: (previous) => previous,
  })
}

export function useLegalDocument(id: string | null) {
  return useQuery({
    queryKey: legalKeys.document(id ?? ''),
    queryFn: () => legalApi.document(id ?? ''),
    enabled: Boolean(id),
    staleTime: 5 * 60_000,
  })
}

export function useLegalDraft(id: string | null) {
  return useQuery({
    queryKey: legalKeys.draft(id ?? ''),
    queryFn: () => legalApi.draft(id ?? ''),
    enabled: Boolean(id),
    staleTime: 0,
  })
}

function useRefresh() {
  const client = useQueryClient()
  return () => void client.invalidateQueries({ queryKey: legalKeys.all })
}

export function useSaveDraft() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: DraftInput) => legalApi.save(input),
    onSuccess: (draft) => {
      client.setQueryData(legalKeys.draft(draft.id), draft)
      void client.invalidateQueries({ queryKey: legalKeys.overview })
    },
  })
}

export function useDraftAction() {
  const client = useQueryClient()
  const refresh = useRefresh()
  return useMutation({
    mutationFn: ({ id, action }: { id: string; action: 'submit' | 'withdraw' | 'approve' | 'remove' }) =>
      legalApi[action](id),
    onSuccess: (result, { id, action }) => {
      if (action === 'submit' || action === 'withdraw') client.setQueryData(legalKeys.draft(id), result)
      else client.removeQueries({ queryKey: legalKeys.draft(id) })
    },
    onSettled: refresh,
  })
}

export function useRejectDraft() {
  const client = useQueryClient()
  const refresh = useRefresh()
  return useMutation({
    mutationFn: ({ id, note }: { id: string; note: string }) => legalApi.reject(id, note.trim()),
    onSuccess: (draft) => client.setQueryData(legalKeys.draft(draft.id), draft),
    onSettled: refresh,
  })
}

export function useCancelScheduled() {
  const refresh = useRefresh()
  return useMutation({
    mutationFn: (documentId: string) => legalApi.cancelScheduled(documentId),
    onSettled: refresh,
  })
}

export function useSetRequired() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (kinds: LegalKind[]) => legalApi.setRequired(kinds),
    onSuccess: (kinds) =>
      client.setQueryData<LegalOverview>(legalKeys.overview, (overview) =>
        overview
          ? {
              ...overview,
              required_kinds: kinds,
              kinds: overview.kinds.map((item) => ({ ...item, required: kinds.includes(item.kind) })),
            }
          : overview,
      ),
    onSettled: () => void client.invalidateQueries({ queryKey: legalKeys.overview }),
  })
}
