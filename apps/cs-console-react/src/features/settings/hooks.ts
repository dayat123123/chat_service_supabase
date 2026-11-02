import { useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { useAgent } from '@/features/auth/hooks'
import { nasabahKeys } from '@/features/nasabah/hooks'
import { errorText } from '@/lib/error-text'
import type { Json } from '@/types/database'

import { settingsApi } from './api'
import type {
  AccountDraft,
  Holiday,
  QuickReplyConfig,
  SettingEntry,
  StaffAccount,
  TopicConfig,
} from './types'

export const settingsKeys = {
  accounts: ['admin', 'accounts'] as const,
  options: ['admin', 'options'] as const,
  topics: ['admin', 'topics'] as const,
  quickReplies: ['admin', 'quick-replies'] as const,
  settings: ['admin', 'settings'] as const,
  holidays: (year: number) => ['admin', 'holidays', year] as const,
  integration: ['admin', 'integration'] as const,
}

function putAccount(client: QueryClient, agent: StaffAccount) {
  client.setQueryData<StaffAccount[]>(settingsKeys.accounts, (items = []) =>
    items.some((item) => item.id === agent.id)
      ? items.map((item) => (item.id === agent.id ? agent : item))
      : [...items, agent],
  )
}

export function useAccounts() {
  return useQuery({ queryKey: settingsKeys.accounts, queryFn: settingsApi.accounts })
}

export function useAdminOptions() {
  return useQuery({ queryKey: settingsKeys.options, queryFn: settingsApi.options, staleTime: 10 * 60_000 })
}

export function useTopicConfigs() {
  return useQuery({ queryKey: settingsKeys.topics, queryFn: settingsApi.topics })
}

export function useQuickReplyConfigs() {
  return useQuery({ queryKey: settingsKeys.quickReplies, queryFn: settingsApi.quickReplies })
}

export function useSettingEntries() {
  return useQuery({ queryKey: settingsKeys.settings, queryFn: settingsApi.settings })
}

export function useHolidays(year: number) {
  return useQuery({ queryKey: settingsKeys.holidays(year), queryFn: () => settingsApi.holidays(year) })
}

const sameSet = (a: string[], b: string[]) => a.length === b.length && a.every((item) => b.includes(item))

export function useSaveAccount() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: async ({
      id,
      draft,
      nasabah,
      community,
    }: {
      id: string | null
      draft: AccountDraft
      nasabah?: string[]
      community?: string[]
    }) => {
      let saved =
        id === null
          ? await settingsApi.createAccount(draft)
          : { agent: await settingsApi.updateAccount(id, draft), temporary_password: null }
      if (nasabah && !sameSet(nasabah, saved.agent.nasabah_permissions)) {
        saved = { ...saved, agent: await settingsApi.setNasabahPermissions(saved.agent.id, nasabah) }
      }
      if (community && !sameSet(community, saved.agent.community_permissions)) {
        saved = { ...saved, agent: await settingsApi.setCommunityPermissions(saved.agent.id, community) }
      }
      return saved
    },
    onSuccess: ({ agent }) => putAccount(client, agent),
  })
}

export function useResetPassword() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => settingsApi.resetPassword(id),
    onSuccess: ({ agent }) => putAccount(client, agent),
    onError: () => void client.invalidateQueries({ queryKey: settingsKeys.accounts }),
  })
}

export function useSaveTopic() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (topic: TopicConfig) => settingsApi.saveTopic(topic),
    onSuccess: (topics) => {
      client.setQueryData(settingsKeys.topics, topics)
      void client.invalidateQueries({ queryKey: ['topics'] })
    },
  })
}

export function useSaveQuickReply() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (reply: QuickReplyConfig) => settingsApi.saveQuickReply(reply),
    onSuccess: (replies) => {
      client.setQueryData(settingsKeys.quickReplies, replies)
      void client.invalidateQueries({ queryKey: ['quick-replies'] })
    },
  })
}

export function useSaveHoliday(year: number) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (holiday: Holiday) => settingsApi.saveHoliday(holiday),
    onSuccess: (holidays) => client.setQueryData(settingsKeys.holidays(year), holidays),
  })
}

export function useDeleteHoliday(year: number) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (day: string) => settingsApi.deleteHoliday(day),
    onSuccess: (holidays) => client.setQueryData(settingsKeys.holidays(year), holidays),
    onError: (error) => toast.error(errorText(error)),
  })
}

export function useSaveSettings() {
  const { t } = useTranslation()
  const client = useQueryClient()
  const me = useAgent().display_name
  return useMutation({
    mutationFn: async (values: Record<string, Json>) => {
      const saved = []
      for (const [key, value] of Object.entries(values)) saved.push(await settingsApi.setSetting(key, value))
      return saved
    },
    onSuccess: (saved) => {
      client.setQueryData<SettingEntry[]>(settingsKeys.settings, (items) =>
        items?.map((item) => {
          const hit = saved.find((entry) => entry.key === item.key)
          return hit
            ? { ...item, value: hit.value, version: hit.version, updated_at: hit.updated_at, updated_by: me }
            : item
        }),
      )
      toast.success(t('app.saved'))
    },
    onError: (error) => {
      toast.error(errorText(error))
      void client.invalidateQueries({ queryKey: settingsKeys.settings })
    },
  })
}

export function useIntegrationStatus() {
  return useQuery({ queryKey: settingsKeys.integration, queryFn: settingsApi.integration, retry: false })
}

export function useTestIntegration() {
  return useMutation({
    mutationFn: ({ url, clientId }: { url: string; clientId: string }) =>
      settingsApi.testIntegration(url, clientId),
  })
}

export function useSaveIntegration() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: ({ url, clientId }: { url: string; clientId: string }) =>
      settingsApi.saveIntegration(url, clientId),
    onSuccess: (result) => {
      client.setQueryData(settingsKeys.integration, result.status)
      if (result.saved) void client.invalidateQueries({ queryKey: nasabahKeys.me })
    },
  })
}

export function useClearIntegration() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: () => settingsApi.clearIntegration(),
    onSuccess: (status) => {
      client.setQueryData(settingsKeys.integration, status)
      void client.invalidateQueries({ queryKey: nasabahKeys.me })
    },
  })
}

export function findSetting(items: SettingEntry[] | undefined, key: string) {
  return items?.find((item) => item.key === key)
}
