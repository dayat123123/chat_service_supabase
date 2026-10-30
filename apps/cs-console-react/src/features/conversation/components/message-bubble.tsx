import {
  AlertCircleIcon,
  BadgeCheckIcon,
  CheckCheckIcon,
  CheckIcon,
  ExternalLinkIcon,
  FileTextIcon,
  LoaderCircleIcon,
  ReplyIcon,
  WalletIcon,
} from 'lucide-react'
import { memo, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
} from '@/components/ui/dialog'
import { Tooltip } from '@/components/ui/menu'
import { clock } from '@/lib/time'
import { cn } from '@/lib/utils'

import type { ChatMessage, PendingMessage } from '../types'
import { AttachmentImage } from './attachment-image'

const separatorCodes = new Set([
  'ticket_opened',
  'ticket_closed',
  'ticket_resolved',
  'ticket_reopened',
  'ticket_reopened_owner',
])

export const SystemMessage = memo(function SystemMessage({ message }: { message: ChatMessage }) {
  const code = typeof message.payload.code === 'string' ? message.payload.code : ''
  if (separatorCodes.has(code)) {
    return (
      <div className="flex items-center gap-3 px-6 py-1.5" role="note">
        <span className="h-px flex-1 bg-border" />
        <span className="max-w-[70%] text-center text-[11px] text-muted-foreground">
          {message.body} · {clock(message.created_at)}
        </span>
        <span className="h-px flex-1 bg-border" />
      </div>
    )
  }
  return (
    <div className="flex justify-center px-6 py-1" role="note">
      <p className="max-w-[80%] rounded-lg bg-muted px-3 py-1.5 text-center text-xs text-muted-foreground">
        {message.body} <span className="tabular opacity-70">{clock(message.created_at)}</span>
      </p>
    </div>
  )
})

function httpsHost(url: string) {
  try {
    const parsed = new URL(url)
    return parsed.protocol === 'https:' ? parsed.host : null
  } catch {
    return null
  }
}

