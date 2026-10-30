import { useQueryClient } from '@tanstack/react-query'
import {
  ImagePlusIcon,
  LinkIcon,
  ListChecksIcon,
  LoaderCircleIcon,
  PlusIcon,
  SendHorizontalIcon,
  ShieldAlertIcon,
  StickyNoteIcon,
  XIcon,
  FileTextIcon,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/menu'
import { useCommandHandler } from '@/features/command/bus'
import { customerKeys } from '@/features/customer/hooks'
import type { AgentProfile } from '@/features/presence/types'
import { customerName, type Ticket } from '@/features/tickets/types'
import { errorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'
import { cn, uuid } from '@/lib/utils'

import { conversationApi } from '../api'
import { useDraft, useQuickReplies, type SendRequest } from '../hooks'
import {
  applyQuickReply,
  fillVariables,
  filterQuickReplies,
  slashToken,
  type SlashToken,
} from '../quick-replies'
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
import { SpecialMessageDialog, type SpecialKind, type SpecialMessage } from './special-dialogs'

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
  const fileInput = useRef<HTMLInputElement>(null)
  const quickReplies = useQuickReplies()

  const matches = useMemo(
    () => (token && mode === 'reply' ? filterQuickReplies(quickReplies.data ?? [], token.query) : []),
    [token, mode, quickReplies.data],
  )
  const secret = mode === 'reply' && requestsSecret(value)
  const note = mode === 'note'

  useEffect(() => {
    const element = textarea.current
    if (!element) return
    element.style.height = 'auto'
    element.style.height = `${Math.min(element.scrollHeight, 220)}px`
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
    (incoming: File[]) => {
      const images: LocalAttachment[] = []
      for (const file of incoming) {
        if (!IMAGE_TYPES.includes(file.type)) {
          toast.error(t('composer.badType', { name: file.name }))
          continue
        }
        if (file.size > MAX_FILE_BYTES) {
          toast.error(t('composer.tooLarge', { name: file.name }))
          continue
        }
        images.push({ id: uuid(), file, preview: URL.createObjectURL(file) })
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
  ])

  useCommandHandler(
    'send',
    useCallback(() => void submit(), [submit]),
  )

  const sendSpecial = async (message: SpecialMessage) => {
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
      className={cn('relative border-t bg-card p-3 compact:p-2', note && 'bg-note/60')}
      onDragOver={(event) => {
        if (note || !event.dataTransfer.types.includes('Files')) return
        event.preventDefault()
        setDragging(true)
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(event) => {
        if (note) return
        event.preventDefault()
        setDragging(false)
        addFiles([...event.dataTransfer.files])
      }}
    >
      {dragging ? (
        <div className="pointer-events-none absolute inset-1 z-20 flex items-center justify-center rounded-lg border-2 border-dashed border-primary bg-primary/10 text-sm font-medium text-primary">
          {t('composer.dropHere')}
        </div>
      ) : null}
      <div className="mb-2 flex items-center gap-2">
        <div
          role="tablist"
          aria-label={t('composer.reply')}
          className="inline-flex rounded-lg bg-muted p-0.5"
        >
          {(['reply', 'note'] as const).map((item) => (
            <button
              key={item}
              type="button"
              role="tab"
              aria-selected={mode === item}
              onClick={() => focus(item)}
              className={cn(
                'inline-flex h-7 items-center gap-1.5 rounded-md px-3 text-xs font-medium transition-colors outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50',
                mode === item
                  ? 'bg-card text-foreground shadow-sm'
                  : 'text-muted-foreground hover:text-foreground',
              )}
            >
              {item === 'note' ? <StickyNoteIcon className="size-3.5" /> : null}
              {t(`composer.${item}`)}
            </button>
          ))}
        </div>
        {note ? (
          <span className="rounded-md bg-note px-2 py-0.5 text-[11px] font-semibold text-note-foreground">
            {t('composer.notVisible')}
          </span>
        ) : null}
        {replyTo && !note ? (
          <span className="flex min-w-0 items-center gap-1 rounded-md bg-accent px-2 py-0.5 text-[11px] text-accent-foreground">
            <span className="truncate">
              {t('conversation.replyingTo', {
                name: replyTo.sender_display_name ?? replyTo.sender_username ?? '',
              })}
            </span>
            <button type="button" aria-label={t('conversation.cancelReply')} onClick={onCancelReply}>
              <XIcon className="size-3" />
            </button>
          </span>
        ) : null}
      </div>
      {blocked || secret ? (
        <div
          role="alert"
          className="mb-2 flex items-start gap-2 rounded-md border border-destructive/30 bg-destructive/10 px-3 py-2 text-xs text-destructive"
        >
          <ShieldAlertIcon className="mt-0.5 size-4 shrink-0" />
          <span>{blocked ?? t('composer.secretBlocked')}</span>
        </div>
      ) : null}
      {files.length > 0 ? (
        <div className="mb-2 flex flex-wrap gap-2">
          {files.map((file) => (
            <div key={file.id} className="relative">
              <img
                src={file.preview}
                alt={file.file.name}
                className="size-16 rounded-md border object-cover"
              />
              <button
                type="button"
                aria-label={t('composer.removeAttachment', { name: file.file.name })}
                onClick={() => {
                  URL.revokeObjectURL(file.preview)
                  setFiles((current) => current.filter((item) => item.id !== file.id))
                }}
                className="absolute -top-1.5 -right-1.5 inline-flex size-5 items-center justify-center rounded-full bg-foreground text-background shadow"
              >
                <XIcon className="size-3" />
              </button>
            </div>
          ))}
        </div>
      ) : null}
      <div className="relative">
        {matches.length > 0 && token ? (
          <ul
            role="listbox"
            aria-label={t('composer.quickReplies')}
            className="absolute bottom-full left-0 z-30 mb-2 max-h-64 w-full overflow-y-auto rounded-lg border bg-popover p-1 shadow-lg"
          >
            {matches.map((reply, index) => (
              <li
                key={reply.id}
                role="option"
                aria-selected={index === highlight}
                onMouseDown={(event) => {
                  event.preventDefault()
                  insertQuickReply(index)
                }}
                onMouseEnter={() => setHighlight(index)}
                className={cn(
                  'cursor-pointer rounded-md px-2.5 py-1.5 text-sm',
                  index === highlight ? 'bg-accent text-accent-foreground' : '',
                )}
              >
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs font-semibold">/{reply.shortcut}</span>
                  <span className="truncate font-medium">{reply.title}</span>
                </div>
                <p className="line-clamp-1 text-xs text-muted-foreground">{reply.body}</p>
              </li>
            ))}
          </ul>
        ) : null}
        <div
          className={cn(
            'flex items-end gap-2 rounded-xl border bg-background p-1.5 focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/30',
            note && 'border-note-border bg-note',
          )}
        >
          {!note ? (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon-sm" aria-label={t('composer.more')}>
                  <PlusIcon />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="start" side="top">
                <DropdownMenuItem onSelect={() => fileInput.current?.click()}>
                  <ImagePlusIcon />
                  {t('composer.attach')}
                </DropdownMenuItem>
                <DropdownMenuItem onSelect={() => setSpecial('card')}>
                  <FileTextIcon />
                  {t('composer.sendCard')}
                </DropdownMenuItem>
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
          ) : null}
          <textarea
            ref={textarea}
            rows={1}
            value={value}
            maxLength={MAX_BODY}
            aria-label={note ? t('composer.note') : t('composer.reply')}
            aria-autocomplete="list"
            aria-expanded={matches.length > 0 && token !== null}
            placeholder={note ? t('composer.notePlaceholder') : t('composer.placeholder')}
            onChange={(event) => onChange(event.target.value, event.target.selectionStart)}
            onKeyDown={onKeyDown}
            onBlur={() => window.setTimeout(() => setToken(null), 150)}
            onPaste={(event) => {
              if (note) return
              const images = [...event.clipboardData.items]
                .filter((item) => item.kind === 'file' && IMAGE_TYPES.includes(item.type))
                .map((item) => item.getAsFile())
                .filter((file): file is File => file !== null)
              if (images.length > 0) {
                event.preventDefault()
                addFiles(images)
              }
            }}
            className="max-h-[220px] min-h-9 flex-1 resize-none bg-transparent px-2 py-2 text-sm outline-none placeholder:text-muted-foreground"
          />
          <Button
            size="icon-sm"
            aria-label={note ? t('composer.saveNote') : t('composer.send')}
            disabled={busy || (!value.trim() && files.length === 0) || secret}
            onClick={() => void submit()}
          >
            {busy ? (
              <LoaderCircleIcon className="animate-spin" />
            ) : note ? (
              <StickyNoteIcon />
            ) : (
              <SendHorizontalIcon />
            )}
          </Button>
        </div>
        <div className="tabular mt-1 flex justify-end text-[11px] text-muted-foreground">
          <span className={cn(value.length > MAX_BODY - 100 && 'text-destructive')}>
            {t('composer.chars', { count: value.length, max: MAX_BODY })}
          </span>
        </div>
      </div>
      <input
        ref={fileInput}
        type="file"
        accept={IMAGE_TYPES.join(',')}
        multiple
        hidden
        onChange={(event) => {
          addFiles([...(event.target.files ?? [])])
          event.target.value = ''
        }}
      />
      <SpecialMessageDialog
        kind={special}
        ticketId={ticket.id}
        onClose={() => setSpecial(null)}
        onSend={(message) => void sendSpecial(message)}
      />
    </div>
  )
}
