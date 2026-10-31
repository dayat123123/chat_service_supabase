import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { cn } from '@/lib/utils'

import { deadlineTone } from '../logic'
import { useDeadlineLabel } from '../labels'
import type { CaseRow, Deadline, Verdict } from '../types'

export function DeadlineText({ deadline, className }: { deadline: Deadline | null; className?: string }) {
  const { t } = useTranslation()
  const label = useDeadlineLabel()
  if (!deadline) {
    return (
      <span className={cn('text-xs text-muted-foreground', className)}>
        {t('compliance.cases.noDeadline')}
      </span>
    )
  }
  const tone = deadlineTone(deadline.state)
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 text-xs',
        tone === 'late'
          ? 'font-medium text-danger'
          : tone === 'warn'
            ? 'font-medium text-warning'
            : 'text-muted-foreground',
        className,
      )}
    >
      <Dot tone={tone} />
      {label(deadline)}
    </span>
  )
}

const verdictClass: Record<Verdict, string> = {
  compliant: 'text-success',
  needs_action: 'text-warning',
  violation: 'text-danger',
}

export function VerdictText({
  verdict,
  className,
}: {
  verdict: Verdict | null | undefined
  className?: string
}) {
  const { t } = useTranslation()
  if (!verdict) {
    return (
      <span className={cn('text-xs text-muted-foreground', className)}>
        {t('compliance.cases.notReviewed')}
      </span>
    )
  }
  return (
    <span className={cn('text-xs font-medium', verdictClass[verdict], className)}>
      {t(`compliance.verdict.${verdict}`)}
    </span>
  )
}

export function CaseKindText({
  row,
  className,
}: {
  row: Pick<CaseRow, 'flags' | 'fake_cs'>
  className?: string
}) {
  const { t } = useTranslation()
  const parts = [
    row.flags.includes('complaint') ? t('compliance.kind.complaint') : null,
    row.flags.includes('fraud') ? t('compliance.kind.fraud') : null,
    row.fake_cs ? t('compliance.kind.fakeCs') : null,
  ].filter(Boolean)
  return (
    <span
      className={cn(
        'text-xs',
        row.flags.includes('fraud') ? 'font-medium text-danger' : 'text-info',
        className,
      )}
    >
      {parts.join(' · ')}
    </span>
  )
}
