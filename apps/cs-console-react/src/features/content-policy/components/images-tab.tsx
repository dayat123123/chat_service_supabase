import { LoaderCircleIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { QueryContent } from '@/features/settings/components/settings-ui'
import { FieldText } from '@/features/system/components/system-ui'
import { policyErrorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useImageThresholds, useSetImageThresholds } from '../hooks'
import {
  sameThresholds,
  thresholdForm,
  thresholdPayload,
  thresholdProblems,
  thresholdsValid,
  type ThresholdForm,
} from '../logic'
import { imageCategories, THRESHOLD_NOTE_MAX, type ImageCategory, type ImageThresholds } from '../types'
import { PolicyCard } from './policy-ui'

function LimitInput({
  id,
  label,
  value,
  invalid,
  onChange,
}: {
  id: string
  label: string
  value: string
  invalid: boolean
  onChange: (value: string) => void
}) {
  return (
    <div className="flex items-center gap-1.5">
      <Input
        id={id}
        inputMode="decimal"
        className="h-8 w-20 text-right"
        placeholder="–"
        aria-label={label}
        aria-invalid={invalid ? true : undefined}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
      <span aria-hidden="true" className="text-xs text-muted-foreground">
        %
      </span>
    </div>
  )
}

function ThresholdsForm({ data }: { data: ImageThresholds }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSetImageThresholds()
  const [form, setForm] = useState<ThresholdForm>(() => thresholdForm(data.thresholds))
  const [note, setNote] = useState('')
  const [checked, setChecked] = useState(false)
  const problems = thresholdProblems(form)
  const valid = thresholdsValid(problems)
  const payload = thresholdPayload(form)
  const dirty = !sameThresholds(payload, data.thresholds)
  const set = (category: ImageCategory, field: 'hold' | 'block', value: string) =>
    setForm((current) => ({ ...current, [category]: { ...current[category], [field]: value } }))
  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setChecked(true)
        if (!valid || !dirty) return
        save
          .mutateAsync({ thresholds: payload, note: note.trim() || null })
          .then((next) => {
            toast.success(t('policy.images.saved', { revision: next.revision }))
            setNote('')
            setChecked(false)
          })
          .catch((error: unknown) => toast.error(policyErrorText(error)))
      }}
    >
      <Table>
        <caption className="sr-only">{t('policy.images.title')}</caption>
        <TableHeader>
          <TableRow>
            <TableHead>{t('policy.images.category')}</TableHead>
            <TableHead>{t('policy.images.hold')}</TableHead>
            <TableHead>{t('policy.images.block')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {imageCategories.map((category) => {
            const issue = checked ? problems.categories[category] : undefined
            const name = t(`policy.images.categories.${category}`)
            return (
              <TableRow key={category} className="align-top">
                <TableCell className="py-2 whitespace-normal">
                  <p className="font-medium">{name}</p>
                  <p className="max-w-sm text-xs text-muted-foreground">
                    {t(`policy.images.hints.${category}`)}
                  </p>
                  {issue ? (
                    <p role="alert" className="pt-1 text-xs text-destructive">
                      {t(`policy.images.problems.${issue}`)}
                    </p>
                  ) : null}
                  {checked && category === 'porn' && problems.pornRequired ? (
                    <p role="alert" className="pt-1 text-xs text-destructive">
                      {t('policy.images.problems.pornRequired')}
                    </p>
                  ) : null}
                </TableCell>
                <TableCell className="py-2">
                  <LimitInput
                    id={`${id}-${category}-hold`}
                    label={t('policy.images.holdFor', { category: name })}
                    value={form[category].hold}
                    invalid={issue === 'hold' || issue === 'order'}
                    onChange={(value) => set(category, 'hold', value)}
                  />
                </TableCell>
                <TableCell className="py-2">
                  <LimitInput
                    id={`${id}-${category}-block`}
                    label={t('policy.images.blockFor', { category: name })}
                    value={form[category].block}
                    invalid={
                      issue === 'block' ||
                      issue === 'order' ||
                      (checked && category === 'porn' && problems.pornRequired)
                    }
                    onChange={(value) => set(category, 'block', value)}
                  />
                </TableCell>
              </TableRow>
            )
          })}
        </TableBody>
      </Table>
      <div className="flex flex-col gap-1.5 sm:max-w-xl">
        <Label htmlFor={`${id}-note`}>{t('policy.images.note')}</Label>
        <Input
          id={`${id}-note`}
          maxLength={THRESHOLD_NOTE_MAX}
          value={note}
          aria-describedby={`${id}-note-text`}
          onChange={(event) => setNote(event.target.value)}
        />
        <FieldText id={`${id}-note-text`} hint={t('policy.images.noteHint')} />
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button type="submit" size="sm" disabled={save.isPending || !dirty}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
        <span className={cn('text-xs', dirty ? 'text-warning' : 'text-muted-foreground')}>
          {dirty ? t('policy.images.unsaved') : t('policy.images.upToDate')}
        </span>
      </div>
    </form>
  )
}

export function ImagesTab() {
  const { t } = useTranslation()
  const thresholds = useImageThresholds()
  return (
    <PolicyCard title={t('policy.images.title')} subtitle={t('policy.images.subtitle')}>
      <QueryContent query={thresholds}>
        {(data) => (
          <>
            <p className="text-xs text-muted-foreground">
              {t('policy.images.revision', {
                revision: data.revision,
                time: stamp(data.updated_at),
                name: data.updated_by ?? t('policy.images.system'),
              })}
            </p>
            <ThresholdsForm key={data.revision} data={data} />
            <ul className="flex max-w-3xl list-disc flex-col gap-1 pl-5 text-xs text-muted-foreground">
              <li>{t('policy.images.ruleBlock')}</li>
              <li>{t('policy.images.ruleHold')}</li>
              <li>{t('policy.images.ruleAvatar')}</li>
            </ul>
          </>
        )}
      </QueryContent>
    </PolicyCard>
  )
}
