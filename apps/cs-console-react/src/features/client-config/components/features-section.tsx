import { LoaderCircleIcon, PencilIcon, PlusIcon, Trash2Icon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Confirm } from '@/features/nasabah/components/confirm'
import { QueryContent, SectionFrame, SettingsCard } from '@/features/settings/components/settings-ui'
import { FieldText } from '@/features/system/components/system-ui'
import { platformErrorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'

import { useClientConfig, useDeleteFlag, useSetFlag, useSetMinVersion } from '../hooks'
import { flagDraft, rolloutLabel, versionValid } from '../logic'
import { appPlatforms, type ClientConfig, type FeatureFlag, type MinVersion } from '../types'
import { FlagDialog } from './flag-dialog'
import { KillSwitchCard } from './kill-switch-card'

function FlagSwitch({ flag }: { flag: FeatureFlag }) {
  const { t } = useTranslation()
  const save = useSetFlag()
  return (
    <Switch
      checked={flag.enabled}
      disabled={save.isPending}
      aria-label={t('platform.flags.toggleLabel', { key: flag.key })}
      onCheckedChange={(value) =>
        save
          .mutateAsync({ ...flagDraft(flag), enabled: value })
          .then(() =>
            toast.success(
              value
                ? t('platform.flags.turnedOn', { key: flag.key })
                : t('platform.flags.turnedOff', { key: flag.key }),
            ),
          )
          .catch((error: unknown) => toast.error(platformErrorText(error)))
      }
    />
  )
}

function Rollout({ flag }: { flag: FeatureFlag }) {
  const { t } = useTranslation()
  const kind = rolloutLabel(flag)
  return (
    <span className="text-xs">
      {t(`platform.flags.rollout.${kind}`, { percent: flag.percentage, count: flag.user_ids.length })}
      {flag.percentage < 100 && flag.percentage > 0 && flag.user_ids.length > 0 ? (
        <span className="block text-muted-foreground">
          {t('platform.flags.plusUsers', { count: flag.user_ids.length })}
        </span>
      ) : null}
    </span>
  )
}

function FlagsCard({ config }: { config: ClientConfig }) {
  const { t } = useTranslation()
  const remove = useDeleteFlag()
  const [editing, setEditing] = useState<FeatureFlag | 'new' | null>(null)
  const [removing, setRemoving] = useState<FeatureFlag | null>(null)
  return (
    <SettingsCard title={t('platform.flags.title')} subtitle={t('platform.flags.subtitle')}>
      <Button size="sm" variant="outline" className="self-start" onClick={() => setEditing('new')}>
        <PlusIcon />
        {t('platform.flags.add')}
      </Button>
      {config.flags.length === 0 ? (
        <p className="border-y py-6 text-center text-row text-muted-foreground">
          {t('platform.flags.empty')}
        </p>
      ) : (
        <Table>
          <caption className="sr-only">{t('platform.flags.title')}</caption>
          <TableHeader>
            <TableRow>
              <TableHead>{t('platform.flags.cols.flag')}</TableHead>
              <TableHead>{t('platform.flags.cols.enabled')}</TableHead>
              <TableHead>{t('platform.flags.cols.rollout')}</TableHead>
              <TableHead>{t('platform.flags.cols.platforms')}</TableHead>
              <TableHead>{t('platform.flags.cols.minVersion')}</TableHead>
              <TableHead>{t('platform.flags.cols.updated')}</TableHead>
              <TableHead>
                <span className="sr-only">{t('platform.flags.cols.actions')}</span>
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {config.flags.map((flag) => (
              <TableRow key={flag.key} className="align-top">
                <TableCell className="py-2 whitespace-normal">
                  <p className="font-mono text-row font-medium">{flag.key}</p>
                  {flag.description ? (
                    <p className="max-w-80 text-xs text-muted-foreground">{flag.description}</p>
                  ) : null}
                </TableCell>
                <TableCell className="py-2">
                  <FlagSwitch flag={flag} />
                </TableCell>
                <TableCell className="py-2 whitespace-normal">
                  <Rollout flag={flag} />
                </TableCell>
                <TableCell className="py-2 text-xs">
                  {flag.platforms.length === 0
                    ? t('platform.flags.allPlatforms')
                    : flag.platforms.map((item) => t(`platform.platforms.${item}`)).join(', ')}
                </TableCell>
                <TableCell className="py-2 font-mono text-xs">{flag.min_app_version ?? '–'}</TableCell>
                <TableCell className="py-2 text-xs whitespace-normal text-muted-foreground">
                  {stamp(flag.updated_at)}
                  {flag.updated_by?.name ? <span className="block">{flag.updated_by.name}</span> : null}
                </TableCell>
                <TableCell className="py-2">
                  <div className="flex justify-end gap-1">
                    <Button
                      size="icon-xs"
                      variant="ghost"
                      aria-label={t('platform.flags.editLabel', { key: flag.key })}
                      onClick={() => setEditing(flag)}
                    >
                      <PencilIcon />
                    </Button>
                    <Button
                      size="icon-xs"
                      variant="ghost"
                      aria-label={t('platform.flags.deleteLabel', { key: flag.key })}
                      onClick={() => setRemoving(flag)}
                    >
                      <Trash2Icon />
                    </Button>
                  </div>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
      {editing ? (
        <FlagDialog
          editing={editing === 'new' ? null : editing}
          existing={config.flags.map((flag) => flag.key)}
          onClose={() => setEditing(null)}
        />
      ) : null}
      <Confirm
        open={removing !== null}
        title={t('platform.flags.deleteTitle', { key: removing?.key ?? '' })}
        body={t('platform.flags.deleteBody')}
        action={t('app.delete')}
        destructive
        pending={remove.isPending}
        onClose={() => setRemoving(null)}
        onConfirm={() =>
          removing &&
          remove
            .mutateAsync(removing.key)
            .then(() => {
              toast.success(t('platform.flags.deleted', { key: removing.key }))
              setRemoving(null)
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
