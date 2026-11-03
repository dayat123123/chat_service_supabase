import { FlaskConicalIcon, LoaderCircleIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { FieldText, ToneBadge } from '@/features/system/components/system-ui'
import { policyErrorText } from '@/lib/error-text'

import { useTestContent } from '../hooks'
import { contentCategories, TEST_TEXT_MAX, testSurfaces, type ContentTest, type TestSurface } from '../types'
import { ActionBadge, PolicyCard } from './policy-ui'

const bannedTones = { allow: 'ok', censor: 'warn', block: 'late' } as const

function Result({ result }: { result: ContentTest }) {
  const { t } = useTranslation()
  const categoryLabel = (category: string) =>
    (contentCategories as readonly string[]).includes(category)
      ? t(`policy.categories.${category as (typeof contentCategories)[number]}`)
      : category === 'coordinated'
        ? t('policy.tester.coordinated')
        : category
  return (
    <section
      aria-live="polite"
      aria-label={t('policy.tester.result')}
      className="flex flex-col gap-3 rounded-lg border p-4"
    >
      <dl className="grid gap-x-6 gap-y-3 sm:grid-cols-2 lg:grid-cols-4">
        <div className="flex flex-col gap-1">
          <dt className="text-xs text-muted-foreground">{t('policy.tester.action')}</dt>
          <dd>
            <ActionBadge action={result.action} />
          </dd>
        </div>
        <div className="flex flex-col gap-1">
          <dt className="text-xs text-muted-foreground">{t('policy.tester.bannedWords')}</dt>
          <dd>
            <ToneBadge tone={bannedTones[result.banned_words]}>
              {t(`policy.tester.banned.${result.banned_words}`)}
            </ToneBadge>
          </dd>
        </div>
        <div className="flex flex-col gap-1">
          <dt className="text-xs text-muted-foreground">{t('policy.tester.categories')}</dt>
          <dd className="text-row">
            {result.categories.length === 0
              ? t('policy.tester.noCategories')
              : result.categories.map(categoryLabel).join(', ')}
          </dd>
        </div>
        <div className="flex flex-col gap-1">
          <dt className="text-xs text-muted-foreground">{t('policy.tester.links')}</dt>
          <dd className="text-row">
            {result.links ? t('policy.tester.hasLinks') : t('policy.tester.noLinks')}
          </dd>
        </div>
      </dl>
      <div className="flex flex-col gap-1">
        <h3 className="text-xs text-muted-foreground">{t('policy.tester.body')}</h3>
        <p className="rounded-md bg-subtle p-2 text-row break-words whitespace-pre-wrap">
          {result.body || '–'}
        </p>
      </div>
      <div className="flex flex-col gap-1">
        <h3 className="text-xs text-muted-foreground">{t('policy.tester.normalized')}</h3>
        <p className="rounded-md bg-subtle p-2 font-mono text-xs break-words whitespace-pre-wrap">
          {result.normalized || '–'}
        </p>
      </div>
    </section>
  )
}

export function TesterTab() {
  const { t } = useTranslation()
  const id = useId()
  const test = useTestContent()
  const [text, setText] = useState('')
  const [surface, setSurface] = useState<TestSurface>('post')
  const [checked, setChecked] = useState(false)
  const valid = text.length >= 1 && text.length <= TEST_TEXT_MAX && text.trim() !== ''
  return (
    <PolicyCard title={t('policy.tester.title')} subtitle={t('policy.tester.subtitle')}>
      <form
        className="flex flex-col gap-3"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (valid) test.mutate({ text, surface })
        }}
      >
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-text`}>{t('policy.tester.text')}</Label>
          <Textarea
            id={`${id}-text`}
            rows={4}
            maxLength={TEST_TEXT_MAX}
            value={text}
            aria-invalid={checked && !valid ? true : undefined}
            aria-describedby={`${id}-text-hint`}
            onChange={(event) => setText(event.target.value)}
          />
          <FieldText
            id={`${id}-text-hint`}
            error={checked && !valid ? t('policy.tester.textProblem', { max: TEST_TEXT_MAX }) : undefined}
            hint={t('policy.tester.textHint')}
          />
        </div>
        <div className="flex flex-wrap items-end gap-3">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-surface`}>{t('policy.tester.surface')}</Label>
            <Select value={surface} onValueChange={(value) => setSurface(value as TestSurface)}>
              <SelectTrigger id={`${id}-surface`} className="w-56">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {testSurfaces.map((item) => (
                  <SelectItem key={item} value={item}>
                    {t(`policy.tester.surfaces.${item}`)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <Button type="submit" size="sm" disabled={test.isPending}>
            {test.isPending ? <LoaderCircleIcon className="animate-spin" /> : <FlaskConicalIcon />}
            {t('policy.tester.run')}
          </Button>
        </div>
      </form>
      {test.isError ? (
        <p role="alert" className="text-row text-destructive">
          {policyErrorText(test.error)}
        </p>
      ) : null}
      {test.data ? <Result result={test.data} /> : null}
      <p className="text-xs text-muted-foreground">{t('policy.tester.note')}</p>
    </PolicyCard>
  )
}
