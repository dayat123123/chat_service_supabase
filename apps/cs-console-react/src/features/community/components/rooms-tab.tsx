import { LoaderCircleIcon, PinIcon, PinOffIcon, SearchIcon, TimerIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Dot } from '@/components/badges'
import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Confirm } from '@/features/nasabah/components/confirm'
import { FieldText } from '@/features/system/components/system-ui'
import { moderationErrorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'
import { stamp } from '@/lib/time'

import { usePinMessage, useRoomMessages, useRoomState, useSetSlowMode } from '../hooks'
import {
  cleanStock,
  fromJakartaInput,
  isUuid,
  jakartaInput,
  slowModeProblem,
  stockCodePattern,
} from '../logic'
import { SLOW_MODE_MAX, type RoomMessage, type RoomState } from '../types'
import { EditedMark, QueueHeader } from './moderation-ui'

const presets = [0, 10, 30, 60, 300] as const

function SlowModeForm({ code, state }: { code: string; state: RoomState | null }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSetSlowMode()
  const manual = state?.override?.source === 'manual' ? state.override : null
  const [seconds, setSeconds] = useState(String(manual?.seconds ?? 0))
  const [until, setUntil] = useState(jakartaInput(manual?.until ?? null))
  const [checked, setChecked] = useState(false)
  const value = /^\d+$/.test(seconds.trim()) ? Number(seconds.trim()) : Number.NaN
  const problem = slowModeProblem(value, value === 0 ? '' : until)
  return (
    <form
      className="flex flex-col gap-3"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (problem) return
        const end = value > 0 && until ? fromJakartaInput(until) : null
        save
          .mutateAsync({ code, seconds: value, until: end })
          .then(() => {
            toast.success(
              value === 0
                ? t('moderation.rooms.slowOff', { stock: code })
                : t('moderation.rooms.slowSaved', { stock: code, seconds: value }),
            )
            setChecked(false)
          })
          .catch((error: unknown) => toast.error(moderationErrorText(error)))
      }}
    >
      <div className="flex flex-col gap-1.5">
        <span className="text-sm font-medium" id={`${id}-presets`}>
          {t('moderation.rooms.presets')}
        </span>
        <ToggleGroup
          type="single"
          value={presets.includes(value as (typeof presets)[number]) ? String(value) : ''}
          aria-labelledby={`${id}-presets`}
          className="flex-wrap self-start"
          onValueChange={(next) => next && setSeconds(next)}
        >
          {presets.map((preset) => (
            <ToggleGroupItem key={preset} value={String(preset)}>
              {preset === 0
                ? t('moderation.rooms.off')
                : t('moderation.rooms.secondsShort', { value: preset })}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-seconds`}>{t('moderation.rooms.seconds')}</Label>
          <Input
            id={`${id}-seconds`}
            inputMode="numeric"
            value={seconds}
            aria-invalid={checked && problem === 'seconds' ? true : undefined}
            aria-describedby={`${id}-seconds-text`}
            onChange={(event) => setSeconds(event.target.value)}
          />
          <FieldText
            id={`${id}-seconds-text`}
            error={
              checked && problem === 'seconds'
                ? t('moderation.rooms.secondsProblem', { max: SLOW_MODE_MAX })
                : undefined
            }
            hint={t('moderation.rooms.secondsHint', { max: SLOW_MODE_MAX })}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-until`}>{t('moderation.rooms.until')}</Label>
          <Input
            id={`${id}-until`}
            type="datetime-local"
            value={until}
            disabled={value === 0}
            aria-invalid={checked && problem && problem !== 'seconds' ? true : undefined}
            aria-describedby={`${id}-until-text`}
            onChange={(event) => setUntil(event.target.value)}
          />
          <FieldText
            id={`${id}-until-text`}
            error={
              checked && problem && problem !== 'seconds'
                ? t(`moderation.rooms.untilProblems.${problem}`)
                : undefined
            }
            hint={t('moderation.rooms.untilHint')}
          />
        </div>
      </div>
      <Button type="submit" size="sm" className="self-start" disabled={save.isPending}>
        {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : <TimerIcon />}
        {t('moderation.rooms.saveSlow')}
      </Button>
    </form>
  )
}

function PinForm({ state }: { state: RoomState }) {
  const { t } = useTranslation()
  const id = useId()
  const pin = usePinMessage()
  const [message, setMessage] = useState('')
  const [checked, setChecked] = useState(false)
  const valid = isUuid(message)
  return (
    <form
      className="flex flex-col gap-1.5"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (!valid) return
        pin
          .mutateAsync({ roomId: state.room_id, messageId: message.trim() })
          .then(() => {
            toast.success(t('moderation.rooms.pinned', { stock: state.stock_code }))
            setMessage('')
            setChecked(false)
          })
          .catch((error: unknown) => toast.error(moderationErrorText(error)))
      }}
    >
      <Label htmlFor={`${id}-message`}>{t('moderation.rooms.messageId')}</Label>
      <div className="flex flex-col gap-2 sm:flex-row">
        <Input
          id={`${id}-message`}
          autoComplete="off"
          spellCheck={false}
          className="font-mono sm:max-w-md"
          value={message}
          aria-invalid={checked && !valid ? true : undefined}
          aria-describedby={`${id}-message-text`}
          onChange={(event) => setMessage(event.target.value)}
        />
        <Button
          type="submit"
          size="sm"
          variant="outline"
          className="self-start sm:self-auto"
          disabled={pin.isPending}
        >
          {pin.isPending ? <LoaderCircleIcon className="animate-spin" /> : <PinIcon />}
          {t('moderation.rooms.pin')}
        </Button>
      </div>
      <FieldText
        id={`${id}-message-text`}
        error={checked && !valid ? t('moderation.rooms.messageIdProblem') : undefined}
        hint={t('moderation.rooms.messageIdHint')}
      />
    </form>
  )
}

