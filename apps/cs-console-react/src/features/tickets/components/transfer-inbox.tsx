import { ArrowRightLeftIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { PriorityBadge } from '@/components/badges'
import { Button } from '@/components/ui/button'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Textarea } from '@/components/ui/textarea'
import { clock } from '@/lib/time'

import { ticketsApi } from '../api'
import { useTicketAction, useTicketUi } from '../hooks'
import { customerName, type OutgoingTransfer, type TransferRequest } from '../types'

export function TransferInbox({
  incoming,
  outgoing,
}: {
  incoming: TransferRequest[]
  outgoing: OutgoingTransfer[]
}) {
  const { t } = useTranslation()
  const [rejecting, setRejecting] = useState<TransferRequest | null>(null)
  const [reason, setReason] = useState('')
  const respond = useTicketAction(
    ({ request, accept, why }: { request: TransferRequest; accept: boolean; why?: string }) =>
      ticketsApi.respondTransfer(request.id, accept, why),
    { ticketId: ({ request }) => request.ticket.id },
  )
  const cancel = useTicketAction((transfer: OutgoingTransfer) => ticketsApi.cancelTransfer(transfer.id), {
    ticketId: (transfer) => transfer.ticket_id,
  })

  if (incoming.length === 0 && outgoing.length === 0) return null
  return (
    <div className="flex flex-col gap-2 border-b bg-accent/40 p-3 compact:p-2">
      {incoming.length > 0 ? (
        <p className="flex items-center gap-1.5 text-xs font-semibold text-accent-foreground">
          <ArrowRightLeftIcon className="size-3.5" />
          {t('tickets.transfersIn')}
        </p>
      ) : null}
      {incoming.map((request) => (
        <div key={request.id} className="rounded-lg border bg-card p-2.5 shadow-xs">
          <div className="flex items-center gap-2">
            <span className="min-w-0 flex-1 truncate text-sm font-semibold">
              {customerName(request.ticket)}
            </span>
            <PriorityBadge priority={request.ticket.priority} />
          </div>
          <p className="mt-0.5 text-xs text-muted-foreground">
            {request.ticket.ticket_number} · {t('tickets.transferFrom', { name: request.from_name ?? '' })}
            {request.expires_at ? ` · ${t('tickets.expiresAt', { time: clock(request.expires_at) })}` : ''}
          </p>
          {request.note ? <p className="mt-1 line-clamp-3 text-xs">“{request.note}”</p> : null}
          <div className="mt-2 flex gap-2">
            <Button
              size="xs"
              disabled={respond.isPending}
              onClick={() =>
                respond.mutate(
                  { request, accept: true },
                  {
                    onSuccess: () => {
                      toast.success(t('tickets.transferAccepted'))
                      useTicketUi.getState().setTab('mine')
                      useTicketUi.getState().select(request.ticket.id)
                    },
                  },
                )
              }
            >
              {t('tickets.accept')}
            </Button>
            <Button
              size="xs"
              variant="outline"
              disabled={respond.isPending}
              onClick={() => {
                setReason('')
                setRejecting(request)
              }}
            >
              {t('tickets.reject')}
            </Button>
          </div>
        </div>
      ))}
      {outgoing.length > 0 ? (
        <p className="text-xs font-semibold text-muted-foreground">{t('tickets.transfersOut')}</p>
      ) : null}
      {outgoing.map((transfer) => (
        <div key={transfer.id} className="flex items-center gap-2 text-xs">
          <span className="min-w-0 flex-1 truncate">
            {t('tickets.transferTo', { name: transfer.to_name ?? '' })}
            {transfer.expires_at ? ` · ${t('tickets.expiresAt', { time: clock(transfer.expires_at) })}` : ''}
          </span>
          <Button
            size="xs"
            variant="ghost"
            disabled={cancel.isPending}
            onClick={() => cancel.mutate(transfer)}
          >
            {t('tickets.cancelTransfer')}
          </Button>
        </div>
      ))}
      <Dialog open={rejecting !== null} onOpenChange={(open) => !open && setRejecting(null)}>
        <DialogContent className="sm:max-w-md" closeLabel={t('app.close')}>
          <DialogHeader>
            <DialogTitle>{t('tickets.rejectTitle')}</DialogTitle>
          </DialogHeader>
          <Textarea
            value={reason}
            maxLength={300}
            onChange={(event) => setReason(event.target.value)}
            placeholder={t('tickets.rejectReason')}
            aria-label={t('tickets.rejectReason')}
          />
          <DialogFooter>
            <Button variant="outline" onClick={() => setRejecting(null)}>
              {t('app.cancel')}
            </Button>
            <Button
              variant="destructive"
              onClick={() => {
                if (rejecting) respond.mutate({ request: rejecting, accept: false, why: reason.trim() })
                setRejecting(null)
              }}
            >
              {t('tickets.reject')}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
