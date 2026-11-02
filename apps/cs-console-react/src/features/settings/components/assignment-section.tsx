import { LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { RadioGroup, RadioGroupItem, Switch } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

import { findSetting, useSaveSettings, useSettingEntries } from '../hooks'
import type { SettingEntry } from '../types'
import { ChangedBy, FieldMessage, QueryContent, SectionFrame, SettingsCard } from './settings-ui'

function numberSetting(items: SettingEntry[], key: string, fallback: number) {
  const value = findSetting(items, key)?.value
  return typeof value === 'number' && Number.isFinite(value) ? Math.trunc(value) : fallback
}

function inRange(value: string, min: number, max: number) {
  if (!/^\d{1,4}$/.test(value.trim())) return false
  const number = Number(value.trim())
  return number >= min && number <= max
}

function SaveButton({
  pending,
  disabled,
  onClick,
}: {
  pending: boolean
  disabled?: boolean
  onClick: () => void
}) {
  const { t } = useTranslation()
  return (
    <Button disabled={disabled || pending} onClick={onClick}>
      {pending ? <LoaderCircleIcon className="animate-spin" /> : null}
      {t('app.save')}
    </Button>
  )
}

function ModeCard({ items }: { items: SettingEntry[] }) {
  const { t } = useTranslation()
  const save = useSaveSettings()
  const entry = findSetting(items, 'assignment.mode')
  const current = typeof entry?.value === 'string' ? entry.value : 'claim'
  const [mode, setMode] = useState(current)
  const options = [
    { value: 'claim', label: t('settings.modeClaim'), hint: t('settings.modeClaimHint') },
    { value: 'auto_assign', label: t('settings.modeAuto'), hint: t('settings.modeAutoHint') },
  ]
  return (
    <SettingsCard title={t('settings.assignmentMode')}>
      <RadioGroup value={mode} onValueChange={setMode} className="flex flex-col gap-3">
        {options.map((option) => (
          <label
            key={option.value}
            className="flex cursor-pointer items-start gap-3 rounded-lg border p-3 has-[[data-state=checked]]:border-primary/50 has-[[data-state=checked]]:bg-primary/5"
          >
            <RadioGroupItem value={option.value} className="mt-0.5" />
            <span>
              <span className="block text-sm font-medium">{option.label}</span>
              <span className="block text-xs text-muted-foreground">{option.hint}</span>
            </span>
          </label>
        ))}
      </RadioGroup>
      <div className="flex flex-wrap items-center gap-3">
        <SaveButton
          pending={save.isPending}
          disabled={mode === current}
          onClick={() => save.mutate({ 'assignment.mode': mode })}
        />
        <ChangedBy entry={entry} />
      </div>
    </SettingsCard>
  )
}

function ReleaseCard({ items }: { items: SettingEntry[] }) {
  const { t } = useTranslation()
  const save = useSaveSettings()
  const saved = numberSetting(items, 'ticket.auto_release_offline_minutes', 0)
  const [enabled, setEnabled] = useState(saved > 0)
  const [minutes, setMinutes] = useState(String(saved > 0 ? saved : 30))
  const [touched, setTouched] = useState(false)
  const valid = !enabled || inRange(minutes, 1, 1440)
  return (
    <SettingsCard title={t('settings.autoRelease')} subtitle={t('settings.autoReleaseHint')}>
      <div className="flex flex-wrap items-end gap-4">
        <label className="flex h-9 items-center gap-2 text-sm font-medium">
          <Switch checked={enabled} onCheckedChange={setEnabled} aria-label={t('settings.autoRelease')} />
          {enabled ? t('app.active') : t('app.inactive')}
        </label>
        <div className="flex w-64 flex-col gap-1.5">
          <Label htmlFor="release-minutes">{t('settings.autoReleaseMinutes')}</Label>
          <Input
            id="release-minutes"
            inputMode="numeric"
            maxLength={4}
            disabled={!enabled}
            value={minutes}
            aria-invalid={touched && !valid ? true : undefined}
            onChange={(event) => setMinutes(event.target.value)}
          />
        </div>
        <SaveButton
          pending={save.isPending}
          onClick={() => {
            setTouched(true)
            if (!valid) return
            save.mutate({ 'ticket.auto_release_offline_minutes': enabled ? Number(minutes.trim()) : 0 })
          }}
        />
      </div>
      <FieldMessage
        error={touched && !valid ? t('settings.numberRange', { min: 1, max: 1440 }) : undefined}
      />
      <ChangedBy entry={findSetting(items, 'ticket.auto_release_offline_minutes')} />
    </SettingsCard>
  )
}

function CloseCard({ items }: { items: SettingEntry[] }) {
  const { t } = useTranslation()
  const save = useSaveSettings()
  const saved = numberSetting(items, 'ticket.auto_close_days', 3)
  const [days, setDays] = useState(String(saved))
  const [touched, setTouched] = useState(false)
  const valid = inRange(days, 1, 30)
  return (
    <SettingsCard title={t('settings.autoClose')} subtitle={t('settings.autoCloseHint')}>
      <div className="flex flex-wrap items-end gap-4">
        <div className="flex w-72 flex-col gap-1.5">
          <Label htmlFor="close-days">{t('settings.autoCloseDays')}</Label>
          <Input
            id="close-days"
            inputMode="numeric"
            maxLength={2}
            value={days}
            aria-invalid={touched && !valid ? true : undefined}
            onChange={(event) => setDays(event.target.value)}
          />
        </div>
        <SaveButton
          pending={save.isPending}
          disabled={valid && Number(days.trim()) === saved}
          onClick={() => {
            setTouched(true)
            if (!valid) return
            save.mutate({ 'ticket.auto_close_days': Number(days.trim()) })
          }}
        />
      </div>
      <FieldMessage error={touched && !valid ? t('settings.numberRange', { min: 1, max: 30 }) : undefined} />
      <ChangedBy entry={findSetting(items, 'ticket.auto_close_days')} />
    </SettingsCard>
  )
}

function AlertsCard({ items }: { items: SettingEntry[] }) {
  const { t } = useTranslation()
  const save = useSaveSettings()
  const [unclaimed, setUnclaimed] = useState(String(numberSetting(items, 'alerts.unclaimed_minutes', 10)))
  const [p1, setP1] = useState(String(numberSetting(items, 'alerts.p1_unclaimed_minutes', 2)))
  const [touched, setTouched] = useState(false)
  const fields = [
    { id: 'alert-unclaimed', label: t('settings.alertUnclaimed'), value: unclaimed, set: setUnclaimed },
    { id: 'alert-p1', label: t('settings.alertP1'), value: p1, set: setP1 },
  ]
  const valid = fields.every((field) => inRange(field.value, 1, 240))
  return (
    <SettingsCard title={t('settings.superAdminAlerts')}>
      <div className="flex flex-wrap items-end gap-4">
        {fields.map((field) => (
          <div key={field.id} className="flex w-72 flex-col gap-1.5">
            <Label htmlFor={field.id}>{field.label}</Label>
            <Input
              id={field.id}
              inputMode="numeric"
              maxLength={3}
              value={field.value}
              aria-invalid={touched && !inRange(field.value, 1, 240) ? true : undefined}
              onChange={(event) => field.set(event.target.value)}
            />
          </div>
        ))}
        <SaveButton
          pending={save.isPending}
          onClick={() => {
            setTouched(true)
            if (!valid) return
            save.mutate({
              'alerts.unclaimed_minutes': Number(unclaimed.trim()),
              'alerts.p1_unclaimed_minutes': Number(p1.trim()),
            })
          }}
        />
      </div>
      <FieldMessage error={touched && !valid ? t('settings.numberRange', { min: 1, max: 240 }) : undefined} />
      <ChangedBy entry={findSetting(items, 'alerts.unclaimed_minutes')} />
    </SettingsCard>
  )
}

export function AssignmentSection() {
  const { t } = useTranslation()
  const settings = useSettingEntries()
  return (
    <SectionFrame title={t('settings.assignment')} description={t('settings.assignmentDescription')}>
      <QueryContent query={settings}>
        {(items) => (
          <div className="flex flex-col gap-4">
            <ModeCard key={`mode-${findSetting(items, 'assignment.mode')?.version ?? 0}`} items={items} />
            <ReleaseCard
              key={`release-${findSetting(items, 'ticket.auto_release_offline_minutes')?.version ?? 0}`}
              items={items}
            />
            <CloseCard
              key={`close-${findSetting(items, 'ticket.auto_close_days')?.version ?? 0}`}
              items={items}
            />
            <AlertsCard
              key={`alerts-${findSetting(items, 'alerts.unclaimed_minutes')?.version ?? 0}-${findSetting(items, 'alerts.p1_unclaimed_minutes')?.version ?? 0}`}
              items={items}
            />
          </div>
        )}
      </QueryContent>
    </SectionFrame>
  )
}