function RecentMessages({ state }: { state: RoomState }) {
  const { t } = useTranslation()
  const pin = usePinMessage()
  const messages = useRoomMessages(state.stock_code)
  const [replacing, setReplacing] = useState<RoomMessage | null>(null)
  const pinnedId = state.pinned_message?.id ?? null
  const items = messages.data?.pages.flatMap((page) => page.items) ?? []
  const run = (message: RoomMessage) =>
    pin
      .mutateAsync({ roomId: state.room_id, messageId: message.id })
      .then(() => {
        toast.success(t('moderation.rooms.pinned', { stock: state.stock_code }))
        setReplacing(null)
      })
      .catch((error: unknown) => toast.error(moderationErrorText(error)))
  return (
    <div className="flex flex-col gap-2">
      <h4 className="text-xs font-medium text-muted-foreground">{t('moderation.rooms.recentTitle')}</h4>
      {messages.isError ? (
        <p role="alert" className="text-row text-destructive">
          {moderationErrorText(messages.error)}
        </p>
      ) : !messages.data ? (
        <ListSkeleton rows={3} />
      ) : items.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('moderation.rooms.noMessages')}</p>
      ) : (
        <ul
          className="max-h-96 overflow-y-auto rounded-md border"
          aria-label={t('moderation.rooms.recentTitle')}
        >
          {items.map((message) => {
            const visible = message.moderation_status === 'visible'
            const pinned = message.id === pinnedId
            const sender = message.sender.display_name ?? message.sender.username ?? '–'
            return (
              <li key={message.id} className="flex items-start gap-3 border-b px-3 py-2 last:border-b-0">
                <div className="min-w-0 flex-1">
                  <p className="flex flex-wrap items-center gap-1 text-xs text-muted-foreground">
                    <span className="font-medium text-foreground">{sender}</span>
                    {message.sender.username ? (
                      <span className="font-mono">@{message.sender.username}</span>
                    ) : null}
                    <span>· {stamp(message.created_at)}</span>
                    <EditedMark editedAt={message.edited_at} />
                    {message.attachments > 0 ? (
                      <span>· {t('moderation.held.attachments', { count: message.attachments })}</span>
                    ) : null}
                    {visible ? null : (
                      <span className="text-warning">
                        ·{' '}
                        {t(
                          `moderation.content.status.${message.moderation_status === 'held' || message.moderation_status === 'hidden' ? message.moderation_status : 'other'}`,
                        )}
                      </span>
                    )}
                  </p>
                  <p className="line-clamp-3 text-row break-words whitespace-pre-wrap">
                    {message.body || '–'}
                  </p>
                </div>
                {pinned ? (
                  <span className="shrink-0 text-xs font-medium text-success">
                    {t('moderation.rooms.isPinned')}
                  </span>
                ) : (
                  <Button
                    size="xs"
                    variant="outline"
                    className="shrink-0"
                    disabled={!visible || pin.isPending}
                    aria-label={t('moderation.rooms.pinFrom', {
                      name: sender,
                      time: stamp(message.created_at),
                    })}
                    onClick={() => (pinnedId ? setReplacing(message) : void run(message))}
                  >
                    <PinIcon />
                    {t('moderation.rooms.pin')}
                  </Button>
                )}
              </li>
            )
          })}
        </ul>
      )}
      {messages.hasNextPage ? (
        <Button
          size="xs"
          variant="ghost"
          className="self-start"
          disabled={messages.isFetchingNextPage}
          onClick={() => void messages.fetchNextPage()}
        >
          {messages.isFetchingNextPage ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('moderation.loadMore')}
        </Button>
      ) : null}
      <Confirm
        open={replacing !== null}
        title={t('moderation.rooms.replaceTitle', { stock: state.stock_code })}
        body={t('moderation.rooms.replaceBody')}
        action={t('moderation.rooms.pin')}
        pending={pin.isPending}
        onClose={() => setReplacing(null)}
        onConfirm={() => replacing && void run(replacing)}
      />
    </div>
  )
}

