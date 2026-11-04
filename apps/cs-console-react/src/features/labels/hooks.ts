import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import type { DateRange } from '@/features/reports/types'
import { refreshTickets, ticketKeys } from '@/features/tickets/hooks'
import type { Ticket, TicketLists } from '@/features/tickets/types'

import { labelsApi } from './api'
import { labelErrorText, listsWithLabels } from './logic'
import type { LabelDraft, TicketLabel } from './types'

export const labelKeys = {
  options: ['labels', 'options'] as const,
  configs: ['admin', 'ticket-labels'] as const,
  report: (range: DateRange) => ['reports', 'labels', range.from, range.to] as const,
}

export function useLabelOptions(enabled = true) {
  return useQuery({ queryKey: labelKeys.options, queryFn: labelsApi.options, enabled, staleTime: 5 * 60_000 })
}

export function useLabelConfigs() {
  return useQuery({ queryKey: labelKeys.configs, queryFn: labelsApi.configs })
}

function useConfigMutation<TArgs>(
  action: (args: TArgs) => ReturnType<typeof labelsApi.configs>,
  feedback: { success?: string; toastErrors: boolean },
) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: action,
    onSuccess: (labels) => {
      client.setQueryData(labelKeys.configs, labels)
      void client.invalidateQueries({ queryKey: labelKeys.options })
      if (feedback.success) toast.success(feedback.success)
    },
    onError: (error) => {
      if (feedback.toastErrors) toast.error(labelErrorText(error))
      void client.invalidateQueries({ queryKey: labelKeys.configs })
    },
  })
}

export function useSaveLabel() {
  const { t } = useTranslation()
  return useConfigMutation((draft: LabelDraft) => labelsApi.save(draft), {
    success: t('labels.settings.saved'),
    toastErrors: false,
  })
}

export function useReorderLabels() {
  return useConfigMutation((ids: string[]) => labelsApi.reorder(ids), { toastErrors: true })
}

export function useTicketLabelChange(ticketId: string) {
  const { t } = useTranslation()
  const client = useQueryClient()
  const apply = (labels: TicketLabel[]) => {
    client.setQueryData<Ticket>(ticketKeys.detail(ticketId), (ticket) =>
      ticket ? { ...ticket, labels } : ticket,
    )
    client.setQueryData<TicketLists>(ticketKeys.lists, (lists) =>
      lists ? listsWithLabels(lists, ticketId, labels) : lists,
    )
  }
  return useMutation({
    mutationFn: ({ label, add }: { label: TicketLabel; add: boolean }) =>
      add ? labelsApi.add(ticketId, label.id) : labelsApi.remove(ticketId, label.id),
    onSuccess: (labels, { label, add }) => {
      apply(labels)
      toast.success(t(add ? 'labels.added' : 'labels.removed', { name: label.name }))
      refreshTickets(client, ticketId)
    },
    onError: (error) => {
      toast.error(labelErrorText(error))
      refreshTickets(client, ticketId)
    },
  })
}

export function useLabelReport(range: DateRange) {
  return useQuery({
    queryKey: labelKeys.report(range),
    queryFn: () => labelsApi.report(range),
    placeholderData: (previous) => previous,
    staleTime: 60_000,
  })
}
