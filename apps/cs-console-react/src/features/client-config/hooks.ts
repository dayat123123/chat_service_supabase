import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { clientConfigApi } from './api'
import type { AppPlatform, ClientConfig, FlagDraft } from './types'

export const clientConfigKeys = { config: ['client-config'] as const }

export function useClientConfig() {
  return useQuery({ queryKey: clientConfigKeys.config, queryFn: clientConfigApi.config, staleTime: 15_000 })
}

function useConfigMutation<TArgs>(run: (args: TArgs) => Promise<ClientConfig>) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: (config) => client.setQueryData(clientConfigKeys.config, config),
    onError: () => void client.invalidateQueries({ queryKey: clientConfigKeys.config }),
  })
}

export const useSetFlag = () => useConfigMutation((draft: FlagDraft) => clientConfigApi.setFlag(draft))

export const useDeleteFlag = () => useConfigMutation((key: string) => clientConfigApi.deleteFlag(key))

export const useSetKillSwitch = () =>
  useConfigMutation((args: { enabled: boolean; reason: string }) =>
    clientConfigApi.setKillSwitch(args.enabled, args.reason),
  )

export const useSetMinVersion = () =>
  useConfigMutation((args: { platform: AppPlatform; version: string | null }) =>
    clientConfigApi.setMinVersion(args.platform, args.version),
  )
