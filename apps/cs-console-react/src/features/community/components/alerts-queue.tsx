import { SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { CopyButton } from '@/components/copy-button'
import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { ToneBadge } from '@/features/system/components/system-ui'
import { useDebounced } from '@/hooks/use-now'
import { moderationErrorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'

import { useManipulationAlerts, useReviewAlert } from '../hooks'
import { cleanStock, evidenceIds, evidenceNumber, evidenceText, stockCodePattern } from '../logic'
import { alertStatuses, type AlertStatus, type ContentTarget, type ManipulationAlert } from '../types'
import { QueueHeader } from './moderation-ui'
import { ReasonDialog } from './shared'

const statusTone = { open: 'warn', reviewed: 'ok', dismissed: 'neutral' } as const

function Fact({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="tabular text-row break-words">{value}</dd>
    </div>
  )
}

const POST_BUTTONS = 12

function Evidence({
  alert,
  onContent,
}: {
  alert: ManipulationAlert
  onContent: (target: ContentTarget) => void
}) {
  const { t } = useTranslation()
  const e = alert.evidence
  const num = (key: string, digits?: number) => {
    const value = evidenceNumber(e, key)
    return value === null ? '–' : formatNumber(value, digits)
  }
  const sample = evidenceText(e, 'sample')
  const posts = evidenceIds(e, 'post_ids')
  return (
    <div className="flex flex-col gap-2">
      <dl className="grid grid-cols-2 gap-x-4 gap-y-2 sm:grid-cols-4">
        {alert.kind === 'mention_spike' ? (
          <>
            <Fact label={t('moderation.alerts.evidence.mentions')} value={num('mentions_last_hour')} />
            <Fact label={t('moderation.alerts.evidence.hourlyAverage')} value={num('hourly_average', 2)} />
            <Fact label={t('moderation.alerts.evidence.authors')} value={num('authors')} />
          </>
        ) : null}
        {alert.kind === 'new_account_concentration' ? (
          <>
            <Fact label={t('moderation.alerts.evidence.mentions')} value={num('mentions_last_hour')} />
            <Fact label={t('moderation.alerts.evidence.newMentions')} value={num('new_account_mentions')} />
            <Fact
              label={t('moderation.alerts.evidence.newDays')}
              value={t('moderation.alerts.evidence.days', { value: num('new_account_days') })}
            />
          </>
        ) : null}
        {alert.kind === 'coordinated_posts' ? (
          <>
            <Fact label={t('moderation.alerts.evidence.authors')} value={num('authors')} />
            <Fact
              label={t('moderation.alerts.evidence.window')}
              value={t('moderation.alerts.evidence.minutes', { value: num('window_minutes') })}
            />
            <Fact label={t('moderation.alerts.evidence.similarPosts')} value={formatNumber(posts.length)} />
          </>
        ) : null}
        {evidenceText(e, 'window_end') ? (
          <Fact
            label={t('moderation.alerts.evidence.windowEnd')}
            value={stamp(evidenceText(e, 'window_end') ?? '')}
          />
        ) : null}
      </dl>
      {sample ? (
        <figure className="flex flex-col gap-1">
          <figcaption className="text-xs text-muted-foreground">
            {t('moderation.alerts.evidence.sample')}
          </figcaption>
          <blockquote className="rounded-md bg-subtle p-2 text-row break-words whitespace-pre-wrap">
            {sample}
          </blockquote>
        </figure>
      ) : null}
      {posts.length > 0 ? (
        <div className="flex flex-col gap-1.5">
          <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
            {t('moderation.alerts.evidence.postIds', { count: posts.length })}
            <CopyButton
              text={posts.join('\n')}
              size="xs"
              label={t('moderation.alerts.evidence.postIdsLabel')}
            />
          </div>
          <ul className="flex flex-wrap gap-1" aria-label={t('moderation.alerts.evidence.postIdsLabel')}>
            {posts.slice(0, POST_BUTTONS).map((id, index) => (
              <li key={id}>
                <Button size="xs" variant="outline" onClick={() => onContent({ type: 'post', id })}>
                  {t('moderation.alerts.evidence.openPost', { index: index + 1 })}
                </Button>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  )
}

function scoreText(alert: ManipulationAlert) {
  if (alert.kind === 'new_account_concentration') return `${formatNumber(Math.round(alert.score * 100))}%`
  if (alert.kind === 'mention_spike') return `×${formatNumber(alert.score, 1)}`
  return formatNumber(alert.score)
}

function AlertItem({
  alert,
  onReview,
  onOpenRoom,
  onContent,
}: {
  alert: ManipulationAlert
  onReview: (status: 'reviewed' | 'dismissed') => void
  onOpenRoom?: (stock: string) => void
  onContent: (target: ContentTarget) => void
}) {
  const { t } = useTranslation()
  const slow = alert.auto_actions.slow_mode
  const held = alert.auto_actions.held_posts ?? []
  return (
    <li className="flex flex-col gap-3 border-b py-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex flex-wrap items-center gap-2">
          <span className="font-mono text-row font-semibold">${alert.stock}</span>
          <span className="text-row">{t(`moderation.alerts.kinds.${alert.kind}`)}</span>
          <span className="tabular text-xs text-muted-foreground">
            {t(`moderation.alerts.scores.${alert.kind}`, { score: scoreText(alert) })}
          </span>
        </div>
        <ToneBadge tone={statusTone[alert.status]}>{t(`moderation.alerts.status.${alert.status}`)}</ToneBadge>
      </div>
      <p className="text-xs text-muted-foreground">
        {t('moderation.alerts.detected', {
          first: stamp(alert.detected_at),
          last: stamp(alert.last_detected_at),
        })}
      </p>
      <Evidence alert={alert} onContent={onContent} />
      {slow || held.length > 0 ? (
        <ul className="flex list-disc flex-col gap-0.5 pl-5 text-xs">
          {slow ? (
            <li>
              {slow.until
                ? t('moderation.alerts.autoSlowUntil', { seconds: slow.seconds, time: stamp(slow.until) })
                : t('moderation.alerts.autoSlow', { seconds: slow.seconds })}
            </li>
          ) : null}
          {held.length > 0 ? <li>{t('moderation.alerts.autoHeld', { count: held.length })}</li> : null}
        </ul>
      ) : null}
      {alert.status !== 'open' ? (
        <p className="text-xs break-words text-muted-foreground">
          {t('moderation.alerts.reviewed', {
            time: alert.reviewed_at ? stamp(alert.reviewed_at) : '–',
            name: alert.reviewed_by?.name ?? '–',
            note: alert.review_note ?? '–',
          })}
        </p>
      ) : null}
      <div className="flex flex-wrap gap-1.5">
        {onOpenRoom ? (
          <Button size="xs" variant="ghost" onClick={() => onOpenRoom(alert.stock)}>
            {t('moderation.alerts.openRoom')}
          </Button>
        ) : null}
        {alert.status === 'open' ? (
          <>
            <Button size="xs" variant="default" onClick={() => onReview('reviewed')}>
              {t('moderation.alerts.markReviewed')}
            </Button>
            <Button size="xs" variant="outline" onClick={() => onReview('dismissed')}>
              {t('moderation.alerts.dismiss')}
            </Button>
          </>
        ) : null}
      </div>
    </li>
  )
}

export function AlertsQueue({
  onOpenRoom,
  onContent,
}: {
  onOpenRoom?: (stock: string) => void
  onContent: (target: ContentTarget) => void
}) {
  const { t } = useTranslation()
  const [status, setStatus] = useState<AlertStatus>('open')
  const [query, setQuery] = useState('')
  const stock = cleanStock(useDebounced(query, 300))
  const filter = stockCodePattern.test(stock) ? stock : null
  const alerts = useManipulationAlerts(status, filter)
  const review = useReviewAlert()
  const [acting, setActing] = useState<{ alert: ManipulationAlert; status: 'reviewed' | 'dismissed' } | null>(
    null,
  )
  return (
    <div className="flex min-w-0 flex-col gap-3">
      <QueueHeader
        title={t('moderation.alerts.title')}
        hint={t('moderation.alerts.hint')}
        count={alerts.data?.length}
      >
        <ToggleGroup
          type="single"
          value={status}
          onValueChange={(value) => {
            if ((alertStatuses as readonly string[]).includes(value)) setStatus(value as AlertStatus)
          }}
          aria-label={t('moderation.filter')}
        >
          {alertStatuses.map((item) => (
            <ToggleGroupItem key={item} value={item}>
              {t(`moderation.alerts.status.${item}`)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      </QueueHeader>
      <div className="relative w-full sm:w-56">
        <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
        <Input
          type="search"
          value={query}
          maxLength={13}
          placeholder={t('moderation.alerts.stockFilter')}
          aria-label={t('moderation.alerts.stockFilter')}
          className="h-8 pl-8 uppercase"
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      {alerts.isError ? (
        <ErrorState error={alerts.error} onRetry={() => void alerts.refetch()} />
      ) : !alerts.data ? (
        <ListSkeleton rows={3} />
      ) : alerts.data.length === 0 ? (
        <EmptyState title={t(`moderation.alerts.empty.${status}`)} />
      ) : (
        <ul className="border-t">
          {alerts.data.map((alert) => (
            <AlertItem
              key={alert.id}
              alert={alert}
              onOpenRoom={onOpenRoom}
              onContent={onContent}
              onReview={(next) => setActing({ alert, status: next })}
            />
          ))}
        </ul>
      )}
      <ReasonDialog
        key={acting ? `${acting.alert.id}-${acting.status}` : 'none'}
        open={acting !== null}
        title={acting ? t(`moderation.alerts.titles.${acting.status}`, { stock: acting.alert.stock }) : ''}
        description={acting ? t(`moderation.alerts.bodies.${acting.status}`) : undefined}
        label={t('moderation.note')}
        hint={t('moderation.noteHint')}
        action={
          acting
            ? t(acting.status === 'reviewed' ? 'moderation.alerts.markReviewed' : 'moderation.alerts.dismiss')
            : ''
        }
        pending={review.isPending}
        onClose={() => setActing(null)}
        onSubmit={(note) => {
          if (!acting) return
          void review
            .mutateAsync({ id: acting.alert.id, status: acting.status, note })
            .then((result) => {
              toast.success(
                acting.status === 'dismissed'
                  ? t('moderation.alerts.dismissed', { count: result.released_posts ?? 0 })
                  : t('moderation.alerts.markedReviewed'),
              )
              setActing(null)
            })
            .catch((error: unknown) => toast.error(moderationErrorText(error)))
        }}
      />
    </div>
  )
}
