import { LoaderCircleIcon, Undo2Icon } from 'lucide-react'
import { memo } from 'react'
import { useTranslation } from 'react-i18next'

import { FlagBadge, PriorityBadge, WaitBadge } from '@/components/badges'
import { Button } from '@/components/ui/button'
import { Avatar } from '@/components/ui/primitives'
import { minutesSince } from '@/lib/time'
import { cn } from '@/lib/utils'

import { customerName, type Ticket } from '../types'

type Props = {
  ticket: Ticket
  topicName: string
  selected: boolean
  now: Date
  warn: number
  late: number
  meId: string
  showOwner: boolean
  leavingName?: string
  claim?: { disabled: boolean; pending: boolean; onClaim: () => void }
  onSelect: () => void
}

export const TicketCard = memo(function TicketCard({
  ticket,
  topicName,
  selected,
  now,
  warn,
  late,
  meId,
  showOwner,
  leavingName,
  claim,
  onSelect,
}: Props) {
  const { t } = useTranslation()
  const name = customerName(ticket)
  const since = ticket.waiting_since ?? ticket.queued_at
  const waited =
    since && ticket.status !== 'resolved' && ticket.status !== 'closed' ? minutesSince(since, now) : null
  const leaving = leavingName !== undefined
  return (
    <div
      data-ticket-id={ticket.id}
      className={cn(
        'relative border-b border-l-[3px] px-3 py-2.5 transition-[background-color,opacity] compact:py-1.5',
        selected ? 'border-l-primary bg-accent/70' : 'border-l-transparent hover:bg-muted/50',
        ticket.priority === 'P1' && !selected && 'border-l-p1/70',
        leaving && 'pointer-events-none animate-out opacity-50 duration-1000 fade-out-0 fill-mode-forwards',
      )}
    >
      <button
        type="button"
        onClick={onSelect}
        aria-current={selected ? 'true' : undefined}
        aria-label={`${ticket.ticket_number} · ${name} · ${topicName}`}
        className="absolute inset-0 z-0 outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-inset"
      />
      <div className="pointer-events-none relative flex items-center gap-2">
        <Avatar name={name || '?'} className="size-7 text-[11px]" />
        <p className="min-w-0 flex-1 truncate text-sm">
          <span className="font-semibold">{name}</span>
          <span className="text-muted-foreground"> · {topicName}</span>
        </p>
        <PriorityBadge priority={ticket.priority} />
      </div>
      {ticket.preview ? (
        <p className="pointer-events-none relative mt-1 line-clamp-2 text-xs text-muted-foreground compact:line-clamp-1">
          “{ticket.preview}”
        </p>
      ) : null}
      {ticket.status === 'open' && ticket.returned_reason ? (
        <p className="pointer-events-none relative mt-1 flex items-center gap-1 text-[11px] font-medium text-sla-warn">
          <Undo2Icon className="size-3" aria-hidden="true" />
          <span className="truncate">{t('tickets.returned', { reason: ticket.returned_reason })}</span>
        </p>
      ) : null}
      <div className="pointer-events-none relative mt-1.5 flex items-center gap-1.5">
        <div className="flex min-w-0 flex-1 flex-wrap items-center gap-1.5">
          <span className="tabular text-[11px] text-muted-foreground">{ticket.ticket_number}</span>
          {waited !== null ? <WaitBadge minutes={waited} warn={warn} late={late} label={undefined} /> : null}
          {ticket.flags.map((flag) => (
            <FlagBadge key={flag} flag={flag} />
          ))}
          {showOwner && ticket.owner ? (
            <span className="truncate text-[11px] text-muted-foreground">
              {t('tickets.handledBy', {
                name: ticket.owner.id === meId ? t('app.you') : ticket.owner.display_name,
              })}
            </span>
          ) : null}
          {leaving ? (
            <span className="rounded bg-foreground/80 px-1.5 text-[11px] font-medium text-background">
              {t('tickets.claimedBy', { name: leavingName })}
            </span>
          ) : null}
        </div>
        {ticket.unread_count > 0 ? (
          <span
            className="tabular inline-flex min-w-5 items-center justify-center rounded-full bg-destructive px-1.5 text-[11px] font-bold text-destructive-foreground"
            aria-label={t('tickets.unread', { count: ticket.unread_count })}
          >
            {ticket.unread_count}
          </span>
        ) : null}
        {claim ? (
          <Button
            size="xs"
            className="pointer-events-auto relative z-10"
            disabled={claim.disabled || claim.pending}
            onClick={claim.onClaim}
            aria-label={`${t('tickets.claim')} ${ticket.ticket_number}`}
          >
            {claim.pending ? <LoaderCircleIcon className="animate-spin" /> : null}
            {claim.pending ? t('tickets.claiming') : t('tickets.claim')}
          </Button>
        ) : null}
      </div>
    </div>
  )
})
