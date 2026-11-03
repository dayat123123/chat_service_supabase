import { LoaderCircleIcon, PlusIcon, Trash2Icon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { QueryContent } from '@/features/settings/components/settings-ui'
import { FieldText } from '@/features/system/components/system-ui'
import { policyErrorText } from '@/lib/error-text'
import { formatNumber } from '@/lib/time'

import { useManipulationSettings, useSetManipulationSettings } from '../hooks'
import {
  manipulationChanges,
  manipulationForm,
  manipulationProblems,
  manipulationValid,
  type ManipulationForm,
} from '../logic'
import {
  booleanSettings,
  manipulationGroups,
  MAX_BUSY_WINDOWS,
  numberSettings,
  type ManipulationGroup,
  type ManipulationSettings,
  type NumberSetting,
} from '../types'
import { PolicyCard } from './policy-ui'

const rangeOf = (setting: NumberSetting) =>
  setting.percent
    ? { min: formatNumber(setting.min * 100), max: formatNumber(setting.max * 100) }
    : { min: formatNumber(setting.min), max: formatNumber(setting.max) }

function SettingsForm({ settings }: { settings: ManipulationSettings }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSetManipulationSettings()
  const [form, setForm] = useState<ManipulationForm>(() => manipulationForm(settings))
  const [checked, setChecked] = useState(false)
  const problems = manipulationProblems(form)
  const valid = manipulationValid(problems)
  const changes = manipulationChanges(settings, form)
  const dirty = Object.keys(changes).length > 0
  const groupItems = (group: ManipulationGroup) => numberSettings.filter((setting) => setting.group === group)
  return (
    <form
      className="flex flex-col gap-6"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (!valid || !dirty) return
        save
          .mutateAsync(changes)
          .then(() => {
            toast.success(t('policy.manipulation.saved', { count: Object.keys(changes).length }))
            setChecked(false)
          })
          .catch((error: unknown) => toast.error(policyErrorText(error)))
      }}
    >
      {manipulationGroups.map((group) => (
        <fieldset key={group} className="flex flex-col gap-3 border-t pt-4">
          <legend className="sr-only">{t(`policy.manipulation.groups.${group}`)}</legend>
          <div aria-hidden="true">
            <h3 className="text-sm font-semibold">{t(`policy.manipulation.groups.${group}`)}</h3>
            <p className="max-w-3xl text-xs text-muted-foreground">
              {t(`policy.manipulation.groupHints.${group}`)}
            </p>
          </div>
          {group === 'auto'
            ? booleanSettings.map((setting) => (
                <label key={setting.id} className="flex items-start gap-2 text-row">
                  <Switch
                    className="mt-0.5"
                    checked={form.booleans[setting.id] ?? false}
                    onCheckedChange={(value) =>
                      setForm((current) => ({
                        ...current,
                        booleans: { ...current.booleans, [setting.id]: value },
                      }))
                    }
                  />
                  <span>
                    <span className="block font-medium">{t(`policy.manipulation.fields.${setting.id}`)}</span>
                    <span className="block text-xs text-muted-foreground">
                      {t(`policy.manipulation.fieldHints.${setting.id}`)}
                    </span>
                  </span>
                </label>
              ))
            : null}
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {groupItems(group).map((setting) => {
              const invalid = checked && problems.numbers.includes(setting.id)
              return (
                <div key={setting.id} className="flex min-w-0 flex-col gap-1.5">
                  <Label htmlFor={`${id}-${setting.id}`}>
                    {t(`policy.manipulation.fields.${setting.id}`)}
                  </Label>
                  <Input
                    id={`${id}-${setting.id}`}
                    inputMode="decimal"
                    value={form.numbers[setting.id] ?? ''}
                    aria-invalid={invalid ? true : undefined}
                    aria-describedby={`${id}-${setting.id}-text`}
                    onChange={(event) =>
                      setForm((current) => ({
                        ...current,
                        numbers: { ...current.numbers, [setting.id]: event.target.value },
                      }))
                    }
                  />
                  <FieldText
                    id={`${id}-${setting.id}-text`}
                    error={
                      invalid
                        ? t(
                            setting.integer
                              ? 'policy.manipulation.rangeInteger'
                              : 'policy.manipulation.range',
                            rangeOf(setting),
                          )
                        : undefined
                    }
                    hint={t(`policy.manipulation.fieldHints.${setting.id}`, rangeOf(setting))}
                  />
                </div>
              )
            })}
          </div>
          {group === 'busy' ? (
            <div className="flex flex-col gap-2">
              <p className="text-sm font-medium" id={`${id}-windows`}>
                {t('policy.manipulation.windows')}
              </p>
              <ul className="flex flex-col gap-2" aria-labelledby={`${id}-windows`}>
                {form.windows.map((window, index) => {
                  const invalid = checked && problems.windows.includes(index)
                  return (
                    <li key={index} className="flex flex-wrap items-center gap-2">
                      <Input
                        type="time"
                        className="h-8 w-32"
                        aria-label={t('policy.manipulation.windowStart', { index: index + 1 })}
                        aria-invalid={invalid ? true : undefined}
                        value={window.start}
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            windows: current.windows.map((item, i) =>
                              i === index ? { ...item, start: event.target.value } : item,
                            ),
                          }))
                        }
                      />
                      <span aria-hidden="true">–</span>
                      <Input
                        type="time"
                        className="h-8 w-32"
                        aria-label={t('policy.manipulation.windowEnd', { index: index + 1 })}
                        aria-invalid={invalid ? true : undefined}
                        value={window.end}
                        onChange={(event) =>
                          setForm((current) => ({
                            ...current,
                            windows: current.windows.map((item, i) =>
                              i === index ? { ...item, end: event.target.value } : item,
                            ),
                          }))
                        }
                      />
                      <Button
                        type="button"
                        size="icon-xs"
                        variant="ghost"
                        aria-label={t('policy.manipulation.removeWindow', { index: index + 1 })}
                        onClick={() =>
                          setForm((current) => ({
                            ...current,
                            windows: current.windows.filter((_, i) => i !== index),
                          }))
                        }
                      >
                        <Trash2Icon />
                      </Button>
                      {invalid ? (
                        <span role="alert" className="text-xs text-destructive">
                          {t('policy.manipulation.windowProblem')}
                        </span>
                      ) : null}
                    </li>
                  )
                })}
              </ul>
              <Button
                type="button"
                size="xs"
                variant="outline"
                className="self-start"
                disabled={form.windows.length >= MAX_BUSY_WINDOWS}
                onClick={() =>
                  setForm((current) => ({
                    ...current,
                    windows: [...current.windows, { start: '09:00', end: '09:30' }],
                  }))
                }
              >
                <PlusIcon />
                {t('policy.manipulation.addWindow')}
              </Button>
              <p className="text-xs text-muted-foreground">
                {t('policy.manipulation.windowsHint', { max: MAX_BUSY_WINDOWS })}
              </p>
            </div>
          ) : null}
        </fieldset>
      ))}
      <div className="flex flex-wrap items-center gap-3 border-t pt-4">
        <Button type="submit" size="sm" disabled={save.isPending || !dirty}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
        {checked && !valid ? (
          <span role="alert" className="text-xs text-destructive">
            {t('policy.manipulation.fixFields')}
          </span>
        ) : (
          <span className="text-xs text-muted-foreground">
            {dirty
              ? t('policy.manipulation.pending', { count: Object.keys(changes).length })
              : t('policy.manipulation.noChanges')}
          </span>
        )}
      </div>
    </form>
  )
}

export function ManipulationTab() {
  const { t } = useTranslation()
  const settings = useManipulationSettings()
  return (
    <PolicyCard title={t('policy.manipulation.title')} subtitle={t('policy.manipulation.subtitle')}>
      <QueryContent query={settings}>
        {(data) => <SettingsForm key={JSON.stringify(data)} settings={data} />}
      </QueryContent>
    </PolicyCard>
  )
}
