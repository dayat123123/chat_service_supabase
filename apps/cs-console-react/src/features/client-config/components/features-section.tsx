import { LoaderCircleIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Confirm } from '@/features/nasabah/components/confirm'
import { QueryContent, SectionFrame, SettingsCard } from '@/features/settings/components/settings-ui'
import { FieldText } from '@/features/system/components/system-ui'
import { platformErrorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'

import { useClientConfig, useSetMinVersion, useToggleFlag } from '../hooks'
import { featureRows, versionValid } from '../logic'
import { appPlatforms, type ClientConfig, type FeatureRow, type MinVersion } from '../types'
import { KillSwitchCard } from './kill-switch-card'

function FeatureItem({ row, onTurnOff }: { row: FeatureRow; onTurnOff: (row: FeatureRow) => void }) {
  const { t } = useTranslation()
  const id = useId()
  const toggle = useToggleFlag()
  const label = t(`platform.flags.features.${row.key}.label`)
  return (
    <li className="flex items-start gap-4 border-b py-3 last:border-b-0">
      <div className="min-w-0 flex-1">
        <Label htmlFor={`${id}-switch`} className="text-row font-medium">
          {label}
        </Label>
        <p id={`${id}-text`} className="text-xs text-muted-foreground">
          {t(`platform.flags.features.${row.key}.description`)}
        </p>
        {row.updated_at ? (
          <p className="text-xs text-muted-foreground">
            {row.updated_by?.name
              ? t('platform.versions.changedBy', { time: stamp(row.updated_at), name: row.updated_by.name })
              : t('platform.versions.changed', { time: stamp(row.updated_at) })}
          </p>
        ) : null}
      </div>
      <Switch
        id={`${id}-switch`}
        checked={row.enabled}
        disabled={toggle.isPending}
        aria-describedby={`${id}-text`}
        onCheckedChange={(value) => {
          if (!value) {
            onTurnOff(row)
            return
          }
          toggle
            .mutateAsync({ key: row.key, enabled: true })
            .then(() => toast.success(t('platform.flags.turnedOn', { feature: label })))
            .catch((error: unknown) => toast.error(platformErrorText(error)))
        }}
      />
    </li>
  )
}

function FlagsCard({ config }: { config: ClientConfig }) {
  const { t } = useTranslation()
  const toggle = useToggleFlag()
  const [turningOff, setTurningOff] = useState<FeatureRow | null>(null)
  const label = turningOff ? t(`platform.flags.features.${turningOff.key}.label`) : ''
  return (
    <SettingsCard title={t('platform.flags.title')} subtitle={t('platform.flags.subtitle')}>
      <ul className="border-y">
        {featureRows(config.flags).map((row) => (
          <FeatureItem key={row.key} row={row} onTurnOff={setTurningOff} />
        ))}
      </ul>
      <Confirm
        open={turningOff !== null}
        title={t('platform.flags.offTitle', { feature: label })}
        body={t('platform.flags.offBody')}
        action={t('platform.flags.offAction')}
        destructive
        pending={toggle.isPending}
        onClose={() => setTurningOff(null)}
        onConfirm={() =>
          turningOff &&
          toggle
            .mutateAsync({ key: turningOff.key, enabled: false })
            .then(() => {
              toast.success(t('platform.flags.turnedOff', { feature: label }))
              setTurningOff(null)
            })
            .catch((error: unknown) => toast.error(platformErrorText(error)))
        }
      />
    </SettingsCard>
  )
}

function VersionRow({ entry }: { entry: MinVersion }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSetMinVersion()
  const [text, setText] = useState(entry.min_version ?? '')
  const [checked, setChecked] = useState(false)
  const [confirming, setConfirming] = useState(false)
  const value = text.trim() === '' ? null : text.trim()
  const invalid = value !== null && !versionValid(value)
  const dirty = value !== entry.min_version
  const platform = t(`platform.platforms.${entry.platform}`)
  const run = () =>
    save
      .mutateAsync({ platform: entry.platform, version: value })
      .then(() => {
        toast.success(
          value
            ? t('platform.versions.saved', { platform, version: value })
            : t('platform.versions.cleared', { platform }),
        )
        setConfirming(false)
        setChecked(false)
      })
      .catch((error: unknown) => toast.error(platformErrorText(error)))
  return (
    <li className="flex flex-col gap-2 border-b py-3 last:border-b-0 sm:flex-row sm:items-start sm:gap-4">
      <form
        className="flex min-w-0 flex-1 flex-col gap-1.5 sm:flex-row sm:items-start sm:gap-3"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (invalid || !dirty) return
          setConfirming(true)
        }}
      >
        <Label htmlFor={`${id}-version`} className="sm:w-24 sm:pt-2">
          {platform}
        </Label>
        <div className="flex min-w-0 flex-col gap-1.5 sm:w-48">
          <Input
            id={`${id}-version`}
            inputMode="decimal"
            placeholder={t('platform.versions.none')}
            value={text}
            aria-invalid={checked && invalid ? true : undefined}
            aria-describedby={`${id}-text`}
            onChange={(event) => setText(event.target.value)}
          />
          <FieldText
            id={`${id}-text`}
            error={checked && invalid ? t('platform.flags.problems.version') : undefined}
            hint={
              entry.min_version
                ? t('platform.versions.current', { version: entry.min_version })
                : t('platform.versions.noMinimum')
            }
          />
        </div>
        <Button
          type="submit"
          size="sm"
          variant="outline"
          disabled={!dirty || save.isPending}
          className="self-start"
        >
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
      </form>
      <p className="text-xs text-muted-foreground sm:w-48 sm:pt-2">
        {entry.updated_by?.name
          ? t('platform.versions.changedBy', { time: stamp(entry.updated_at), name: entry.updated_by.name })
          : t('platform.versions.changed', { time: stamp(entry.updated_at) })}
      </p>
      <Confirm
        open={confirming}
        title={
          value
            ? t('platform.versions.confirmTitle', { platform, version: value })
            : t('platform.versions.clearTitle', { platform })
        }
        body={value ? t('platform.versions.confirmBody', { platform }) : t('platform.versions.clearBody')}
        action={t('app.save')}
        pending={save.isPending}
        onClose={() => setConfirming(false)}
        onConfirm={() => void run()}
      />
    </li>
  )
}

function VersionsCard({ config }: { config: ClientConfig }) {
  const { t } = useTranslation()
  return (
    <SettingsCard title={t('platform.versions.title')} subtitle={t('platform.versions.subtitle')}>
      <ul className="border-y">
        {[...config.min_versions]
          .sort((a, b) => appPlatforms.indexOf(a.platform) - appPlatforms.indexOf(b.platform))
          .map((entry) => (
            <VersionRow key={`${entry.platform}:${entry.min_version ?? ''}`} entry={entry} />
          ))}
      </ul>
    </SettingsCard>
  )
}

export function FeaturesSection() {
  const { t } = useTranslation()
  const config = useClientConfig()
  return (
    <SectionFrame title={t('platform.flags.pageTitle')} description={t('platform.flags.pageDescription')}>
      <QueryContent query={config}>
        {(data) => (
          <>
            <KillSwitchCard state={data.kill_switch} />
            <FlagsCard config={data} />
            <VersionsCard config={data} />
          </>
        )}
      </QueryContent>
    </SectionFrame>
  )
}
