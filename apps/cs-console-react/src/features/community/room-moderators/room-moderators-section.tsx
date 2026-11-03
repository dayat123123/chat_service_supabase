import {
  LoaderCircleIcon,
  SearchIcon,
  ShieldCheckIcon,
  ShieldPlusIcon,
  ShieldXIcon,
  SlidersHorizontalIcon,
  Undo2Icon,
} from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ReasonDialog } from '@/components/reason-dialog'
import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAgent } from '@/features/auth/hooks'
import { FieldText } from '@/features/system/components/system-ui'
import { stamp } from '@/lib/time'

import {
  useAppointRoomModerator,
  useRemoveRoomModerator,
  useRoomModActions,
  useRoomModCandidates,
  useRoomModerators,
  useSaveRoomModSettings,
  useUndoRoomModAction,
} from './hooks'
import {
  actionState,
  canEditRoomModSettings,
  roomModErrorText,
  settingsChanges,
  settingsDraft,
  userLabel,
} from './logic'
import {
  roomModSettingKeys,
  roomModSettingRanges,
  type RoomModAction,
  type RoomModCandidate,
  type RoomModerator,
  type RoomModSettings,
} from './types'

function Criteria({ settings }: { settings: RoomModSettings }) {
  const { t } = useTranslation()
  return (
    <p className="max-w-3xl text-xs text-muted-foreground">
      {t('moderation.roomMods.criteria', {
        trust: settings['room_mods.min_trust_level'],
        days: settings['room_mods.sanction_free_days'],
        perRoom: settings['room_mods.max_per_room'],
        perUser: settings['room_mods.max_rooms_per_user'],
        hours: settings['room_mods.max_mute_hours'],
      })}
    </p>
  )
}

function ModeratorRow({ moderator, onRemove }: { moderator: RoomModerator; onRemove?: () => void }) {
  const { t } = useTranslation()
  const user = moderator.user
  return (
    <li className="flex flex-wrap items-start gap-3 border-b px-3 py-2 last:border-b-0">
      <div className="min-w-0 flex-1">
        <p className="flex flex-wrap items-center gap-1 text-row">
          <ShieldCheckIcon className="size-4 text-success" aria-hidden />
          <span className="font-medium">{userLabel(user)}</span>
          {user.username ? (
            <span className="font-mono text-xs text-muted-foreground">@{user.username}</span>
          ) : null}
          <span className="text-xs text-muted-foreground">
            · {t('moderation.roomMods.trust', { level: user.trust_level })}
          </span>
        </p>
        <p className="text-xs text-muted-foreground">
          {moderator.removed_at
            ? t('moderation.roomMods.removedBy', {
                name: moderator.removed_by?.name ?? t('moderation.roomMods.system'),
                time: stamp(moderator.removed_at),
                reason: moderator.remove_reason ?? '–',
              })
            : t('moderation.roomMods.appointedBy', {
                name: moderator.appointed_by?.name ?? '–',
                time: stamp(moderator.appointed_at),
              })}
        </p>
        {moderator.note ? <p className="text-xs break-words whitespace-pre-wrap">{moderator.note}</p> : null}
        {moderator.removed_at ? null : (
          <p className="text-xs text-muted-foreground">
            {t('moderation.roomMods.activity', { count: moderator.actions_7d, undone: moderator.undone_7d })}
          </p>
        )}
        {!moderator.removed_at && moderator.problems.length > 0 ? (
          <p className="text-xs text-warning">
            {t('moderation.roomMods.suspended', {
              reasons: moderator.problems
                .map((problem) => t(`moderation.roomMods.problems.${problem}`))
                .join(', '),
            })}
          </p>
        ) : null}
      </div>
      {onRemove ? (
        <Button
          size="xs"
          variant="outline"
          className="shrink-0"
          aria-label={t('moderation.roomMods.removeFor', { name: userLabel(user) })}
          onClick={onRemove}
        >
          <ShieldXIcon />
          {t('moderation.roomMods.remove')}
        </Button>
      ) : null}
    </li>
  )
}

