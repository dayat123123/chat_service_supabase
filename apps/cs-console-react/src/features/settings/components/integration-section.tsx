import {
  CheckCircle2Icon,
  CheckIcon,
  CopyIcon,
  LoaderCircleIcon,
  PlugZapIcon,
  TriangleAlertIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Dot } from '@/components/badges'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Confirm } from '@/features/nasabah/components/confirm'
import { errorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useClearIntegration, useIntegrationStatus, useSaveIntegration, useTestIntegration } from '../hooks'
import { csadminConfigBlock, validClientId, validCsadminUrl } from '../logic'
import type { IntegrationCheck, IntegrationStatus } from '../types'
import { FieldMessage, QueryContent, SectionFrame, SettingsCard } from './settings-ui'

export function IntegrationBadge({ configured, className }: { configured: boolean; className?: string }) {
  const { t } = useTranslation()
  return (
    <span
      className={cn(
        'inline-flex shrink-0 items-center gap-1.5 rounded-sm border px-1.5 py-px text-xs font-medium',
        configured ? 'border-success/40 text-success' : 'border-warning/40 text-warning',
        className,
      )}
    >
      <Dot tone={configured ? 'ok' : 'warn'} />
      {configured ? t('settings.integrationActive') : t('settings.integrationNotSet')}
    </span>
  )
}

function CheckMessage({ check, saved }: { check: IntegrationCheck; saved: boolean | null }) {
  const { t } = useTranslation()
  const ok = check.result === 'ok'
  const Icon = ok ? CheckCircle2Icon : TriangleAlertIcon
  return (
    <p
      role="status"
      className={cn('flex items-start gap-2 text-row', ok ? 'text-success' : 'text-destructive')}
    >
      <Icon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
      <span>
        {saved === false ? `${t('settings.notSaved')} ` : null}
        {t(`settings.testResult.${check.result}`, { ms: check.duration_ms, status: check.status ?? '-' })}
      </span>
    </p>
  )
}

const tidyUrl = (value: string) => value.trim().replace(/\/+$/, '')

function ConnectionCard({
  status,
  clientId,
  onClientId,
}: {
  status: IntegrationStatus
  clientId: string
  onClientId: (value: string) => void
}) {
  const { t } = useTranslation()
  const test = useTestIntegration()
  const save = useSaveIntegration()
  const clear = useClearIntegration()
  const [url, setUrl] = useState(status.url)
  const [touched, setTouched] = useState(false)
  const [result, setResult] = useState<{ check: IntegrationCheck; saved: boolean | null } | null>(null)
  const [confirming, setConfirming] = useState(false)
  const typedUrl = tidyUrl(url)
  const typedClient = clientId.trim()
  const urlProblem = typedUrl === '' ? 'required' : validCsadminUrl(typedUrl) ? null : 'invalid'
  const clientProblem = typedClient === '' ? 'required' : validClientId(typedClient) ? null : 'invalid'
  const unchanged = status.configured && typedUrl === status.url && typedClient === status.client_id
  const busy = test.isPending || save.isPending || clear.isPending
  const edit = (apply: () => void) => {
    apply()
    setResult(null)
  }
  const whenValid = (run: () => void) => {
    setTouched(true)
    if (!urlProblem && !clientProblem) run()
  }

  return (
    <SettingsCard title={t('settings.csadminTitle')}>
      <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_14rem]">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="csadmin-url">{t('settings.csadminUrl')}</Label>
          <Input
            id="csadmin-url"
            inputMode="url"
            autoComplete="off"
            spellCheck={false}
            maxLength={200}
            placeholder="http://192.168.10.10:9001/csAdmin"
            value={url}
            aria-invalid={touched && urlProblem ? true : undefined}
            onChange={(event) => edit(() => setUrl(event.target.value))}
          />
          <FieldMessage
            error={
              touched && urlProblem
                ? t(urlProblem === 'required' ? 'settings.csadminUrlRequired' : 'settings.csadminUrlInvalid')
                : undefined
            }
            hint={t('settings.csadminUrlHint')}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="csadmin-client">{t('settings.csadminClientId')}</Label>
          <Input
            id="csadmin-client"
            autoComplete="off"
            spellCheck={false}
            maxLength={50}
            placeholder={t('settings.clientIdPlaceholder')}
            value={clientId}
            aria-invalid={touched && clientProblem ? true : undefined}
            onChange={(event) => edit(() => onClientId(event.target.value))}
          />
          <FieldMessage
            error={
              touched && clientProblem
                ? t(
                    clientProblem === 'required'
                      ? 'settings.csadminClientIdRequired'
                      : 'settings.csadminClientIdInvalid',
                  )
                : undefined
            }
            hint={t('settings.csadminClientIdHint')}
          />
        </div>
      </div>
      <p className={cn('text-xs', status.configured ? 'text-muted-foreground' : 'text-warning')}>
        {status.configured
          ? t('settings.integrationSince', {
              time: status.connected_at ? stamp(status.connected_at) : '-',
              name: status.connected_by ?? '-',
            })
          : t('settings.integrationNotSetHint')}
      </p>
      <div className="flex flex-wrap items-center gap-3">
        <Button
          variant="outline"
          disabled={busy}
          onClick={() =>
            whenValid(() =>
              test.mutate(
                { url: typedUrl, clientId: typedClient },
                {
                  onSuccess: (check) => setResult({ check, saved: null }),
                  onError: (error) => toast.error(errorText(error)),
                },
              ),
            )
          }
        >
          {test.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('settings.testConnection')}
        </Button>
        <Button
          disabled={busy || unchanged}
          onClick={() =>
            whenValid(() =>
              save.mutate(
                { url: typedUrl, clientId: typedClient },
                {
                  onSuccess: (saved) => {
                    setResult({ check: saved.check, saved: saved.saved })
                    if (saved.saved) toast.success(t('settings.integrationSaved'))
                  },
                  onError: (error) => toast.error(errorText(error)),
                },
              ),
            )
          }
        >
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : <PlugZapIcon />}
          {t('settings.saveActivate')}
        </Button>
        {status.configured ? (
          <Button
            variant="ghost"
            className="text-destructive"
            disabled={busy}
            onClick={() => setConfirming(true)}
          >
            {t('settings.disconnect')}
          </Button>
        ) : null}
      </div>
      {result ? <CheckMessage check={result.check} saved={result.saved} /> : null}
      <Confirm
        open={confirming}
        title={t('settings.disconnectTitle')}
        body={t('settings.disconnectBody')}
        action={t('settings.disconnect')}
        pending={clear.isPending}
        destructive
        onConfirm={() =>
          clear.mutate(undefined, {
            onSuccess: (next) => {
              setConfirming(false)
              setUrl(next.url)
              onClientId(next.client_id)
              setResult(null)
              setTouched(false)
              toast.success(t('settings.disconnected'))
            },
            onError: (error) => toast.error(errorText(error)),
          })
        }
        onClose={() => setConfirming(false)}
      />
    </SettingsCard>
  )
}

