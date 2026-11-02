import { EyeIcon, LoaderCircleIcon } from 'lucide-react'
import { useCallback, useMemo, useState } from 'react'
import { Trans, useTranslation } from 'react-i18next'

import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/primitives'
import { useAgent } from '@/features/auth/hooks'
import { useCommandHandler } from '@/features/command/bus'
import { useNotes } from '@/features/customer/hooks'
import { GoOnlineButton } from '@/features/presence/components/go-online-button'
import { useActionGuard, useClaimGate } from '@/features/presence/hooks'
import { isSuperAdmin, worksTickets } from '@/features/presence/types'
import { ticketsApi } from '@/features/tickets/api'
import {
  useClaimTicket,
  useTicketAction,
  useTicketDetail,
  useTicketLists,
  useTicketUi,
  useTopics,
} from '@/features/tickets/hooks'
import { newerActiveTicket } from '@/features/tickets/logic'
import { emptyLists, type Ticket } from '@/features/tickets/types'

import { latestCustomerMessage } from '../cache'
import { useMarkRead, useMembers, useMessages, usePending, useRoom, useSendMessage } from '../hooks'
import type { ChatMessage, PendingMessage } from '../types'
import { ActionDialog, type TicketAction } from './action-dialogs'
import { Composer } from './composer'
import { ConversationHeader } from './conversation-header'
import { MessageList } from './message-list'

const barClass = 'flex min-h-12 shrink-0 items-center gap-3 border-t bg-subtle px-(--pane-px) py-2'

function StatusNote({ ticket }: { ticket: Ticket }) {
  const { t } = useTranslation()
  if (ticket.status === 'resolved') return t('conversation.resolvedNote')
  if (ticket.status === 'closed') return t('conversation.closedNote')
  return (
    <Trans
      i18nKey="conversation.handledByOther"
      values={{ name: ticket.owner?.display_name ?? '' }}
      components={{ strong: <strong className="font-medium text-foreground" /> }}
    />
  )
}

function NewerTicketBar({ ticket, newer }: { ticket: Ticket; newer: Ticket }) {
  const { t } = useTranslation()
  return (
    <div className={barClass} role="status">
      <p className="min-w-0 flex-1 text-row text-muted-foreground">
        {t(
          ticket.status === 'resolved' ? 'conversation.newerAfterResolved' : 'conversation.newerAfterClosed',
          {
            number: newer.ticket_number,
          },
        )}
      </p>
      <Button size="sm" variant="outline" onClick={() => useTicketUi.getState().select(newer.id)}>
        {t('conversation.openActiveTicket')}
      </Button>
    </div>
  )
}

