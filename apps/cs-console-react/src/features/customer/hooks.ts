import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { conversationApi } from '@/features/conversation/api'

import { customerApi } from './api'

export const customerKeys = {
  history: (customerId: string) => ['customer-history', customerId] as const,
  notes: (customerId: string) => ['customer-notes', customerId] as const,
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
