import {
  ArrowLeftIcon,
  ChevronDownIcon,
  ClockIcon,
  MoveRightIcon,
  PanelRightCloseIcon,
  PanelRightOpenIcon,
  SquareCheckBigIcon,
  Undo2Icon,
  UserPlusIcon,
  ArrowRightLeftIcon,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { FlagBadge, PriorityBadge, TicketStatusBadge } from '@/components/badges'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger,
  Tooltip,
} from '@/components/ui/menu'
import { Kbd } from '@/components/ui/primitives'
import { useTopicName } from '@/features/tickets/hooks'
import { customerName, ticketPriorities, type Ticket } from '@/features/tickets/types'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import type { TicketAction } from './action-dialogs'

type Props = {
  ticket: Ticket
  meId: string
  owner: boolean
  supervisor: boolean
  joined: boolean
  customerOnline: boolean
  infoOpen: boolean
  busy: boolean
  onToggleInfo: () => void
  onBack?: () => void
  onAction: (action: TicketAction) => void
  onWait: () => void
  onJoin: () => void
  onPriority: (priority: string) => void
}

export function ConversationHeader({
  ticket,
  meId,
  owner,
  supervisor,
  joined,
  customerOnline,
  infoOpen,
  busy,
  onToggleInfo,
  onBack,
  onAction,
  onWait,
  onJoin,
  onPriority,
}: Props) {
  const { t } = useTranslation()
  const topicName = useTopicName()
  const active = ticket.status === 'claimed' || ticket.status === 'waiting_customer'
  const canChangePriority = active && (owner || supervisor)
  const ownerName = ticket.owner
    ? ticket.owner.id === meId
      ? t('app.you')
      : ticket.owner.display_name
    : null
  return (
    <header className="flex flex-col gap-2 border-b bg-card px-4 py-3 compact:py-2">
      <div className="flex items-start gap-2">
        {onBack ? (
          <Button variant="ghost" size="icon-sm" aria-label={t('tickets.list')} onClick={onBack}>
            <ArrowLeftIcon />
          </Button>
        ) : null}
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-1.5">
            <h2 className="tabular text-base font-semibold select-all">#{ticket.ticket_number}</h2>
            <span className="text-sm text-muted-foreground">· {topicName(ticket.topic)}</span>
            {canChangePriority ? (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <button
                    type="button"
                    aria-label={t('conversation.changePriority')}
                    className="inline-flex items-center rounded-md outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50"
                  >
                    <PriorityBadge priority={ticket.priority} />
                    <ChevronDownIcon className="size-3.5 text-muted-foreground" />
                  </button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="start" className="min-w-24">
                  <DropdownMenuRadioGroup value={ticket.priority} onValueChange={onPriority}>
                    {ticketPriorities.map((priority) => (
                      <DropdownMenuRadioItem key={priority} value={priority}>
                        {priority}
                      </DropdownMenuRadioItem>
                    ))}
                  </DropdownMenuRadioGroup>
                </DropdownMenuContent>
              </DropdownMenu>
            ) : (
              <PriorityBadge priority={ticket.priority} />
            )}
            <TicketStatusBadge status={ticket.status} />
            {ticket.flags.map((flag) => (
              <FlagBadge key={flag} flag={flag} />
            ))}
          </div>
          <p className="mt-0.5 flex flex-wrap items-center gap-x-2 text-xs text-muted-foreground">
            <span className="inline-flex items-center gap-1 font-medium text-foreground">
              <span
                className={cn(
                  'size-2 rounded-full',
                  customerOnline ? 'bg-status-online' : 'bg-status-offline',
                )}
                aria-hidden="true"
              />
              {customerName(ticket)}
              <span className="sr-only">
                {customerOnline ? t('conversation.customerOnline') : t('conversation.customerAway')}
              </span>
            </span>
            {ownerName ? <span>· {t('conversation.owner', { name: ownerName })}</span> : null}
            {ticket.created_at ? (
              <span>· {t('conversation.createdAt', { time: stamp(ticket.created_at) })}</span>
            ) : null}
            {ticket.complaint_due_at ? (
              <span className="text-flag-complaint">
                · {t('conversation.complaintDue', { time: stamp(ticket.complaint_due_at) })}
              </span>
            ) : null}
          </p>
        </div>
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
      {owner || (supervisor && active) ? (
        <div className="flex flex-wrap items-center gap-1.5">
          {owner ? (
            <>
              <Button
                size="xs"
                variant="outline"
                disabled={busy || ticket.status === 'waiting_customer'}
                onClick={onWait}
              >
                <ClockIcon />
                {t('conversation.waitCustomer')}
              </Button>
              <Button size="xs" variant="outline" disabled={busy} onClick={() => onAction('release')}>
                <Undo2Icon />
                {t('conversation.release')}
              </Button>
              <Button
                size="xs"
                variant="outline"
                disabled={busy || ticket.transfer !== null}
                onClick={() => onAction('transfer')}
              >
                <ArrowRightLeftIcon />
                {t('conversation.transfer')}
              </Button>
              <Button size="xs" disabled={busy} onClick={() => onAction('resolve')}>
                <SquareCheckBigIcon />
                {t('conversation.resolve')}
                <Kbd className="ml-1 h-4 bg-primary-foreground/20 text-primary-foreground">E</Kbd>
              </Button>
            </>
          ) : null}
          {supervisor && !owner ? (
            <>
              {!joined ? (
                <Button size="xs" variant="outline" disabled={busy} onClick={onJoin}>
                  <UserPlusIcon />
                  {t('conversation.join')}
                </Button>
              ) : null}
              <Button size="xs" variant="outline" disabled={busy} onClick={() => onAction('reassign')}>
                <MoveRightIcon />
                {t('conversation.reassign')}
              </Button>
            </>
          ) : null}
        </div>
      ) : null}
    </header>
  )
}
