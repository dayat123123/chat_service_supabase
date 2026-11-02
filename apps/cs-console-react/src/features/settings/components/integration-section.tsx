import type { UseQueryResult } from '@tanstack/react-query'
import { CheckCircle2Icon, CheckIcon, CopyIcon, LoaderCircleIcon, TriangleAlertIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { errorText } from '@/lib/error-text'
import { cn } from '@/lib/utils'
import type { Json } from '@/types/database'

import {
  findSetting,
  useIntegrationStatus,
  useSaveSettings,
  useSettingEntries,
  useTestIntegration,
} from '../hooks'
import { csadminConfigBlock, textSetting, validClientId, validCsadminUrl } from '../logic'
import type { IntegrationCheck, IntegrationStatus, SettingEntry } from '../types'
import { ChangedBy, FieldMessage, QueryContent, SectionFrame, SettingsCard } from './settings-ui'

const urlKey = 'nasabah.csadmin_url'
const clientKey = 'nasabah.csadmin_client_id'

function CheckMessage({ check }: { check: IntegrationCheck }) {
  const { t } = useTranslation()
  const ok = check.result === 'ok'
  const Icon = ok ? CheckCircle2Icon : TriangleAlertIcon
  return (
    <p
      role="status"
      className={cn('flex items-start gap-2 text-row', ok ? 'text-success' : 'text-destructive')}
    >
      <Icon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
      {t(`settings.testResult.${check.result}`, { ms: check.duration_ms, status: check.status ?? '-' })}
    </p>
  )
}

function InUse({ status }: { status: UseQueryResult<IntegrationStatus> }) {
  const { t } = useTranslation()
  if (status.isError) {
    return (
      <p className="text-xs text-destructive">
        {t('settings.integrationUnavailable')} {errorText(status.error)}
      </p>
    )
  }
  if (!status.data) return null
  if (status.data.url_source === 'none')
    return <p className="text-xs text-warning">{t('settings.csadminNone')}</p>
  return (
    <p className="text-xs text-muted-foreground">
      {t('settings.csadminInUse', {
        url: status.data.url,
        source:
          status.data.url_source === 'settings'
            ? t('settings.csadminFromSettings')
            : t('settings.csadminFromServer'),
      })}
    </p>
  )
}

function AddressCard({
  items,
  status,
}: {
  items: SettingEntry[]
  status: UseQueryResult<IntegrationStatus>
}) {
  const { t } = useTranslation()
  const save = useSaveSettings()
  const test = useTestIntegration()
  const savedUrl = textSetting(findSetting(items, urlKey)?.value)
  const savedClient = textSetting(findSetting(items, clientKey)?.value)
  const [url, setUrl] = useState(savedUrl)
  const [clientId, setClientId] = useState(savedClient)
  const [touched, setTouched] = useState(false)
  const trimmedUrl = url.trim()
  const trimmedClient = clientId.trim()
  const urlValid = trimmedUrl === '' || validCsadminUrl(trimmedUrl)
  const clientValid = trimmedClient === '' || validClientId(trimmedClient)
  const serverClient = status.data?.client_id_source === 'server' ? status.data.client_id : 'web-cs'
  const changes: Record<string, Json> = {}
  if (trimmedUrl !== savedUrl) changes[urlKey] = trimmedUrl
  if (trimmedClient !== savedClient) changes[clientKey] = trimmedClient
  const edit = (apply: () => void) => {
    apply()
    test.reset()
  }
  const check = (run: () => void) => {
    setTouched(true)
    if (urlValid && clientValid) run()
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
            placeholder={status.data?.url_source === 'server' ? status.data.url : 'http://192.168.10.10:8080'}
            value={url}
            aria-invalid={touched && !urlValid ? true : undefined}
            onChange={(event) => edit(() => setUrl(event.target.value))}
          />
          <FieldMessage
            error={touched && !urlValid ? t('settings.csadminUrlInvalid') : undefined}
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
            placeholder={serverClient}
            value={clientId}
            aria-invalid={touched && !clientValid ? true : undefined}
            onChange={(event) => edit(() => setClientId(event.target.value))}
          />
          <FieldMessage
            error={touched && !clientValid ? t('settings.csadminClientIdInvalid') : undefined}
            hint={t('settings.csadminClientIdHint', { value: serverClient })}
          />
        </div>
      </div>
      <InUse status={status} />
      <div className="flex flex-wrap items-center gap-3">
        <Button
          variant="outline"
          disabled={test.isPending}
          onClick={() => check(() => test.mutate({ url: trimmedUrl, clientId: trimmedClient }))}
        >
          {test.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('settings.testConnection')}
        </Button>
        <Button
          disabled={save.isPending || Object.keys(changes).length === 0}
          onClick={() => check(() => save.mutate(changes, { onSuccess: () => void status.refetch() }))}
        >
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
        <ChangedBy entry={findSetting(items, urlKey)} />
      </div>
      {test.data ? <CheckMessage check={test.data} /> : null}
      {test.error ? (
        <p role="alert" className="text-row text-destructive">
          {errorText(test.error)}
        </p>
      ) : null}
    </SettingsCard>
  )
}

function KeyBlock({ status }: { status: IntegrationStatus }) {
  const { t } = useTranslation()
  const [copied, setCopied] = useState(false)
  if (!status.key_configured) {
    return <p className="text-row text-warning">{t('settings.integrationKeyMissing')}</p>
  }
  const block = csadminConfigBlock(status.client_id, status.public_key)
  return (
    <>
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
    </>
  )
}

export function IntegrationSection() {
  const { t } = useTranslation()
  const settings = useSettingEntries()
  const status = useIntegrationStatus()
  return (
    <SectionFrame title={t('settings.integration')} description={t('settings.integrationDescription')}>
      <QueryContent query={settings}>
        {(items) => (
          <div className="flex flex-col gap-4">
            <AddressCard
              key={`${findSetting(items, urlKey)?.version ?? 0}-${findSetting(items, clientKey)?.version ?? 0}`}
              items={items}
              status={status}
            />
            <SettingsCard title={t('settings.integrationKey')} subtitle={t('settings.integrationKeyHint')}>
              <QueryContent query={status}>{(data) => <KeyBlock status={data} />}</QueryContent>
            </SettingsCard>
          </div>
        )}
      </QueryContent>
    </SectionFrame>
  )
}
