import { ExternalLinkIcon, EyeIcon, EyeOffIcon, KeyRoundIcon, TriangleAlertIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { CopyButton } from '@/components/copy-button'
import { Button } from '@/components/ui/button'
import { useClientConfig } from '@/features/client-config/hooks'
import { QueryContent, SectionFrame, SettingsCard } from '@/features/settings/components/settings-ui'
import { appEnv } from '@/lib/supabase'
import { formatNumber, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useAppIntegration } from '../hooks'
import { ago, prodConfig, shortKey } from '../logic'
import {
  INTEGRATION_GUIDE_URL,
  LIBRARY_MIN_VERSION,
  LIBRARY_NAME,
  type AppIntegrationOverview,
  type BridgeInstance,
  type BridgeStatus,
} from '../types'

const statusTone = { active: 'ok', warning: 'warn', no_heartbeat: 'late' } as const

function useAgo() {
  const { t } = useTranslation()
  return (value: string) => {
    const relative = ago(value)
    return t(`platform.appIntegration.ago.${relative.unit}`, { count: relative.count })
  }
}

export function BridgeStatusBadge({ status }: { status: BridgeStatus }) {
  const { t } = useTranslation()
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-sm border px-1.5 py-px text-xs font-medium',
        status === 'active' && 'border-success/40 text-success',
        status === 'warning' && 'border-warning/40 text-warning',
        status === 'no_heartbeat' && 'border-destructive/40 text-destructive',
      )}
    >
      <Dot tone={statusTone[status]} />
      {t(`platform.appIntegration.status.${status}`)}
    </span>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="grid gap-1 sm:grid-cols-[14rem_minmax(0,1fr)] sm:gap-3">
      <dt className="text-row text-muted-foreground">{label}</dt>
      <dd className="min-w-0 text-row">{children}</dd>
    </div>
  )
}

function MinVersions() {
  const { t } = useTranslation()
  const config = useClientConfig()
  const limits = (config.data?.min_versions ?? []).filter((row) => row.min_version)
  if (!config.data) return <span className="text-muted-foreground">{t('app.none')}</span>
  if (limits.length === 0)
    return <span className="text-muted-foreground">{t('platform.appIntegration.noMinVersions')}</span>
  return (
    <span>
      {limits.map((row) => `${t(`platform.platforms.${row.platform}`)} ${row.min_version ?? ''}`).join(' · ')}
    </span>
  )
}

function ConnectionCard() {
  const { t } = useTranslation()
  const env = appEnv()
  const apiUrl = env.publicApiUrl ?? env.supabaseUrl
  const [revealed, setRevealed] = useState(false)
  const config = prodConfig(apiUrl, env.anonKey)
  return (
    <SettingsCard
      title={t('platform.appIntegration.connection')}
      subtitle={t('platform.appIntegration.connectionHint')}
    >
      <dl className="flex flex-col gap-3">
        <Field label={t('platform.appIntegration.apiUrl')}>
          <span className="flex flex-wrap items-center gap-2">
            <code className="font-mono text-xs break-all">{apiUrl}</code>
            <CopyButton text={apiUrl} label={t('platform.appIntegration.apiUrl')} size="xs" />
          </span>
        </Field>
        <Field label={t('platform.appIntegration.anonKey')}>
          <span className="flex flex-wrap items-center gap-2">
            <code data-testid="anon-key" className="font-mono text-xs break-all">
              {revealed ? env.anonKey : shortKey(env.anonKey)}
            </code>
            <Button type="button" variant="outline" size="xs" onClick={() => setRevealed((value) => !value)}>
              {revealed ? <EyeOffIcon /> : <EyeIcon />}
              {revealed ? t('platform.appIntegration.hideKey') : t('platform.appIntegration.showKey')}
            </Button>
            <CopyButton text={env.anonKey} label={t('platform.appIntegration.anonKey')} size="xs" />
          </span>
        </Field>
        <Field label={t('platform.appIntegration.library')}>
          {t('platform.appIntegration.libraryValue', { name: LIBRARY_NAME, version: LIBRARY_MIN_VERSION })}
        </Field>
        <Field label={t('platform.appIntegration.minVersions')}>
          <MinVersions />
        </Field>
      </dl>
      <div className="flex flex-col gap-2">
        <h3 className="text-row font-medium">{t('platform.appIntegration.prodConfig')}</h3>
        <pre
          aria-label={t('platform.appIntegration.prodConfig')}
          className="overflow-x-auto rounded-md border bg-muted px-3 py-2.5 font-mono text-xs leading-5 select-all"
        >
          {config}
        </pre>
        <div className="flex flex-wrap items-center gap-3">
          <CopyButton text={config} label={t('platform.appIntegration.prodConfig')} />
          <a
            href={INTEGRATION_GUIDE_URL}
            target="_blank"
            rel="noreferrer"
            className="inline-flex items-center gap-1.5 rounded-sm text-row text-primary outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring/50"
          >
            {t('platform.appIntegration.guide')}
            <ExternalLinkIcon className="size-3.5" aria-hidden="true" />
          </a>
        </div>
      </div>
    </SettingsCard>
  )
}