function CandidateRow({ candidate, onAppoint }: { candidate: RoomModCandidate; onAppoint: () => void }) {
  const { t } = useTranslation()
  const blocked = !candidate.eligible || candidate.is_moderator
  return (
    <li className="flex flex-wrap items-start gap-3 border-b px-3 py-2 last:border-b-0">
      <div className="min-w-0 flex-1">
        <p className="flex flex-wrap items-center gap-1 text-row">
          <span className="font-medium">{userLabel(candidate)}</span>
          {candidate.username ? (
            <span className="font-mono text-xs text-muted-foreground">@{candidate.username}</span>
          ) : null}
          <span className="text-xs text-muted-foreground">
            · {t('moderation.roomMods.trust', { level: candidate.trust_level })}
          </span>
        </p>
        <p className={candidate.eligible ? 'text-xs text-muted-foreground' : 'text-xs text-warning'}>
          {candidate.is_moderator
            ? t('moderation.roomMods.alreadyHere')
            : candidate.eligible
              ? t('moderation.roomMods.eligible', { count: candidate.moderated_rooms })
              : t('moderation.roomMods.notEligible', {
                  reasons: candidate.problems
                    .map((problem) => t(`moderation.roomMods.problems.${problem}`))
                    .join(', '),
                })}
        </p>
      </div>
      <Button
        size="xs"
        variant="outline"
        className="shrink-0"
        disabled={blocked}
        aria-label={t('moderation.roomMods.appointFor', { name: userLabel(candidate) })}
        onClick={onAppoint}
      >
        <ShieldPlusIcon />
        {t('moderation.roomMods.appoint')}
      </Button>
    </li>
  )
}

function AppointForm({ code }: { code: string }) {
  const { t } = useTranslation()
  const id = useId()
  const [query, setQuery] = useState('')
  const [picked, setPicked] = useState<RoomModCandidate | null>(null)
  const candidates = useRoomModCandidates(code, query)
  const appoint = useAppointRoomModerator()
  const text = query.trim()
  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor={`${id}-query`}>{t('moderation.roomMods.search')}</Label>
      <div className="relative w-full sm:max-w-sm">
        <SearchIcon className="pointer-events-none absolute top-2.5 left-2.5 size-4 text-muted-foreground" />
        <Input
          id={`${id}-query`}
          type="search"
          autoComplete="off"
          spellCheck={false}
          maxLength={60}
          className="pl-8"
          value={query}
          aria-describedby={`${id}-query-text`}
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      <FieldText id={`${id}-query-text`} hint={t('moderation.roomMods.searchHint')} />
      {text.length < 2 ? null : candidates.isError ? (
        <p role="alert" className="text-row text-destructive">
          {roomModErrorText(candidates.error)}
        </p>
      ) : !candidates.data ? (
        <ListSkeleton rows={2} />
      ) : candidates.data.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('moderation.roomMods.noCandidates')}</p>
      ) : (
        <ul
          className="max-h-72 overflow-y-auto rounded-md border"
          aria-label={t('moderation.roomMods.candidates')}
        >
          {candidates.data.map((candidate) => (
            <CandidateRow key={candidate.id} candidate={candidate} onAppoint={() => setPicked(candidate)} />
          ))}
        </ul>
      )}
      <ReasonDialog
        open={picked !== null}
        title={t('moderation.roomMods.appointTitle', { name: userLabel(picked), stock: code })}
        description={t('moderation.roomMods.appointBody')}
        label={t('moderation.roomMods.noteLabel')}
        hint={t('moderation.roomMods.noteHint')}
        action={t('moderation.roomMods.appoint')}
        optional
        min={0}
        pending={appoint.isPending}
        onClose={() => setPicked(null)}
        onSubmit={(note) =>
          picked &&
          void appoint
            .mutateAsync({ code, userId: picked.id, note: note || null })
            .then(() => {
              toast.success(t('moderation.roomMods.appointed', { name: userLabel(picked), stock: code }))
              setPicked(null)
              setQuery('')
            })
            .catch((error: unknown) => toast.error(roomModErrorText(error)))
        }
      />
    </div>
  )
}

