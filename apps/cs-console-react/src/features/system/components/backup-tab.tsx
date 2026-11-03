import { format as formatLocal } from 'date-fns'
import { enUS, id as idLocale } from 'date-fns/locale'
import {
  DatabaseBackupIcon,
  FlaskConicalIcon,
  InfoIcon,
  LoaderCircleIcon,
  LockIcon,
  TriangleAlertIcon,
} from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { UsageBar } from '@/components/usage-bar'
import { Button } from '@/components/ui/button'
import { Checkbox, Switch, ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { QueryContent, SettingsCard } from '@/features/settings/components/settings-ui'
import { errorText } from '@/lib/error-text'
import { durationLabel, formatBytes, formatPercent, stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useBackupOverview, useRequestBackup, useSetBackupSchedule, useSetBackupTarget } from '../hooks'
import {
  BACKUP_PASSWORD_MIN,
  backupBusy,
  passwordMode,
  recoveredUntil,
  runDuration,
  scheduleLimits,
  scheduleOf,
  scheduleProblems,
  stagingDisk,
  targetProblems,
  usageTone,
  weekdays,
  type TargetField,
} from '../logic'
import type {
  BackupConfig,
  BackupOverview,
  BackupRequestKind,
  BackupRun,
  BackupScheduleInput,
  BackupTargetInput,
} from '../types'
import { FieldText, SecretField, TextField, ToneBadge } from './system-ui'

function Fact({ label, children, className }: { label: string; children: React.ReactNode; className?: string }) {
  return (
    <div className={cn('flex min-w-0 flex-col gap-1 bg-background px-4 py-3', className)}>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="flex min-w-0 flex-col gap-1 text-row">{children}</dd>
    </div>
  )
}

function Muted({ children }: { children: React.ReactNode }) {
  return <span className="text-xs break-words text-muted-foreground">{children}</span>
}

function ServiceState({ overview }: { overview: BackupOverview }) {
  const { t } = useTranslation()
  const { summary } = overview
  const busy = backupBusy(overview)
  if (!summary.configured) return <ToneBadge tone="warn">{t('system.backup.state.notConfigured')}</ToneBadge>
  if (!summary.live) return <ToneBadge tone="late">{t('system.backup.state.offline')}</ToneBadge>
  if (summary.state?.repository_ready === false) {
    return <ToneBadge tone="late">{t('system.backup.state.repository')}</ToneBadge>
  }
  return (
    <>
      <ToneBadge tone="ok">{t('system.backup.state.running')}</ToneBadge>
      {busy ? <Muted>{t('system.backup.busy', { task: busy })}</Muted> : null}
    </>
  )
}

function Summary({ overview }: { overview: BackupOverview }) {
  const { t } = useTranslation()
  const { summary } = overview
  const state = summary.state
  const disk = stagingDisk(overview)
  const test = summary.last_restore_test
  const recovered = test ? recoveredUntil(test) : null
  const wal = state?.wal
  const diskText = disk
    ? t('system.disks.usage', {
        percent: formatPercent(disk.used),
        avail: formatBytes(disk.avail),
        total: formatBytes(disk.total),
      })
    : ''
  return (
    <dl className="grid grid-cols-1 gap-px overflow-hidden rounded-lg border bg-border sm:grid-cols-2 xl:grid-cols-3">
      <Fact label={t('system.backup.summary.service')}>
        <span className="flex flex-wrap items-center gap-2">
          <ServiceState overview={overview} />
        </span>
        {summary.target ? <span className="font-mono text-xs break-all text-muted-foreground">{summary.target}</span> : null}
        {state?.error ? <span className="text-xs break-words text-destructive">{state.error}</span> : null}
      </Fact>
      <Fact label={t('system.backup.summary.wal')}>
        {!summary.live || !wal ? (
          <Muted>{t('system.backup.unknown')}</Muted>
        ) : wal.slot_lost ? (
          <ToneBadge tone="late" className="self-start">{t('system.backup.walSlotLost')}</ToneBadge>
        ) : wal.streaming ? (
          <ToneBadge tone="ok" className="self-start">{t('system.backup.walStreaming')}</ToneBadge>
        ) : (
          <ToneBadge tone="late" className="self-start">{t('system.backup.walStopped')}</ToneBadge>
        )}
        {wal?.error ? <span className="text-xs break-words text-destructive">{wal.error}</span> : null}
      </Fact>
      <Fact label={t('system.backup.summary.base')}>
        {summary.last_base ? (
          <>
            <span className="tabular">{stamp(summary.last_base.finished_at)}</span>
            <Muted>
              {[
                formatBytes(summary.last_base.bytes),
                summary.last_base.snapshot_id ? t('system.backup.snapshot', { id: summary.last_base.snapshot_id.slice(0, 12) }) : null,
              ]
                .filter(Boolean)
                .join(' · ')}
            </Muted>
          </>
        ) : (
          <Muted>{t('system.backup.never')}</Muted>
        )}
      </Fact>
      <Fact label={t('system.backup.summary.offsite')}>
        {state?.offsite?.last_ok_at ? (
          <span className="tabular">{stamp(state.offsite.last_ok_at)}</span>
        ) : (
          <Muted>{summary.live ? t('system.backup.never') : t('system.backup.unknown')}</Muted>
        )}
        {state?.offsite?.last_error ? (
          <span className="text-xs break-words text-destructive">{state.offsite.last_error}</span>
        ) : null}
      </Fact>
      <Fact label={t('system.backup.summary.restoreTest')}>
        {test ? (
          <>
            <span className="flex flex-wrap items-center gap-2">
              <ToneBadge tone={test.status === 'ok' ? 'ok' : 'late'}>{t(`system.backup.runStatus.${test.status}`)}</ToneBadge>
              <span className="tabular">{stamp(test.finished_at)}</span>
            </span>
            <Muted>
              {[
                recovered ? t('system.backup.recoveredUntil', { time: stamp(recovered) }) : null,
                t('system.backup.took', { duration: durationLabel(runDuration(test)) }),
              ]
                .filter(Boolean)
                .join(' · ')}
            </Muted>
            {test.error ? <span className="text-xs break-words text-destructive">{test.error}</span> : null}
          </>
        ) : (
          <Muted>{t('system.backup.never')}</Muted>
        )}
      </Fact>
      <Fact label={t('system.backup.summary.staging')}>
        {disk ? (
          <>
            <span className="tabular text-xs">{diskText}</span>
            <UsageBar
              ratio={disk.used}
              tone={usageTone(disk.used) === 'ok' ? 'accent' : usageTone(disk.used)}
              label={t('system.backup.summary.staging')}
              valueText={diskText}
            />
          </>
        ) : (
          <Muted>{t('system.backup.unknown')}</Muted>
        )}
      </Fact>
    </dl>
  )
}

function Requests({ overview }: { overview: BackupOverview }) {
  const { t } = useTranslation()
  const request = useRequestBackup()
  const configured = overview.config.configured
  const pending = (kind: BackupRequestKind) => overview.requests.find((item) => item.kind === kind)
  const ask = (kind: BackupRequestKind) =>
    void request
      .mutateAsync(kind)
      .then(() => toast.success(t(`system.backup.requested.${kind}`)))
      .catch((error: unknown) => toast.error(errorText(error)))
  const buttons: { kind: BackupRequestKind; icon: typeof DatabaseBackupIcon }[] = [
    { kind: 'base', icon: DatabaseBackupIcon },
    { kind: 'restore_test', icon: FlaskConicalIcon },
  ]
  return (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap gap-2">
        {buttons.map(({ kind, icon: Icon }) => (
          <Button
            key={kind}
            size="sm"
            variant="outline"
            disabled={!configured || request.isPending || pending(kind) !== undefined}
            onClick={() => ask(kind)}
          >
            {request.isPending && request.variables === kind ? <LoaderCircleIcon className="animate-spin" /> : <Icon />}
            {t(`system.backup.request.${kind}`)}
          </Button>
        ))}
      </div>
      {!configured ? <p className="text-xs text-muted-foreground">{t('system.backup.requestNeedsConfig')}</p> : null}
      {overview.requests.length > 0 ? (
        <ul className="flex flex-col gap-1" aria-live="polite">
          {overview.requests.map((item) => (
            <li key={item.kind} className="flex items-center gap-2 text-xs text-muted-foreground">
              <LoaderCircleIcon className="size-3.5 animate-spin" aria-hidden="true" />
              {t('system.backup.pending', {
                kind: t(`system.backup.kinds.${item.kind}`),
                name: item.requested_by ?? '–',
                time: stamp(item.requested_at),
              })}
            </li>
          ))}
          {!overview.summary.live ? <li className="text-xs text-warning">{t('system.backup.pendingOffline')}</li> : null}
        </ul>
      ) : null}
    </div>
  )
}

type TargetForm = Omit<BackupTargetInput, 'password' | 'secretAccessKey'>

function targetOf(config: BackupConfig): TargetForm {
  return {
    endpoint: config.endpoint ?? '',
    bucket: config.bucket ?? '',
    prefix: config.prefix ?? '',
    region: config.region ?? '',
    accessKeyId: config.access_key_id ?? '',
  }
}

const targetKey = (config: BackupConfig) =>
  [
    config.endpoint,
    config.bucket,
    config.prefix,
    config.region,
    config.access_key_id,
    config.secret_set,
    config.password_set,
  ].join('|')

function TargetCard({ config }: { config: BackupConfig }) {
  const { t } = useTranslation()
  const ids = useId()
  const save = useSetBackupTarget()
  const [form, setForm] = useState<TargetForm>(() => targetOf(config))
  const [secret, setSecret] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [acknowledged, setAcknowledged] = useState(false)
  const [checked, setChecked] = useState(false)
  const input: BackupTargetInput = { ...form, secretAccessKey: secret.trim(), password }
  const mode = passwordMode(config, input)
  const problems = targetProblems(input, { confirm, acknowledged }, config)
  const shown = checked ? problems : {}
  const update = (patch: Partial<TargetForm>) => setForm((current) => ({ ...current, ...patch }))
  const problem = (field: TargetField) => {
    const value = shown[field]
    return value ? t(`system.backup.problems.${field}.${value}` as 'system.backup.problems.endpoint.required') : undefined
  }

  const clearSecrets = () => {
    setSecret('')
    setPassword('')
    setConfirm('')
    setAcknowledged(false)
  }

  const submit = () => {
    setChecked(true)
    if (Object.keys(problems).length > 0) return
    save
      .mutateAsync({ ...input, password: mode === 'locked' ? '' : password })
      .then(() => {
        clearSecrets()
        setChecked(false)
        toast.success(t('system.backup.targetSaved'))
      })
      .catch((error: unknown) => {
        toast.error(errorText(error))
      })
      .finally(() => save.reset())
  }

  return (
    <SettingsCard title={t('system.backup.targetTitle')} subtitle={t('system.backup.targetHint')}>
      <form
        className="flex flex-col gap-4"
        noValidate
        autoComplete="off"
        onSubmit={(event) => {
          event.preventDefault()
          submit()
        }}
      >
        <div className="grid gap-4 sm:grid-cols-2">
          <TextField
            id={`${ids}-endpoint`}
            label={t('system.backup.fields.endpoint')}
            value={form.endpoint}
            placeholder="https://s3.example.co.id"
            inputMode="url"
            onChange={(endpoint) => update({ endpoint })}
            error={problem('endpoint')}
          />
          <TextField
            id={`${ids}-bucket`}
            label={t('system.backup.fields.bucket')}
            value={form.bucket}
            onChange={(bucket) => update({ bucket })}
            error={problem('bucket')}
          />
          <TextField
            id={`${ids}-prefix`}
            label={t('system.backup.fields.prefix')}
            value={form.prefix}
            placeholder="olt/prod"
            onChange={(prefix) => update({ prefix })}
            error={problem('prefix')}
            hint={t('system.backup.fields.prefixHint')}
          />
          <TextField
            id={`${ids}-region`}
            label={t('system.backup.fields.region')}
            value={form.region}
            onChange={(region) => update({ region })}
            error={problem('region')}
            hint={t('system.backup.fields.optional')}
          />
          <TextField
            id={`${ids}-key`}
            label={t('system.backup.fields.accessKeyId')}
            value={form.accessKeyId}
            autoComplete="off"
            spellCheck={false}
            onChange={(accessKeyId) => update({ accessKeyId })}
            error={problem('accessKeyId')}
          />
          <SecretField
            id={`${ids}-secret`}
            label={t('system.backup.fields.secretAccessKey')}
            stored={config.secret_set}
            value={secret}
            onChange={setSecret}
            error={problem('secretAccessKey')}
          />
        </div>
        <section
          aria-labelledby={`${ids}-password-title`}
          className="flex flex-col gap-3 rounded-lg border bg-subtle p-3"
        >
          <h3 id={`${ids}-password-title`} className="flex items-center gap-2 text-row font-semibold">
            <LockIcon className="size-4 text-muted-foreground" aria-hidden="true" />
            {t('system.backup.password.title')}
          </h3>
          {mode === 'locked' ? (
            <p className="flex items-start gap-2 text-row">
              <InfoIcon className="mt-0.5 size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
              <span>
                {config.password_set_at
                  ? t('system.backup.password.lockedSince', { time: stamp(config.password_set_at) })
                  : t('system.backup.password.locked')}{' '}
                {t('system.backup.password.lockedHint')}
              </span>
            </p>
          ) : (
            <>
              {mode === 'new_repository' ? (
                <p role="note" className="flex items-start gap-2 text-row text-warning">
                  <TriangleAlertIcon className="mt-0.5 size-4 shrink-0" aria-hidden="true" />
                  {t('system.backup.password.newRepository')}
                </p>
              ) : (
                <p className="text-row text-muted-foreground">{t('system.backup.password.first')}</p>
              )}
              <div className="grid gap-4 sm:grid-cols-2">
                <SecretField
                  id={`${ids}-password`}
                  label={t('system.backup.fields.password')}
                  stored={false}
                  value={password}
                  onChange={setPassword}
                  error={problem('password')}
                  hint={t('system.backup.password.length', { min: BACKUP_PASSWORD_MIN })}
                />
                <SecretField
                  id={`${ids}-confirm`}
                  label={t('system.backup.fields.confirm')}
                  stored={false}
                  value={confirm}
                  onChange={setConfirm}
                  error={problem('confirm')}
                  hint={t('system.backup.password.confirmHint')}
                />
              </div>
              <div className="flex items-start gap-2">
                <Checkbox
                  id={`${ids}-ack`}
                  checked={acknowledged}
                  className="mt-0.5"
                  aria-invalid={shown.acknowledged ? true : undefined}
                  aria-describedby={`${ids}-ack-text`}
                  onCheckedChange={(value) => setAcknowledged(value === true)}
                />
                <div className="flex flex-col gap-1">
                  <Label htmlFor={`${ids}-ack`} className="leading-snug font-normal">
                    {t('system.backup.password.acknowledge')}
                  </Label>
                  <FieldText id={`${ids}-ack-text`} error={problem('acknowledged')} />
                </div>
              </div>
            </>
          )}
          <p className="text-xs text-muted-foreground">{t('system.backup.password.cannotChange')}</p>
        </section>
        <div className="flex flex-wrap items-center gap-3">
          <Button type="submit" size="sm" disabled={save.isPending}>
            {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
            {t('system.backup.saveTarget')}
          </Button>
          {config.updated_at && config.configured ? (
            <span className="text-xs text-muted-foreground">
              {t('system.lastChanged', { time: stamp(config.updated_at), name: config.updated_by ?? '–' })}
            </span>
          ) : null}
        </div>
      </form>
    </SettingsCard>
  )
}

function weekdayName(day: number, language: string) {
  return formatLocal(new Date(2024, 0, 7 + day), 'EEEE', { locale: language === 'en' ? enUS : idLocale })
}

type NumberField = keyof typeof scheduleLimits

function ScheduleCard({ config }: { config: BackupConfig }) {
  const { t, i18n } = useTranslation()
  const ids = useId()
  const save = useSetBackupSchedule()
  const [form, setForm] = useState<Record<keyof BackupScheduleInput, string | boolean>>(() => {
    const value = scheduleOf(config)
    return {
      ...value,
      offsiteMinutes: String(value.offsiteMinutes),
      retentionDaily: String(value.retentionDaily),
      retentionWeekly: String(value.retentionWeekly),
      retentionMonthly: String(value.retentionMonthly),
      walDays: String(value.walDays),
      restoreTestWeekday: String(value.restoreTestWeekday),
    }
  })
  const [checked, setChecked] = useState(false)
  const text = (key: keyof BackupScheduleInput) => String(form[key])
  const number = (key: keyof BackupScheduleInput) => (/^\d+$/.test(text(key)) ? Number(text(key)) : Number.NaN)
  const input: BackupScheduleInput = {
    baseTime: text('baseTime'),
    offsiteMinutes: number('offsiteMinutes'),
    retentionDaily: number('retentionDaily'),
    retentionWeekly: number('retentionWeekly'),
    retentionMonthly: number('retentionMonthly'),
    walDays: number('walDays'),
    restoreTest: form.restoreTest === true,
    restoreTestWeekday: number('restoreTestWeekday'),
    restoreTestTime: text('restoreTestTime'),
  }
  const problems = scheduleProblems(input)
  const shown = checked ? problems : {}
  const set = (key: keyof BackupScheduleInput, value: string | boolean) =>
    setForm((current) => ({ ...current, [key]: value }))

  const numberField = (key: NumberField) => {
    const [min, max] = scheduleLimits[key]
    return (
      <TextField
        key={key}
        id={`${ids}-${key}`}
        label={t(`system.backup.schedule.${key}`)}
        value={text(key)}
        inputMode="numeric"
        onChange={(value) => set(key, value)}
        error={shown[key] ? t('system.backup.schedule.range', { min, max }) : undefined}
        hint={t('system.backup.schedule.range', { min, max })}
      />
    )
  }

  return (
    <SettingsCard title={t('system.backup.schedule.title')} subtitle={t('system.backup.schedule.hint')}>
      <form
        className="flex flex-col gap-4"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (Object.keys(problems).length > 0) return
          save
            .mutateAsync(input)
            .then(() => {
              setChecked(false)
              toast.success(t('system.backup.schedule.saved'))
            })
            .catch((error: unknown) => toast.error(errorText(error)))
        }}
      >
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <TextField
            id={`${ids}-base`}
            type="time"
            label={t('system.backup.schedule.baseTime')}
            value={text('baseTime')}
            onChange={(value) => set('baseTime', value)}
            error={shown.baseTime ? t('system.backup.schedule.timeInvalid') : undefined}
            hint={t('system.backup.schedule.baseTimeHint')}
          />
          {numberField('offsiteMinutes')}
          {numberField('walDays')}
          {numberField('retentionDaily')}
          {numberField('retentionWeekly')}
          {numberField('retentionMonthly')}
        </div>
        <fieldset className="flex flex-col gap-3 rounded-lg border p-3">
          <legend className="px-1 text-row font-semibold">{t('system.backup.schedule.restoreTitle')}</legend>
          <div className="flex items-center gap-2">
            <Switch
              id={`${ids}-restore`}
              checked={form.restoreTest === true}
              onCheckedChange={(value) => set('restoreTest', value)}
            />
            <Label htmlFor={`${ids}-restore`}>{t('system.backup.schedule.restoreTest')}</Label>
          </div>
          <p className="text-xs text-muted-foreground">{t('system.backup.schedule.restoreHint')}</p>
          <div className="flex flex-col gap-1.5">
            <span id={`${ids}-weekday`} className="text-row font-medium">
              {t('system.backup.schedule.weekday')}
            </span>
            <ToggleGroup
              type="single"
              value={text('restoreTestWeekday')}
              disabled={form.restoreTest !== true}
              aria-labelledby={`${ids}-weekday`}
              className="flex-wrap"
              onValueChange={(value) => value && set('restoreTestWeekday', value)}
            >
              {weekdays.map((day) => {
                const name = weekdayName(day, i18n.language)
                return (
                  <ToggleGroupItem key={day} value={String(day)} aria-label={name} className="px-2.5 capitalize">
                    {name.slice(0, 3)}
                  </ToggleGroupItem>
                )
              })}
            </ToggleGroup>
          </div>
          <TextField
            id={`${ids}-restore-time`}
            type="time"
            className="sm:max-w-48"
            label={t('system.backup.schedule.restoreTime')}
            value={text('restoreTestTime')}
            disabled={form.restoreTest !== true}
            onChange={(value) => set('restoreTestTime', value)}
            error={shown.restoreTestTime ? t('system.backup.schedule.timeInvalid') : undefined}
          />
        </fieldset>
        <Button type="submit" size="sm" className="self-start" disabled={save.isPending}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('system.backup.schedule.save')}
        </Button>
      </form>
    </SettingsCard>
  )
}

