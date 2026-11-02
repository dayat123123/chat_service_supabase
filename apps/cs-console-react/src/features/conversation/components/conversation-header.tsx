import { ArrowLeftIcon, EllipsisIcon, PanelRightCloseIcon, PanelRightOpenIcon } from 'lucide-react'
import { useCallback, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Dot, FlagText, PriorityText } from '@/components/badges'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
  DropdownMenuTrigger,
  Tooltip,
} from '@/components/ui/menu'
import { useTopicName } from '@/features/tickets/hooks'
import { customerName, ticketPriorities, type Ticket } from '@/features/tickets/types'
import { useNow } from '@/hooks/use-now'
import { minutesSince, stamp, waitLabel } from '@/lib/time'

import type { TicketAction } from './action-dialogs'

const WIDE_HEADER = 720

function useWide() {
  const [wide, setWide] = useState(true)
  const ref = useCallback((node: HTMLElement | null) => {
    if (!node) return
    const observer = new ResizeObserver(([entry]) => setWide((entry?.contentRect.width ?? 0) >= WIDE_HEADER))
    observer.observe(node)
    return () => observer.disconnect()
  }, [])
  return [wide, ref] as const
}

type Props = {
  ticket: Ticket
  meId: string
  owner: boolean
  superAdmin: boolean
  customerOnline: boolean
  infoOpen: boolean
  busy: boolean
  onToggleInfo: () => void
  onBack?: () => void
  onAction: (action: TicketAction) => void
  onWait: () => void
  onPriority: (priority: string) => void
}

export function ConversationHeader({
  ticket,
  meId,
  owner,
  superAdmin,
  customerOnline,
  infoOpen,
  busy,
  onToggleInfo,
  onBack,
  onAction,
  onWait,
  onPriority,
}: Props) {
  const { t } = useTranslation()
  const topicName = useTopicName()
  const now = useNow(30_000)
  const [wide, headerRef] = useWide()
  const active = ticket.status === 'claimed' || ticket.status === 'waiting_customer'
  const canChangePriority = active && (owner || superAdmin)
  const canReassign = superAdmin && !owner && (active || ticket.status === 'open')
  const ownerName = ticket.owner
    ? ticket.owner.id === meId
      ? t('app.you')
      : ticket.owner.display_name
    : null
  const started = ticket.claimed_at ?? ticket.created_at
  const meta = [
    topicName(ticket.topic),
    <PriorityText key="priority" priority={ticket.priority} />,
    ...ticket.flags.map((flag) => <FlagText key={flag} flag={flag} />),
    ownerName ? t('conversation.owner', { name: ownerName }) : null,
    ticket.status === 'waiting_customer' ? t('tickets.status.waiting_customer') : null,
    active && started ? (
      <span key="duration" className="tabular">
        {waitLabel(minutesSince(started, now))}
      </span>
    ) : null,
    ticket.complaint_due_at ? (
      <span key="due" className="text-info">
        {t('conversation.complaintDue', { time: stamp(ticket.complaint_due_at) })}
      </span>
    ) : null,
  ].filter(Boolean)
  return (
    <header
      ref={headerRef}
      className="flex shrink-0 items-center gap-3 border-b bg-background px-(--pane-px) py-2.5 compact:py-2"
    >
      {onBack ? (
        <Button variant="ghost" size="icon-sm" aria-label={t('tickets.list')} onClick={onBack}>
          <ArrowLeftIcon />
        </Button>
      ) : null}
      <div className="min-w-0 flex-1">
        <div className="flex min-w-0 items-baseline gap-2">
          <h2 className="truncate text-panel font-medium">{customerName(ticket)}</h2>
          <span className="shrink-0 font-mono text-xs text-muted-foreground select-all">
            {ticket.ticket_number}
          </span>
          <span className="inline-flex shrink-0 items-center self-center">
            <Dot tone={customerOnline ? 'ok' : 'neutral'} />
            <span className="sr-only">
              {customerOnline ? t('conversation.customerOnline') : t('conversation.customerAway')}
            </span>
          </span>
        </div>
        <p className="mt-0.5 truncate text-xs text-muted-foreground">
          {meta.map((item, index) => (
            <span key={index}>
              {index > 0 ? ' · ' : null}
              {item}
            </span>
          ))}
        </p>
      </div>
      <div className="flex shrink-0 items-center gap-1.5">
        {owner ? (
          <>
            {wide ? (
              <Button
                size="sm"
                variant="outline"
                disabled={busy || ticket.status === 'waiting_customer'}
                onClick={onWait}
              >
                {t('conversation.waitCustomer')}
              </Button>
            ) : null}
            <Button size="sm" variant="outline" disabled={busy} onClick={() => onAction('release')}>
              {t('conversation.release')}
            </Button>
            <Button
              size="sm"
              variant="outline"
              disabled={busy || ticket.transfer !== null}
              onClick={() => onAction('transfer')}
            >
              {t('conversation.transfer')}
            </Button>
            <Tooltip content={t('conversation.resolveHint')}>
              <Button size="sm" disabled={busy} onClick={() => onAction('resolve')}>
                {t('conversation.resolve')}
              </Button>
            </Tooltip>
          </>
        ) : null}
        {canReassign ? (
          <Button size="sm" variant="outline" disabled={busy} onClick={() => onAction('reassign')}>
            {t('conversation.reassign')}
          </Button>
        ) : null}
        {canChangePriority || owner ? (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon-sm" aria-label={t('conversation.moreActions')}>
                <EllipsisIcon />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-52">
              {owner && !wide ? (
                <DropdownMenuItem disabled={busy || ticket.status === 'waiting_customer'} onSelect={onWait}>
                  {t('conversation.waitCustomer')}
                </DropdownMenuItem>
              ) : null}
              {canChangePriority ? (
                <DropdownMenuSub>
                  <DropdownMenuSubTrigger>{t('conversation.changePriority')}</DropdownMenuSubTrigger>
                  <DropdownMenuSubContent>
                    <DropdownMenuRadioGroup value={ticket.priority} onValueChange={onPriority}>
                      {ticketPriorities.map((priority) => (
                        <DropdownMenuRadioItem key={priority} value={priority}>
                          {priority}
                        </DropdownMenuRadioItem>
                      ))}
                    </DropdownMenuRadioGroup>
                  </DropdownMenuSubContent>
                </DropdownMenuSub>
              ) : null}
            </DropdownMenuContent>
          </DropdownMenu>
        ) : null}
        <Tooltip content={infoOpen ? t('customer.collapse') : t('customer.expand')}>
          <Button
            variant="ghost"
            size="icon-sm"
            aria-label={infoOpen ? t('customer.collapse') : t('customer.expand')}
            onClick={onToggleInfo}
          >
            {infoOpen ? <PanelRightCloseIcon /> : <PanelRightOpenIcon />}
          </Button>
        </Tooltip>
      </div>
    </header>
  )
}