function PinnedCard({ state }: { state: RoomState }) {
  const { t } = useTranslation()
  const pin = usePinMessage()
  const [confirming, setConfirming] = useState(false)
  const message = state.pinned_message
  return (
    <section className="flex flex-col gap-3 border-t pt-4" aria-labelledby="room-pinned">
      <h3 id="room-pinned" className="text-sm font-semibold">
        {t('moderation.rooms.pinnedTitle')}
      </h3>
      {message ? (
        <div className="flex flex-col gap-2 rounded-md border p-3">
          <p className="text-xs text-muted-foreground">
            {message.sender_display_name ?? message.sender_username ?? '–'}
            {message.sender_username ? <span className="font-mono"> @{message.sender_username}</span> : null}
            {' · '}
            {stamp(message.created_at)}
          </p>
          <p className="text-row break-words whitespace-pre-wrap">{message.body || '–'}</p>
          <p className="text-xs text-muted-foreground">
            {t('moderation.rooms.pinnedBy', {
              time: state.pinned_at ? stamp(state.pinned_at) : '–',
              name: state.override?.pinned_by?.name ?? '–',
            })}
          </p>
          <Button size="xs" variant="outline" className="self-start" onClick={() => setConfirming(true)}>
            <PinOffIcon />
            {t('moderation.rooms.unpin')}
          </Button>
        </div>
      ) : (
        <p className="text-row text-muted-foreground">{t('moderation.rooms.noPinned')}</p>
      )}
      <RecentMessages state={state} />
      <details className="group rounded-md border px-3 py-2">
        <summary className="cursor-pointer text-xs font-medium text-muted-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring/50">
          {t('moderation.rooms.byId')}
        </summary>
        <div className="pt-3">
          <PinForm state={state} />
        </div>
      </details>
      <Confirm
        open={confirming}
        title={t('moderation.rooms.unpinTitle', { stock: state.stock_code })}
        body={t('moderation.rooms.unpinBody')}
        action={t('moderation.rooms.unpin')}
        pending={pin.isPending}
        onClose={() => setConfirming(false)}
        onConfirm={() =>
          void pin
            .mutateAsync({ roomId: state.room_id, messageId: null })
            .then(() => {
              toast.success(t('moderation.rooms.unpinned', { stock: state.stock_code }))
              setConfirming(false)
            })
            .catch((error: unknown) => toast.error(moderationErrorText(error)))
        }
      />
    </section>
  )
}

