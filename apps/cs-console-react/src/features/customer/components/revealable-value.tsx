import { EyeIcon } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { clock } from '@/lib/time'

import { useRevealedValue } from '../hooks'
import type { RevealField } from '../types'
import { RevealDialog } from './reveal-dialog'

export function InfoRow({ label, value, action }: { label: string; value: ReactNode; action?: ReactNode }) {
  return (
    <div className="grid grid-cols-[112px_1fr_auto] items-start gap-2 py-1 text-xs">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="min-w-0 break-words">{value ?? '–'}</dd>
      {action ?? <span />}
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
          <span className="font-medium text-foreground">
            {revealed.value}
            <span className="block text-[10px] text-muted-foreground">
              {t('customer.revealedUntil', { time: clock(new Date(revealed.until)) })}
            </span>
          </span>
        ) : (
          <span className="tabular">{masked ?? '–'}</span>
        )
      }
      action={
        canReveal && masked && !revealed ? (
          <>
            <Button size="xs" variant="link" className="h-auto px-0" onClick={() => setOpen(true)}>
              <EyeIcon />
              {t('customer.reveal')}
            </Button>
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
