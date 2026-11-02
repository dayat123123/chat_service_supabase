import { useQueryClient } from '@tanstack/react-query'
import {
  EllipsisIcon,
  LinkIcon,
  ListChecksIcon,
  LoaderCircleIcon,
  PaperclipIcon,
  ShieldAlertIcon,
  SlashIcon,
  XIcon,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Dot } from '@/components/badges'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  floatClass,
  Tooltip,
} from '@/components/ui/menu'
import { useCommandHandler } from '@/features/command/bus'
import { customerKeys } from '@/features/customer/hooks'
import { GoOnlineButton } from '@/features/presence/components/go-online-button'
import { useAgent } from '@/features/auth/hooks'
import { useActionGuard } from '@/features/presence/hooks'
import type { AgentProfile } from '@/features/presence/types'
import { customerName, type Ticket } from '@/features/tickets/types'
import { errorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'
import { cn, uuid } from '@/lib/utils'

import { conversationApi } from '../api'
import { clipboardImages, fitImage, pasteBelongsElsewhere } from '../clipboard'
import { useDraft, useQuickReplies, type SendRequest } from '../hooks'
import {
  applyQuickReply,
  fillVariables,
  filterQuickReplies,
  slashToken,
  type SlashToken,
} from '../quick-replies'
import { ATTACHMENT_TYPES, fileSize, isDocumentFile, mediaLimit, mediaProblem } from '../media'
import { requestsSecret } from '../secret'
import {
  IMAGE_TYPES,
  MAX_BODY,
  MAX_FILE_BYTES,
  MAX_FILES,
  type ChatMessage,
  type ComposerMode,
  type LocalAttachment,
  type SendResult,
} from '../types'
import { PendingAttachments } from './pending-attachments'
import { SpecialMessageDialog, type SpecialKind, type SpecialMessage } from './special-dialogs'

const MAX_INPUT_HEIGHT = 182

function ToolButton({
  label,
  onClick,
  disabled,
  children,
}: {
  label: string
  onClick?: () => void
  disabled?: boolean
  children: React.ReactNode
}) {
  return (
    <Tooltip content={label}>
      <Button variant="ghost" size="icon-xs" aria-label={label} onClick={onClick} disabled={disabled}>
        {children}
      </Button>
    </Tooltip>
  )
}

type Props = {
  ticket: Ticket
  agent: AgentProfile
  replyTo: ChatMessage | null
  onCancelReply: () => void
  send: (request: SendRequest) => Promise<SendResult>
  onTyping: () => void
  onStopTyping: () => void
}

export function Composer({ ticket, agent, replyTo, onCancelReply, send, onTyping, onStopTyping }: Props) {
  const { t } = useTranslation()
  const client = useQueryClient()
  const [mode, setMode] = useState<ComposerMode>('reply')
  const [value, setValue, clearDraft] = useDraft(agent.id, ticket.id, mode)
  const [files, setFiles] = useState<LocalAttachment[]>([])
  const [dragging, setDragging] = useState(false)
  const [busy, setBusy] = useState(false)
  const [blocked, setBlocked] = useState<string | null>(null)
  const [token, setToken] = useState<SlashToken | null>(null)
  const [highlight, setHighlight] = useState(0)
  const [special, setSpecial] = useState<SpecialKind | null>(null)
  const textarea = useRef<HTMLTextAreaElement>(null)
  const listId = `quick-replies-${ticket.id}`
  const fileInput = useRef<HTMLInputElement>(null)
  const quickReplies = useQuickReplies()
  const guard = useActionGuard()
  const offline = useAgent().status === 'offline'

  const matches = useMemo(
    () => (token && mode === 'reply' ? filterQuickReplies(quickReplies.data ?? [], token.query) : []),
    [token, mode, quickReplies.data],
  )
  const secret = mode === 'reply' && requestsSecret(value)
  const note = mode === 'note'
  const locked = offline && !note

  useEffect(() => {
    const element = textarea.current
    if (!element) return
    element.style.height = 'auto'
    element.style.height = `${Math.min(element.scrollHeight, MAX_INPUT_HEIGHT)}px`
  }, [value, mode])

  const filesRef = useRef(files)
  useEffect(() => {
    filesRef.current = files
  }, [files])
  useEffect(
    () => () => {
      filesRef.current.forEach((file) => URL.revokeObjectURL(file.preview))
    },
    [],
  )

  const addFiles = useCallback(
    async (incoming: File[]) => {
      const prepared = await Promise.all(
        incoming.map((file) =>
          IMAGE_TYPES.includes(file.type) ? fitImage(file, MAX_FILE_BYTES) : Promise.resolve(file),
        ),
      )
      const images: LocalAttachment[] = []
      for (const file of prepared) {
        const problem = mediaProblem(file)
        if (problem === 'badType') {
          toast.error(t('composer.badType', { name: file.name }))
          continue
        }
        if (problem === 'tooLarge') {
          toast.error(t('composer.tooLarge', { name: file.name, max: fileSize(mediaLimit(file)) }))
          continue
        }
        images.push({ id: uuid(), file, preview: isDocumentFile(file) ? '' : URL.createObjectURL(file) })
      }
      setFiles((current) => {
        const room = MAX_FILES - current.length
        if (images.length > room) toast.error(t('composer.tooMany'))
        images.slice(room).forEach((image) => URL.revokeObjectURL(image.preview))
        return [...current, ...images.slice(0, room)]
      })
    },
    [t],
  )

  useEffect(() => {
    if (note || locked) return
    const onPaste = (event: ClipboardEvent) => {
      if (event.defaultPrevented || pasteBelongsElsewhere(event.target)) return
      const images = clipboardImages(event.clipboardData)
      if (images.length === 0) return
      event.preventDefault()
      void addFiles(images)
      textarea.current?.focus()
    }
    window.addEventListener('paste', onPaste)
    return () => window.removeEventListener('paste', onPaste)
  }, [note, locked, addFiles])

  const focus = useCallback((next: ComposerMode) => {
    setMode(next)
    requestAnimationFrame(() => textarea.current?.focus())
  }, [])
  useCommandHandler(
    'focusReply',
    useCallback(() => focus('reply'), [focus]),
  )
  useCommandHandler(
    'focusNote',
    useCallback(() => focus('note'), [focus]),
  )

  const submit = useCallback(async () => {
    const body = value.trim()
    if (busy) return
    if (note) {
      if (!body) return
      setBusy(true)
      try {
        await conversationApi.addNote(body, { ticketId: ticket.id })
        clearDraft()
        toast.success(t('composer.noteSaved'))
        if (ticket.customer?.id)
          void client.invalidateQueries({ queryKey: customerKeys.notes(ticket.customer.id) })
      } catch (error) {
        toast.error(errorText(error))
      } finally {
        setBusy(false)
      }
      return
    }
    if (!body && files.length === 0) return
    if (requestsSecret(body)) {
      setBlocked(t('composer.secretBlocked'))
      return
    }
    if (!guard('reply')) return
    const attachments = files
    setBusy(true)
    setBlocked(null)
    clearDraft()
    setFiles([])
    onStopTyping()
    onCancelReply()
    try {
      const result = await send({ body, files: attachments, replyTo })
      if (result.status === 'blocked') {
        setBlocked(result.message ?? t('errors.secretBlocked'))
        setValue(body)
      }
    } catch (error) {
      const apiError = toApiError(error)
      if (apiError.code !== 'network') {
        toast.error(errorText(apiError))
        setValue(body)
      }
    } finally {
      setBusy(false)
      requestAnimationFrame(() => textarea.current?.focus())
    }
  }, [
    value,
    busy,
    note,
    files,
    ticket,
    t,
    client,
    clearDraft,
    onStopTyping,
    onCancelReply,
    send,
    replyTo,
    setValue,
    guard,
  ])

  useCommandHandler(
    'send',
    useCallback(() => void submit(), [submit]),
  )

  const sendSpecial = async (message: SpecialMessage) => {
    if (!guard('reply')) return
    setSpecial(null)
    try {
      const result = await send({ body: message.body, kind: message.kind, payload: message.payload })
      if (result.status === 'blocked') setBlocked(result.message ?? t('errors.secretBlocked'))
    } catch (error) {
      toast.error(errorText(error))
    }
  }

  const insertQuickReply = (index: number) => {
    const reply = matches[index]
    const element = textarea.current
    if (!reply || !token || !element) return
    const text = fillVariables(reply.body, {
      customer: customerName(ticket),
      ticketNumber: ticket.ticket_number,
      agent: agent.display_name,
    })
    const next = applyQuickReply(value, token, text)
    setValue(next.value)
    setToken(null)
    requestAnimationFrame(() => {
      element.focus()
      element.setSelectionRange(next.caret, next.caret)
    })
  }

  const onChange = (next: string, caret: number) => {
    setValue(next)
    setBlocked(null)
    const found = mode === 'reply' ? slashToken(next, caret) : null
    setToken(found)
    setHighlight(0)
    if (mode === 'reply' && next.trim()) onTyping()
  }

  const startQuickReply = () => {
    const element = textarea.current
    if (!element) return
    const caret = element.selectionStart
    const before = value.slice(0, caret)
    const insert = before === '' || /\s$/.test(before) ? '/' : ' /'
    const position = caret + insert.length
    onChange(before + insert + value.slice(caret), position)
    requestAnimationFrame(() => {
      element.focus()
      element.setSelectionRange(position, position)
    })
  }

  const onKeyDown = (event: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (matches.length > 0 && token) {
      if (event.key === 'ArrowDown') {
        event.preventDefault()
        setHighlight((index) => (index + 1) % matches.length)
        return
      }
      if (event.key === 'ArrowUp') {
        event.preventDefault()
        setHighlight((index) => (index - 1 + matches.length) % matches.length)
        return
      }
      if (event.key === 'Enter' || event.key === 'Tab') {
        event.preventDefault()
        insertQuickReply(highlight)
        return
      }
      if (event.key === 'Escape') {
        event.preventDefault()
        setToken(null)
        return
      }
    }
    if (
      event.key === 'Enter' &&
      !event.shiftKey &&
      !event.ctrlKey &&
      !event.metaKey &&
      !event.nativeEvent.isComposing
    ) {
      event.preventDefault()
      void submit()
    }
  }

  return (
    <div
      className={cn(
        'relative shrink-0 border-t px-(--pane-px) pt-2 pb-3 compact:pb-2',
        note ? 'bg-note' : 'bg-background',
      )}
      onDragOver={(event) => {
        if (note || locked || !event.dataTransfer.types.includes('Files')) return
        event.preventDefault()
        setDragging(true)
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(event) => {
        if (note || locked) return
        event.preventDefault()
        setDragging(false)
        void addFiles([...event.dataTransfer.files])
      }}
    >
      {dragging ? (
        <div className="pointer-events-none absolute inset-1 z-20 flex items-center justify-center rounded-lg border border-dashed border-strong bg-background text-row text-muted-foreground">
          {t('composer.dropHere')}
        </div>
      ) : null}
      <div className="mb-2 flex min-w-0 items-center gap-3">
        <div role="tablist" aria-label={t('composer.reply')} className="flex shrink-0 items-center gap-2">
          {(['reply', 'note'] as const).map((item, index) => (
            <span key={item} className="flex items-center gap-2">
              {index > 0 ? <span aria-hidden="true" className="h-3 w-px bg-border" /> : null}
              <button
                type="button"
                role="tab"
                aria-selected={mode === item}
                onClick={() => focus(item)}
                className={cn(
                  'rounded-sm text-xs transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring/50',
                  mode === item
                    ? 'font-medium text-foreground'
                    : 'text-muted-foreground hover:text-foreground',
                )}
              >
                {t(`composer.${item}`)}
              </button>
            </span>
          ))}
        </div>
        {note ? (
          <span className="truncate text-xs text-muted-foreground">{t('composer.notVisible')}</span>
        ) : null}
        {replyTo && !note ? (
          <span className="flex min-w-0 items-center gap-1 text-xs text-muted-foreground">
            <span className="truncate">
              {t('conversation.replyingTo', {
                name: replyTo.sender_display_name ?? replyTo.sender_username ?? '',
              })}
            </span>
            <button
              type="button"
              aria-label={t('conversation.cancelReply')}
              onClick={onCancelReply}
              className="inline-flex size-5 shrink-0 items-center justify-center rounded-sm outline-none hover:bg-muted hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50"
            >
              <XIcon className="size-3" />
            </button>
          </span>
        ) : null}
      </div>
      {locked ? (
        <div
          role="status"
          className="mb-2 flex flex-wrap items-center gap-x-1.5 gap-y-1 text-xs text-muted-foreground"
        >
          <Dot tone="warn" />
          <span className="min-w-0 flex-1">{t('presence.offlineReplyHint')}</span>
          <GoOnlineButton size="xs" />
        </div>
      ) : null}
      {blocked || secret ? (
        <p role="alert" className="mb-2 flex items-start gap-1.5 text-xs text-destructive">
          <ShieldAlertIcon className="mt-px size-3.5 shrink-0" />
          <span>{blocked ?? t('composer.secretBlocked')}</span>
        </p>
      ) : null}
      <PendingAttachments
        files={files}
        onRemove={(file) => {
          URL.revokeObjectURL(file.preview)
          setFiles((current) => current.filter((item) => item.id !== file.id))
        }}
      />
      <div className="relative">
        {matches.length > 0 && token ? (
          <ul
            id={listId}
            role="listbox"
            aria-label={t('composer.quickReplies')}
            className={cn(floatClass, 'absolute bottom-full left-0 mb-2 max-h-64 w-full overflow-y-auto p-1')}
          >
            {matches.map((reply, index) => (
              <li
                key={reply.id}
                id={`${listId}-${index}`}
                role="option"
                aria-selected={index === highlight}
                onMouseDown={(event) => {
                  event.preventDefault()
                  insertQuickReply(index)
                }}
                onMouseEnter={() => setHighlight(index)}
                className={cn(
                  'cursor-pointer rounded-md px-2 py-1.5 text-sm',
                  index === highlight && 'bg-muted',
                )}
              >
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs text-muted-foreground">/{reply.shortcut}</span>
                  <span className="truncate font-medium">{reply.title}</span>
                </div>
                <p className="line-clamp-1 text-xs text-muted-foreground">{reply.body}</p>
              </li>
            ))}
          </ul>
        ) : null}
        <div
          className={cn(
            'rounded-lg border transition-[border-color,box-shadow] focus-within:border-ring/50 focus-within:ring-2 focus-within:ring-ring/10',
            note ? 'border-note-border' : locked ? 'bg-muted' : 'bg-background',
          )}
        >
          <textarea
            ref={textarea}
            rows={1}
            value={value}
            maxLength={MAX_BODY}
            disabled={locked}
            aria-label={note ? t('composer.note') : t('composer.reply')}
            aria-autocomplete="list"
            aria-controls={matches.length > 0 && token ? listId : undefined}
            aria-activedescendant={matches.length > 0 && token ? `${listId}-${highlight}` : undefined}
            placeholder={note ? t('composer.notePlaceholder') : t('composer.placeholder')}
            onChange={(event) => onChange(event.target.value, event.target.selectionStart)}
            onKeyDown={onKeyDown}
            onBlur={() => window.setTimeout(() => setToken(null), 150)}
            onPaste={(event) => {
              if (note) return
              const images = clipboardImages(event.clipboardData)
              if (images.length > 0) {
                event.preventDefault()
                void addFiles(images)
              }
            }}
            className="block max-h-[182px] min-h-[42px] w-full resize-none bg-transparent px-3 pt-2.5 pb-1 text-sm leading-normal outline-none disabled:cursor-not-allowed disabled:text-muted-foreground"
          />
          <div className="flex items-center gap-0.5 px-1.5 pb-1.5">
            {!note ? (
              <>
                <ToolButton
                  label={t('composer.attach')}
                  disabled={locked}
                  onClick={() => fileInput.current?.click()}
                >
                  <PaperclipIcon />
                </ToolButton>
                <ToolButton
                  label={t('composer.insertQuickReply')}
                  disabled={locked}
                  onClick={startQuickReply}
                >
                  <SlashIcon />
                </ToolButton>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon-xs" aria-label={t('composer.more')} disabled={locked}>
                      <EllipsisIcon />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="start" side="top">
                    <DropdownMenuItem onSelect={() => setSpecial('help')}>
                      <LinkIcon />
                      {t('composer.sendHelpLink')}
                    </DropdownMenuItem>
                    <DropdownMenuItem onSelect={() => setSpecial('options')}>
                      <ListChecksIcon />
                      {t('composer.sendOptions')}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </>
            ) : null}
            <div className="ml-auto flex min-w-0 items-center gap-3 pl-2">
              {locked ? null : (
                <span className="hidden truncate text-xs text-muted-foreground lg:inline">
                  {t('composer.hint')}
                </span>
              )}
              <span
                className={cn(
                  'tabular text-xs text-muted-foreground',
                  value.length > MAX_BODY - 100 && 'text-destructive',
                )}
              >
                {t('composer.chars', { count: value.length, max: MAX_BODY })}
              </span>
              <Button
                size="sm"
                disabled={busy || locked || (!value.trim() && files.length === 0) || secret}
                onClick={() => void submit()}
              >
                {busy ? <LoaderCircleIcon className="animate-spin" /> : null}
                {note ? t('composer.saveNote') : t('composer.send')}
              </Button>
            </div>
          </div>
        </div>
      </div>
      <input
        ref={fileInput}
        type="file"
        accept={ATTACHMENT_TYPES.join(',')}
        multiple
        hidden
        onChange={(event) => {
          void addFiles([...(event.target.files ?? [])])
          event.target.value = ''
        }}
      />
      <SpecialMessageDialog
        kind={special}
        onClose={() => setSpecial(null)}
        onSend={(message) => void sendSpecial(message)}
      />
    </div>
  )
}
