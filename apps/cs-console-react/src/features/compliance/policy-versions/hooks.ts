import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { policyVersionsApi } from './api'
import { VERSION_PAGE_SIZE, type SimInput } from './types'

export const policyVersionKeys = {
  all: ['compliance', 'policy'] as const,
  state: ['compliance', 'policy', 'state'] as const,
  changes: (status: 'pending' | 'decided') => ['compliance', 'policy', 'changes', status] as const,
  change: (id: number) => ['compliance', 'policy', 'change', id] as const,
  versions: ['compliance', 'policy', 'versions'] as const,
  version: (version: number) => ['compliance', 'policy', 'version', version] as const,
  fourEyes: ['compliance', 'policy', 'four-eyes'] as const,
}

const editorKeys = [['content-policy'], ['compliance', 'banned-words']] as const

export function useRefreshPolicy() {
  const client = useQueryClient()
  return (editors: boolean) => {
    void client.invalidateQueries({ queryKey: policyVersionKeys.all })
    if (editors) editorKeys.forEach((queryKey) => void client.invalidateQueries({ queryKey }))
  }
}

export function usePolicyState(enabled = true) {
  return useQuery({
    queryKey: policyVersionKeys.state,
    queryFn: policyVersionsApi.state,
    enabled,
    staleTime: 15_000,
    refetchInterval: 60_000,
  })
}

export function usePolicyChanges(status: 'pending' | 'decided') {
  return useQuery({
    queryKey: policyVersionKeys.changes(status),
    queryFn: () => policyVersionsApi.changes(status),
    staleTime: 15_000,
  })
}

export function usePolicyChange(id: number | null) {
  return useQuery({
    queryKey: policyVersionKeys.change(id ?? 0),
    queryFn: () => policyVersionsApi.change(id ?? 0),
    enabled: id !== null,
  })
}

export function usePolicyVersions() {
  return useInfiniteQuery({
    queryKey: policyVersionKeys.versions,
    queryFn: ({ pageParam }) => policyVersionsApi.versions(pageParam, VERSION_PAGE_SIZE),
    initialPageParam: null as number | null,
    getNextPageParam: (page) => page.next,
    staleTime: 30_000,
  })
}

export function usePolicyVersion(version: number | null) {
  return useQuery({
    queryKey: policyVersionKeys.version(version ?? 0),
    queryFn: () => policyVersionsApi.version(version ?? 0),
    enabled: version !== null,
  })
}

export function useSubmitDraft() {
  const refresh = useRefreshPolicy()
  return useMutation({
    mutationFn: (reason: string) => policyVersionsApi.submit(reason),
    onSettled: () => refresh(true),
  })
}

export function useDiscardDraft() {
  const refresh = useRefreshPolicy()
  return useMutation({ mutationFn: policyVersionsApi.discard, onSettled: () => refresh(true) })
}

export function useDecideChange() {
  const refresh = useRefreshPolicy()
  return useMutation({
    mutationFn: (args: { id: number; approve: boolean; note: string }) =>
      policyVersionsApi.decide(args.id, args.approve, args.note),
    onSettled: (_data, _error, args) => refresh(args.approve),
  })
}

export function useWithdrawChange() {
  const refresh = useRefreshPolicy()
  return useMutation({
    mutationFn: (id: number) => policyVersionsApi.withdraw(id),
    onSettled: () => refresh(false),
  })
}

export function useRollback() {
  const refresh = useRefreshPolicy()
  return useMutation({
    mutationFn: (args: { version: number; reason: string }) =>
      policyVersionsApi.rollback(args.version, args.reason),
    onSettled: () => refresh(true),
  })
}

export function useSimulate() {
  return useMutation({ mutationFn: (input: SimInput) => policyVersionsApi.simulate(input) })
}

export function usePolicyFourEyes() {
  return useQuery({ queryKey: policyVersionKeys.fourEyes, queryFn: policyVersionsApi.fourEyes })
}

export function useSetPolicyFourEyes() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (enabled: boolean) => policyVersionsApi.setFourEyes(enabled),
    onSuccess: (data) => client.setQueryData(policyVersionKeys.fourEyes, data),
    onError: () => void client.invalidateQueries({ queryKey: policyVersionKeys.fourEyes }),
  })
}
