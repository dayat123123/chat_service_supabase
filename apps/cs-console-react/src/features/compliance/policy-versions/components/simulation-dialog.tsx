import { FlaskConicalIcon, LoaderCircleIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Textarea } from '@/components/ui/textarea'
import { ActionBadge } from '@/features/content-policy/components/policy-ui'
import {
  contentActions,
  contentCategories,
  TEST_TEXT_MAX,
  testSurfaces,
  type TestSurface,
} from '@/features/content-policy/types'
import { FieldText, ToneBadge } from '@/features/system/components/system-ui'
import { policyErrorText } from '@/lib/error-text'
import { format } from '@/lib/time'

import { useSimulate } from '../hooks'
import { countDelta, outcomeShift } from '../logic'
import { simDays, type ImageAction, type SimOutcome, type SimTarget, type Simulation } from '../types'
import { DiffCounts } from './diff-view'

const imageActions: ImageAction[] = ['allow', 'hold', 'block']

function useCategoryText() {
  const { t } = useTranslation()
  return (outcome: SimOutcome) =>
    outcome.categories
      .map((category) =>
        category === 'banned_words'
          ? t('policy.versions.simulation.bannedWords')
          : (contentCategories as readonly string[]).includes(category)
            ? t(`policy.categories.${category as (typeof contentCategories)[number]}`)
            : category,
      )
      .join(', ')
}

function Outcome({ outcome }: { outcome: SimOutcome }) {
  const { t } = useTranslation()
  const categories = useCategoryText()(outcome)
  return (
    <span className="inline-flex flex-col items-start gap-0.5">
      <ActionBadge action={outcome.action} />
      {categories ? (
        <span className="text-xs text-muted-foreground">
          {t('policy.versions.simulation.categories', { list: categories })}
        </span>
      ) : null}
    </span>
  )
}

function ShiftBadge({ current, draft }: { current: SimOutcome; draft: SimOutcome }) {
  const { t } = useTranslation()
  const shift = outcomeShift(current.action, draft.action)
  if (shift === 'same') return null
  return (
    <ToneBadge tone={shift === 'stricter' ? 'late' : 'ok'}>
      {t(`policy.versions.simulation.shift.${shift}`)}
    </ToneBadge>
  )
}