function ActionRow({
  action,
  showStock,
  onUndo,
}: {
  action: RoomModAction
  showStock: boolean
  onUndo?: () => void
}) {
  const { t } = useTranslation()
  const state = actionState(action)
  return (
    <li className="flex flex-wrap items-start gap-3 border-b px-3 py-2 last:border-b-0">
      <div className="min-w-0 flex-1">
        <p className="flex flex-wrap items-center gap-1 text-xs text-muted-foreground">
          <span className="font-medium text-foreground">
            {t(`moderation.roomMods.actions.${action.action}`)}
          </span>
          <span>· {t(`moderation.roomMods.reasons.${action.reason}`, { defaultValue: action.reason })}</span>
          {showStock && action.stock_code ? <span className="font-mono">· ${action.stock_code}</span> : null}
          <span>· {stamp(action.created_at)}</span>
        </p>
        <p className="text-xs text-muted-foreground">
          {t('moderation.roomMods.byOn', {
            moderator: userLabel(action.moderator),
            target: userLabel(action.target),
          })}
          {action.moderator && !action.moderator_active
            ? ` · ${t('moderation.roomMods.formerModerator')}`
            : ''}
        </p>
        {action.message ? (
          <p className="line-clamp-2 text-row break-words whitespace-pre-wrap">
            {action.message.deleted ? t('moderation.roomMods.messageDeleted') : action.message.excerpt || '–'}
          </p>
        ) : null}
        {action.note ? (
          <p className="text-xs break-words text-muted-foreground">
            {t('moderation.roomMods.note', { note: action.note })}
          </p>
        ) : null}
        <p className={state === 'undone' ? 'text-xs text-warning' : 'text-xs text-muted-foreground'}>
          {state === 'undone'
            ? t('moderation.roomMods.undoneBy', {
                name: action.undone_by?.name ?? '–',
                time: stamp(action.undone_at ?? action.created_at),
                note: action.undo_note ?? '–',
              })
            : action.action === 'mute' && action.mute_until
              ? t(state === 'active' ? 'moderation.roomMods.mutedUntil' : 'moderation.roomMods.muteEnded', {
                  time: stamp(action.mute_until),
                })
              : action.action === 'escalate'
                ? t('moderation.roomMods.reportStatus', {
                    status: t(`moderation.roomMods.reportStatuses.${action.report?.status ?? 'open'}`, {
                      defaultValue: action.report?.status ?? '–',
                    }),
                  })
                : state === 'active'
                  ? t('moderation.roomMods.hiddenNow')
                  : t('moderation.roomMods.hiddenEnded')}
          {action.appeal
            ? ` · ${t('moderation.roomMods.appeal', {
                status: t(`moderation.roomMods.appealStatuses.${action.appeal.status}`, {
                  defaultValue: action.appeal.status,
                }),
              })}`
            : ''}
        </p>
      </div>
      {onUndo ? (
        <Button
          size="xs"
          variant="outline"
          className="shrink-0"
          aria-label={t('moderation.roomMods.undoFor', {
            action: t(`moderation.roomMods.actions.${action.action}`),
            time: stamp(action.created_at),
          })}
          onClick={onUndo}
        >
          <Undo2Icon />
          {t('moderation.roomMods.undo')}
        </Button>
      ) : null}
    </li>
  )
}