export function ReadOnlyBar({ ticket }: { ticket: Ticket }) {
  const { t } = useTranslation()
  const gate = useClaimGate()
  const guard = useActionGuard()
  const claim = useClaimTicket()
  const lists = useTicketLists()
  const newer = newerActiveTicket(lists.data ?? emptyLists, ticket)
  if (newer) return <NewerTicketBar ticket={ticket} newer={newer} />
  return (
    <div className={barClass} role="status">
      <p className="min-w-0 flex-1 text-row text-muted-foreground">
        {ticket.status === 'open' ? (
          (gate.reason ?? t('conversation.readOnlyPreview'))
        ) : (
          <StatusNote ticket={ticket} />
        )}
      </p>
      {ticket.status === 'open' ? (
        <>
          {gate.needsOnline ? <GoOnlineButton /> : null}
          <Button
            size="sm"
            disabled={claim.isPending}
            data-blocked={!gate.canClaim || undefined}
            className="data-[blocked=true]:opacity-60"
            onClick={() => {
              if (guard('claim')) claim.mutate(ticket.id)
            }}
          >
            {claim.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
            {t('tickets.claimTicket')}
          </Button>
        </>
      ) : null}
    </div>
  )
}

export function MonitorBar({ ticket }: { ticket: Ticket }) {
  const { t } = useTranslation()
  return (
    <div className={barClass} role="status">
      <EyeIcon className="size-4 shrink-0 text-muted-foreground" />
      <p className="min-w-0 flex-1 text-row text-muted-foreground">
        <span className="font-medium text-foreground">{t('presence.monitorMode')}</span>
        {' · '}
        {ticket.status === 'open' ? t('conversation.monitorUnclaimed') : <StatusNote ticket={ticket} />}
      </p>
    </div>
  )
}

function Conversation({
  ticket,
  infoOpen,
  onToggleInfo,
  onBack,
}: {
  ticket: Ticket
  infoOpen: boolean
  onToggleInfo: () => void
  onBack?: () => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const worker = worksTickets(agent)
  const superAdmin = isSuperAdmin(agent)
  const me = useMemo(
    () => ({ id: agent.id, username: agent.agent_code, displayName: agent.display_name }),
    [agent.id, agent.agent_code, agent.display_name],
  )
  const room = useRoom(ticket, me)
  const messages = useMessages(ticket.room_id)
  const members = useMembers(ticket.room_id)
  const notes = useNotes(ticket.customer?.id)
  const ticketNotes = useMemo(
    () => (notes.data ?? []).filter((note) => note.ticket_id === ticket.id),
    [notes.data, ticket.id],
  )
  const pendingAll = usePending((state) => state.items)
  const pending = useMemo(
    () => pendingAll.filter((item) => item.roomId === ticket.room_id),
    [pendingAll, ticket.room_id],
  )
  const { send, resend } = useSendMessage(ticket, agent.id)
  const topics = useTopics()
  const [replyTo, setReplyTo] = useState<ChatMessage | null>(null)
  const [action, setAction] = useState<TicketAction | null>(null)

  const active = ticket.status === 'claimed' || ticket.status === 'waiting_customer'
  const owner = worker && active && ticket.owner?.id === agent.id
  const customer = (members.data ?? []).find((member) => member.user_id === ticket.customer?.id)
  const latest = latestCustomerMessage(messages.messages)
  useMarkRead(ticket.room_id, owner, latest?.created_at)

  const trustedHosts = useMemo(() => {
    const hosts = new Set<string>()
    for (const topic of topics.data ?? []) {
      try {
        if (topic.help_url) hosts.add(new URL(topic.help_url).host)
      } catch {
        continue
      }
    }
    return hosts
  }, [topics.data])
  const trustedHost = useCallback((host: string) => trustedHosts.has(host), [trustedHosts])

  const ticketId = () => ticket.id
  const wait = useTicketAction(() => ticketsApi.waitCustomer(ticket), {
    ticketId,
    success: t('conversation.waitingSet'),
  })
  const release = useTicketAction((reason: string) => ticketsApi.release(ticket, reason), {
    ticketId,
    success: t('conversation.released'),
  })
  const transfer = useTicketAction(
    ({ agentId, note }: { agentId: string; name: string; note: string }) =>
      ticketsApi.requestTransfer(ticket, agentId, note),
    { ticketId, success: ({ name }) => t('conversation.transferSent', { name }) },
  )
  const resolve = useTicketAction(
    ({ outcome, summary }: { outcome: string; summary: string }) =>
      ticketsApi.resolve(ticket, outcome, summary),
    { ticketId, success: t('conversation.resolved') },
  )
  const priority = useTicketAction((value: string) => ticketsApi.setPriority(ticket, value), {
    ticketId,
    success: (value) => t('conversation.priorityChanged', { priority: value }),
  })
  const reassign = useTicketAction(
    ({ agentId, reason }: { agentId: string; name: string; reason: string }) =>
      ticketsApi.reassign(ticket.id, agentId, reason),
    { ticketId, success: ({ name }) => t('conversation.reassigned', { name }) },
  )
  const busy = [wait, release, transfer, resolve, priority, reassign].some((mutation) => mutation.isPending)

  useCommandHandler(
    'resolve',
    useMemo(() => (owner ? () => setAction('resolve') : null), [owner]),
  )
  useCommandHandler(
    'release',
    useMemo(() => (owner ? () => setAction('release') : null), [owner]),
  )
  useCommandHandler(
    'transfer',
    useMemo(() => (owner ? () => setAction('transfer') : null), [owner]),
  )
  useCommandHandler(
    'waitCustomer',
    useMemo(() => (owner ? () => wait.mutate(undefined) : null), [owner, wait]),
  )

  const discard = useCallback((item: PendingMessage) => {
    item.files.forEach((file) => URL.revokeObjectURL(file.preview))
    usePending.getState().remove(item.clientId)
  }, [])

  return (
    <div className="flex h-full flex-col bg-background">
      <ConversationHeader
        ticket={ticket}
        meId={agent.id}
        owner={owner}
        superAdmin={superAdmin}
        customerOnline={room.customerOnline}
        infoOpen={infoOpen}
        busy={busy}
        onToggleInfo={onToggleInfo}
        onBack={onBack}
        onAction={setAction}
        onWait={() => wait.mutate(undefined)}
        onPriority={(value) => priority.mutate(value)}
      />
      {messages.isPending ? (
        <div className="flex flex-1 flex-col gap-3 p-(--pane-px)" aria-busy="true">
          <Skeleton className="h-8 w-2/3 rounded-xl" />
          <Skeleton className="ml-auto h-8 w-1/2 rounded-xl" />
          <Skeleton className="h-8 w-3/5 rounded-xl" />
        </div>
      ) : messages.isError ? (
        <ErrorState className="flex-1" error={messages.error} onRetry={() => void messages.refetch()} />
      ) : (
        <MessageList
          messages={messages.messages}
          notes={ticketNotes}
          pending={pending}
          meId={agent.id}
          customerReadAt={customer?.last_read_at ?? null}
          hasOlder={messages.hasNextPage}
          loadingOlder={messages.isFetchingNextPage}
          onLoadOlder={() => void messages.fetchNextPage()}
          trustedHost={trustedHost}
          onReply={owner ? setReplyTo : undefined}
          onResend={(item) => void resend(item).catch(() => undefined)}
          onDiscard={discard}
        />
      )}
      <div className="min-h-5 px-(--pane-px) pb-1 text-xs text-muted-foreground" aria-live="polite">
        {room.typing ? t('conversation.typing', { name: room.typing }) : null}
      </div>
      {owner ? (
        <Composer
          ticket={ticket}
          agent={agent}
          replyTo={replyTo}
          onCancelReply={() => setReplyTo(null)}
          send={send}
          onTyping={room.sendTyping}
          onStopTyping={room.stopTyping}
        />
      ) : worker ? (
        <ReadOnlyBar ticket={ticket} />
      ) : (
        <MonitorBar ticket={ticket} />
      )}
      <ActionDialog
        action={action}
        onClose={() => setAction(null)}
        submit={{
          release: (reason) => release.mutateAsync(reason),
          transfer: (agentId, name, note) => transfer.mutateAsync({ agentId, name, note }),
          resolve: (outcome, summary) => resolve.mutateAsync({ outcome, summary }),
          reassign: (agentId, name, reason) => reassign.mutateAsync({ agentId, name, reason }),
        }}
      />
    </div>
  )
}

export function ConversationPane({
  ticketId,
  infoOpen,
  onToggleInfo,
  onBack,
}: {
  ticketId: string
  infoOpen: boolean
  onToggleInfo: () => void
  onBack?: () => void
}) {
  const detail = useTicketDetail(ticketId)
  if (detail.isPending) {
    return (
      <div className="flex h-full flex-col gap-2 p-(--pane-px)" aria-busy="true">
        <Skeleton className="h-3 w-1/4" />
        <Skeleton className="h-2.5 w-2/5" />
      </div>
    )
  }
  if (detail.isError)
    return <ErrorState className="h-full" error={detail.error} onRetry={() => void detail.refetch()} />
  return <Conversation ticket={detail.data} infoOpen={infoOpen} onToggleInfo={onToggleInfo} onBack={onBack} />
}
