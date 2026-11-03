import { LoaderCircleIcon, PlusIcon, XIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Confirm } from '@/features/nasabah/components/confirm'
import { QueryContent } from '@/features/settings/components/settings-ui'
import { FieldText } from '@/features/system/components/system-ui'
import { policyErrorText } from '@/lib/error-text'

import { useAddPhrase, useAddTerm, useContentRules, useDeletePhrase, useDeleteTerm } from '../hooks'
import { normalizeTerm, termProblem } from '../logic'
import { PolicyCard } from './policy-ui'

type Kind = 'allowlist' | 'promo'

function TermList({
  kind,
  items,
  min,
  add,
  remove,
}: {
  kind: Kind
  items: string[]
  min: number
  add: ReturnType<typeof useAddTerm>
  remove: ReturnType<typeof useDeleteTerm>
}) {
  const { t } = useTranslation()
  const id = useId()
  const [text, setText] = useState('')
  const [checked, setChecked] = useState(false)
  const [removing, setRemoving] = useState<string | null>(null)
  const value = normalizeTerm(text)
  const problem = termProblem(value, min)
  const exists = items.includes(value)
  const error =
    checked && problem
      ? t(`policy.terms.problems.${problem}`, { min })
      : checked && exists
        ? t('policy.terms.exists')
        : undefined
  return (
    <PolicyCard title={t(`policy.terms.${kind}.title`)} subtitle={t(`policy.terms.${kind}.subtitle`)}>
      <form
        className="flex flex-col gap-1.5"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (problem || exists) return
          add
            .mutateAsync(value)
            .then(() => {
              toast.success(t('policy.terms.added', { term: value }))
              setText('')
              setChecked(false)
            })
            .catch((caught: unknown) => toast.error(policyErrorText(caught)))
        }}
      >
        <Label htmlFor={`${id}-term`}>{t(`policy.terms.${kind}.label`)}</Label>
        <div className="flex flex-col gap-2 sm:flex-row">
          <Input
            id={`${id}-term`}
            autoComplete="off"
            maxLength={60}
            placeholder={t(`policy.terms.${kind}.placeholder`)}
            className="sm:max-w-sm"
            value={text}
            aria-invalid={error ? true : undefined}
            aria-describedby={`${id}-term-text`}
            onChange={(event) => setText(event.target.value)}
          />
          <Button
            type="submit"
            size="sm"
            variant="outline"
            className="self-start sm:self-auto"
            disabled={add.isPending}
          >
            {add.isPending ? <LoaderCircleIcon className="animate-spin" /> : <PlusIcon />}
            {t('policy.terms.add')}
          </Button>
        </div>
        <FieldText id={`${id}-term-text`} error={error} hint={t('policy.terms.hint', { min })} />
      </form>
      {items.length === 0 ? (
        <p className="text-row text-muted-foreground">{t(`policy.terms.${kind}.empty`)}</p>
      ) : (
        <ul className="flex flex-wrap gap-1.5" aria-label={t(`policy.terms.${kind}.title`)}>
          {items.map((item) => (
            <li
              key={item}
              className="inline-flex items-center gap-1 rounded-md border bg-subtle py-0.5 pr-0.5 pl-2 text-row"
            >
              {item}
              <Button
                size="icon-xs"
                variant="ghost"
                aria-label={t('policy.terms.deleteLabel', { term: item })}
                onClick={() => setRemoving(item)}
              >
                <XIcon />
              </Button>
            </li>
          ))}
        </ul>
      )}
      <Confirm
        open={removing !== null}
        title={t('policy.terms.deleteTitle', { term: removing ?? '' })}
        body={t(`policy.terms.${kind}.deleteBody`)}
        action={t('app.delete')}
        destructive
        pending={remove.isPending}
        onClose={() => setRemoving(null)}
        onConfirm={() =>
          removing &&
          remove
            .mutateAsync(removing)
            .then(() => {
              toast.success(t('policy.terms.deleted', { term: removing }))
              setRemoving(null)
            })
            .catch((caught: unknown) => toast.error(policyErrorText(caught)))
        }
      />
    </PolicyCard>
  )
}

export function TermsTab() {
  const rules = useContentRules()
  const addTerm = useAddTerm()
  const deleteTerm = useDeleteTerm()
  const addPhrase = useAddPhrase()
  const deletePhrase = useDeletePhrase()
  return (
    <QueryContent query={rules}>
      {(data) => (
        <div className="flex flex-col gap-6">
          <TermList
            kind="promo"
            items={data.promo_phrases.map((item) => item.phrase)}
            min={3}
            add={addPhrase}
            remove={deletePhrase}
          />
          <TermList
            kind="allowlist"
            items={data.allowlist.map((item) => item.term)}
            min={2}
            add={addTerm}
            remove={deleteTerm}
          />
        </div>
      )}
    </QueryContent>
  )
}
