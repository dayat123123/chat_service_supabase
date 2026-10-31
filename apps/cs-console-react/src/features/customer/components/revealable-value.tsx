import { EyeIcon } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Tooltip } from '@/components/ui/menu'
import { clock } from '@/lib/time'

import { useRevealedValue } from '../hooks'
import type { RevealField } from '../types'
import { RevealDialog } from './reveal-dialog'

export function InfoRow({ label, value, action }: { label: string; value: ReactNode; action?: ReactNode }) {
  return (
    <div className="grid min-h-7 grid-cols-[104px_minmax(0,1fr)] items-start gap-x-3 py-1 text-row">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="tabular flex min-w-0 items-start justify-between gap-2">
        <span className="min-w-0 break-words">{value ?? '–'}</span>
        {action}
      </dd>
    </div>
  )
}

export function RevealableValue({
  ticketId,
  field,
  masked,
  label,
  canReveal,
}: {
  ticketId: string
  field: RevealField
  masked: string | undefined
  label: string
  canReveal: boolean
}) {
  const { t } = useTranslation()
  const revealed = useRevealedValue(ticketId, field)
  const [open, setOpen] = useState(false)
  return (
    <InfoRow
      label={label}
      value={
        revealed ? (
          <span>
            {revealed.value}
            <span className="block text-xs text-muted-foreground">
              {t('customer.revealedUntil', { time: clock(new Date(revealed.until)) })}
            </span>
          </span>
        ) : (
          <span className="font-mono text-xs">{masked ?? '–'}</span>
        )
      }
      action={
        canReveal && masked && !revealed ? (
          <>
            <Tooltip content={t('customer.reveal')}>
              <Button
                variant="ghost"
                size="icon-xs"
                className="-my-1 size-6"
                aria-label={t('customer.reveal')}
                onClick={() => setOpen(true)}
              >
                <EyeIcon />
              </Button>
            </Tooltip>
            <RevealDialog
              ticketId={ticketId}
              field={field}
              label={label}
              open={open}
              onOpenChange={setOpen}
            />
          </>
        ) : undefined
      }
    />
  )
}
