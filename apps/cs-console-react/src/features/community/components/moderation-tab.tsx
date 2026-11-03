import { SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Avatar } from '@/components/ui/primitives'
import { useAgent } from '@/features/auth/hooks'
import { useDebounced } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { metaKey, useContentMeta, useFindUsers, useResolveReport, useReports } from '../hooks'
import { canEditHistory, moderationQueuesFor } from '../logic'
import {
  reportStatuses,
  type ContentMeta,
  type ContentTarget,
  type ModerationQueue,
  type ReportAction,
  type ReportRow,
  type ReportStatus,
} from '../types'
import { AlertsQueue } from './alerts-queue'
import { AppealsQueue } from './appeals-queue'
import { ContentSheet } from './content-sheet'
import { EditHistoryButton } from './edit-history'
import { HeldQueue } from './held-queue'
import { MediaQueue } from './media-queue'
import { EditedMark } from './moderation-ui'
import { OfficialBadge, ReasonDialog } from './shared'
import { UserSheet } from './user-sheet'

const actionsFor = (row: ReportRow): ReportAction[] => {
  if (row.target_type === 'user') return ['dismiss']
  if (row.target_status === 'removed') return ['dismiss']
  if (row.target_status === 'hidden') return ['restore', 'remove', 'dismiss']
  return ['hide', 'remove', 'dismiss']
}

const contentTarget = (row: ReportRow): ContentTarget | null =>
  row.target_type === 'user' ? null : { type: row.target_type, id: row.target_id }

function ReportItem({
  row,
  canAct,
  history,
  meta,
  onUser,
  onAct,
  onContent,
}: {
  row: ReportRow
  canAct: boolean
  history: boolean
  meta: ContentMeta | undefined
  onUser: (id: string) => void
  onAct: (action: ReportAction) => void
  onContent: (target: ContentTarget) => void
}) {
  const target = contentTarget(row)
  const { t } = useTranslation()
  const author = row.author_display_name ?? row.author_username ?? '–'
  return (
    <li className="flex flex-col gap-2 border-b py-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-muted-foreground">
          <span className="font-medium text-foreground">{t(`community.targets.${row.target_type}`)}</span>
          <span>· {t('community.reportCount', { count: row.report_count })}</span>
          <span>
            ·{' '}
            {row.reasons
              .map((reason) => t(`community.reasons.${reason}`, { defaultValue: reason }))
              .join(', ')}
          </span>
          <span>· {stamp(row.last_reported_at)}</span>
          <EditedMark editedAt={meta?.edited_at} />
        </span>
        <span
          className={cn(
            'text-xs',
            row.target_status === 'visible' ? 'text-muted-foreground' : 'text-warning',
          )}
        >
          {t(`community.targetStatus.${row.target_status}`, { defaultValue: row.target_status })}
        </span>
      </div>
      <p className="text-row break-words whitespace-pre-wrap">{row.excerpt || '–'}</p>
      <div className="flex flex-wrap items-center justify-between gap-2">
        {row.author_id ? (
          <button
            type="button"
            onClick={() => onUser(row.author_id ?? '')}
            className="flex items-center gap-1.5 rounded-sm text-xs text-primary outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring/50"
          >
            {author}
            {row.author_username ? (
              <span className="font-mono text-muted-foreground">@{row.author_username}</span>
            ) : null}
            {row.author_is_official ? <OfficialBadge /> : null}
          </button>
        ) : (
          <span />
        )}
        <div className="flex flex-wrap gap-1.5">
          {target ? (
            <Button size="xs" variant="ghost" onClick={() => onContent(target)}>
              {t('moderation.content.open')}
            </Button>
          ) : null}
          {history && meta?.edited_at && (row.target_type === 'post' || row.target_type === 'comment') ? (
            <EditHistoryButton type={row.target_type} id={row.target_id} />
          ) : null}
          {canAct
            ? actionsFor(row).map((action) => (
                <Button
                  key={action}
                  size="xs"
                  variant={action === 'remove' ? 'destructive' : action === 'dismiss' ? 'ghost' : 'outline'}
                  onClick={() => onAct(action)}
                >
                  {t(`community.reportActions.${action}`)}
                </Button>
              ))
            : null}
        </div>
      </div>
    </li>
  )
}

