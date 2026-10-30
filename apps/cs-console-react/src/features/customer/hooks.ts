import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { create } from 'zustand'

import { conversationApi } from '@/features/conversation/api'

import { customerApi } from './api'
import type { Revealed, RevealField } from './types'

export const customerKeys = {
  profile: (ticketId: string) => ['customer', ticketId, 'profile'] as const,
  orders: (ticketId: string) => ['customer', ticketId, 'orders'] as const,
  cash: (ticketId: string) => ['customer', ticketId, 'cash'] as const,
  sessions: (ticketId: string) => ['customer', ticketId, 'sessions'] as const,
  security: (ticketId: string) => ['customer', ticketId, 'security'] as const,
  history: (customerId: string) => ['customer-history', customerId] as const,
  notes: (customerId: string) => ['customer-notes', customerId] as const,
}

const noRetry = { retry: false, staleTime: 60_000 } as const

export function useCustomerSection<T>(key: readonly unknown[], load: () => Promise<T>, enabled: boolean) {
  return useQuery({ queryKey: key, queryFn: load, enabled, ...noRetry })
}

export function useHistory(customerId: string | undefined) {
  return useQuery({
    queryKey: customerKeys.history(customerId ?? ''),
    queryFn: () => customerApi.history(customerId ?? ''),
    enabled: Boolean(customerId),
  })
}

export function useNotes(customerId: string | undefined) {
  return useQuery({
    queryKey: customerKeys.notes(customerId ?? ''),
    queryFn: () => customerApi.notes(customerId ?? ''),
    enabled: Boolean(customerId),
  })
}

export function useAddNote(customerId: string | undefined) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: ({ body, ticketId }: { body: string; ticketId?: string }) =>
      conversationApi.addNote(body, ticketId ? { ticketId } : { customerId }),
    onSuccess: () => {
      if (customerId) void client.invalidateQueries({ queryKey: customerKeys.notes(customerId) })
    },
  })
}

type RevealStore = {
  items: Record<string, Revealed>
  put: (ticketId: string, item: Revealed) => void
  clear: () => void
}

export const useRevealed = create<RevealStore>((set) => ({
  items: {},
  put: (ticketId, item) =>
    set((state) => ({ items: { ...state.items, [`${ticketId}:${item.field}`]: item } })),
  clear: () => set({ items: {} }),
}))

export function useRevealedValue(ticketId: string, field: RevealField) {
  const item = useRevealed((state) => state.items[`${ticketId}:${field}`])
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    if (!item) return
    const remaining = item.until - Date.now()
    if (remaining <= 0) return
    const timer = window.setTimeout(() => setNow(Date.now()), remaining + 50)
    return () => window.clearTimeout(timer)
  }, [item])
  return item && item.until > now ? item : undefined
}

export function useReveal(ticketId: string) {
  const put = useRevealed((state) => state.put)
  return useMutation({
    mutationFn: ({ field, reason }: { field: RevealField; reason: string }) =>
      customerApi.reveal(ticketId, field, reason),
    onSuccess: (item) => put(ticketId, item),
  })
}
