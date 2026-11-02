import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'

import { useAuth } from '@/features/auth/hooks'

import { pushApi } from './api'
import type { ServiceAccountKey } from './firebase-key'
import type { PushState, PushStatus } from './types'

export const pushKeys = {
  status: ['push', 'status'] as const,
  users: (query: string) => ['push', 'users', query] as const,
  campaign: (id: string) => ['push', 'campaign', id] as const,
}

export function credentialsLoading(status: PushStatus) {
  const live = status.instances.filter((instance) => instance.live)
  return (
    live.length > 0 && !live.some((instance) => instance.credentials_revision === status.credentials_revision)
  )
}

export function usePushStatus() {
  return useQuery({
    queryKey: pushKeys.status,
    queryFn: pushApi.status,
    refetchInterval: (query) => (query.state.data && credentialsLoading(query.state.data) ? 2_000 : 15_000),
    staleTime: 1_000,
  })
}

export function useSyncPushReady(state: PushState | undefined) {
  const updateAgent = useAuth((store) => store.updateAgent)
  useEffect(() => {
    const phase = useAuth.getState().phase
    if (!state || phase.kind !== 'ready') return
    const ready = state === 'active'
    if (phase.agent.settings.community_push_ready === ready) return
    updateAgent({ ...phase.agent, settings: { ...phase.agent.settings, community_push_ready: ready } })
  }, [state, updateAgent])
}

export function useSetPushCredentials() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: ({ key, replaceProject }: { key: ServiceAccountKey; replaceProject: boolean }) =>
      pushApi.setCredentials(key, replaceProject),
    onSuccess: () => void client.invalidateQueries({ queryKey: pushKeys.status }),
  })
}

export function useRemovePushCredentials() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: pushApi.removeCredentials,
    onSuccess: () => void client.invalidateQueries({ queryKey: pushKeys.status }),
  })
}

export function usePushUsers(query: string) {
  const text = query.trim()
  return useQuery({
    queryKey: pushKeys.users(text),
    queryFn: () => pushApi.findUsers(text),
    enabled: text.replace(/^@/, '').length >= 2,
    placeholderData: (previous) => previous,
  })
}

export function usePushTest() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (userId: string) => pushApi.test(userId),
    onSuccess: () => void client.invalidateQueries({ queryKey: pushKeys.status }),
  })
}

export function useCampaignPush(id: string, live: boolean) {
  return useQuery({
    queryKey: pushKeys.campaign(id),
    queryFn: () => pushApi.campaign(id),
    refetchInterval: live ? 5_000 : false,
    staleTime: 5_000,
  })
}