function ActionLog({ code }: { code: string }) {
  const { t } = useTranslation()
  const id = useId()
  const [scope, setScope] = useState<'room' | 'all'>('room')
  const actions = useRoomModActions(scope === 'room' ? code : null)
  const undo = useUndoRoomModAction()
  const [target, setTarget] = useState<RoomModAction | null>(null)
  const items = actions.data?.pages.flatMap((page) => page.items) ?? []
  return (
    <section className="flex flex-col gap-2 border-t pt-4" aria-labelledby={`${id}-log`}>
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h3 id={`${id}-log`} className="text-sm font-semibold">
          {t('moderation.roomMods.logTitle')}
        </h3>
        <ToggleGroup
          type="single"
          value={scope}
          aria-label={t('moderation.roomMods.scope')}
          onValueChange={(next) => (next === 'room' || next === 'all') && setScope(next)}
        >
          <ToggleGroupItem value="room">
            {t('moderation.roomMods.scopeRoom', { stock: code })}
          </ToggleGroupItem>
          <ToggleGroupItem value="all">{t('moderation.roomMods.scopeAll')}</ToggleGroupItem>
        </ToggleGroup>
      </div>
      <p className="max-w-3xl text-xs text-muted-foreground">{t('moderation.roomMods.logHint')}</p>
      {actions.isError ? (
        <ErrorState error={actions.error} onRetry={() => void actions.refetch()} />
      ) : !actions.data ? (
        <ListSkeleton rows={3} />
      ) : items.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('moderation.roomMods.noActions')}</p>
      ) : (
        <ul
          className="max-h-[28rem] overflow-y-auto rounded-md border"
          aria-label={t('moderation.roomMods.logTitle')}
        >
          {items.map((action) => (
            <ActionRow
              key={action.id}
              action={action}
              showStock={scope === 'all'}
              onUndo={action.can_undo ? () => setTarget(action) : undefined}
            />
          ))}
        </ul>
      )}
      {actions.hasNextPage ? (
        <Button
          size="xs"
          variant="ghost"
          className="self-start"
          disabled={actions.isFetchingNextPage}
          onClick={() => void actions.fetchNextPage()}
        >
          {actions.isFetchingNextPage ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('moderation.loadMore')}
        </Button>
      ) : null}
      <ReasonDialog
        open={target !== null}
        title={t(
          target?.action === 'mute'
            ? 'moderation.roomMods.undoMuteTitle'
            : 'moderation.roomMods.undoHideTitle',
          {
            name: userLabel(target?.target ?? null),
          },
        )}
        description={t(
          target?.action === 'mute' ? 'moderation.roomMods.undoMuteBody' : 'moderation.roomMods.undoHideBody',
        )}
        label={t('moderation.roomMods.undoNote')}
        action={t('moderation.roomMods.undo')}
        pending={undo.isPending}
        onClose={() => setTarget(null)}
        onSubmit={(note) =>
          target &&
          void undo
            .mutateAsync({ id: target.id, note })
            .then(() => {
              toast.success(t('moderation.roomMods.undone'))
              setTarget(null)
            })
            .catch((error: unknown) => toast.error(roomModErrorText(error)))
        }
      />
    </section>
  )
}

function SettingsForm({ settings }: { settings: RoomModSettings }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSaveRoomModSettings()
  const [draft, setDraft] = useState(() => settingsDraft(settings))
  const [checked, setChecked] = useState(false)
  const { changes, invalid } = settingsChanges(settings, draft)
  return (
    <form
      className="flex flex-col gap-3 pt-3"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (invalid.length > 0 || Object.keys(changes).length === 0) return
        save
          .mutateAsync(changes)
          .then(() => {
            toast.success(t('moderation.roomMods.settingsSaved'))
            setChecked(false)
          })
          .catch((error: unknown) => toast.error(roomModErrorText(error)))
      }}
    >
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {roomModSettingKeys.map((key) => {
          const [min, max] = roomModSettingRanges[key]
          const field = `${id}-${key.replace('.', '-')}`
          const bad = checked && invalid.includes(key)
          return (
            <div key={key} className="flex flex-col gap-1.5">
              <Label htmlFor={field}>
                {t(`moderation.roomMods.settings.${key.replace('room_mods.', '') as SettingName}`)}
              </Label>
              <Input
                id={field}
                inputMode="numeric"
                value={draft[key]}
                aria-invalid={bad ? true : undefined}
                aria-describedby={`${field}-text`}
                onChange={(event) => setDraft({ ...draft, [key]: event.target.value })}
              />
              <FieldText
                id={`${field}-text`}
                error={bad ? t('moderation.roomMods.rangeProblem', { min, max }) : undefined}
                hint={t('moderation.roomMods.range', { min, max })}
              />
            </div>
          )
        })}
      </div>
      <Button
        type="submit"
        size="sm"
        className="self-start"
        disabled={save.isPending || (checked && invalid.length === 0 && Object.keys(changes).length === 0)}
      >
        {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : <SlidersHorizontalIcon />}
        {t('moderation.roomMods.saveSettings')}
      </Button>
    </form>
  )
}

