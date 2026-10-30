import { LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'

import { useSaveSettings, useSettingEntries } from '../hooks'
import { placeholders } from '../logic'
import type { SettingEntry } from '../types'
import { ChangedBy, QueryContent, SectionFrame, SettingsCard } from './settings-ui'

function texts(value: unknown) {
  const source = typeof value === 'object' && value !== null ? (value as Record<string, unknown>) : {}
  return {
    id: typeof source.id === 'string' ? source.id : '',
    en: typeof source.en === 'string' ? source.en : '',
  }
}

function MessageEditor({ entry }: { entry: SettingEntry }) {
  const { t } = useTranslation()
  const save = useSaveSettings()
  const saved = texts(entry.value)
  const [draft, setDraft] = useState(saved)
  const changed = draft.id !== saved.id || draft.en !== saved.en
  const valid = [draft.id, draft.en].every((text) => text.trim().length >= 2 && text.trim().length <= 500)
  const variables = placeholders([saved.id, saved.en])
  const fields = [
    { language: 'id' as const, label: t('settings.messageId') },
    { language: 'en' as const, label: t('settings.messageEn') },
  ]
  return (
    <SettingsCard
      title={entry.description ?? entry.key}
      subtitle={
        variables.length === 0
          ? t('settings.noVariables')
          : `${t('settings.variables')}: ${variables.join(', ')}`
      }
    >
      {fields.map((field) => {
        const id = `${entry.key}-${field.language}`
        const length = draft[field.language].trim().length
        return (
          <div key={field.language} className="flex flex-col gap-1.5">
            <Label htmlFor={id}>{field.label}</Label>
            <Textarea
              id={id}
              rows={3}
              maxLength={500}
              value={draft[field.language]}
              aria-invalid={length < 2 ? true : undefined}
              onChange={(event) =>
                setDraft((current) => ({ ...current, [field.language]: event.target.value }))
              }
            />
            <p
              className={
                length < 2 ? 'text-xs text-destructive' : 'tabular text-right text-xs text-muted-foreground'
              }
            >
              {length < 2 ? t('settings.messageInvalid') : `${draft[field.language].length}/500`}
            </p>
          </div>
        )
      })}
      <div className="flex flex-wrap items-center gap-3">
        <Button
          disabled={!changed || !valid || save.isPending}
          onClick={() => save.mutate({ [entry.key]: { id: draft.id.trim(), en: draft.en.trim() } })}
        >
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
        <ChangedBy entry={entry} />
      </div>
    </SettingsCard>
  )
}

export function MessagesSection() {
  const { t } = useTranslation()
  const settings = useSettingEntries()
  return (
    <SectionFrame title={t('settings.messages')} description={t('settings.messagesDescription')}>
      <QueryContent query={settings}>
        {(items) => (
          <div className="flex flex-col gap-4">
            {items
              .filter((entry) => entry.key.startsWith('messages.'))
              .map((entry) => (
                <MessageEditor key={`${entry.key}-${entry.version}`} entry={entry} />
              ))}
          </div>
        )}
      </QueryContent>
    </SectionFrame>
  )
}
