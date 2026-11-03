import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Switch } from '@/components/ui/controls'
import { usePolicyFourEyes, useSetPolicyFourEyes } from '@/features/compliance/policy-versions/hooks'
import { errorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'

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

function PolicyFourEyesCard() {
  const { t } = useTranslation()
  const query = usePolicyFourEyes()
  const save = useSetPolicyFourEyes()
  return (
    <SettingsCard title={t('settings.policyFourEyes')} subtitle={t('settings.policyFourEyesHint')}>
      <QueryContent query={query}>
        {(setting) => (
          <>
            <label className="flex h-9 items-center gap-2 text-sm font-medium">
              <Switch
                checked={setting.enabled}
                disabled={save.isPending}
                aria-label={t('settings.policyFourEyes')}
                onCheckedChange={(value) =>
                  save.mutate(value, { onError: (caught) => toast.error(errorText(caught)) })
                }
              />
              {setting.enabled ? t('app.active') : t('app.inactive')}
            </label>
            <p className="text-xs text-muted-foreground">
              {setting.updated_by
                ? t('settings.lastChangedBy', { time: stamp(setting.updated_at), name: setting.updated_by })
                : t('settings.lastChanged', { time: stamp(setting.updated_at) })}
            </p>
          </>
        )}
      </QueryContent>
    </SettingsCard>
  )
}

export function CommunitySection() {
  const { t } = useTranslation()
  const settings = useSettingEntries()
  return (
    <SectionFrame title={t('settings.community')} description={t('settings.communityDescription')}>
      <QueryContent query={settings}>{(items) => <FourEyesCard items={items} />}</QueryContent>
      <PolicyFourEyesCard />
    </SectionFrame>
  )
}
