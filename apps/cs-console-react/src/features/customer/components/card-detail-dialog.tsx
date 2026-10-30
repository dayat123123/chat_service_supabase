import { useQuery } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'

import { ErrorState } from '@/components/states'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Skeleton } from '@/components/ui/primitives'
import { stamp } from '@/lib/time'

import { customerApi } from '../api'

export type CardRef = { card: string; ref: string }

function display(value: unknown): string {
  if (value === null || value === undefined) return '–'
  if (typeof value === 'string') return /^\d{4}-\d{2}-\d{2}T/.test(value) ? stamp(value) : value
  if (typeof value === 'number' || typeof value === 'boolean') return String(value)
  return JSON.stringify(value) ?? '–'
}

export function CardDetailDialog({
  ticketId,
  card,
  onClose,
}: {
  ticketId: string
  card: CardRef | null
  onClose: () => void
}) {
  const { t } = useTranslation()
  const detail = useQuery({
    queryKey: ['customer', ticketId, 'card', card?.card, card?.ref],
    queryFn: () =>
      card?.card === 'cash_transaction'
        ? customerApi.cashDetail(ticketId, card.ref)
        : customerApi.order(ticketId, card?.ref ?? ''),
    enabled: card !== null,
    retry: false,
  })
  const title = card
    ? `${card.card === 'cash_transaction' ? t('conversation.cardCash') : t('conversation.cardOrder')} ${card.ref}`
    : ''
  return (
    <Dialog open={card !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
        </DialogHeader>
        {detail.isPending ? (
          <div className="flex flex-col gap-2">
            <Skeleton className="h-3.5 w-2/3" />
            <Skeleton className="h-3.5 w-1/2" />
            <Skeleton className="h-3.5 w-3/4" />
          </div>
        ) : detail.isError ? (
          <ErrorState error={detail.error} onRetry={() => void detail.refetch()} />
        ) : (
          <dl className="grid grid-cols-[140px_1fr] gap-x-3 gap-y-1.5 text-sm">
            {Object.entries(detail.data).map(([key, value]) => (
              <div key={key} className="contents">
                <dt className="text-muted-foreground">{key}</dt>
                <dd className="break-words">{display(value)}</dd>
              </div>
            ))}
          </dl>
        )}
      </DialogContent>
    </Dialog>
  )
}
