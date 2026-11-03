import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { bannersApi, clientConfigApi } from './api'
import type { AppPlatform, BannerDraft, ClientConfig } from './types'

export const clientConfigKeys = {
  config: ['client-config'] as const,
  banners: ['client-config', 'banners'] as const,
}

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

export const useToggleFlag = () =>
  useConfigMutation((args: { key: string; enabled: boolean }) =>
    clientConfigApi.toggleFlag(args.key, args.enabled),
  )

export const useSetKillSwitch = () =>
  useConfigMutation((args: { enabled: boolean; reason: string }) =>
    clientConfigApi.setKillSwitch(args.enabled, args.reason),
  )

export const useSetMinVersion = () =>
  useConfigMutation((args: { platform: AppPlatform; version: string | null }) =>
    clientConfigApi.setMinVersion(args.platform, args.version),
  )

export function useBanners() {
  return useQuery({ queryKey: clientConfigKeys.banners, queryFn: bannersApi.list, staleTime: 15_000 })
}

function useBannerMutation<TArgs, TResult>(run: (args: TArgs) => Promise<TResult>) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSettled: () => client.invalidateQueries({ queryKey: clientConfigKeys.banners }),
  })
}

export const useSaveBanner = () =>
  useBannerMutation((args: { id: string | null; draft: BannerDraft }) => bannersApi.save(args.id, args.draft))

export const useDeleteBanner = () => useBannerMutation((id: string) => bannersApi.remove(id))