function Runs({ runs }: { runs: BackupRun[] }) {
  const { t } = useTranslation()
  return (
    <SettingsCard title={t('system.backup.runs.title')}>
      {runs.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('system.backup.runs.empty')}</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('system.backup.runs.kind')}</TableHead>
              <TableHead>{t('system.backup.runs.status')}</TableHead>
              <TableHead>{t('system.backup.runs.finished')}</TableHead>
              <TableHead>{t('system.backup.runs.duration')}</TableHead>
              <TableHead>{t('system.backup.runs.size')}</TableHead>
              <TableHead>{t('system.backup.runs.snapshot')}</TableHead>
              <TableHead>{t('system.backup.runs.error')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {runs.map((run) => (
              <TableRow key={run.id}>
                <TableCell>{t(`system.backup.kinds.${run.kind}`)}</TableCell>
                <TableCell>
                  <ToneBadge tone={run.status === 'ok' ? 'ok' : 'late'}>{t(`system.backup.runStatus.${run.status}`)}</ToneBadge>
                </TableCell>
                <TableCell className="tabular text-xs text-muted-foreground">{stamp(run.finished_at)}</TableCell>
                <TableCell className="tabular text-xs">{durationLabel(runDuration(run))}</TableCell>
                <TableCell className="tabular text-xs">{run.bytes === undefined ? '–' : formatBytes(run.bytes)}</TableCell>
                <TableCell className="font-mono text-xs" title={run.snapshot_id}>
                  {run.snapshot_id ? run.snapshot_id.slice(0, 12) : '–'}
                </TableCell>
                <TableCell className="max-w-72 truncate text-xs text-destructive" title={run.error}>
                  {run.error ?? ''}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </SettingsCard>
  )
}

export function BackupTab() {
  const { t } = useTranslation()
  const overview = useBackupOverview()
  return (
    <QueryContent query={overview}>
      {(data) => (
        <div className="flex flex-col gap-5">
          <Summary overview={data} />
          <SettingsCard title={t('system.backup.manualTitle')} subtitle={t('system.backup.manualHint')}>
            <Requests overview={data} />
          </SettingsCard>
          <TargetCard key={targetKey(data.config)} config={data.config} />
          <ScheduleCard key={JSON.stringify(scheduleOf(data.config))} config={data.config} />
          <Runs runs={data.runs} />
        </div>
      )}
    </QueryContent>
  )
}
