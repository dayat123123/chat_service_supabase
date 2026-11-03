import { LockIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { cn } from '@/lib/utils'

import { retentionState } from '../logic'
import type { EvidenceFileStatus, EvidenceRow } from '../types'

const fileTone = {
  pending: 'warn',
  copied: 'ok',
  missing: 'late',
  failed: 'late',
} as const

export function FileStatusText({ status, className }: { status: EvidenceFileStatus; className?: string }) {
  const { t } = useTranslation()
  return (
    <span className={cn('inline-flex items-center gap-1.5 text-xs', className)}>
      <Dot tone={fileTone[status]} />
      {t(`evidence.fileStatus.${status}`)}
    </span>
  )
}

export function RetentionText({
  row,
  className,
}: {
  row: Pick<EvidenceRow, 'legal_hold' | 'retain_until'>
  className?: string
}) {
  const { t } = useTranslation()
  const state = retentionState(row)
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 text-xs',
        state === 'held' && 'font-medium text-warning',
        state === 'expiring' && 'text-danger',
        state === 'active' && 'text-muted-foreground',
        className,
      )}
    >
      {state === 'held' ? <LockIcon className="size-3.5" aria-hidden="true" /> : null}
      {t(`evidence.retention.${state}`)}
    </span>
  )
}

export function FilesSummary({ row }: { row: Pick<EvidenceRow, 'files'> }) {
  const { t } = useTranslation()
  const { files } = row
  if (files.total === 0) return <span className="text-xs text-muted-foreground">{t('evidence.noFiles')}</span>
  const tone = files.missing + files.failed > 0 ? 'late' : files.pending > 0 ? 'warn' : 'ok'
  return (
    <span className="tabular inline-flex items-center gap-1.5 text-xs">
      <Dot tone={tone} />
      {t('evidence.filesCount', { copied: files.copied, total: files.total })}
    </span>
  )
}