function ReportsQueue({
  onUser,
  onContent,
}: {
  onUser: (id: string) => void
  onContent: (target: ContentTarget) => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const [status, setStatus] = useState<ReportStatus>('open')
  const reports = useReports(status)
  const resolve = useResolveReport()
  const [acting, setActing] = useState<{ row: ReportRow; action: ReportAction } | null>(null)
  const canModerate = agent.community_permissions.includes('community.moderate')
  const metas = useContentMeta(
    (reports.data ?? []).flatMap((row) => {
      const target = contentTarget(row)
      return target ? [target] : []
    }),
  )
  return (
    <div className="flex min-w-0 flex-col gap-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-panel font-semibold">{t('community.reportQueue')}</h2>
        <ToggleGroup
          type="single"
          value={status}
          onValueChange={(value) => {
            if ((reportStatuses as readonly string[]).includes(value)) setStatus(value as ReportStatus)
          }}
          aria-label={t('community.filter')}
        >
          {reportStatuses.map((item) => (
            <ToggleGroupItem key={item} value={item}>
              {t(`community.reportStatus.${item}`)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      </div>
      {reports.isError ? (
        <ErrorState error={reports.error} onRetry={() => void reports.refetch()} />
      ) : !reports.data ? (
        <ListSkeleton rows={5} />
      ) : reports.data.length === 0 ? (
        <EmptyState title={t(`community.emptyReports.${status}`)} />
      ) : (
        <ul className="border-t">
          {reports.data.map((row) => (
            <ReportItem
              key={`${row.target_type}-${row.target_id}`}
              row={row}
              canAct={canModerate && status === 'open'}
              history={canEditHistory(agent.community_permissions, row.target_type)}
              meta={metas.get(metaKey({ type: row.target_type as ContentTarget['type'], id: row.target_id }))}
              onUser={onUser}
              onAct={(action) => setActing({ row, action })}
              onContent={onContent}
            />
          ))}
        </ul>
      )}
      <ReasonDialog
        key={acting ? `${acting.row.target_id}-${acting.action}` : 'none'}
        open={acting !== null}
        title={acting ? t(`community.reportActionTitles.${acting.action}`) : ''}
        label={t('community.reason')}
        action={acting ? t(`community.reportActions.${acting.action}`) : ''}
        destructive={acting?.action === 'remove'}
        pending={resolve.isPending}
        onClose={() => setActing(null)}
        onSubmit={(reason) => {
          if (!acting) return
          void resolve
            .mutateAsync({
              type: acting.row.target_type,
              id: acting.row.target_id,
              action: acting.action,
              reason,
            })
            .then(() => {
              setActing(null)
              toast.success(t('community.reportResolved'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }}
      />
    </div>
  )
}

function FindUser({ onUser }: { onUser: (id: string) => void }) {
  const { t } = useTranslation()
  const [query, setQuery] = useState('')
  const search = useDebounced(query, 300)
  const users = useFindUsers(search)
  return (
    <aside className="flex flex-col gap-3" aria-labelledby="find-user">
      <h2 id="find-user" className="text-panel font-semibold">
        {t('community.findUser')}
      </h2>
      <div className="relative">
        <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
        <Input
          type="search"
          value={query}
          maxLength={60}
          placeholder={t('community.findUserPlaceholder')}
          aria-label={t('community.findUser')}
          className="h-8 pl-8"
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      {search.trim().length >= 2 ? (
        users.data && users.data.length === 0 ? (
          <p className="text-row text-muted-foreground">{t('community.noUsers')}</p>
        ) : (
          <ul className="border-t">
            {(users.data ?? []).map((user) => (
              <li key={user.id}>
                <button
                  type="button"
                  onClick={() => onUser(user.id)}
                  className="flex w-full items-center gap-2 border-b px-1 py-2 text-left outline-none hover:bg-muted/50 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset"
                >
                  <Avatar name={user.display_name ?? user.username} />
                  <span className="min-w-0 flex-1">
                    <span className="flex items-center gap-1 truncate text-row font-medium">
                      {user.display_name ?? user.username}
                      {user.is_official ? <OfficialBadge /> : null}
                    </span>
                    <span className="block truncate font-mono text-xs text-muted-foreground">
                      @{user.username}
                    </span>
                  </span>
                  {user.banned ? <span className="text-xs text-danger">{t('community.banned')}</span> : null}
                  {!user.banned && user.muted ? (
                    <span className="text-xs text-warning">{t('community.muted')}</span>
                  ) : null}
                </button>
              </li>
            ))}
          </ul>
        )
      ) : (
        <p className="text-xs text-muted-foreground">{t('community.findUserHint')}</p>
      )}
    </aside>
  )
}

function QueueTabs({
  queues,
  current,
  onChange,
}: {
  queues: ModerationQueue[]
  current: ModerationQueue
  onChange: (queue: ModerationQueue) => void
}) {
  const { t } = useTranslation()
  return (
    <div
      role="tablist"
      aria-label={t('moderation.queuesLabel')}
      className="flex gap-1 overflow-x-auto rounded-lg bg-muted p-1"
    >
      {queues.map((item) => (
        <button
          key={item}
          id={`moderation-queue-${item}`}
          type="button"
          role="tab"
          aria-selected={current === item}
          aria-controls="moderation-queue-panel"
          tabIndex={current === item ? 0 : -1}
          onKeyDown={(event) => {
            if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return
            const index = queues.indexOf(item)
            const next =
              queues[(index + (event.key === 'ArrowRight' ? 1 : queues.length - 1)) % queues.length]
            if (!next) return
            onChange(next)
            document.getElementById(`moderation-queue-${next}`)?.focus()
          }}
          onClick={() => onChange(item)}
          className={cn(
            'inline-flex h-8 shrink-0 items-center rounded-md px-3 text-row whitespace-nowrap transition-colors outline-none focus-visible:ring-2 focus-visible:ring-ring/50',
            current === item
              ? 'bg-background font-medium text-foreground shadow-float'
              : 'text-muted-foreground hover:text-foreground',
          )}
        >
          {t(`moderation.queues.${item}`)}
        </button>
      ))}
    </div>
  )
}

export function ModerationTab({
  queue,
  onQueue,
  onOpenRoom,
}: {
  queue?: ModerationQueue
  onQueue?: (queue: ModerationQueue) => void
  onOpenRoom?: (stock: string) => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const queues = moderationQueuesFor(agent.community_permissions)
  const [local, setLocal] = useState<ModerationQueue>('reports')
  const wanted = queue ?? local
  const current = queues.includes(wanted) ? wanted : (queues[0] ?? 'reports')
  const [userId, setUserId] = useState<string | null>(null)
  const [content, setContent] = useState<ContentTarget | null>(null)
  const openUser = (id: string) => {
    setContent(null)
    setUserId(id)
  }
  const choose = (next: ModerationQueue) => {
    setLocal(next)
    onQueue?.(next)
  }
  return (
    <section className="flex flex-col gap-4" aria-label={t('community.tabs.moderation')}>
      {queues.length > 1 ? <QueueTabs queues={queues} current={current} onChange={choose} /> : null}
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]">
        <div
          id="moderation-queue-panel"
          role={queues.length > 1 ? 'tabpanel' : undefined}
          aria-labelledby={queues.length > 1 ? `moderation-queue-${current}` : undefined}
          className="min-w-0"
        >
          {current === 'reports' ? <ReportsQueue onUser={openUser} onContent={setContent} /> : null}
          {current === 'held' ? <HeldQueue onUser={openUser} onContent={setContent} /> : null}
          {current === 'media' ? <MediaQueue onUser={openUser} onContent={setContent} /> : null}
          {current === 'alerts' ? <AlertsQueue onOpenRoom={onOpenRoom} onContent={setContent} /> : null}
          {current === 'appeals' ? <AppealsQueue onUser={openUser} /> : null}
        </div>
        <FindUser onUser={openUser} />
      </div>
      <UserSheet userId={userId} onClose={() => setUserId(null)} />
      <ContentSheet target={content} onClose={() => setContent(null)} onUser={openUser} />
    </section>
  )
}
