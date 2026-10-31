import { LoaderCircleIcon } from 'lucide-react'
import { memo } from 'react'
import { useTranslation } from 'react-i18next'

import { Dot, FlagText, PriorityText, UnreadBadge } from '@/components/badges'
import { Button } from '@/components/ui/button'
import { waitTone } from '@/lib/sla'
import { clock, minutesSince, waitLabel } from '@/lib/time'
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

export const TicketRow = memo(function TicketRow({
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
  const done = ticket.status === 'resolved' || ticket.status === 'closed'
  const since = ticket.waiting_since ?? ticket.queued_at
  const waited = since && !done ? minutesSince(since, now) : null
  const finishedAt = ticket.resolved_at ?? ticket.closed_at
  const leaving = leavingName !== undefined
  const note = leaving
    ? t('tickets.claimedBy', { name: leavingName })
    : ticket.status === 'open' && ticket.returned_reason
      ? t('tickets.returned', { reason: ticket.returned_reason })
      : null
  return (
    <div
      data-ticket-id={ticket.id}
      className={cn(
        'group relative border-b px-3 py-(--row-py) transition-colors',
        selected ? 'bg-selected' : 'hover:bg-muted',
        leaving && 'pointer-events-none animate-leave overflow-hidden',
      )}
    >
      {selected ? (
        <span aria-hidden="true" className="absolute inset-y-0 left-0 w-0.5 bg-foreground" />
      ) : null}
      <button
        type="button"
        onClick={onSelect}
        aria-current={selected ? 'true' : undefined}
        aria-label={`${ticket.ticket_number} · ${name} · ${topicName}`}
        className="absolute inset-0 z-0 outline-none focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset"
      />
      <div className="pointer-events-none relative flex items-center gap-2">
        <Dot tone={waited === null ? 'neutral' : waitTone(waited, warn, late)} />
        <span className="min-w-0 flex-1 truncate text-row font-medium">{name}</span>
        <span className="tabular shrink-0 text-xs text-muted-foreground">
          {waited !== null ? waitLabel(waited) : finishedAt ? clock(finishedAt) : ''}
        </span>
      </div>
      <p className="pointer-events-none relative mt-0.5 truncate pl-4 text-xs text-muted-foreground">
        {topicName}
        {' · '}
        <PriorityText priority={ticket.priority} />
        {ticket.flags.map((flag) => (
          <span key={flag}>
            {' · '}
            <FlagText flag={flag} />
          </span>
        ))}
        {showOwner && ticket.owner
          ? ` · ${t('tickets.handledBy', {
              name: ticket.owner.id === meId ? t('app.you') : ticket.owner.display_name,
            })}`
          : null}
      </p>
      <div className="pointer-events-none relative mt-0.5 flex items-center gap-2 pl-4">
        <p
          className={cn(
            'min-w-0 flex-1 truncate text-xs',
            note ? 'font-medium text-foreground' : 'text-muted-foreground',
          )}
        >
          {note ?? ticket.preview ?? ''}
        </p>
        {ticket.unread_count > 0 ? (
          <UnreadBadge
            count={ticket.unread_count}
            label={t('tickets.unread', { count: ticket.unread_count })}
          />
        ) : null}
      </div>
      {claim ? (
        <Button
          size="xs"
          variant="outline"
          className={cn(
            'pointer-events-auto absolute top-[calc(var(--row-py)-0.25rem)] right-3 z-10 opacity-0 group-focus-within:opacity-100 group-hover:opacity-100 focus-visible:opacity-100 pointer-coarse:opacity-100',
            selected && 'opacity-100',
          )}
          disabled={claim.disabled || claim.pending}
          onClick={claim.onClaim}
          aria-label={`${t('tickets.claim')} ${ticket.ticket_number}`}
        >
          {claim.pending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {claim.pending ? t('tickets.claiming') : t('tickets.claim')}
        </Button>
      ) : null}
    </div>
  )
})