function KeyCard({ status, clientId }: { status: IntegrationStatus; clientId: string }) {
  const { t } = useTranslation()
  const [copied, setCopied] = useState(false)
  if (!status.key_configured) {
    return (
      <SettingsCard title={t('settings.integrationKey')}>
        <p className="text-row text-warning">{t('settings.integrationKeyMissing')}</p>
      </SettingsCard>
    )
  }
  const block = csadminConfigBlock(clientId.trim() || t('settings.clientIdUnknown'), status.public_key)
  return (
    <SettingsCard title={t('settings.integrationKey')} subtitle={t('settings.integrationKeyHint')}>
      <pre
        aria-label={t('settings.integrationKey')}
        className="overflow-x-auto rounded-md border bg-muted px-3 py-2.5 font-mono text-xs leading-5 select-all"
      >
        {block}
      </pre>
      <div className="flex flex-wrap items-center gap-3">
        <Button
          variant="outline"
          size="sm"
          onClick={() =>
            void navigator.clipboard
              .writeText(block)
              .then(() => setCopied(true))
              .catch(() => setCopied(false))
          }
        >
          {copied ? <CheckIcon /> : <CopyIcon />}
          {copied ? t('app.copied') : t('app.copy')}
        </Button>
        <p className="text-xs text-muted-foreground">{t('settings.integrationAllowedIps')}</p>
      </div>
    </SettingsCard>
  )
}

function IntegrationContent({ status }: { status: IntegrationStatus }) {
  const [clientId, setClientId] = useState(status.client_id)
  return (
    <div className="flex flex-col gap-4">
      <ConnectionCard
        key={`${status.url}|${status.client_id}|${String(status.configured)}`}
        status={status}
        clientId={clientId}
        onClientId={setClientId}
      />
      <KeyCard status={status} clientId={clientId} />
    </div>
  )
}

export function IntegrationSection() {
  const { t } = useTranslation()
  const status = useIntegrationStatus()
  return (
    <SectionFrame
      title={t('settings.integration')}
      description={t('settings.integrationDescription')}
      action={status.data ? <IntegrationBadge configured={status.data.configured} /> : undefined}
    >
      <QueryContent query={status}>{(data) => <IntegrationContent status={data} />}</QueryContent>
    </SectionFrame>
  )
}