function InstanceDetail({ instance }: { instance: BridgeInstance }) {
  const { t } = useTranslation()
  return (
    <>
      <Field label={t('platform.appIntegration.mode')}>
        <code className="font-mono text-xs">{instance.olt_mode ?? '–'}</code>
      </Field>
      <Field label={t('platform.appIntegration.keys')}>
        {instance.keys.length === 0 ? (
          <span className="text-muted-foreground">{t('platform.appIntegration.noKeys')}</span>
        ) : (
          <ul className="flex flex-wrap gap-1.5">
            {instance.keys.map((key) => (
              <li
                key={key.kid}
                className={cn(
                  'inline-flex items-center gap-1 rounded-sm border px-1.5 py-px font-mono text-xs',
                  key.kid.startsWith('dev-') && 'border-warning/40 text-warning',
                )}
              >
                <KeyRoundIcon className="size-3" aria-hidden="true" />
                {key.kid}
                {key.alg ? <span className="text-muted-foreground">({key.alg})</span> : null}
              </li>
            ))}
          </ul>
        )}
      </Field>
      {instance.issuer !== null ? (
        <Field label={t('platform.appIntegration.issuer')}>
          <code className="font-mono text-xs">{instance.issuer}</code>
        </Field>
      ) : null}
      {instance.audience !== null ? (
        <Field label={t('platform.appIntegration.audience')}>
          <code className="font-mono text-xs">{instance.audience}</code>
        </Field>
      ) : null}
      {instance.max_ttl_seconds !== null ? (
        <Field label={t('platform.appIntegration.maxTtl')}>
          {t('platform.appIntegration.seconds', { count: instance.max_ttl_seconds })}
        </Field>
      ) : null}
    </>
  )
}

function LoginCard({ data }: { data: AppIntegrationOverview }) {
  const { t } = useTranslation()
  const since = useAgo()
  const [first] = data.instances
  return (
    <SettingsCard
      title={t('platform.appIntegration.login')}
      subtitle={t('platform.appIntegration.loginHint')}
    >
      <div className="flex flex-wrap items-center gap-2">
        <BridgeStatusBadge status={data.status} />
        {data.status === 'no_heartbeat' ? (
          <span className="text-row text-muted-foreground">
            {t('platform.appIntegration.noHeartbeat')}{' '}
            {data.last_seen_at
              ? t('platform.appIntegration.lastHeartbeat', {
                  time: stamp(data.last_seen_at),
                  ago: since(data.last_seen_at),
                })
              : t('platform.appIntegration.neverHeartbeat')}
          </span>
        ) : null}
      </div>
      {data.warnings.length > 0 ? (
        <ul role="status" className="flex flex-col gap-1.5">
          {data.warnings.map((warning) => (
            <li key={warning} className="flex items-start gap-2 text-row text-warning">
              <TriangleAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
              {t(`platform.appIntegration.warnings.${warning}`)}
            </li>
          ))}
        </ul>
      ) : null}
      <dl className="flex flex-col gap-3">
        {first ? <InstanceDetail instance={first} /> : null}
        {data.instances.length > 0 ? (
          <Field label={t('platform.appIntegration.instances')}>
            <ul className="flex flex-col gap-0.5">
              {data.instances.map((instance) => (
                <li key={instance.instance} className="text-xs">
                  <code className="font-mono">{instance.instance}</code>{' '}
                  <span className="text-muted-foreground">
                    {t('platform.appIntegration.instanceLine', {
                      version: instance.version ?? '–',
                      ago: since(instance.last_seen_at),
                    })}
                  </span>
                  {instance.status !== 'ok' ? (
                    <span className="text-warning">
                      {' '}
                      · {t('platform.appIntegration.degraded')}
                      {instance.error ? `: ${instance.error}` : ''}
                    </span>
                  ) : null}
                </li>
              ))}
            </ul>
          </Field>
        ) : null}
        <Field label={t('platform.appIntegration.lastLogin')}>
          {data.logins.last_login_at ? (
            <span>
              {stamp(data.logins.last_login_at)} WIB{' '}
              <span className="text-muted-foreground">({since(data.logins.last_login_at)})</span>
            </span>
          ) : (
            <span className="text-muted-foreground">{t('platform.appIntegration.noLogin')}</span>
          )}
        </Field>
        <Field label={t('platform.appIntegration.logins24h')}>{formatNumber(data.logins.users_24h)}</Field>
      </dl>
      <p className="text-xs text-muted-foreground">{t('platform.appIntegration.keyHelp')}</p>
    </SettingsCard>
  )
}

export function AppIntegrationSection() {
  const { t } = useTranslation()
  const overview = useAppIntegration()
  return (
    <SectionFrame title={t('settings.appIntegration')} description={t('platform.appIntegration.description')}>
      <div className="flex flex-col gap-4">
        <ConnectionCard />
        <QueryContent query={overview}>{(data) => <LoginCard data={data} />}</QueryContent>
      </div>
    </SectionFrame>
  )
}
