import { CircleAlertIcon, CircleCheckIcon, LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { errorText } from '@/lib/error-text'
import { format } from '@/lib/time'

import { useConfirmPolicy, usePolicies } from '../hooks'
import { policyDraftProblem } from '../logic'
import type { Policy, PolicyChange, PolicyKey } from '../types'

const nameKey = (key: PolicyKey) => key.replaceAll('.', '_') as 'complaint_days'

const fullStamp = (value: string) => `${format(value, 'd MMM yyyy, HH.mm')} WIB`

function PolicyCard({ policy }: { policy: Policy }) {
  const { t } = useTranslation()
  const confirm = useConfirmPolicy()
  const [value, setValue] = useState(String(policy.value))
  const [note, setNote] = useState('')
  const [asking, setAsking] = useState(false)
  const name = t(`compliance.policy.names.${nameKey(policy.key)}`)
  const unit = t(`compliance.policy.units.${policy.unit}`)
  const problem = policyDraftProblem(value, policy.min, policy.max)
  const changed = problem === null && Number(value) !== policy.value
  const id = `policy-${nameKey(policy.key)}`

  const submit = () =>
    confirm.mutate(
      { key: policy.key, value: Number(value), note },
      {
        onSuccess: (saved) => {
          setValue(String(saved.value))
          setNote('')
          toast.success(t('compliance.policy.done', { name }))
        },
        onError: (error) => toast.error(errorText(error)),
      },
    )

  return (
    <section
      aria-labelledby={`${id}-title`}
      className="flex flex-col gap-4 border-b py-5 first:pt-0 last:border-b-0 lg:flex-row lg:gap-8"
    >
      <div className="flex min-w-0 flex-col gap-1.5 lg:w-80 lg:shrink-0">
        <h2 id={`${id}-title`} className="text-panel font-semibold">
          {name}
        </h2>
        <p className="text-row text-muted-foreground">
          {t(`compliance.policy.hints.${nameKey(policy.key)}`)}
        </p>
        <p className="tabular text-metric font-medium">
          {policy.value} <span className="text-row font-normal text-muted-foreground">{unit}</span>
        </p>
        {policy.confirmed && policy.confirmation ? (
          <p className="inline-flex items-start gap-1.5 text-xs text-success">
            <CircleCheckIcon className="mt-px size-3.5 shrink-0" aria-hidden="true" />
            <span>
              {t('compliance.policy.confirmed', {
                name: policy.confirmation.confirmed_by ?? '–',
                time: fullStamp(policy.confirmation.confirmed_at),
              })}
              {policy.confirmation.note ? (
                <span className="block text-muted-foreground">{policy.confirmation.note}</span>
              ) : null}
            </span>
          </p>
        ) : (
          <p className="inline-flex items-start gap-1.5 text-xs text-warning">
            <CircleAlertIcon className="mt-px size-3.5 shrink-0" aria-hidden="true" />
            <span>
              <span className="font-medium">{t('compliance.policy.unconfirmed')}</span>.{' '}
              {policy.confirmation
                ? t('compliance.policy.changedSince', { version: policy.confirmation.version })
                : t('compliance.policy.unconfirmedHint')}
            </span>
          </p>
        )}
      </div>
      <form
        className="grid min-w-0 flex-1 gap-3 sm:grid-cols-[10rem_1fr]"
        onSubmit={(event) => {
          event.preventDefault()
          if (problem) return
          if (changed) setAsking(true)
          else submit()
        }}
      >
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-value`}>
            {t('compliance.policy.valueLabel', { min: policy.min, max: policy.max, unit })}
          </Label>
          <Input
            id={`${id}-value`}
            inputMode="numeric"
            value={value}
            aria-invalid={problem ? true : undefined}
            onChange={(event) => setValue(event.target.value)}
          />
          {problem ? (
            <p className="text-xs text-destructive" role="alert">
              {problem === 'invalid'
                ? t('compliance.policy.invalid')
                : t('compliance.policy.outOfRange', { min: policy.min, max: policy.max, unit })}
            </p>
          ) : null}
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor={`${id}-note`}>{t('compliance.policy.noteLabel')}</Label>
          <Input
            id={`${id}-note`}
            maxLength={500}
            value={note}
            placeholder={t('compliance.policy.notePlaceholder')}
            onChange={(event) => setNote(event.target.value)}
          />
        </div>
        <Button
          type="submit"
          size="sm"
          className="self-start sm:col-start-2 sm:justify-self-start"
          variant={changed || !policy.confirmed ? 'default' : 'outline'}
          disabled={problem !== null || confirm.isPending}
        >
          {confirm.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {changed ? t('compliance.policy.saveConfirm') : t('compliance.policy.confirm')}
        </Button>
      </form>
      <AlertDialog open={asking} onOpenChange={setAsking}>
        <AlertDialogContent>
          <AlertDialogTitle>{t('compliance.policy.changeTitle', { name })}</AlertDialogTitle>
          <AlertDialogDescription>
            {t('compliance.policy.changeBody', { from: policy.value, to: value, unit })}
          </AlertDialogDescription>
          <div className="flex justify-end gap-2">
            <AlertDialogCancel>{t('app.cancel')}</AlertDialogCancel>
            <AlertDialogAction onClick={submit}>{t('compliance.policy.saveConfirm')}</AlertDialogAction>
          </div>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  )
}

function History({ history }: { history: PolicyChange[] }) {
  const { t } = useTranslation()
  if (history.length === 0) {
    return (
      <p className="border-y py-3 text-row text-muted-foreground">{t('compliance.policy.historyEmpty')}</p>
    )
  }
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('compliance.policy.colTime')}</TableHead>
          <TableHead>{t('compliance.policy.colPolicy')}</TableHead>
          <TableHead>{t('compliance.policy.colChange')}</TableHead>
          <TableHead>{t('compliance.policy.colBy')}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {history.map((change) => (
          <TableRow key={`${change.key}-${change.version}`}>
            <TableCell className="tabular text-xs text-muted-foreground">
              {fullStamp(change.changed_at)}
            </TableCell>
            <TableCell>{t(`compliance.policy.names.${nameKey(change.key)}`)}</TableCell>
            <TableCell className="tabular">
              {change.old_value ?? '–'} → <span className="font-medium">{change.new_value}</span>
            </TableCell>
            <TableCell>{change.changed_by ?? t('compliance.policy.system')}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

export function CompliancePolicyPage() {
  const { t } = useTranslation()
  const policies = usePolicies()
  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1120px] flex-col gap-6 px-4 py-5 lg:px-6">
        <header>
          <h1 className="text-lg font-semibold">{t('compliance.policy.title')}</h1>
          <p className="text-row text-muted-foreground">{t('compliance.policy.subtitle')}</p>
        </header>
        {policies.data ? (
          <>
            <div className="flex flex-col border-y py-5">
              {policies.data.policies.map((policy) => (
                <PolicyCard key={`${policy.key}-${policy.version}`} policy={policy} />
              ))}
            </div>
            <section className="flex flex-col gap-3" aria-labelledby="policy-history-title">
              <h2 id="policy-history-title" className="text-panel font-semibold">
                {t('compliance.policy.historyTitle')}
              </h2>
              <History history={policies.data.history} />
            </section>
          </>
        ) : policies.isError ? (
          <ErrorState error={policies.error} onRetry={() => void policies.refetch()} />
        ) : (
          <ListSkeleton rows={3} />
        )}
      </div>
    </div>
  )
}
