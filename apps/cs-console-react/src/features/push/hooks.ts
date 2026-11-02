import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { pushApi } from './api'

export const pushKeys = {
  status: ['push', 'status'] as const,
  users: (query: string) => ['push', 'users', query] as const,
  campaign: (id: string) => ['push', 'campaign', id] as const,
}

export function usePushStatus() {
  return useQuery({
    queryKey: pushKeys.status,
    queryFn: pushApi.status,
    refetchInterval: 15_000,
    staleTime: 5_000,
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
