import { toApiError } from '@/lib/errors'
import { rpc, supabase } from '@/lib/supabase'
import { uuid } from '@/lib/utils'

import { AFTER_LIMIT } from './cache'
import { DOCUMENT_BUCKET, isDocumentFile } from './media'
import type {
  Attachment,
  ChatMessage,
  PersonalQuickReply,
  PersonalReplyDraft,
  QuickReply,
  RoomMember,
  SendKind,
  SendResult,
} from './types'

export const PAGE_SIZE = 50

function normalize(message: ChatMessage): ChatMessage {
  return { ...message, attachments: message.attachments ?? [], payload: message.payload ?? {} }
}

const extension: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
}

export async function imageSize(file: File) {
  try {
    const bitmap = await createImageBitmap(file)
    const size = { width: bitmap.width, height: bitmap.height }
    bitmap.close()
    return size
  } catch {
    return { width: null, height: null }
  }
}

export type SendInput = {
  ticketId: string
  body: string
  clientId: string
  kind?: SendKind
  payload?: Record<string, unknown>
  replyToId?: string
  attachments?: Attachment[]
}

export const conversationApi = {
  page: async (roomId: string, cursor?: string) =>
    (
      await rpc<ChatMessage[]>('get_messages', { p_room_id: roomId, p_cursor: cursor, p_limit: PAGE_SIZE })
    ).map(normalize),
  after: async (roomId: string, cursor: string) =>
    (
      await rpc<ChatMessage[]>('get_messages', { p_room_id: roomId, p_after: cursor, p_limit: AFTER_LIMIT })
    ).map(normalize),
  send: async (input: SendInput): Promise<SendResult> => {
    const result = await rpc<{ status: string; message?: unknown; code?: string }>('agent_send_message', {
      p_ticket_id: input.ticketId,
      p_body: input.body,
      p_client_id: input.clientId,
      p_kind: input.kind ?? 'text',
      p_payload: (input.payload ?? {}) as never,
      p_reply_to_id: input.replyToId,
      p_attachments: (input.attachments ?? []) as never,
    })
    if (result.status === 'sent' && result.message && typeof result.message === 'object') {
      return { status: 'sent', message: normalize(result.message as ChatMessage) }
    }
    return {
      status: 'blocked',
      code: result.code,
      message: typeof result.message === 'string' ? result.message : undefined,
    }
  },
  markRead: (roomId: string) => rpc<null>('mark_read', { p_room_id: roomId }),
  members: (roomId: string) => rpc<RoomMember[]>('room_members', { p_room_id: roomId }),
  quickReplies: (language: string) => rpc<QuickReply[]>('quick_replies', { p_language: language }),
  myQuickReplies: () => rpc<PersonalQuickReply[]>('my_quick_replies'),
  saveMyQuickReply: (draft: PersonalReplyDraft) =>
    rpc<PersonalQuickReply>('save_my_quick_reply', {
      p_id: draft.id,
      p_title: draft.title,
      p_body: draft.body,
      p_shortcut: draft.shortcut === '' ? null : draft.shortcut,
    }),
  deleteMyQuickReply: (id: string) => rpc<{ deleted: boolean }>('delete_my_quick_reply', { p_id: id }),
  addNote: (body: string, target: { ticketId?: string; customerId?: string }) =>
    rpc<unknown>('add_note', {
      p_body: body,
      p_ticket_id: target.ticketId,
      p_customer_id: target.customerId,
    }),
  upload: async (roomId: string, userId: string, file: File): Promise<Attachment> => {
    if (isDocumentFile(file)) {
      const path = `rooms/${roomId}/${userId}/${uuid()}.pdf`
      const { error } = await supabase()
        .storage.from(DOCUMENT_BUCKET)
        .upload(path, file, { contentType: file.type })
      if (error) throw toApiError(error)
      return {
        bucket: DOCUMENT_BUCKET,
        path,
        mime: file.type,
        name: file.name.slice(0, 200),
        size: file.size,
      }
    }
    const path = `rooms/${roomId}/${userId}/${uuid()}.${extension[file.type] ?? 'jpg'}`
    const { error } = await supabase()
      .storage.from('attachments')
      .upload(path, file, { contentType: file.type })
    if (error) throw toApiError(error)
    const size = await imageSize(file)
    return { path, mime: file.type, width: size.width, height: size.height }
  },
  signedUrl: async (path: string, bucket = 'attachments') => {
    const { data, error } = await supabase().storage.from(bucket).createSignedUrl(path, 120)
    if (error) throw toApiError(error)
    return data.signedUrl
  },
}