type SettingName =
  'min_trust_level' | 'sanction_free_days' | 'max_mute_hours' | 'max_per_room' | 'max_rooms_per_user'

export function RoomModeratorsSection({ code }: { code: string }) {
  const { t } = useTranslation()
  const id = useId()
  const agent = useAgent()
  const list = useRoomModerators(code)
  const remove = useRemoveRoomModerator()
  const [removing, setRemoving] = useState<RoomModerator | null>(null)
  const data = list.data
  return (
    <section className="flex flex-col gap-3 border-t pt-4" aria-labelledby={`${id}-title`}>
      <h3 id={`${id}-title`} className="text-sm font-semibold">
        {t('moderation.roomMods.title')}
      </h3>
      <p className="max-w-3xl text-xs text-muted-foreground">{t('moderation.roomMods.hint')}</p>
      {list.isError ? (
        <ErrorState error={list.error} onRetry={() => void list.refetch()} />
      ) : !data ? (
        <ListSkeleton rows={2} />
      ) : (
        <>
          <Criteria settings={data.settings} />
          {data.moderators.length === 0 ? (
            <p className="text-row text-muted-foreground">{t('moderation.roomMods.empty')}</p>
          ) : (
            <ul className="rounded-md border" aria-label={t('moderation.roomMods.activeList')}>
              {data.moderators.map((moderator) => (
                <ModeratorRow
                  key={moderator.id}
                  moderator={moderator}
                  onRemove={() => setRemoving(moderator)}
                />
              ))}
            </ul>
          )}
          <AppointForm code={code} />
          {data.removed.length > 0 ? (
            <details className="rounded-md border px-3 py-2">
              <summary className="cursor-pointer text-xs font-medium text-muted-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring/50">
                {t('moderation.roomMods.history', { count: data.removed.length })}
              </summary>
              <ul className="pt-2">
                {data.removed.map((moderator) => (
                  <ModeratorRow key={moderator.id} moderator={moderator} />
                ))}
              </ul>
            </details>
          ) : null}
          {agent && canEditRoomModSettings(agent.roles) ? (
            <details className="rounded-md border px-3 py-2">
              <summary className="cursor-pointer text-xs font-medium text-muted-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring/50">
                {t('moderation.roomMods.settingsTitle')}
              </summary>
              <SettingsForm key={JSON.stringify(data.settings)} settings={data.settings} />
            </details>
          ) : null}
        </>
      )}
      <ActionLog code={code} />
      <ReasonDialog
        open={removing !== null}
        title={t('moderation.roomMods.removeTitle', { name: userLabel(removing?.user ?? null), stock: code })}
        description={t('moderation.roomMods.removeBody')}
        label={t('moderation.roomMods.removeReason')}
        action={t('moderation.roomMods.remove')}
        destructive
        pending={remove.isPending}
        onClose={() => setRemoving(null)}
        onSubmit={(reason) =>
          removing &&
          void remove
            .mutateAsync({ code, userId: removing.user.id, reason })
            .then(() => {
              toast.success(t('moderation.roomMods.removed', { name: userLabel(removing.user), stock: code }))
              setRemoving(null)
            })
            .catch((error: unknown) => toast.error(roomModErrorText(error)))
        }
      />
    </section>
  )
}
