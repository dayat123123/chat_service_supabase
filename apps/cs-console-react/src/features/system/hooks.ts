import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { systemApi } from './api'
import { backupBusy, deliveryPending } from './logic'
import type {
  AlertChannel,
  AlertChannels,
  BackupConfig,
  BackupOverview,
  BackupRequestKind,
  BackupScheduleInput,
  BackupTargetInput,
  EmailInput,
  TelegramInput,
} from './types'

export const systemKeys = {
  health: ['system', 'health'] as const,
  badge: ['system', 'badge'] as const,
  backup: ['system', 'backup'] as const,
  channels: ['system', 'channels'] as const,
}

export function useSystemHealth() {
  return useQuery({
    queryKey: systemKeys.health,
    queryFn: systemApi.health,
    refetchInterval: 15_000,
    staleTime: 5_000,
  })
}

export function useHealthBadge(enabled: boolean) {
  return useQuery({
    queryKey: systemKeys.badge,
    queryFn: systemApi.badge,
    enabled,
    refetchInterval: 60_000,
    staleTime: 30_000,
  })
}

export function useAcknowledgeAlert() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (alertId: number) => systemApi.acknowledge(alertId),
    onSettled: () => {
      void client.invalidateQueries({ queryKey: systemKeys.health })
      void client.invalidateQueries({ queryKey: systemKeys.badge })
    },
  })
}

export function useBackupOverview() {
  return useQuery({
    queryKey: systemKeys.backup,
    queryFn: systemApi.backup,
    refetchInterval: (query) => {
      const data = query.state.data
      return data && (data.requests.length > 0 || backupBusy(data)) ? 5_000 : 30_000
    },
    staleTime: 2_000,
  })
}

function useConfigSaved() {
  const client = useQueryClient()
  return (config: BackupConfig) => {
    client.setQueryData<BackupOverview>(systemKeys.backup, (overview) =>
      overview ? { ...overview, config } : overview,
    )
    void client.invalidateQueries({ queryKey: systemKeys.backup })
    void client.invalidateQueries({ queryKey: systemKeys.health })
  }
}

export function useSetBackupTarget() {
  const saved = useConfigSaved()
  return useMutation({
    mutationFn: (input: BackupTargetInput) => systemApi.setBackupTarget(input),
    onSuccess: saved,
    gcTime: 0,
  })
}

export function useSetBackupSchedule() {
  const saved = useConfigSaved()
  return useMutation({
    mutationFn: (input: BackupScheduleInput) => systemApi.setBackupSchedule(input),
    onSuccess: saved,
  })
}

export function useRequestBackup() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (kind: BackupRequestKind) => systemApi.requestBackup(kind),
    onSuccess: (overview) => client.setQueryData(systemKeys.backup, overview),
    onSettled: () => void client.invalidateQueries({ queryKey: systemKeys.backup }),
  })
}

export function useAlertChannels() {
  return useQuery({
    queryKey: systemKeys.channels,
    queryFn: systemApi.channels,
    refetchInterval: (query) => (deliveryPending(query.state.data) ? 3_000 : 60_000),
    staleTime: 2_000,
  })
}

function useChannelsMutation<T>(run: (input: T) => Promise<AlertChannels>, secret = false) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSuccess: (channels) => client.setQueryData(systemKeys.channels, channels),
    onError: () => void client.invalidateQueries({ queryKey: systemKeys.channels }),
    gcTime: secret ? 0 : undefined,
  })
}

export const useSetAlertOptions = () =>
  useChannelsMutation(({ label, consoleUrl }: { label: string; consoleUrl: string }) =>
    systemApi.setOptions(label, consoleUrl),
  )

export const useSetTelegram = () =>
  useChannelsMutation((input: TelegramInput) => systemApi.setTelegram(input), true)

export const useSetEmail = () => useChannelsMutation((input: EmailInput) => systemApi.setEmail(input), true)

export const useSendAlertTest = () =>
  useChannelsMutation((channel: AlertChannel) => systemApi.sendTest(channel))
