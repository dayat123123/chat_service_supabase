import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { integrationKeysApi } from './api'
import type { IntegrationKey, KeyDraft } from './types'

export const integrationKeys = {
  all: ['integration-keys'] as const,
  list: ['integration-keys', 'list'] as const,
  stats: (days: number) => ['integration-keys', 'stats', days] as const,
  daily: (days: number, keyId: string) => ['integration-keys', 'daily', days, keyId] as const,
  officials: ['integration-keys', 'officials'] as const,
}

export function useIntegrationKeys() {
  return useQuery({ queryKey: integrationKeys.list, queryFn: integrationKeysApi.list, staleTime: 15_000 })
}

export function useIntegrationOfficialAccounts() {
  return useQuery({
    queryKey: integrationKeys.officials,
    queryFn: integrationKeysApi.officialAccounts,
    staleTime: 60_000,
  })
}

export function useKeyDaily(days: number, keyId: string | null) {
  return useQuery({
    queryKey: integrationKeys.daily(days, keyId ?? ''),
    queryFn: () => integrationKeysApi.statsDaily(days, keyId ?? ''),
    enabled: keyId !== null,
    placeholderData: (previous) => previous,
    refetchInterval: 60_000,
  })
}

export function useIntegrationStats(days: number) {
  return useQuery({
    queryKey: integrationKeys.stats(days),
    queryFn: () => integrationKeysApi.stats(days),
    refetchInterval: 60_000,
    placeholderData: (previous) => previous,
  })
}

function useRefresh() {
  const client = useQueryClient()
  return () => void client.invalidateQueries({ queryKey: integrationKeys.all })
}

export function useCreateIntegrationKey(reveal: (secret: string, key: IntegrationKey) => void) {
  const refresh = useRefresh()
  return useMutation({
    mutationFn: async (draft: KeyDraft) => {
      const created = await integrationKeysApi.create(draft)
      reveal(created.secret, created.key)
      return created.key
    },
    onSettled: refresh,
  })
}

export function useUpdateIntegrationKey() {
  const refresh = useRefresh()
  return useMutation({
    mutationFn: (args: { id: string; draft: KeyDraft }) => integrationKeysApi.update(args.id, args.draft),
    onSettled: refresh,
  })
}

export function useRevokeIntegrationKey() {
  const refresh = useRefresh()
  return useMutation({
    mutationFn: (args: { id: string; reason: string }) => integrationKeysApi.revoke(args.id, args.reason),
    onSettled: refresh,
  })
}
