import { useTranslation } from 'react-i18next'

import { Dot } from '@/components/badges'
import { Switch } from '@/components/ui/controls'
import { useAgent } from '@/features/auth/hooks'

import { findSetting, useSaveSettings, useSettingEntries } from '../hooks'
import type { SettingEntry } from '../types'
import { ChangedBy, QueryContent, SectionFrame, SettingsCard } from './settings-ui'

function FourEyesCard({ items }: { items: SettingEntry[] }) {
  const { t } = useTranslation()
  const save = useSaveSettings()
  const entry = findSetting(items, 'community.four_eyes')
  const enabled = entry?.value !== false
  return (
    <SettingsCard title={t('settings.fourEyes')} subtitle={t('settings.fourEyesHint')}>
      <label className="flex h-9 items-center gap-2 text-sm font-medium">
        <Switch
          checked={enabled}
          disabled={save.isPending}
          aria-label={t('settings.fourEyes')}
          onCheckedChange={(value) => save.mutate({ 'community.four_eyes': value })}
        />
        {enabled ? t('app.active') : t('app.inactive')}
      </label>
      <ChangedBy entry={entry} />
    </SettingsCard>
  )
}

function PushCard() {
  const { t } = useTranslation()
  const ready = useAgent().settings.community_push_ready
  return (
    <SettingsCard title={t('settings.pushChannel')}>
      <p className="flex items-start gap-2 text-row">
        <Dot tone={ready ? 'ok' : 'warn'} className="mt-1.5" />
        {ready ? t('settings.pushReady') : t('settings.pushNotReady')}
      </p>
    </SettingsCard>
  )
}

export function CommunitySection() {
  const { t } = useTranslation()
  const settings = useSettingEntries()
  return (
    <SectionFrame title={t('settings.community')} description={t('settings.communityDescription')}>
      <QueryContent query={settings}>
        {(items) => (
          <div className="flex flex-col gap-4">
            <FourEyesCard items={items} />
            <PushCard />
          </div>
        )}
      </QueryContent>
    </SectionFrame>
  )
}