function SafeLink({
  url,
  title,
  trusted,
}: {
  url: string
  title: string
  trusted: (host: string) => boolean
}) {
  const { t } = useTranslation()
  const [confirming, setConfirming] = useState(false)
  const host = httpsHost(url)
  if (host === null) return <span>{url}</span>
  const open = () => window.open(url, '_blank', 'noopener,noreferrer')
  return (
    <>
      <a
        href={url}
        target="_blank"
        rel="noopener noreferrer"
        onClick={(event) => {
          if (trusted(host)) return
          event.preventDefault()
          setConfirming(true)
        }}
        className="mt-1 inline-flex max-w-full items-center gap-1 font-medium underline underline-offset-2"
      >
        <ExternalLinkIcon className="size-3.5 shrink-0" />
        <span className="truncate">{title || url}</span>
      </a>
      <AlertDialog open={confirming} onOpenChange={setConfirming}>
        <AlertDialogContent className="sm:max-w-md">
          <AlertDialogTitle>{t('conversation.externalTitle')}</AlertDialogTitle>
          <AlertDialogDescription>{t('conversation.externalBody', { host })}</AlertDialogDescription>
          <p className="text-xs break-all text-muted-foreground">{url}</p>
          <div className="flex justify-end gap-2">
            <AlertDialogCancel>{t('app.cancel')}</AlertDialogCancel>
            <AlertDialogAction onClick={open}>{t('conversation.openLink')}</AlertDialogAction>
          </div>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}

type BubbleProps = {
  message: ChatMessage
  mine: boolean
  staff: boolean
  first: boolean
  last: boolean
  read: boolean
  trustedHost: (host: string) => boolean
  onReply?: (message: ChatMessage) => void
  onOpenCard?: (payload: { card: string; ref: string }) => void
}

export const MessageBubble = memo(function MessageBubble({
  message,
  mine,
  staff,
  first,
  last,
  read,
  trustedHost,
  onReply,
  onOpenCard,
}: BubbleProps) {
  const { t } = useTranslation()
  const right = staff
  const name = message.sender_display_name ?? message.sender_username ?? ''
  const options = Array.isArray(message.payload.options)
    ? message.payload.options.filter((option): option is string => typeof option === 'string')
    : []
  const masked = Array.isArray(message.payload.masked)
    ? message.payload.masked.filter((field): field is string => typeof field === 'string')
    : []
  const card =
    message.kind === 'card' && typeof message.payload.ref === 'string'
      ? {
          card: typeof message.payload.card === 'string' ? message.payload.card : 'order',
          ref: message.payload.ref,
        }
      : null
  const url =
    message.kind === 'help_link' && typeof message.payload.url === 'string' ? message.payload.url : null

  return (
    <div
      className={cn(
        'group flex px-4 compact:px-3',
        right ? 'justify-end' : 'justify-start',
        first ? 'mt-2 compact:mt-1.5' : 'mt-0.5',
      )}
    >
      <div className={cn('flex max-w-[78%] flex-col', right ? 'items-end' : 'items-start')}>
        {first ? (
          <div className="mb-0.5 flex items-center gap-1.5 px-1 text-[11px] text-muted-foreground">
            <span className="font-semibold text-foreground">
              {staff ? name : name || t('conversation.customer')}
            </span>
            {staff ? (
              <span className="inline-flex items-center gap-0.5 font-medium text-sla-ok">
                <BadgeCheckIcon className="size-3" aria-hidden="true" />
                {t('conversation.official')}
              </span>
            ) : null}
          </div>
        ) : null}
        <div className={cn('flex items-end gap-1', right ? 'flex-row-reverse' : 'flex-row')}>
          <div
            className={cn(
              'rounded-2xl px-3 py-2 text-sm compact:py-1.5',
              mine
                ? 'bg-bubble-mine text-bubble-mine-foreground'
                : staff
                  ? 'bg-secondary text-secondary-foreground'
                  : 'bg-bubble-theirs text-bubble-theirs-foreground',
              right ? (last ? 'rounded-br-md' : '') : last ? 'rounded-bl-md' : '',
            )}
          >
            {message.reply_to_body ? (
              <div className="mb-1.5 border-l-2 border-current/40 pl-2 text-xs opacity-80">
                <div className="font-semibold">{message.reply_to_sender_username ?? ''}</div>
                <div className="line-clamp-2">{message.reply_to_body}</div>
              </div>
            ) : null}
            {message.attachments.length > 0 ? (
              <div
                className={cn(
                  'mb-1 grid gap-1',
                  message.attachments.length > 1 ? 'grid-cols-2' : 'grid-cols-1',
                )}
              >
                {message.attachments.map((attachment) => (
                  <AttachmentImage
                    key={attachment.path}
                    attachment={attachment}
                    compact={message.attachments.length > 1}
                  />
                ))}
              </div>
            ) : null}
            {card ? (
              <div className="flex min-w-48 items-center gap-2 rounded-lg bg-card/90 p-2 text-card-foreground">
                {card.card === 'cash_transaction' ? (
                  <WalletIcon className="size-5 text-primary" />
                ) : (
                  <FileTextIcon className="size-5 text-primary" />
                )}
                <div className="min-w-0 flex-1">
                  <div className="text-xs text-muted-foreground">
                    {card.card === 'cash_transaction'
                      ? t('conversation.cardCash')
                      : t('conversation.cardOrder')}
                  </div>
                  <div className="tabular truncate font-semibold">{card.ref}</div>
                </div>
                {onOpenCard ? (
                  <Button size="xs" variant="outline" onClick={() => onOpenCard(card)}>
                    {t('conversation.openCard')}
                  </Button>
                ) : null}
              </div>
            ) : message.is_deleted ? (
              <p className="italic opacity-70">{t('conversation.deleted')}</p>
            ) : message.body ? (
              <p className="break-words whitespace-pre-wrap">{message.body}</p>
            ) : null}
            {url ? <SafeLink url={url} title={message.body} trusted={trustedHost} /> : null}
            {options.length > 0 ? (
              <div className="mt-1.5 flex flex-wrap gap-1" aria-label={t('conversation.quickOptions')}>
                {options.map((option) => (
                  <span key={option} className="rounded-full border border-current/30 px-2 py-0.5 text-xs">
                    {option}
                  </span>
                ))}
              </div>
            ) : null}
            {masked.length > 0 ? (
              <p className="mt-1 text-[11px] opacity-75">
                {t('conversation.masked', { fields: masked.join(', ') })}
              </p>
            ) : null}
            <div
              className={cn(
                'tabular mt-0.5 flex items-center gap-1 text-[10px] opacity-70',
                right ? 'justify-end' : '',
              )}
            >
              {clock(message.created_at)}
              {staff ? (
                <Tooltip content={read ? t('conversation.read') : t('conversation.sent')}>
                  <span aria-label={read ? t('conversation.read') : t('conversation.sent')}>
                    {read ? <CheckCheckIcon className="size-3.5" /> : <CheckIcon className="size-3.5" />}
                  </span>
                </Tooltip>
              ) : null}
            </div>
          </div>
          {onReply ? (
            <Button
              variant="ghost"
              size="icon-xs"
              className="opacity-0 transition-opacity group-hover:opacity-100 focus-visible:opacity-100"
              aria-label={t('conversation.replyTo')}
              onClick={() => onReply(message)}
            >
              <ReplyIcon />
            </Button>
          ) : null}
        </div>
      </div>
    </div>
  )
})

export function PendingBubble({
  pending,
  onResend,
  onDiscard,
}: {
  pending: PendingMessage
  onResend: () => void
  onDiscard: () => void
}) {
  const { t } = useTranslation()
  const failed = pending.status === 'failed'
  return (
    <div className="mt-0.5 flex justify-end px-4 compact:px-3">
      <div className="flex max-w-[78%] flex-col items-end">
        <div
          className={cn(
            'rounded-2xl rounded-br-md px-3 py-2 text-sm',
            failed
              ? 'border border-destructive/40 bg-destructive/10 text-foreground'
              : 'bg-bubble-mine/70 text-bubble-mine-foreground',
          )}
        >
          {pending.files.length > 0 ? (
            <div className="mb-1 grid grid-cols-2 gap-1">
              {pending.files.map((file) => (
                <img
                  key={file.id}
                  src={file.preview}
                  alt={file.file.name}
                  className="h-20 w-28 rounded-md object-cover"
                />
              ))}
            </div>
          ) : null}
          {pending.body ? <p className="break-words whitespace-pre-wrap">{pending.body}</p> : null}
        </div>
        <div className="mt-0.5 flex items-center gap-2 text-[11px] text-muted-foreground" aria-live="polite">
          {failed ? (
            <>
              <span className="inline-flex items-center gap-1 text-destructive">
                <AlertCircleIcon className="size-3.5" />
                {t('conversation.failed')}
              </span>
              <Button size="xs" variant="link" className="h-auto px-0" onClick={onResend}>
                {t('conversation.resend')}
              </Button>
              <Button
                size="xs"
                variant="link"
                className="h-auto px-0 text-muted-foreground"
                onClick={onDiscard}
              >
                {t('conversation.discard')}
              </Button>
            </>
          ) : (
            <span className="inline-flex items-center gap-1">
              <LoaderCircleIcon className="size-3 animate-spin" />
              {t('conversation.sending')}
            </span>
          )}
        </div>
      </div>
    </div>
  )
}
