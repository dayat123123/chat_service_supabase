import { BadgeCheckIcon, LoaderCircleIcon, SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  ToggleGroup,
  ToggleGroupItem,
} from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Avatar } from '@/components/ui/primitives'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { Textarea } from '@/components/ui/textarea'
import { useAgent } from '@/features/auth/hooks'
import { useDebounced } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'
import { formatNumber, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import {
  useCommunityUser,
  useFindUsers,
  useResolveReport,
  useReports,
  useRevokeSanction,
  useRevokeSessions,
  useSanction,
} from '../hooks'
import { reportStatuses, type ReportAction, type ReportRow, type ReportStatus } from '../types'
import { OfficialBadge, ReasonDialog } from './shared'

const sanctionChoices = [
  { value: 'ladder', kind: null, hours: null },
  { value: 'warning', kind: 'warning', hours: null },
  { value: 'mute24', kind: 'mute', hours: 24 },
  { value: 'mute168', kind: 'mute', hours: 168 },
  { value: 'ban7', kind: 'ban', hours: 168 },
  { value: 'ban', kind: 'ban', hours: null },
] as const

type SanctionChoice = (typeof sanctionChoices)[number]['value']

function SanctionDialog({ userId, name, onClose }: { userId: string; name: string; onClose: () => void }) {
  const { t } = useTranslation()
  const sanction = useSanction()
  const [choice, setChoice] = useState<SanctionChoice>('ladder')
  const [reason, setReason] = useState('')
  const [touched, setTouched] = useState(false)
  const valid = reason.trim().length >= 5 && reason.trim().length <= 500
  const picked = sanctionChoices.find((item) => item.value === choice) ?? sanctionChoices[0]
  return (
    <Dialog open onOpenChange={(next) => !next && !sanction.isPending && onClose()}>
      <DialogContent className="sm:max-w-md" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('community.sanctionTitle', { name })}</DialogTitle>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          onSubmit={(event) => {
            event.preventDefault()
            setTouched(true)
            if (!valid) return
            void sanction
              .mutateAsync({ id: userId, reason: reason.trim(), kind: picked.kind, hours: picked.hours })
              .then(() => {
                toast.success(t('community.sanctioned'))
                onClose()
              })
              .catch((error: unknown) => toast.error(errorText(error)))
          }}
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="sanction-kind">{t('community.sanctionKind')}</Label>
            <Select value={choice} onValueChange={(value) => setChoice(value as SanctionChoice)}>
              <SelectTrigger id="sanction-kind" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {sanctionChoices.map((item) => (
                  <SelectItem key={item.value} value={item.value}>
                    {t(`community.sanctionChoices.${item.value}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="sanction-reason">{t('community.reason')}</Label>
            <Textarea
              id="sanction-reason"
              rows={3}
              maxLength={500}
              value={reason}
              aria-invalid={touched && !valid ? true : undefined}
              onChange={(event) => setReason(event.target.value)}
            />
            <p className={cn('text-xs', touched && !valid ? 'text-destructive' : 'text-muted-foreground')}>
              {t('community.reasonHint')}
            </p>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" disabled={sanction.isPending} onClick={onClose}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" variant="destructive" disabled={sanction.isPending}>
              {sanction.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('community.applySanction')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function UserDetail({ userId }: { userId: string }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const user = useCommunityUser(userId)
  const revoke = useRevokeSanction()
  const sessions = useRevokeSessions()
  const [sanctioning, setSanctioning] = useState(false)
  const [revoking, setRevoking] = useState<string | null>(null)
  const [signingOut, setSigningOut] = useState(false)
  const canSanction = agent.community_permissions.includes('community.sanction')
  if (user.isError) return <ErrorState error={user.error} onRetry={() => void user.refetch()} />
  if (!user.data) return <ListSkeleton rows={6} className="pt-10" />
  const { profile, counts } = user.data
  const name = profile.display_name ?? profile.username
  const protectedAccount = profile.is_official || profile.is_staff
  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex items-center gap-3 border-b px-5 pt-4 pr-12 pb-3">
        <Avatar name={name} className="size-9 text-xs" />
        <div className="min-w-0">
          <p className="flex items-center gap-1.5 truncate text-panel font-medium">
            {name}
            {profile.is_verified && !profile.is_official ? (
              <BadgeCheckIcon className="size-4 text-primary" aria-label={t('community.verified')} />
            ) : null}
            {profile.is_official ? <OfficialBadge /> : null}
          </p>
          <p className="truncate font-mono text-xs text-muted-foreground">@{profile.username}</p>
        </div>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <dl className="grid grid-cols-2 gap-x-4 gap-y-3 border-b px-5 py-4 sm:grid-cols-4">
          {(
            [
              ['posts', counts.posts],
              ['comments', counts.comments],
              ['reportsAgainst', counts.reports_against],
              ['reportsMade', counts.reports_made],
            ] as const
          ).map(([key, value]) => (
            <div key={key}>
              <dt className="text-xs text-muted-foreground">{t(`community.counts.${key}`)}</dt>
              <dd className="tabular text-row font-medium">{formatNumber(value)}</dd>
            </div>
          ))}
        </dl>
        <div className="flex flex-wrap items-center gap-2 border-b px-5 py-3 text-xs text-muted-foreground">
          <span>{t('community.joined', { time: stamp(profile.created_at) })}</span>
          <span>· {t('community.trust', { level: profile.trust_level })}</span>
          {profile.banned ? <span className="font-medium text-danger">· {t('community.banned')}</span> : null}
          {profile.muted ? <span className="font-medium text-warning">· {t('community.muted')}</span> : null}
        </div>
        {canSanction && !protectedAccount ? (
          <div className="flex flex-wrap gap-2 border-b px-5 py-3">
            <Button size="sm" variant="destructive" onClick={() => setSanctioning(true)}>
              {t('community.applySanction')}
            </Button>
            <Button size="sm" variant="outline" onClick={() => setSigningOut(true)}>
              {t('community.revokeSessions')}
            </Button>
          </div>
        ) : null}
        <section className="border-b px-5 py-3" aria-labelledby="user-sanctions">
          <h3 id="user-sanctions" className="mb-1 text-xs font-medium text-muted-foreground">
            {t('community.sanctions')}
          </h3>
          {user.data.sanctions.length === 0 ? (
            <p className="text-row text-muted-foreground">{t('community.noSanctions')}</p>
          ) : (
            <ul>
              {user.data.sanctions.map((item) => (
                <li
                  key={item.id}
                  className="flex items-start justify-between gap-3 border-b py-2 last:border-b-0"
                >
                  <div className="min-w-0">
                    <p className="text-row font-medium">
                      {t(`community.sanctionKinds.${item.kind}`)}
                      {item.active ? (
                        <span className="ml-2 text-xs text-danger">{t('community.active')}</span>
                      ) : null}
                    </p>
                    <p className="text-xs break-words text-muted-foreground">
                      {[
                        stamp(item.created_at),
                        item.ends_at ? t('community.until', { time: stamp(item.ends_at) }) : null,
                        item.created_by,
                        item.reason,
                        item.revoked_at ? t('community.revokedAt', { time: stamp(item.revoked_at) }) : null,
                      ]
                        .filter(Boolean)
                        .join(' · ')}
                    </p>
                  </div>
                  {canSanction && item.active ? (
                    <Button size="xs" variant="ghost" onClick={() => setRevoking(item.id)}>
                      {t('community.revoke')}
                    </Button>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
        </section>
        <section className="px-5 py-3" aria-labelledby="user-posts">
          <h3 id="user-posts" className="mb-1 text-xs font-medium text-muted-foreground">
            {t('community.recentPosts')}
          </h3>
          {user.data.recent_posts.length + user.data.recent_comments.length === 0 ? (
            <p className="text-row text-muted-foreground">{t('community.noContent')}</p>
          ) : (
            <ul>
              {[...user.data.recent_posts, ...user.data.recent_comments]
                .sort((a, b) => b.created_at.localeCompare(a.created_at))
                .slice(0, 12)
                .map((item) => (
                  <li key={item.id} className="border-b py-2 last:border-b-0">
                    <p className="text-row break-words">{item.body || '–'}</p>
                    <p className="text-xs text-muted-foreground">
                      {stamp(item.created_at)}
                      {'post_id' in item ? ` · ${t('community.comment')}` : ''}
                      {item.moderation_status !== 'visible'
                        ? ` · ${t(`community.moderation.${item.moderation_status === 'hidden' ? 'hidden' : 'held'}`)}`
                        : ''}
                    </p>
                  </li>
                ))}
            </ul>
          )}
        </section>
      </div>
      {sanctioning ? (
        <SanctionDialog userId={userId} name={name} onClose={() => setSanctioning(false)} />
      ) : null}
      <ReasonDialog
        open={revoking !== null}
        title={t('community.revokeTitle')}
        label={t('community.reason')}
        action={t('community.revoke')}
        pending={revoke.isPending}
        onClose={() => setRevoking(null)}
        onSubmit={(reason) =>
          void revoke
            .mutateAsync({ id: revoking ?? '', reason })
            .then(() => {
              setRevoking(null)
              toast.success(t('community.revoked'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
      />
      <ReasonDialog
        open={signingOut}
        title={t('community.revokeSessionsTitle', { name })}
        description={t('community.revokeSessionsBody')}
        label={t('community.reason')}
        action={t('community.revokeSessions')}
        destructive
        pending={sessions.isPending}
        onClose={() => setSigningOut(false)}
        onSubmit={(reason) =>
          void sessions
            .mutateAsync({ id: userId, reason })
            .then(() => {
              setSigningOut(false)
              toast.success(t('community.sessionsRevoked'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }
      />
    </div>
  )
}

export function UserSheet({ userId, onClose }: { userId: string | null; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Sheet open={userId !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('community.userDetail')}
        closeLabel={t('app.close')}
        className="w-[min(560px,100vw)] bg-background"
      >
        {userId ? <UserDetail key={userId} userId={userId} /> : null}
      </SheetContent>
    </Sheet>
  )
}

const actionsFor = (row: ReportRow): ReportAction[] => {
  if (row.target_type === 'user') return ['dismiss']
  if (row.target_status === 'removed') return ['dismiss']
  if (row.target_status === 'hidden') return ['restore', 'remove', 'dismiss']
  return ['hide', 'remove', 'dismiss']
}

function ReportItem({
  row,
  canAct,
  onUser,
  onAct,
}: {
  row: ReportRow
  canAct: boolean
  onUser: (id: string) => void
  onAct: (action: ReportAction) => void
}) {
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
        {canAct ? (
          <div className="flex flex-wrap gap-1.5">
            {actionsFor(row).map((action) => (
              <Button
                key={action}
                size="xs"
                variant={action === 'remove' ? 'destructive' : action === 'dismiss' ? 'ghost' : 'outline'}
                onClick={() => onAct(action)}
              >
                {t(`community.reportActions.${action}`)}
              </Button>
            ))}
          </div>
        ) : null}
      </div>
    </li>
  )
}

export function ModerationTab() {
  const { t } = useTranslation()
  const agent = useAgent()
  const [status, setStatus] = useState<ReportStatus>('open')
  const reports = useReports(status)
  const resolve = useResolveReport()
  const [query, setQuery] = useState('')
  const search = useDebounced(query, 300)
  const users = useFindUsers(search)
  const [userId, setUserId] = useState<string | null>(null)
  const [acting, setActing] = useState<{ row: ReportRow; action: ReportAction } | null>(null)
  const canModerate = agent.community_permissions.includes('community.moderate')

  return (
    <section
      className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_320px]"
      aria-label={t('community.tabs.moderation')}
    >
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
                onUser={setUserId}
                onAct={(action) => setActing({ row, action })}
              />
            ))}
          </ul>
        )}
      </div>
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
                    onClick={() => setUserId(user.id)}
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
                    {user.banned ? (
                      <span className="text-xs text-danger">{t('community.banned')}</span>
                    ) : null}
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
      <UserSheet userId={userId} onClose={() => setUserId(null)} />
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
    </section>
  )
}
