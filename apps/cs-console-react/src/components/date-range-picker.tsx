import { subDays } from 'date-fns'
import { CalendarRangeIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/menu'
import { rangeProblem, type RangeProblem } from '@/features/reports/range'
import type { DateRange } from '@/features/reports/types'
import { isoDay, todayInJakarta } from '@/lib/time'
import { cn } from '@/lib/utils'

const problemKey: Record<
  RangeProblem,
  'reports.rangeInvalid' | 'reports.rangeOrder' | 'reports.rangeFuture' | 'reports.rangeTooLong'
> = {
  invalid: 'reports.rangeInvalid',
  order: 'reports.rangeOrder',
  future: 'reports.rangeFuture',
  tooLong: 'reports.rangeTooLong',
}

export function DateRangePicker({
  range,
  active,
  maxDays,
  onApply,
}: {
  range: DateRange
  active: boolean
  maxDays: number
  onApply: (range: DateRange) => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const [open, setOpen] = useState(false)
  const [draft, setDraft] = useState(range)
  const [problem, setProblem] = useState<RangeProblem | null>(null)
  const today = todayInJakarta()
  const max = isoDay(today)
  const min = isoDay(subDays(today, 730))
  return (
    <Popover
      open={open}
      onOpenChange={(next) => {
        setOpen(next)
        if (next) {
          setDraft(range)
          setProblem(null)
        }
      }}
    >
      <PopoverTrigger asChild>
        <Button variant="outline" size="sm" className={cn(active && 'border-strong bg-muted')}>
          <CalendarRangeIcon />
          {t('reports.custom')}
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-72">
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault()
            const issue = rangeProblem(draft, today, maxDays)
            setProblem(issue)
            if (issue) return
            onApply(draft)
            setOpen(false)
          }}
        >
          <div className="grid grid-cols-2 gap-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${id}-from`}>{t('reports.from')}</Label>
              <Input
                id={`${id}-from`}
                type="date"
                min={min}
                max={max}
                required
                value={draft.from}
                onChange={(event) => setDraft((current) => ({ ...current, from: event.target.value }))}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${id}-to`}>{t('reports.to')}</Label>
              <Input
                id={`${id}-to`}
                type="date"
                min={min}
                max={max}
                required
                value={draft.to}
                onChange={(event) => setDraft((current) => ({ ...current, to: event.target.value }))}
              />
            </div>
          </div>
          {problem ? (
            <p role="alert" className="text-xs text-destructive">
              {t(problemKey[problem], { days: maxDays })}
            </p>
          ) : (
            <p className="text-xs text-muted-foreground">{t('reports.rangeTooLong', { days: maxDays })}</p>
          )}
          <Button type="submit" size="sm" className="self-end">
            {t('reports.apply')}
          </Button>
        </form>
      </PopoverContent>
    </Popover>
  )
}
