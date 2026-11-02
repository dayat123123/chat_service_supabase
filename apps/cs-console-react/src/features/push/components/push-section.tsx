import {
  CircleAlertIcon,
  CircleCheckIcon,
  LoaderCircleIcon,
  SearchIcon,
  SendIcon,
  ServerOffIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { MetricStrip } from '@/components/metric-strip'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Avatar } from '@/components/ui/primitives'
import { QueryContent, SectionFrame, SettingsCard } from '@/features/settings/components/settings-ui'
import { useDebounced } from '@/hooks/use-now'
import { errorText } from '@/lib/error-text'
import { formatNumber, minutesSince, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { credentialsLoading, usePushStatus, usePushTest, usePushUsers, useSyncPushReady } from '../hooks'
import type { PushDevice, PushStatus, PushUser } from '../types'
import { CredentialsCard } from './credentials-card'
import { PushStateBadge } from './push-state'

const QUEUE_LATE_MINUTES = 5

function StateMessage({ status }: { status: PushStatus }) {
  const { t } = useTranslation()
  const live = status.instances.filter((instance) => instance.live)
  const project = live.find((instance) => instance.project_id)?.project_id
  const error = live.find((instance) => instance.error)?.error
  const loading = status.state !== 'offline' && credentialsLoading(status)
  const Icon = loading
    ? LoaderCircleIcon
    : status.state === 'active'
      ? CircleCheckIcon
      : status.state === 'offline'
        ? ServerOffIcon
        : CircleAlertIcon
  return (
    <div className="flex flex-col gap-2">
      <p
        role="status"
        className={cn(
          'flex items-start gap-2 text-row',
          loading && 'text-muted-foreground',
          !loading && status.state === 'active' && 'text-success',
          !loading && status.state === 'not_configured' && 'text-warning',
          !loading && (status.state === 'error' || status.state === 'offline') && 'text-destructive',
        )}
      >
        <Icon className={cn('mt-0.5 size-4 shrink-0', loading && 'animate-spin')} aria-hidden="true" />
        <span>
          {loading
            ? t(status.credentials ? 'push.stateMessage.loading' : 'push.stateMessage.unloading')
            : t(`push.stateMessage.${status.state}`, { project: project ?? '-', error: error ?? '-' })}
        </span>
      </p>
      {live.length > 0 ? (
        <ul className="flex flex-col gap-0.5 text-xs text-muted-foreground">
          {live.map((instance) => (
            <li key={instance.instance} className="font-mono">
              {t('push.instance', {
                name: instance.instance,
                version: instance.version ?? '-',
                time: stamp(instance.seen_at),
              })}
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  )
}

function Metrics({ status }: { status: PushStatus }) {
  const { t } = useTranslation()
  const waiting = minutesSince(status.queue.oldest_at) ?? 0
  return (
    <MetricStrip
      metrics={[
        {
          label: t('push.metrics.devices'),
          value: formatNumber(status.devices.total),
          caption: t('push.metrics.platforms', {
            android: formatNumber(status.devices.android),
            ios: formatNumber(status.devices.ios),
            web: formatNumber(status.devices.web),
          }),
        },
        {
          label: t('push.metrics.users'),
          value: formatNumber(status.devices.users),
          caption: t('push.metrics.active30', { count: status.devices.active_30d }),
        },
        {
          label: t('push.metrics.sent'),
          value: formatNumber(status.last_24h.sent),
          caption: status.last_sent_at
            ? t('push.metrics.lastSent', { time: stamp(status.last_sent_at) })
            : t('push.metrics.neverSent'),
        },
        {
          label: t('push.metrics.failed'),
          value: formatNumber(status.last_24h.failed),
          tone: status.last_24h.failed > 0 ? 'warn' : undefined,
          caption: t('push.metrics.failedCaption', {
            invalid: formatNumber(status.last_24h.invalid),
            expired: formatNumber(status.last_24h.expired),
          }),
        },
        {
          label: t('push.metrics.queued'),
          value: formatNumber(status.queue.queued),
          tone: status.queue.queued > 0 && waiting >= QUEUE_LATE_MINUTES ? 'late' : undefined,
          caption: status.queue.oldest_at
            ? t('push.metrics.oldest', { time: stamp(status.queue.oldest_at) })
            : t('push.metrics.empty'),
        },
      ]}
    />
  )
}

function DeviceList({ devices }: { devices: PushDevice[] }) {
  const { t } = useTranslation()
  return (
    <span className="flex flex-col text-xs text-muted-foreground">
      {devices.map((device, index) => (
        <span key={`${device.platform}-${index}`} className="truncate">
          {[t(`push.platforms.${device.platform}`), device.app_version, stamp(device.last_seen_at)]
            .filter(Boolean)
            .join(' · ')}
        </span>
      ))}
    </span>
  )
}

function TestRow({ user, disabled }: { user: PushUser; disabled: boolean }) {
  const { t } = useTranslation()
  const test = usePushTest()
  const name = user.display_name ?? user.username
  return (
    <li className="flex flex-wrap items-center gap-2 border-b px-1 py-2">
      <Avatar name={name} />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-row font-medium">
          {name} <span className="font-mono text-xs font-normal text-muted-foreground">@{user.username}</span>
        </span>
        <DeviceList devices={user.devices} />
      </span>
      <Button
        size="xs"
        variant="outline"
        disabled={disabled || test.isPending}
        aria-label={t('push.testFor', { name })}
        onClick={() =>
          void test
            .mutateAsync(user.id)
            .then((result) => toast.success(t('push.testSent', { count: result.queued })))
            .catch((error: unknown) => toast.error(errorText(error)))
        }
      >
        {test.isPending ? <LoaderCircleIcon className="animate-spin" /> : <SendIcon />}
        {t('push.test')}
      </Button>
    </li>
  )
}

function TestCard({ active }: { active: boolean }) {
  const { t } = useTranslation()
  const [query, setQuery] = useState('')
  const search = useDebounced(query, 300)
  const users = usePushUsers(search)
  const ready = search.trim().replace(/^@/, '').length >= 2
  return (
    <SettingsCard title={t('push.testTitle')} subtitle={t('push.testHint')}>
      {!active ? <p className="text-row text-muted-foreground">{t('push.testInactive')}</p> : null}
      <div className="relative w-full sm:w-80">
        <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
        <Input
          type="search"
          value={query}
          maxLength={60}
          placeholder={t('push.searchPlaceholder')}
          aria-label={t('push.search')}
          className="h-8 pl-8"
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      {ready ? (
        users.data && users.data.length === 0 ? (
          <p className="text-row text-muted-foreground">{t('push.noUsers')}</p>
        ) : (
          <ul className="border-t">
            {(users.data ?? []).map((user) => (
              <TestRow key={user.id} user={user} disabled={!active} />
            ))}
          </ul>
        )
      ) : null}
    </SettingsCard>
  )
}

export function PushSection() {
  const { t } = useTranslation()
  const status = usePushStatus()
  useSyncPushReady(status.data?.state)
  return (
    <SectionFrame
      title={t('push.title')}
      description={t('push.description')}
      action={status.data ? <PushStateBadge state={status.data.state} className="mt-1" /> : null}
    >
      <QueryContent query={status}>
        {(data) => (
          <div className="flex flex-col gap-4">
            <SettingsCard title={t('push.serviceTitle')}>
              <StateMessage status={data} />
            </SettingsCard>
            <CredentialsCard status={data} />
            <Metrics status={data} />
            {data.last_error ? (
              <p className="text-xs text-muted-foreground">
                {t('push.lastError', {
                  time: stamp(data.last_error.at),
                  kind: data.last_error.kind,
                  error: data.last_error.error,
                })}
              </p>
            ) : null}
            <p className="text-xs text-muted-foreground">
              {t('push.policy', { hours: data.ttl_hours, attempts: data.max_attempts })}
            </p>
            <TestCard active={data.state === 'active'} />
          </div>
        )}
      </QueryContent>
    </SectionFrame>
  )
}
