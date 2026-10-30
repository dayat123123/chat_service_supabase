import { useMutation, useQuery, useQueryClient, type QueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { useCallback, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { create } from 'zustand'

import i18n from '@/i18n'
import { errorText } from '@/lib/error-text'
import { ApiError, toApiError } from '@/lib/errors'
import { realtime } from '@/lib/realtime'

import { ticketsApi } from './api'
import { claimedByOther, noFilter, withoutTicket } from './logic'
import { emptyLists, type TicketFilter, type TicketLists, type TicketTab } from './types'

export const ticketKeys = {
  all: ['tickets'] as const,
  lists: ['tickets', 'lists'] as const,
  detail: (id: string) => ['tickets', 'detail', id] as const,
  search: (query: string) => ['tickets', 'search', query] as const,
  topics: (language: string) => ['topics', language] as const,
}

type TicketUi = {
  tab: TicketTab
  filter: TicketFilter
  query: string
  selectedId: string | null
  leaving: Record<string, string>
  setTab: (tab: TicketTab) => void
  setFilter: (filter: TicketFilter) => void
  setQuery: (query: string) => void
  select: (ticketId: string | null) => void
  markLeaving: (ticketId: string, name: string) => void
  clearLeaving: (ticketId: string) => void
  reset: () => void
}

export const useTicketUi = create<TicketUi>((set) => ({
  tab: 'open',
  filter: noFilter,
  query: '',
  selectedId: null,
  leaving: {},
  setTab: (tab) => set({ tab }),
  setFilter: (filter) => set({ filter }),
  setQuery: (query) => set({ query }),
  select: (selectedId) => set({ selectedId }),
  markLeaving: (ticketId, name) => set((state) => ({ leaving: { ...state.leaving, [ticketId]: name } })),
  clearLeaving: (ticketId) =>
    set((state) => {
      const leaving = { ...state.leaving }
      delete leaving[ticketId]
      return { leaving }
    }),
  reset: () => set({ tab: 'open', filter: noFilter, query: '', selectedId: null, leaving: {} }),
}))

export function useOpenTicket() {
  const navigate = useNavigate()
  return useCallback(
    (ticketId: string) => {
      useTicketUi.getState().select(ticketId)
      void navigate({ to: '/' })
    },
    [navigate],
  )
}

export function useTicketLists(enabled = true) {
  return useQuery({
    queryKey: ticketKeys.lists,
    queryFn: ticketsApi.lists,
    enabled,
    refetchInterval: 30_000,
    placeholderData: (previous) => previous,
  })
}

export function useTopics() {
  const { i18n } = useTranslation()
  const language = i18n.language === 'en' ? 'en' : 'id'
  return useQuery({
    queryKey: ticketKeys.topics(language),
    queryFn: () => ticketsApi.topics(language),
    staleTime: 10 * 60_000,
  })
}

export function useTopicName() {
  const { data } = useTopics()
  return (code: string) => data?.find((topic) => topic.code === code)?.name ?? code
}

export function useTicketSearch(query: string) {
  return useQuery({
    queryKey: ticketKeys.search(query),
    queryFn: () => ticketsApi.search(query),
    enabled: query.length >= 2,
    staleTime: 5_000,
  })
}

export function useTicketDetail(ticketId: string | null) {
  return useQuery({
    queryKey: ticketKeys.detail(ticketId ?? ''),
    queryFn: () => ticketsApi.detail(ticketId ?? ''),
    enabled: ticketId !== null,
  })
}

export function refreshTickets(client: QueryClient, ticketId?: string) {
  void client.invalidateQueries({ queryKey: ticketKeys.lists })
  if (ticketId) void client.invalidateQueries({ queryKey: ticketKeys.detail(ticketId) })
}

export function useClaimTicket() {
  const client = useQueryClient()
  const { setTab, select } = useTicketUi.getState()
  return useMutation({
    mutationFn: (ticketId: string) => ticketsApi.claim(ticketId),
    onSuccess: (ticket) => {
      client.setQueryData(ticketKeys.detail(ticket.id), ticket)
      setTab('mine')
      select(ticket.id)
      refreshTickets(client, ticket.id)
    },
    onError: (error, ticketId) => {
      toast.error(errorText(error))
      client.setQueryData<TicketLists>(ticketKeys.lists, (lists) =>
        withoutTicket(lists ?? emptyLists, ticketId),
      )
      refreshTickets(client, ticketId)
    },
  })
}

export function useTicketAction<TArgs>(
  action: (args: TArgs) => Promise<unknown>,
  options: {
    success?: string | ((args: TArgs) => string)
    ticketId: (args: TArgs) => string
    onSuccess?: (args: TArgs) => void
  },
) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: action,
    onSuccess: (_result, args) => {
      const message = typeof options.success === 'function' ? options.success(args) : options.success
      if (message) toast.success(message)
      refreshTickets(client, options.ticketId(args))
      options.onSuccess?.(args)
    },
    onError: (error, args) => {
      const apiError = toApiError(error)
      toast.error(errorText(apiError))
      if (apiError instanceof ApiError) refreshTickets(client, options.ticketId(args))
    },
  })
}

export function useTicketRealtime(meId: string, enabled: boolean, supervisor: boolean) {
  const client = useQueryClient()
  useEffect(() => {
    if (!enabled) return
    let timer: number | undefined
    const removals = new Set<number>()
    const stop = realtime.subscribe((event) => {
      if (event.type === 'agent' || event.type === 'alert') return
      const taken = claimedByOther(event, meId)
      if (taken) {
        const { markLeaving, clearLeaving, selectedId } = useTicketUi.getState()
        const viewing = !supervisor && selectedId === taken.ticketId
        if (viewing) toast.info(i18n.t('tickets.takenByOther', { name: taken.name }))
        markLeaving(taken.ticketId, taken.name)
        const removal = window.setTimeout(() => {
          removals.delete(removal)
          client.setQueryData<TicketLists>(ticketKeys.lists, (lists) =>
            withoutTicket(lists ?? emptyLists, taken.ticketId),
          )
          clearLeaving(taken.ticketId)
          if (viewing && useTicketUi.getState().selectedId === taken.ticketId)
            useTicketUi.getState().select(null)
        }, 1_600)
        removals.add(removal)
      }
      if (!taken || supervisor) void client.invalidateQueries({ queryKey: ticketKeys.detail(event.ticketId) })
      window.clearTimeout(timer)
      timer = window.setTimeout(
        () => {
          void client.invalidateQueries({ queryKey: ticketKeys.lists })
        },
        taken ? 1_700 : 250,
      )
    })
    return () => {
      stop()
      window.clearTimeout(timer)
      removals.forEach((removal) => window.clearTimeout(removal))
    }
  }, [client, meId, enabled, supervisor])
}