function RoomBody({
  code,
  state,
  onOpenAlerts,
}: {
  code: string
  state: RoomState
  onOpenAlerts?: () => void
}) {
  const { t } = useTranslation()
  const slow = state.slow_mode
  const override = state.override
  return (
    <div className="flex flex-col gap-4">
      <section className="flex flex-col gap-2" aria-labelledby="room-status">
        <h3 id="room-status" className="text-sm font-semibold">
          {t('moderation.rooms.statusTitle')}
        </h3>
        <p role="status" className="flex flex-wrap items-center gap-2 text-row">
          <Dot tone={slow.seconds > 0 ? 'warn' : 'ok'} />
          {slow.seconds > 0
            ? slow.until
              ? t('moderation.rooms.slowActiveUntil', {
                  seconds: slow.seconds,
                  time: stamp(slow.until),
                  source: t(`moderation.rooms.sources.${slow.source ?? 'manual'}`),
                })
              : t('moderation.rooms.slowActive', {
                  seconds: slow.seconds,
                  source: t(`moderation.rooms.sources.${slow.source ?? 'manual'}`),
                })
            : t('moderation.rooms.slowInactive')}
        </p>
        {override && override.seconds > 0 ? (
          <p className="text-xs text-muted-foreground">
            {t('moderation.rooms.override', {
              seconds: override.seconds,
              until: override.until ? stamp(override.until) : t('moderation.rooms.permanent'),
              source: t(`moderation.rooms.sources.${override.source ?? 'manual'}`),
              name: override.updated_by?.name ?? t('moderation.rooms.system'),
              time: stamp(override.updated_at),
            })}
          </p>
        ) : null}
        {state.open_alerts.length > 0 ? (
          <div className="flex flex-wrap items-center gap-2 text-xs text-warning">
            {t('moderation.rooms.openAlerts', { count: state.open_alerts.length })}
            {onOpenAlerts ? (
              <Button size="xs" variant="ghost" onClick={onOpenAlerts}>
                {t('moderation.rooms.viewAlerts')}
              </Button>
            ) : null}
          </div>
        ) : null}
      </section>
      <section className="flex flex-col gap-3 border-t pt-4" aria-labelledby="room-slow">
        <h3 id="room-slow" className="text-sm font-semibold">
          {t('moderation.rooms.slowTitle')}
        </h3>
        <p className="max-w-3xl text-xs text-muted-foreground">{t('moderation.rooms.slowHint')}</p>
        <SlowModeForm key={`${code}-${override?.updated_at ?? ''}`} code={code} state={state} />
      </section>
      <PinnedCard state={state} />
    </div>
  )
}

export function RoomsTab({
  stock,
  onStock,
  onOpenAlerts,
}: {
  stock?: string
  onStock?: (stock: string) => void
  onOpenAlerts?: () => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const [local, setLocal] = useState<string | null>(stock ?? null)
  const code = stock ?? local
  const [text, setText] = useState(code ?? '')
  const [checked, setChecked] = useState(false)
  const typed = cleanStock(text)
  const valid = stockCodePattern.test(typed)
  const room = useRoomState(code)
  const missing = room.isError && toApiError(room.error).code === 'room_not_found'
  return (
    <section className="flex flex-col gap-4" aria-label={t('community.tabs.rooms')}>
      <QueueHeader title={t('moderation.rooms.title')} hint={t('moderation.rooms.hint')} />
      <form
        className="flex flex-col gap-1.5"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (!valid) return
          setLocal(typed)
          onStock?.(typed)
        }}
      >
        <Label htmlFor={`${id}-stock`}>{t('moderation.rooms.stock')}</Label>
        <div className="flex gap-2">
          <div className="relative w-full sm:w-56">
            <SearchIcon className="pointer-events-none absolute top-2.5 left-2.5 size-4 text-muted-foreground" />
            <Input
              id={`${id}-stock`}
              autoComplete="off"
              spellCheck={false}
              maxLength={13}
              placeholder="BBCA"
              className="pl-8 font-mono uppercase"
              value={text}
              aria-invalid={checked && !valid ? true : undefined}
              aria-describedby={`${id}-stock-text`}
              onChange={(event) => setText(event.target.value)}
            />
          </div>
          <Button type="submit">{t('moderation.rooms.open')}</Button>
        </div>
        <FieldText
          id={`${id}-stock-text`}
          error={checked && !valid ? t('moderation.rooms.stockProblem') : undefined}
          hint={t('moderation.rooms.stockHint')}
        />
      </form>
      {code === null ? null : room.data ? (
        <div className="flex flex-col gap-1">
          <h2 className="font-mono text-panel font-semibold">${room.data.stock_code}</h2>
          <RoomBody code={code} state={room.data} onOpenAlerts={onOpenAlerts} />
        </div>
      ) : missing ? (
        <div className="flex flex-col gap-3">
          <p className="text-row text-muted-foreground">{t('moderation.rooms.missing', { stock: code })}</p>
          <SlowModeForm key={code} code={code} state={null} />
        </div>
      ) : room.isError ? (
        <ErrorState error={room.error} onRetry={() => void room.refetch()} />
      ) : (
        <ListSkeleton rows={3} />
      )}
      <p className="text-xs text-muted-foreground">{t('moderation.rooms.scheduleNote')}</p>
    </section>
  )
}
