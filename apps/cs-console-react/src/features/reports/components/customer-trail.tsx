import { useTranslation } from 'react-i18next'

import { PriorityText, TicketStatusText } from '@/components/badges'
import { MetricStrip } from '@/components/metric-strip'
import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/controls'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { detailsText, isKnownEvent } from '@/features/compliance/logic'
import { format, formatNumber, formatRating, minutesLabel } from '@/lib/time'

import { useCustomerTrail } from '../hooks'
import { rangeLabel } from '../range'
import { closeReason, customerLabel, readableEventData, trailSummary } from '../trail'
import type { CustomerReport, DateRange, TrailEvent, TrailTicket } from '../types'

const actorTypes = ['customer', 'agent', 'service', 'system']

const fullStamp = (value: string) => `${format(value, 'd MMM yyyy, HH.mm')} WIB`

function Fact({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col gap-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="tabular text-row">{children}</dd>
    </div>
  )
}

function EventRow({ event }: { event: TrailEvent }) {
  const { t } = useTranslation()
  const actor =
    event.actor_name ??
    (event.actor_type && actorTypes.includes(event.actor_type)
      ? t(`compliance.actorTypes.${event.actor_type as 'system'}`)
      : event.actor_type)
  const reason =
    event.type === 'closed'
      ? closeReason(typeof event.data.reason === 'string' ? event.data.reason : null)
      : null
  const details = reason
    ? t(`reports.closeReasons.${reason}`)
    : detailsText(readableEventData(event.data), (value) => fullStamp(value))
  return (
    <li className="flex gap-3 border-b py-2 last:border-b-0">
      <span className="tabular w-28 shrink-0 text-xs text-muted-foreground">
        {format(event.created_at, 'd MMM, HH.mm.ss')}
      </span>
      <div className="min-w-0 flex-1">
        <p className="text-row font-medium">
          {isKnownEvent(event.type) ? t(`compliance.events.${event.type}`) : event.type}
        </p>
        {actor || details ? (
          <p className="text-xs break-words text-muted-foreground">
            {[actor, details].filter(Boolean).join(' · ')}
          </p>
        ) : null}
      </div>
    </li>
  )
}

function TicketTrail({ ticket }: { ticket: TrailTicket }) {
  const { t } = useTranslation()
  const reason = closeReason(ticket.close_reason)
  return (
    <AccordionItem value={ticket.id}>
      <AccordionTrigger className="text-row font-normal text-foreground normal-case">
        <span className="flex min-w-0 flex-1 flex-col items-start gap-0.5">
          <span className="flex flex-wrap items-center gap-x-2 gap-y-0.5">
            <span className="font-mono text-xs font-semibold">{ticket.ticket_number}</span>
            <PriorityText priority={ticket.priority} className="text-xs" />
            <TicketStatusText status={ticket.status} />
            {ticket.rating ? (
              <span className="tabular text-xs text-muted-foreground">
                {t('reports.ratingValue', { rating: ticket.rating })}
              </span>
            ) : null}
          </span>
          <span className="text-xs text-muted-foreground">
            {[ticket.topic_name, fullStamp(ticket.created_at), ticket.agent ?? t('reports.noAgent')].join(
              ' · ',
            )}
          </span>
        </span>
      </AccordionTrigger>
      <AccordionContent className="flex flex-col gap-3">
        <dl className="grid grid-cols-2 gap-x-4 gap-y-2.5 sm:grid-cols-3">
          <Fact label={t('reports.untilClaimed')}>{minutesLabel(ticket.claim_minutes)}</Fact>
          <Fact label={t('reports.firstResponse')}>{minutesLabel(ticket.first_response_minutes)}</Fact>
          <Fact label={t('reports.duration')}>{minutesLabel(ticket.resolution_minutes)}</Fact>
          <Fact label={t('reports.rating')}>
            {ticket.rating ? t('reports.ratingValue', { rating: ticket.rating }) : t('reports.notRated')}
          </Fact>
          <Fact label={t('reports.closedAs')}>{reason ? t(`reports.closeReasons.${reason}`) : '–'}</Fact>
          <Fact label={t('reports.reopenedTransfers')}>
            {t('reports.reopenedTransfersValue', { reopened: ticket.reopened, transfers: ticket.transfers })}
          </Fact>
        </dl>
        {ticket.rating_comment ? (
          <blockquote className="border-l-2 pl-3 text-row text-muted-foreground">
            “{ticket.rating_comment}”
          </blockquote>
        ) : null}
        <div>
          <h4 className="text-xs font-medium text-muted-foreground">
            {t('reports.trailEvents', { count: ticket.events.length })}
          </h4>
          <ol className="flex flex-col">
            {ticket.events.map((event, index) => (
              <EventRow key={`${event.created_at}-${index}`} event={event} />
            ))}
          </ol>
        </div>
      </AccordionContent>
    </AccordionItem>
  )
}

function TrailBody({ customer, range }: { customer: CustomerReport; range: DateRange }) {
  const { t } = useTranslation()
  const trail = useCustomerTrail(customer.id, range)
  if (trail.isError) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-2 p-6">
        <ErrorState error={trail.error} onRetry={() => void trail.refetch()} />
      </div>
    )
  }
  if (!trail.data) return <ListSkeleton rows={8} className="pt-10" />
  const tickets = trail.data.tickets
  const summary = trailSummary(tickets)
  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-0.5 border-b px-5 pt-4 pr-12 pb-3">
        <h2 className="text-panel font-semibold">{customerLabel(trail.data.customer)}</h2>
        <p className="text-row text-muted-foreground">
          {trail.data.customer.username ? (
            <span className="font-mono">@{trail.data.customer.username} · </span>
          ) : null}
          {rangeLabel(range)}
        </p>
        <p className="text-xs text-muted-foreground">{t('reports.trailAccessLogged')}</p>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <MetricStrip
          className="border-t-0 md:grid-cols-4 xl:grid-cols-4"
          metrics={[
            {
              label: t('reports.tickets'),
              value: formatNumber(summary.tickets),
              caption: t('reports.closedUnratedCount', { count: summary.closedUnrated }),
            },
            { label: t('reports.firstResponse'), value: minutesLabel(summary.avgFirstResponse) },
            { label: t('reports.duration'), value: minutesLabel(summary.avgResolution) },
            {
              label: t('reports.avgRating'),
              value: summary.avgRating === null ? '–' : `${formatRating(summary.avgRating)}/5`,
              caption: t('reports.ratingCount', { count: summary.ratings }),
            },
          ]}
        />
        {tickets.length === 0 ? (
          <EmptyState title={t('reports.trailEmpty')} />
        ) : (
          <Accordion
            type="multiple"
            defaultValue={tickets.slice(0, 1).map((ticket) => ticket.id)}
            className="px-5"
          >
            {tickets.map((ticket) => (
              <TicketTrail key={ticket.id} ticket={ticket} />
            ))}
          </Accordion>
        )}
      </div>
    </div>
  )
}

export function CustomerTrailSheet({
  customer,
  range,
  onClose,
}: {
  customer: CustomerReport | null
  range: DateRange
  onClose: () => void
}) {
  const { t } = useTranslation()
  return (
    <Sheet open={customer !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('reports.trailTitle')}
        closeLabel={t('app.close')}
        className="w-[min(760px,100vw)] bg-background"
      >
        {customer ? <TrailBody key={customer.id} customer={customer} range={range} /> : null}
      </SheetContent>
    </Sheet>
  )
}
