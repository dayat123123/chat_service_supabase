import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { create } from 'zustand'

import { ticketKeys } from '@/features/tickets/hooks'
import type { Ticket } from '@/features/tickets/types'
import { toApiError } from '@/lib/errors'
import { realtime } from '@/lib/realtime'
import { readLocal, writeLocal } from '@/lib/storage'
import { uuid } from '@/lib/utils'

import { conversationApi, PAGE_SIZE } from './api'
import {
  collectAfter,
  insertMessages,
  newestCursor,
  orderedMessages,
  overlapCursor,
  type MessagePages,
} from './cache'
import { createGapSchedule } from './gap-schedule'
import type {
  ChatMessage,
  LocalAttachment,
  PendingMessage,
  PersonalReplyDraft,
  RoomMember,
  SendKind,
  SendResult,
} from './types'

export const conversationKeys = {
  messages: (roomId: string) => ['messages', roomId] as const,
  members: (roomId: string) => ['members', roomId] as const,
  quickReplies: (language: string) => ['quick-replies', language] as const,
  myQuickReplies: ['quick-replies', 'mine'] as const,
  signedUrl: (path: string, bucket: string) => ['signed-url', bucket, path] as const,
}

type PendingStore = {
  items: PendingMessage[]
  add: (item: PendingMessage) => void
  update: (clientId: string, patch: Partial<PendingMessage>) => void
  remove: (clientId: string) => void
  clear: () => void
}

export const usePending = create<PendingStore>((set, get) => ({
  items: [],
  add: (item) =>
    set((state) => ({ items: [...state.items.filter((p) => p.clientId !== item.clientId), item] })),
  update: (clientId, patch) =>
    set((state) => ({ items: state.items.map((p) => (p.clientId === clientId ? { ...p, ...patch } : p)) })),
  remove: (clientId) => set((state) => ({ items: state.items.filter((p) => p.clientId !== clientId) })),
  clear: () => {
    get().items.forEach((item) => item.files.forEach((file) => URL.revokeObjectURL(file.preview)))
    set({ items: [] })
  },
}))

export function useMessages(roomId: string) {
  const query = useInfiniteQuery({
    queryKey: conversationKeys.messages(roomId),
    queryFn: ({ pageParam }) => conversationApi.page(roomId, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (last) => (last.length < PAGE_SIZE ? undefined : last[last.length - 1]?.cursor),
    staleTime: Infinity,
  })
  const messages = useMemo(() => orderedMessages(query.data), [query.data])
  return { ...query, messages }
}

export function useMembers(roomId: string) {
  return useQuery({
    queryKey: conversationKeys.members(roomId),
    queryFn: () => conversationApi.members(roomId),
    staleTime: 60_000,
  })
}

export function useQuickReplies() {
  const { i18n } = useTranslation()
  const language = i18n.language === 'en' ? 'en' : 'id'
  return useQuery({
    queryKey: conversationKeys.quickReplies(language),
    queryFn: () => conversationApi.quickReplies(language),
    staleTime: 5 * 60_000,
  })
}

export function useMyQuickReplies() {
  return useQuery({ queryKey: conversationKeys.myQuickReplies, queryFn: conversationApi.myQuickReplies })
}

export function useSaveMyQuickReply() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (draft: PersonalReplyDraft) => conversationApi.saveMyQuickReply(draft),
    onSettled: () => client.invalidateQueries({ queryKey: ['quick-replies'] }),
  })
}

export function useDeleteMyQuickReply() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => conversationApi.deleteMyQuickReply(id),
    onSettled: () => client.invalidateQueries({ queryKey: ['quick-replies'] }),
  })
}

export function useSignedUrl(path: string, bucket = 'attachments') {
  return useQuery({
    queryKey: conversationKeys.signedUrl(path, bucket),
    queryFn: () => conversationApi.signedUrl(path, bucket),
    staleTime: 90_000,
    gcTime: 110_000,
  })
}

