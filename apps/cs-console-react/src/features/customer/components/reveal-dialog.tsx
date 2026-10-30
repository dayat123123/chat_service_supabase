import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { useAgent } from '@/features/auth/hooks'
import { errorText } from '@/lib/error-text'

import { useReveal } from '../hooks'
import type { RevealField } from '../types'

export function RevealDialog({
  ticketId,
  field,
  label,
  open,
  onOpenChange,
}: {
  ticketId: string
  field: RevealField
  label: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t, i18n } = useTranslation()
  const agent = useAgent()
  const reveal = useReveal(ticketId)
  const reasons = Object.entries(agent.settings.reveal_reasons)
  const [reason, setReason] = useState('')
  const language = i18n.language === 'en' ? 'en' : 'id'
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) {
          setReason('')
          reveal.reset()
        }
        onOpenChange(next)
      }}
    >
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('customer.revealTitle', { field: label })}</DialogTitle>
          <DialogDescription>{t('customer.revealHint')}</DialogDescription>
        </DialogHeader>
        <div className="flex flex-col gap-2">
          <Label htmlFor="reveal-reason">{t('customer.revealReason')}</Label>
          <Select value={reason} onValueChange={setReason}>
            <SelectTrigger id="reveal-reason">
              <SelectValue placeholder={t('customer.revealReason')} />
            </SelectTrigger>
            <SelectContent>
              {reasons.map(([code, names]) => (
                <SelectItem key={code} value={code}>
                  {names[language]}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        {reveal.isError ? (
          <p role="alert" className="text-sm text-destructive">
            {errorText(reveal.error)}
          </p>
        ) : null}
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t('app.cancel')}
          </Button>
          <Button
            disabled={!reason || reveal.isPending}
            onClick={() =>
              reveal.mutate(
                { field, reason },
                {
                  onSuccess: () => {
                    setReason('')
                    onOpenChange(false)
                  },
                },
              )
            }
          >
            {t('customer.reveal')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
