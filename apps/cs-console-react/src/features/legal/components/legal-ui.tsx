import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { UsageBar } from '@/components/usage-bar'
import { formatNumber, formatPercent } from '@/lib/time'
import { cn } from '@/lib/utils'

import { acceptanceRatio, bodyLines, draftTone } from '../logic'
import type { DraftStatus } from '../types'

const borders: Record<DraftStatus, string> = {
  draft: 'border-border text-muted-foreground',
  pending: 'border-warning/40 text-warning',
  rejected: 'border-destructive/40 text-destructive',
  published: 'border-success/40 text-success',
}

export function DraftStatusBadge({ status, className }: { status: DraftStatus; className?: string }) {
  const { t } = useTranslation()
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-sm border px-1.5 py-px text-xs font-medium whitespace-nowrap',
        borders[status],
        className,
      )}
    >
      <Dot tone={draftTone(status)} />
      {t(`legal.status.${status}`)}
    </span>
  )
}

export function AcceptanceMeter({ accepted, activeUsers }: { accepted: number; activeUsers: number }) {
  const { t } = useTranslation()
  const ratio = acceptanceRatio(accepted, activeUsers)
  const text =
    ratio === null
      ? t('legal.acceptanceNoUsers', { accepted: formatNumber(accepted) })
      : t('legal.acceptance', {
          accepted: formatNumber(accepted),
          total: formatNumber(activeUsers),
          percent: formatPercent(ratio),
        })
  return (
    <div className="flex flex-col gap-1">
      <p className="tabular text-xs text-muted-foreground">{text}</p>
      {ratio === null ? null : <UsageBar ratio={ratio} label={t('legal.acceptanceLabel')} valueText={text} />}
    </div>
  )
}

export function LegalPreview({ title, body, className }: { title: string; body: string; className?: string }) {
  const { t } = useTranslation()
  return (
    <section
      aria-label={t('legal.preview.label')}
      className={cn('flex flex-col gap-3 rounded-lg border bg-subtle p-4', className)}
    >
      <p className="text-label font-medium text-muted-foreground uppercase">{t('legal.preview.hint')}</p>
      <div className="mx-auto flex w-full max-w-prose flex-col gap-3 rounded-md border bg-background p-4">
        <h3 className="text-panel font-semibold break-words">{title.trim() || t('legal.preview.noTitle')}</h3>
        {body.trim() ? (
          <p className="text-sm leading-relaxed break-words whitespace-pre-wrap">{bodyLines(body)}</p>
        ) : (
          <p className="text-sm text-muted-foreground">{t('legal.preview.empty')}</p>
        )}
      </div>
    </section>
  )
}

export function Fact({
  label,
  children,
  className,
}: {
  label: string
  children: React.ReactNode
  className?: string
}) {
  return (
    <div className={cn('flex min-w-0 flex-col gap-0.5', className)}>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-row break-words">{children}</dd>
    </div>
  )
}
