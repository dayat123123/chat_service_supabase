import { ArrowDownIcon, ArrowUpIcon, LoaderCircleIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { Button } from '@/components/ui/button'
import { RadioGroup, RadioGroupItem, Switch } from '@/components/ui/controls'
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import {
  ActiveBadge,
  FieldMessage,
  QueryContent,
  SectionFrame,
} from '@/features/settings/components/settings-ui'
import { stamp } from '@/lib/time'

import { useLabelConfigs, useReorderLabels, useSaveLabel } from '../hooks'
import { activeLabelCount, labelErrorText, moveLabel } from '../logic'
import { labelColors, MAX_ACTIVE_LABELS, MAX_LABEL_NAME, type LabelColor, type LabelConfig } from '../types'
import { LabelChip, LabelDot } from './label-chip'

function LabelDialog({
  label,
  activeFull,
  onClose,
}: {
  label: LabelConfig | null
  activeFull: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  const save = useSaveLabel()
  const [name, setName] = useState(label?.name ?? '')
  const [color, setColor] = useState<LabelColor>(label?.color ?? 'neutral')
  const [active, setActive] = useState(label?.active ?? !activeFull)
  const [touched, setTouched] = useState(false)
  const trimmed = name.trim().replace(/\s+/g, ' ')
  const invalid = trimmed.length === 0 || trimmed.length > MAX_LABEL_NAME
  const blockedActive = active && activeFull && !(label?.active ?? false)

  const submit = async (event: React.FormEvent) => {
    event.preventDefault()
    setTouched(true)
    if (invalid || blockedActive) return
    try {
      await save.mutateAsync({ id: label?.id ?? null, name: trimmed, color, active })
      onClose()
    } catch {
      return
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-[440px]" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>{label ? t('labels.settings.editTitle') : t('labels.settings.add')}</DialogTitle>
        </DialogHeader>
        <form className="flex flex-col gap-4" onSubmit={(event) => void submit(event)} noValidate>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="label-name">{t('labels.settings.name')}</Label>
            <Input
              id="label-name"
              autoFocus
              value={name}
              maxLength={MAX_LABEL_NAME}
              aria-invalid={touched && invalid ? true : undefined}
              onChange={(event) => setName(event.target.value)}
            />
            <FieldMessage
              error={
                touched && invalid ? t('labels.settings.invalidName', { max: MAX_LABEL_NAME }) : undefined
              }
              hint={t('labels.settings.nameHint', { max: MAX_LABEL_NAME })}
            />
          </div>
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1.5 text-sm font-medium">{t('labels.settings.color')}</legend>
            <RadioGroup
              value={color}
              onValueChange={(value) => setColor(value as LabelColor)}
              className="flex flex-wrap gap-x-4 gap-y-2"
            >
              {labelColors.map((item) => (
                <label key={item} className="inline-flex items-center gap-2 text-sm">
                  <RadioGroupItem value={item} aria-label={t(`labels.colors.${item}`)} />
                  <LabelDot color={item} />
                  {t(`labels.colors.${item}`)}
                </label>
              ))}
            </RadioGroup>
          </fieldset>
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <LabelChip label={{ id: 'preview', name: trimmed || t('labels.label'), color }} />
          </div>
          <label className="flex items-center justify-between gap-3 text-sm font-medium">
            {t('app.active')}
            <Switch checked={active} onCheckedChange={setActive} />
          </label>
          {blockedActive ? (
            <p role="alert" className="text-row text-destructive">
              {t('labels.settings.limitReached', { max: MAX_ACTIVE_LABELS })}
            </p>
          ) : null}
          {save.error ? (
            <p role="alert" className="text-row text-destructive">
              {labelErrorText(save.error)}
            </p>
          ) : null}
          <DialogFooter>
            <Button type="button" variant="ghost" disabled={save.isPending} onClick={onClose}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('app.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function LabelsTable({ labels, onEdit }: { labels: LabelConfig[]; onEdit: (label: LabelConfig) => void }) {
  const { t } = useTranslation()
  const reorder = useReorderLabels()
  const ids = labels.map((label) => label.id)
  const move = (index: number, step: number) => reorder.mutate(moveLabel(ids, index, step))
  if (labels.length === 0)
    return <p className="border-t pt-4 text-row text-muted-foreground">{t('labels.settings.empty')}</p>
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('labels.settings.colOrder')}</TableHead>
          <TableHead>{t('labels.settings.colName')}</TableHead>
          <TableHead>{t('labels.settings.colStatus')}</TableHead>
          <TableHead>{t('labels.settings.colTickets')}</TableHead>
          <TableHead>{t('labels.settings.colUpdated')}</TableHead>
          <TableHead>
            <span className="sr-only">{t('app.edit')}</span>
          </TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {labels.map((label, index) => (
          <TableRow key={label.id}>
            <TableCell>
              <span className="inline-flex items-center gap-0.5">
                <Button
                  variant="ghost"
                  size="icon-xs"
                  aria-label={t('labels.settings.moveUp', { name: label.name })}
                  disabled={index === 0 || reorder.isPending}
                  onClick={() => move(index, -1)}
                >
                  <ArrowUpIcon />
                </Button>
                <Button
                  variant="ghost"
                  size="icon-xs"
                  aria-label={t('labels.settings.moveDown', { name: label.name })}
                  disabled={index === labels.length - 1 || reorder.isPending}
                  onClick={() => move(index, 1)}
                >
                  <ArrowDownIcon />
                </Button>
              </span>
            </TableCell>
            <TableCell>
              <LabelChip label={label} />
            </TableCell>
            <TableCell>
              <ActiveBadge active={label.active} />
            </TableCell>
            <TableCell className="tabular text-muted-foreground">
              {t('labels.settings.tickets', { count: label.tickets })}
            </TableCell>
            <TableCell className="text-muted-foreground">
              {label.updated_at ? stamp(label.updated_at) : '–'}
            </TableCell>
            <TableCell className="text-right">
              <Button variant="ghost" size="xs" onClick={() => onEdit(label)}>
                {t('app.edit')}
              </Button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

export function LabelsSection() {
  const { t } = useTranslation()
  const labels = useLabelConfigs()
  const [editing, setEditing] = useState<{ label: LabelConfig | null; key: number } | null>(null)
  const active = activeLabelCount(labels.data ?? [])
  return (
    <SectionFrame
      title={t('labels.settings.title')}
      description={t('labels.settings.description')}
      action={
        <Button onClick={() => setEditing({ label: null, key: Date.now() })}>
          <PlusIcon />
          {t('labels.settings.add')}
        </Button>
      }
    >
      <QueryContent query={labels}>
        {(items) => (
          <>
            <p className="tabular text-row text-muted-foreground">
              {t('labels.settings.activeCount', { count: active, max: MAX_ACTIVE_LABELS })}
            </p>
            <LabelsTable labels={items} onEdit={(label) => setEditing({ label, key: Date.now() })} />
          </>
        )}
      </QueryContent>
      {editing ? (
        <LabelDialog
          key={editing.key}
          label={editing.label}
          activeFull={active >= MAX_ACTIVE_LABELS}
          onClose={() => setEditing(null)}
        />
      ) : null}
    </SectionFrame>
  )
}
