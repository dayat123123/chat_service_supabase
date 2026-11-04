import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { useAgent, useAuth } from '@/features/auth/hooks'
import { worksTickets } from '@/features/presence/types'

import { accountApi } from './api'
import type { PasswordValues, StatsPeriod } from './types'

export const accountKeys = {
  profile: (agentId: string) => ['account', agentId, 'profile'] as const,
  stats: (agentId: string, period: StatsPeriod) => ['account', agentId, 'stats', period] as const,
}

export function useMyProfile() {
  const agent = useAgent()
  return useQuery({ queryKey: accountKeys.profile(agent.id), queryFn: accountApi.profile })
}

export function useMyStats(period: StatsPeriod) {
  const agent = useAgent()
  return useQuery({
    queryKey: accountKeys.stats(agent.id, period),
    queryFn: () => accountApi.stats(period),
    placeholderData: (previous) => previous,
    staleTime: 30_000,
    refetchInterval: 60_000,
  })
}

export function useChangeOwnPassword() {
  const agent = useAgent()
  const client = useQueryClient()
  return useMutation({
    mutationFn: (values: PasswordValues) => accountApi.changePassword(values.current, values.next),
    onSuccess: () => void client.invalidateQueries({ queryKey: accountKeys.profile(agent.id) }),
  })
}

export function useSignOutEverywhere() {
  const signOut = useAuth((state) => state.signOut)
  return useMutation({
    mutationFn: () => {
      const phase = useAuth.getState().phase
      return accountApi.signOutEverywhere(phase.kind === 'ready' && worksTickets(phase.agent))
    },
    onSuccess: () => void signOut('manual'),
  })
}