export function useRoom(ticket: Ticket, me: { id: string; username: string; displayName: string }) {
  const client = useQueryClient()
  const roomId = ticket.room_id
  const owner = ticket.is_mine
  const [typing, setTyping] = useState<string | null>(null)
  const [online, setOnline] = useState<string[]>([])
  const handle = useRef<ReturnType<typeof realtime.room> | null>(null)
  const typingTimer = useRef<number | undefined>(undefined)

  const syncAfter = useCallback(async () => {
    const key = conversationKeys.messages(roomId)
    const cursor = newestCursor(client.getQueryData<MessagePages>(key))
    if (!cursor) {
      await client.invalidateQueries({ queryKey: key })
      return
    }
    const { messages: fresh, complete } = await collectAfter(
      (after) => conversationApi.after(roomId, after),
      overlapCursor(cursor),
    )
    if (fresh.length > 0) {
      client.setQueryData<MessagePages>(key, (data) => insertMessages(data, fresh))
      const pending = usePending.getState()
      fresh.forEach((message) => {
        if (message.client_id) pending.remove(message.client_id)
      })
    }
    if (!complete) await client.invalidateQueries({ queryKey: key })
  }, [client, roomId])

  useEffect(() => {
    const gaps = createGapSchedule({
      run: () => void syncAfter().catch(() => undefined),
      isVisible: () => document.visibilityState === 'visible',
    })
    handle.current = realtime.room(
      roomId,
      me,
      {
        onMessage: gaps.now,
        onTyping: (user, isTyping) => {
          window.clearTimeout(typingTimer.current)
          setTyping(isTyping ? user.name : null)
          if (isTyping) typingTimer.current = window.setTimeout(() => setTyping(null), 6_000)
        },
        onReceipt: (receipt) =>
          client.setQueryData<RoomMember[]>(conversationKeys.members(roomId), (members) =>
            members?.map((member) =>
              member.user_id === receipt.userId
                ? { ...member, last_read_at: receipt.lastReadAt, last_delivered_at: receipt.lastDeliveredAt }
                : member,
            ),
          ),
        onPresence: setOnline,
        onTicket: () => {
          void client.invalidateQueries({ queryKey: ticketKeys.detail(ticket.id) })
          void client.invalidateQueries({ queryKey: ticketKeys.lists })
        },
        onMessagesJoined: (recovered) => (recovered ? gaps.reconnected() : gaps.now()),
      },
      { signals: owner },
    )
    const stopResync = realtime.onResync(gaps.reconnected)
    const stopQueue = realtime.subscribe((event) => {
      if (event.type === 'message' && event.roomId === roomId) gaps.now()
    })
    const onVisible = () => {
      if (document.visibilityState === 'visible') gaps.now()
    }
    document.addEventListener('visibilitychange', onVisible)
    window.addEventListener('focus', onVisible)
    return () => {
      stopResync()
      stopQueue()
      gaps.stop()
      document.removeEventListener('visibilitychange', onVisible)
      window.removeEventListener('focus', onVisible)
      window.clearTimeout(typingTimer.current)
      handle.current?.close()
      handle.current = null
    }
  }, [client, roomId, ticket.id, owner, me, syncAfter])

  const lastTyping = useRef(0)
  const stopTimer = useRef<number | undefined>(undefined)
  const sendTyping = useCallback(() => {
    const now = Date.now()
    if (now - lastTyping.current > 2_500) {
      lastTyping.current = now
      handle.current?.sendTyping(true)
    }
    window.clearTimeout(stopTimer.current)
    stopTimer.current = window.setTimeout(() => {
      lastTyping.current = 0
      handle.current?.sendTyping(false)
    }, 4_000)
  }, [])
  const stopTyping = useCallback(() => {
    window.clearTimeout(stopTimer.current)
    if (lastTyping.current !== 0) handle.current?.sendTyping(false)
    lastTyping.current = 0
  }, [])

  const customerId = ticket.customer?.id
  return {
    typing,
    customerOnline: customerId ? online.includes(customerId) : false,
    sendTyping,
    stopTyping,
    syncAfter,
  }
}

