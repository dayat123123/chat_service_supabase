import { LoaderCircleIcon, TagIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  Tooltip,
} from '@/components/ui/menu'
import type { Ticket } from '@/features/tickets/types'

import { useLabelOptions, useTicketLabelChange } from '../hooks'
import { atLabelLimit, ticketLabels } from '../logic'
import { MAX_TICKET_LABELS, type TicketLabel } from '../types'
import { LabelDot } from './label-chip'

export function TicketLabelMenu({ ticket }: { ticket: Pick<Ticket, 'id' | 'ticket_number' | 'labels'> }) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const options = useLabelOptions(open)
  const change = useTicketLabelChange(ticket.id)
  const current = ticketLabels(ticket)
  const full = atLabelLimit(current)
  const chosen = new Set(current.map((label) => label.id))
  const choices: TicketLabel[] = [
    ...current.filter((label) => !(options.data ?? []).some((option) => option.id === label.id)),
    ...(options.data ?? []),
  ]
  const toggle = (label: TicketLabel, add: boolean) => {
    if (change.isPending) return
    change.mutate({ label, add })
  }
  const label = t('labels.addFor', { ticket: ticket.ticket_number })
  return (
    <DropdownMenu open={open} onOpenChange={setOpen}>
      <Tooltip content={t('labels.listLabel')}>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon-sm" aria-label={label}>
            <TagIcon />
          </Button>
        </DropdownMenuTrigger>
      </Tooltip>
      <DropdownMenuContent align="end" className="w-60">
        <DropdownMenuLabel className="flex items-center justify-between gap-2">
          <span>{t('labels.listLabel')}</span>
          <span className="tabular">
            {current.length}/{MAX_TICKET_LABELS}
          </span>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        {options.isPending ? (
          <p className="flex items-center gap-2 px-2 py-1.5 text-xs text-muted-foreground" role="status">
            <LoaderCircleIcon className="size-3.5 animate-spin" />
            {t('labels.loading')}
          </p>
        ) : choices.length === 0 ? (
          <p className="px-2 py-1.5 text-xs text-muted-foreground">{t('labels.noOptions')}</p>
        ) : (
          choices.map((choice) => {
            const checked = chosen.has(choice.id)
            return (
              <DropdownMenuCheckboxItem
                key={choice.id}
                checked={checked}
                disabled={change.isPending || (!checked && full)}
                onSelect={(event) => event.preventDefault()}
                onCheckedChange={(value) => toggle(choice, value === true)}
              >
                <LabelDot color={choice.color} />
                <span className="truncate">{choice.name}</span>
              </DropdownMenuCheckboxItem>
            )
          })
        )}
        {full ? (
          <p className="px-2 pt-1.5 pb-1 text-xs text-muted-foreground">
            {t('labels.limit', { max: MAX_TICKET_LABELS })}
          </p>
        ) : null}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
