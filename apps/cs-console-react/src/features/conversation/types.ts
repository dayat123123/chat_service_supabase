export type Attachment = {
  path: string
  bucket?: string | null
  mime?: string | null
  name?: string | null
  size?: number | null
  width?: number | null
  height?: number | null
}

export type SenderRole = 'customer' | 'agent' | 'supervisor' | 'system'

export type ChatMessage = {
  id: string
  room_id: string
  sender_id: string | null
  sender_username: string | null
  sender_display_name: string | null
  body: string
  is_deleted: boolean
  reply_to_id: string | null
  reply_to_body: string | null
  reply_to_sender_username: string | null
  attachments: Attachment[]
  client_id: string | null
  created_at: string
  cursor: string
  kind: string
  payload: Record<string, unknown>
  session_id: string | null
  sender_role: SenderRole | null
}

export type RoomMember = {
  user_id: string
  display_name: string | null
  username: string | null
  role: string
  is_staff: boolean
  last_read_at: string | null
  last_delivered_at: string | null
}

export type QuickReply = { id: string; scope: string; shortcut: string; title: string; body: string }

export type LocalAttachment = { id: string; file: File; preview: string }

export type PendingMessage = {
  clientId: string
  roomId: string
  ticketId: string
  body: string
  files: LocalAttachment[]
  replyTo: ChatMessage | null
  status: 'sending' | 'failed'
  createdAt: string
}

export type SendKind = 'text' | 'quick_reply' | 'help_link'

export type SendResult =
  { status: 'sent'; message: ChatMessage } | { status: 'blocked'; code?: string; message?: string }

export type ComposerMode = 'reply' | 'note'

export const MAX_BODY = 4000
export const MAX_FILES = 4
export const MAX_FILE_BYTES = 5 * 1024 * 1024
export const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif']

export function isStaffMessage(message: Pick<ChatMessage, 'sender_role'>) {
  return message.sender_role === 'agent' || message.sender_role === 'supervisor'
}

export function isSystemMessage(message: Pick<ChatMessage, 'kind'>) {
  return message.kind === 'system' || message.kind === 'csat'
}