function Result({ result }: { result: Simulation }) {
  const { t } = useTranslation()
  const { content, images, sample } = result
  return (
    <section
      aria-live="polite"
      aria-label={t('policy.versions.simulation.result')}
      className="flex flex-col gap-4"
    >
      <p className="text-row">
        <DiffCounts diff={result.target.summary} />
      </p>
      {sample ? (
        <div className="flex flex-col gap-1.5 rounded-lg border p-3">
          <h3 className="text-row font-medium">{t('policy.versions.simulation.sample')}</h3>
          <dl className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1">
              <dt className="text-xs text-muted-foreground">
                {t('policy.versions.simulation.currentPolicy')}
              </dt>
              <dd>
                <Outcome outcome={sample.current} />
              </dd>
            </div>
            <div className="flex flex-col gap-1">
              <dt className="text-xs text-muted-foreground">{t('policy.versions.simulation.draftPolicy')}</dt>
              <dd>
                <Outcome outcome={sample.draft} />
              </dd>
            </div>
          </dl>
        </div>
      ) : null}
      <div className="flex flex-col gap-2">
        <p className="text-row">
          {t('policy.versions.simulation.scanned', { count: content.scanned })} ·{' '}
          <strong>{t('policy.versions.simulation.changed', { count: content.changed })}</strong> ·{' '}
          {t('policy.versions.simulation.stricter', { count: content.stricter })} ·{' '}
          {t('policy.versions.simulation.looser', { count: content.looser })}
        </p>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('policy.versions.simulation.action')}</TableHead>
              <TableHead className="text-right">{t('policy.versions.simulation.currentPolicy')}</TableHead>
              <TableHead className="text-right">{t('policy.versions.simulation.draftPolicy')}</TableHead>
              <TableHead className="text-right">{t('policy.versions.simulation.delta')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {contentActions.map((action) => (
              <TableRow key={action}>
                <TableCell>
                  <ActionBadge action={action} />
                </TableCell>
                <TableCell className="tabular text-right">{content.current[action]}</TableCell>
                <TableCell className="tabular text-right">{content.draft[action]}</TableCell>
                <TableCell className="tabular text-right">
                  {countDelta(content.current[action], content.draft[action])}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
      <div className="flex flex-col gap-2">
        <h3 className="text-row font-medium">{t('policy.versions.simulation.items')}</h3>
        {content.items.length === 0 ? (
          <p className="text-row text-muted-foreground">{t('policy.versions.simulation.noItems')}</p>
        ) : (
          <>
            <ul className="flex flex-col divide-y rounded-lg border">
              {content.items.map((item) => (
                <li key={`${item.type}:${item.id}`} className="flex flex-col gap-1.5 p-3">
                  <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                    <span>{t(`policy.versions.simulation.types.${item.type}`)}</span>
                    <span>{format(item.created_at, 'd MMM yyyy, HH.mm')} WIB</span>
                    <ShiftBadge current={item.current} draft={item.draft} />
                  </div>
                  <p className="text-row break-words whitespace-pre-wrap">{item.excerpt}</p>
                  <div className="flex flex-wrap items-start gap-2">
                    <Outcome outcome={item.current} />
                    <span aria-hidden="true" className="text-muted-foreground">
                      →
                    </span>
                    <Outcome outcome={item.draft} />
                  </div>
                </li>
              ))}
            </ul>
            <p className="text-xs text-muted-foreground">{t('policy.versions.simulation.itemsLimit')}</p>
          </>
        )}
      </div>
      <div className="flex flex-col gap-1.5">
        <h3 className="text-row font-medium">
          {t('policy.versions.simulation.images', { days: content.days })}
        </h3>
        <p className="text-row">
          {t('policy.versions.simulation.scanned', { count: images.scanned })} ·{' '}
          {t('policy.versions.simulation.changed', { count: images.changed })}
        </p>
        <p className="flex flex-wrap gap-x-4 gap-y-1 text-row">
          {imageActions.map((action) => (
            <span key={action} className="tabular">
              {t(`policy.versions.simulation.imageActions.${action}`)}: {images.current[action]} →{' '}
              {images.draft[action]}
            </span>
          ))}
        </p>
        <p className="text-xs text-muted-foreground">{t('policy.versions.simulation.imagesHint')}</p>
      </div>
    </section>
  )
}

function targetLabel(target: SimTarget) {
  switch (target.kind) {
    case 'draft':
      return { key: 'draft' as const, id: 0 }
    case 'change':
      return { key: 'change' as const, id: target.id }
    case 'version':
      return { key: 'version' as const, id: target.version }
  }
}

export function SimulationDialog({
  target,
  open,
  onClose,
}: {
  target: SimTarget
  open: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  const id = useId()
  const simulate = useSimulate()
  const [text, setText] = useState('')
  const [surface, setSurface] = useState<TestSurface>('post')
  const [days, setDays] = useState(7)
  const label = targetLabel(target)
  const tooLong = text.length > TEST_TEXT_MAX
  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (next) return
        simulate.reset()
        onClose()
      }}
    >
      <DialogContent className="max-h-[92vh] overflow-y-auto sm:max-w-3xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('policy.versions.simulation.title')}</DialogTitle>
          <DialogDescription>
            {t('policy.versions.simulation.subtitle', {
              target: t(`policy.versions.simulation.targets.${label.key}`, { id: label.id }),
            })}
          </DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-3"
          noValidate
          onSubmit={(event) => {
            event.preventDefault()
            if (tooLong) return
            simulate.mutate({ target, text, surface, days })
          }}
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor={`${id}-text`}>{t('policy.versions.simulation.text')}</Label>
            <Textarea
              id={`${id}-text`}
              rows={3}
              value={text}
              aria-invalid={tooLong ? true : undefined}
              aria-describedby={`${id}-text-hint`}
              onChange={(event) => setText(event.target.value)}
            />
            <FieldText
              id={`${id}-text-hint`}
              error={tooLong ? t('policy.tester.textProblem', { max: TEST_TEXT_MAX }) : undefined}
              hint={t('policy.versions.simulation.textHint')}
            />
          </div>
          <div className="flex flex-wrap items-end gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${id}-surface`}>{t('policy.versions.simulation.surface')}</Label>
              <Select value={surface} onValueChange={(value) => setSurface(value as TestSurface)}>
                <SelectTrigger id={`${id}-surface`} className="w-52">
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
            <div className="flex flex-col gap-1.5">
              <Label htmlFor={`${id}-days`}>{t('policy.versions.simulation.days')}</Label>
              <Select value={String(days)} onValueChange={(value) => setDays(Number(value))}>
                <SelectTrigger id={`${id}-days`} className="w-44">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {simDays.map((item) => (
                    <SelectItem key={item} value={String(item)}>
                      {t('policy.versions.simulation.dayOptions', { count: item })}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <Button type="submit" size="sm" disabled={simulate.isPending}>
              {simulate.isPending ? <LoaderCircleIcon className="animate-spin" /> : <FlaskConicalIcon />}
              {t('policy.versions.simulation.run')}
            </Button>
          </div>
          <p className="text-xs text-muted-foreground">
            {t('policy.versions.simulation.scope', { days, limit: 300 })}
          </p>
        </form>
        {simulate.isError ? (
          <p role="alert" className="text-row text-destructive">
            {policyErrorText(simulate.error)}
          </p>
        ) : null}
        {simulate.data ? <Result result={simulate.data} /> : null}
      </DialogContent>
    </Dialog>
  )
}