export type SendRequest = {
  body: string
  files?: LocalAttachment[]
  replyTo?: ChatMessage | null
  kind?: SendKind
  payload?: Record<string, unknown>
}

export function useSendMessage(ticket: Ticket, meId: string) {
  const client = useQueryClient()
  const run = useCallback(
    async (
      pending: PendingMessage,
      extra: { kind?: SendKind; payload?: Record<string, unknown> },
    ): Promise<SendResult> => {
      const store = usePending.getState()
      const showPending = !extra.kind || extra.kind === 'text'
      if (showPending) store.add({ ...pending, status: 'sending' })
      try {
        const attachments = await Promise.all(
          pending.files.map((file) => conversationApi.upload(pending.roomId, meId, file.file)),
        )
        const result = await conversationApi.send({
          ticketId: pending.ticketId,
          body: pending.body,
          clientId: pending.clientId,
          kind: extra.kind,
          payload: extra.payload,
          replyToId: pending.replyTo?.id,
          attachments,
        })
        if (result.status === 'sent') {
          client.setQueryData<MessagePages>(conversationKeys.messages(pending.roomId), (data) =>
            insertMessages(data, [{ ...result.message, local: true }]),
          )
          pending.files.forEach((file) => URL.revokeObjectURL(file.preview))
        }
        store.remove(pending.clientId)
        void client.invalidateQueries({ queryKey: ticketKeys.lists })
        return result
      } catch (error) {
        const apiError = toApiError(error)
        if (showPending && apiError.code === 'network') store.update(pending.clientId, { status: 'failed' })
        else store.remove(pending.clientId)
        throw apiError
      }
    },
    [client, meId],
  )

  const send = useCallback(
    (request: SendRequest) =>
      run(
        {
          clientId: uuid(),
          roomId: ticket.room_id,
          ticketId: ticket.id,
          body: request.body,
          files: request.files ?? [],
          replyTo: request.replyTo ?? null,
          status: 'sending',
          createdAt: new Date().toISOString(),
        },
        { kind: request.kind, payload: request.payload },
      ),
    [run, ticket.id, ticket.room_id],
  )

  const resend = useCallback((pending: PendingMessage) => run(pending, {}), [run])
  return { send, resend }
}

export function useMarkRead(roomId: string, enabled: boolean, latestCustomerAt: string | undefined) {
  const client = useQueryClient()
  const marked = useRef<string | undefined>(undefined)
  useEffect(() => {
    if (!enabled || !latestCustomerAt) return
    const mark = () => {
      if (document.hidden || marked.current === latestCustomerAt) return
      marked.current = latestCustomerAt
      void conversationApi
        .markRead(roomId)
        .then(() => client.invalidateQueries({ queryKey: ticketKeys.lists }))
        .catch(() => {
          marked.current = undefined
        })
    }
    mark()
    document.addEventListener('visibilitychange', mark)
    return () => document.removeEventListener('visibilitychange', mark)
  }, [client, roomId, enabled, latestCustomerAt])
}

export function useDraft(agentId: string, ticketId: string, mode: string) {
  const key = `draft.${agentId}.${ticketId}.${mode}`
  const [value, setValue] = useState(() => readLocal(key) ?? '')
  const [loadedKey, setLoadedKey] = useState(key)
  if (loadedKey !== key) {
    setLoadedKey(key)
    setValue(readLocal(key) ?? '')
  }
  useEffect(() => {
    writeLocal(key, value ? value : null)
  }, [key, value])
  const clear = useCallback(() => {
    setValue('')
    writeLocal(key, null)
  }, [key])
  return [value, setValue, clear] as const
}
