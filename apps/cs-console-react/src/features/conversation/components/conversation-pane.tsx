import { useQueryClient } from '@tanstack/react-query'
import { LoaderCircleIcon } from 'lucide-react'
import { useCallback, useMemo, useState } from 'react'
import { Trans, useTranslation } from 'react-i18next'

import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/primitives'
import { useAgent } from '@/features/auth/hooks'
import { useCommandHandler } from '@/features/command/bus'
import { CardDetailDialog, type CardRef } from '@/features/customer/components/card-detail-dialog'
import { useNotes } from '@/features/customer/hooks'
import { atCapacity, isSupervisor } from '@/features/presence/types'
import { ticketsApi } from '@/features/tickets/api'
import { useClaimTicket, useTicketAction, useTicketDetail, useTopics } from '@/features/tickets/hooks'
import type { Ticket } from '@/features/tickets/types'

import { latestCustomerMessage } from '../cache'
import {
  conversationKeys,
  useMarkRead,
  useMembers,
  useMessages,
  usePending,
  useRoom,
  useSendMessage,
} from '../hooks'
import type { ChatMessage, PendingMessage } from '../types'
import { ActionDialog, type TicketAction } from './action-dialogs'
import { Composer } from './composer'
import { ConversationHeader } from './conversation-header'
import { MessageList } from './message-list'

function ReadOnlyBar({
  ticket,
  canJoin,
  joining,
  onJoin,
}: {
  ticket: Ticket
  canJoin: boolean
  joining: boolean
  onJoin: () => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const claim = useClaimTicket()
  const canClaim = agent.status === 'online' && !atCapacity(agent)
  const owned = ticket.status === 'claimed' || ticket.status === 'waiting_customer'
  return (
    <div
      className="flex min-h-12 shrink-0 items-center gap-3 border-t bg-subtle px-(--pane-px) py-2"
      role="status"
    >
      <p className="min-w-0 flex-1 text-row text-muted-foreground">
        {ticket.status === 'open' ? (
          t('conversation.readOnlyPreview')
        ) : ticket.status === 'resolved' ? (
          t('conversation.resolvedNote')
        ) : ticket.status === 'closed' ? (
          t('conversation.closedNote')
        ) : (
          <Trans
            i18nKey="conversation.handledByOther"
            values={{ name: ticket.owner?.display_name ?? '' }}
            components={{ strong: <strong className="font-medium text-foreground" /> }}
          />
        )}
      </p>
      {ticket.status === 'open' ? (
        <Button size="sm" disabled={!canClaim || claim.isPending} onClick={() => claim.mutate(ticket.id)}>
          {claim.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('tickets.claimTicket')}
        </Button>
      ) : owned && canJoin ? (
        <Button size="sm" variant="outline" disabled={joining} onClick={onJoin}>
          {t('conversation.join')}
        </Button>
      ) : null}
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
  const client = useQueryClient()
  const agent = useAgent()
  const supervisor = isSupervisor(agent)
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
  const [card, setCard] = useState<CardRef | null>(null)

  const active = ticket.status === 'claimed' || ticket.status === 'waiting_customer'
  const owner = active && ticket.owner?.id === agent.id
  const joined = (members.data ?? []).some((member) => member.user_id === agent.id)
  const canReply = owner || (supervisor && active && joined)
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
  const join = useTicketAction(() => ticketsApi.join(ticket.id), {
    ticketId,
    success: t('conversation.joined'),
    onSuccess: () => void client.invalidateQueries({ queryKey: conversationKeys.members(ticket.room_id) }),
  })
  const reassign = useTicketAction(
    ({ agentId, reason }: { agentId: string; name: string; reason: string }) =>
      ticketsApi.reassign(ticket.id, agentId, reason),
    { ticketId, success: ({ name }) => t('conversation.reassigned', { name }) },
  )
  const busy = [wait, release, transfer, resolve, priority, join, reassign].some(
    (mutation) => mutation.isPending,
  )

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
        supervisor={supervisor}
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
          onReply={canReply ? setReplyTo : undefined}
          onOpenCard={setCard}
          onResend={(item) => void resend(item).catch(() => undefined)}
          onDiscard={discard}
        />
      )}
      <div className="min-h-5 px-(--pane-px) pb-1 text-xs text-muted-foreground" aria-live="polite">
        {room.typing ? t('conversation.typing', { name: room.typing }) : null}
      </div>
      {canReply ? (
        <Composer
          ticket={ticket}
          agent={agent}
          replyTo={replyTo}
          onCancelReply={() => setReplyTo(null)}
          send={send}
          onTyping={room.sendTyping}
          onStopTyping={room.stopTyping}
        />
      ) : (
        <ReadOnlyBar
          ticket={ticket}
          canJoin={supervisor && !joined}
          joining={join.isPending}
          onJoin={() => join.mutate(undefined)}
        />
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
      <CardDetailDialog ticketId={ticket.id} card={card} onClose={() => setCard(null)} />
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
