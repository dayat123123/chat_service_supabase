import { LinkIcon, LoaderCircleIcon, SendIcon, Trash2Icon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue, Switch } from '@/components/ui/controls'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { QueryContent, SettingsCard } from '@/features/settings/components/settings-ui'
import { errorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'

import { useAlertChannels, useSendAlertTest, useSetAlertOptions, useSetEmail, useSetTelegram } from '../hooks'
import {
  ALERT_LABEL_MAX,
  MAX_EMAIL_RECIPIENTS,
  MAX_TELEGRAM_CHATS,
  emailProblems,
  optionsProblems,
  parseList,
  parsePort,
  telegramProblems,
  type ChannelProblem,
} from '../logic'
import type { AlertChannel, AlertChannels, Delivery, SmtpSecurity } from '../types'
import { FieldText, SecretField, TextField, ToneBadge } from './system-ui'

const deliveryTones = { pending: 'neutral', sent: 'ok', failed: 'late' } as const

function LastDelivery({ delivery }: { delivery: Delivery | null }) {
  const { t } = useTranslation()
  if (!delivery) return <p className="text-xs text-muted-foreground">{t('system.channels.noDelivery')}</p>
  return (
    <div className="flex flex-col gap-1" aria-live="polite">
      <p className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
        <span>{t('system.channels.lastDelivery')}</span>
        <ToneBadge tone={deliveryTones[delivery.status]}>
          {delivery.status === 'pending' ? (
            <LoaderCircleIcon className="size-3 animate-spin" aria-hidden="true" />
          ) : null}
          {t(`system.channels.deliveryStatus.${delivery.status}`)}
        </ToneBadge>
        <span>
          {t(`system.channels.deliveryKind.${delivery.kind}`)} · {stamp(delivery.at)}
        </span>
      </p>
      {delivery.status === 'pending' ? (
        <p className="text-xs text-muted-foreground">{t('system.channels.pendingHint')}</p>
      ) : null}
      {delivery.error ? <p className="text-xs break-words text-destructive">{delivery.error}</p> : null}
    </div>
  )
}

function TestButton({
  channel,
  ready,
  dirty,
  delivery,
}: {
  channel: AlertChannel
  ready: boolean
  dirty: boolean
  delivery: Delivery | null
}) {
  const { t } = useTranslation()
  const test = useSendAlertTest()
  const waiting = delivery?.status === 'pending' && delivery.kind === 'test'
  return (
    <div className="flex flex-col gap-2 border-t pt-3">
      <div className="flex flex-wrap items-center gap-2">
        <Button
          type="button"
          size="sm"
          variant="outline"
          disabled={!ready || dirty || test.isPending || waiting}
          onClick={() =>
            void test
              .mutateAsync(channel)
              .then(() => toast.success(t('system.channels.testQueued')))
              .catch((error: unknown) => toast.error(errorText(error)))
          }
        >
          {test.isPending ? <LoaderCircleIcon className="animate-spin" /> : <SendIcon />}
          {t(`system.channels.test.${channel}`)}
        </Button>
        {!ready ? (
          <span className="text-xs text-muted-foreground">{t('system.channels.testNeedsSave')}</span>
        ) : dirty ? (
          <span className="text-xs text-muted-foreground">{t('system.channels.testDirty')}</span>
        ) : null}
      </div>
      <LastDelivery delivery={delivery} />
    </div>
  )
}

function useProblem() {
  const { t } = useTranslation()
  return (scope: string, problem: ChannelProblem | undefined, options?: { max?: number }) =>
    problem
      ? t(`system.channels.problems.${scope}.${problem}` as 'system.channels.problems.host.invalid', options ?? {})
      : undefined
}

function OptionsCard({ channels }: { channels: AlertChannels }) {
  const { t } = useTranslation()
  const ids = useId()
  const save = useSetAlertOptions()
  const [label, setLabel] = useState(channels.label)
  const [url, setUrl] = useState(channels.console_url ?? '')
  const [checked, setChecked] = useState(false)
  const problems = optionsProblems(label, url)
  const shown = checked ? problems : {}
  const dirty = label !== channels.label || url !== (channels.console_url ?? '')
  const problem = useProblem()
  return (
    <SettingsCard title={t('system.channels.optionsTitle')} subtitle={t('system.channels.optionsHint')}>
      <form
        className="flex flex-col gap-4"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (Object.keys(problems).length > 0) return
          save
            .mutateAsync({ label, consoleUrl: url })
            .then(() => {
              setChecked(false)
              toast.success(t('system.channels.saved'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }}
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            id={`${ids}-label`}
            label={t('system.channels.label')}
            value={label}
            maxLength={ALERT_LABEL_MAX}
            onChange={setLabel}
            error={problem('label', shown.label, { max: ALERT_LABEL_MAX })}
            hint={t('system.channels.labelHint')}
          />
          <div className="flex min-w-0 flex-col gap-1.5">
            <TextField
              id={`${ids}-url`}
              label={t('system.channels.consoleUrl')}
              value={url}
              inputMode="url"
              placeholder="https://cs.example.co.id"
              onChange={setUrl}
              error={problem('consoleUrl', shown.consoleUrl)}
              hint={t('system.channels.consoleUrlHint', {
                url: `${(url.trim() || window.location.origin).replace(/\/+$/, '')}/system`,
              })}
            />
            {url.trim() === '' ? (
              <Button
                type="button"
                size="xs"
                variant="ghost"
                className="self-start"
                onClick={() => setUrl(window.location.origin)}
              >
                <LinkIcon />
                {t('system.channels.useThisAddress')}
              </Button>
            ) : null}
          </div>
        </div>
        <Button type="submit" size="sm" className="self-start" disabled={save.isPending || !dirty}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
      </form>
    </SettingsCard>
  )
}

function TelegramCard({ channels }: { channels: AlertChannels }) {
  const { t } = useTranslation()
  const ids = useId()
  const save = useSetTelegram()
  const saved = channels.telegram
  const [enabled, setEnabled] = useState(saved.enabled)
  const [token, setToken] = useState('')
  const [chats, setChats] = useState(saved.chat_ids.join('\n'))
  const [checked, setChecked] = useState(false)
  const chatIds = parseList(chats)
  const input = { enabled, chatIds, botToken: token }
  const problems = telegramProblems(input, saved.token_set)
  const shown = checked ? problems : {}
  const dirty = enabled !== saved.enabled || token !== '' || chatIds.join(',') !== saved.chat_ids.join(',')
  const problem = useProblem()
  return (
    <SettingsCard title={t('system.channels.telegram.title')} subtitle={t('system.channels.telegram.hint')}>
      <ol className="flex list-decimal flex-col gap-1 pl-5 text-row text-muted-foreground">
        <li>{t('system.channels.telegram.steps.bot')}</li>
        <li>{t('system.channels.telegram.steps.group')}</li>
        <li>{t('system.channels.telegram.steps.chat')}</li>
      </ol>
      <form
        className="flex flex-col gap-4"
        noValidate
        autoComplete="off"
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (Object.keys(problems).length > 0) return
          save
            .mutateAsync(input)
            .then(() => {
              setToken('')
              setChecked(false)
              toast.success(t('system.channels.saved'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
            .finally(() => save.reset())
        }}
      >
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center gap-2">
            <Switch id={`${ids}-enabled`} checked={enabled} onCheckedChange={setEnabled} />
            <Label htmlFor={`${ids}-enabled`}>{t('system.channels.telegram.enabled')}</Label>
          </div>
          <FieldText id={`${ids}-enabled-text`} error={problem('telegram', shown.enabled)} />
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <SecretField
            id={`${ids}-token`}
            label={t('system.channels.telegram.token')}
            stored={saved.token_set}
            value={token}
            onChange={setToken}
            autoComplete="off"
            error={problem('token', shown.botToken)}
          />
          <div className="flex min-w-0 flex-col gap-1.5">
            <Label htmlFor={`${ids}-chats`}>{t('system.channels.telegram.chats')}</Label>
            <Textarea
              id={`${ids}-chats`}
              rows={3}
              value={chats}
              spellCheck={false}
              className="font-mono"
              aria-invalid={shown.chatIds ? true : undefined}
              aria-describedby={`${ids}-chats-text`}
              onChange={(event) => setChats(event.target.value)}
            />
            <FieldText
              id={`${ids}-chats-text`}
              error={problem('chats', shown.chatIds, { max: MAX_TELEGRAM_CHATS })}
              hint={t('system.channels.telegram.chatsHint', { max: MAX_TELEGRAM_CHATS })}
            />
          </div>
        </div>
        <Button type="submit" size="sm" className="self-start" disabled={save.isPending || !dirty}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
      </form>
      <TestButton
        channel="telegram"
        ready={saved.enabled && saved.token_set}
        dirty={dirty}
        delivery={channels.last.telegram}
      />
    </SettingsCard>
  )
}

const securities: SmtpSecurity[] = ['starttls', 'tls', 'none']

function EmailCard({ channels }: { channels: AlertChannels }) {
  const { t } = useTranslation()
  const ids = useId()
  const save = useSetEmail()
  const saved = channels.email
  const [enabled, setEnabled] = useState(saved.enabled)
  const [host, setHost] = useState(saved.host ?? '')
  const [port, setPort] = useState(saved.port === null ? '' : String(saved.port))
  const [security, setSecurity] = useState<SmtpSecurity>(saved.security ?? 'starttls')
  const [username, setUsername] = useState(saved.username ?? '')
  const [password, setPassword] = useState('')
  const [clearPassword, setClearPassword] = useState(false)
  const [from, setFrom] = useState(saved.from ?? '')
  const [to, setTo] = useState(saved.to.join('\n'))
  const [checked, setChecked] = useState(false)
  const recipients = parseList(to)
  const input = {
    enabled,
    host,
    port: parsePort(port),
    security,
    username,
    from,
    to: recipients,
    password: clearPassword ? '' : password ? password : null,
  }
  const problems = emailProblems(input)
  const shown = checked ? problems : {}
  const dirty =
    enabled !== saved.enabled ||
    host !== (saved.host ?? '') ||
    port !== (saved.port === null ? '' : String(saved.port)) ||
    security !== (saved.security ?? 'starttls') ||
    username !== (saved.username ?? '') ||
    from !== (saved.from ?? '') ||
    recipients.join(',') !== saved.to.join(',') ||
    password !== '' ||
    clearPassword
  const problem = useProblem()
  return (
    <SettingsCard title={t('system.channels.email.title')} subtitle={t('system.channels.email.hint')}>
      <form
        className="flex flex-col gap-4"
        noValidate
        autoComplete="off"
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (Object.keys(problems).length > 0) return
          save
            .mutateAsync(input)
            .then(() => {
              setPassword('')
              setClearPassword(false)
              setChecked(false)
              toast.success(t('system.channels.saved'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
            .finally(() => save.reset())
        }}
      >
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center gap-2">
            <Switch id={`${ids}-enabled`} checked={enabled} onCheckedChange={setEnabled} />
            <Label htmlFor={`${ids}-enabled`}>{t('system.channels.email.enabled')}</Label>
          </div>
          <FieldText id={`${ids}-enabled-text`} error={problem('email', shown.enabled)} />
        </div>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)]">
          <TextField
            id={`${ids}-host`}
            label={t('system.channels.email.host')}
            value={host}
            placeholder="smtp.example.co.id"
            spellCheck={false}
            onChange={setHost}
            error={problem('host', shown.host)}
          />
          <TextField
            id={`${ids}-port`}
            label={t('system.channels.email.port')}
            value={port}
            inputMode="numeric"
            placeholder="587"
            onChange={setPort}
            error={problem('port', shown.port)}
          />
          <div className="flex min-w-0 flex-col gap-1.5">
            <Label htmlFor={`${ids}-security`}>{t('system.channels.email.security')}</Label>
            <Select value={security} onValueChange={(value) => setSecurity(value as SmtpSecurity)}>
              <SelectTrigger id={`${ids}-security`}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {securities.map((item) => (
                  <SelectItem key={item} value={item}>
                    {t(`system.channels.email.securities.${item}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            id={`${ids}-username`}
            label={t('system.channels.email.username')}
            value={username}
            autoComplete="off"
            spellCheck={false}
            onChange={setUsername}
            error={problem('username', shown.username)}
            hint={t('system.backup.fields.optional')}
          />
          <div className="flex min-w-0 flex-col gap-1.5">
            <SecretField
              id={`${ids}-password`}
              label={t('system.channels.email.password')}
              stored={saved.password_set && !clearPassword}
              value={password}
              disabled={clearPassword}
              onChange={setPassword}
              error={problem('password', shown.password)}
              hint={clearPassword ? t('system.channels.email.passwordCleared') : undefined}
            />
            {saved.password_set ? (
              <Button
                type="button"
                size="xs"
                variant="ghost"
                className="self-start"
                aria-pressed={clearPassword}
                onClick={() => {
                  setPassword('')
                  setClearPassword((value) => !value)
                }}
              >
                <Trash2Icon />
                {clearPassword ? t('system.channels.email.keepPassword') : t('system.channels.email.clearPassword')}
              </Button>
            ) : null}
          </div>
          <TextField
            id={`${ids}-from`}
            type="email"
            label={t('system.channels.email.from')}
            value={from}
            placeholder="alert@example.co.id"
            onChange={setFrom}
            error={problem('from', shown.from)}
          />
          <div className="flex min-w-0 flex-col gap-1.5">
            <Label htmlFor={`${ids}-to`}>{t('system.channels.email.to')}</Label>
            <Textarea
              id={`${ids}-to`}
              rows={3}
              value={to}
              spellCheck={false}
              aria-invalid={shown.to ? true : undefined}
              aria-describedby={`${ids}-to-text`}
              onChange={(event) => setTo(event.target.value)}
            />
            <FieldText
              id={`${ids}-to-text`}
              error={problem('to', shown.to, { max: MAX_EMAIL_RECIPIENTS })}
              hint={t('system.channels.email.toHint', { max: MAX_EMAIL_RECIPIENTS })}
            />
          </div>
        </div>
        <Button type="submit" size="sm" className="self-start" disabled={save.isPending || !dirty}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
      </form>
      <TestButton
        channel="email"
        ready={saved.enabled && saved.host !== null}
        dirty={dirty}
        delivery={channels.last.email}
      />
    </SettingsCard>
  )
}

export function AlertsTab() {
  const { t } = useTranslation()
  const channels = useAlertChannels()
  return (
    <QueryContent query={channels}>
      {(data) => (
        <div className="flex flex-col gap-5">
          <p className="max-w-3xl text-row text-muted-foreground">{t('system.channels.intro')}</p>
          <OptionsCard key={`${data.label}|${data.console_url ?? ''}`} channels={data} />
          <TelegramCard key={JSON.stringify(data.telegram)} channels={data} />
          <EmailCard key={JSON.stringify(data.email)} channels={data} />
          {data.updated_by ? (
            <p className="text-xs text-muted-foreground">
              {t('system.lastChanged', { time: stamp(data.updated_at), name: data.updated_by })}
            </p>
          ) : null}
        </div>
      )}
    </QueryContent>
  )
}
