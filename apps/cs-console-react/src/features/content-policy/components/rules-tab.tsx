import { LoaderCircleIcon } from 'lucide-react'
import { useId, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { QueryContent } from '@/features/settings/components/settings-ui'
import { FieldText } from '@/features/system/components/system-ui'
import { policyErrorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'

import { useContentRules, useSetContentRule, useSetNewAccountDays } from '../hooks'
import { sortRules } from '../logic'
import {
  contentActions,
  contentScopes,
  NEW_ACCOUNT_DAYS_MAX,
  type ContentAction,
  type ContentRule,
  type ContentRules,
  type ContentScope,
} from '../types'
import { PolicyCard } from './policy-ui'

function RuleRow({ rule }: { rule: ContentRule }) {
  const { t } = useTranslation()
  const save = useSetContentRule()
  const name = t(`policy.categories.${rule.category}`)
  const change = (action: ContentAction, scope: ContentScope) =>
    save
      .mutateAsync({ category: rule.category, action, scope })
      .then(() =>
        toast.success(
          t('policy.rules.changed', {
            category: name,
            action: t(`policy.actions.${action}`),
            scope: t(`policy.scopes.${scope}`),
          }),
        ),
      )
      .catch((error: unknown) => toast.error(policyErrorText(error)))
  return (
    <TableRow className="align-top">
      <TableCell className="py-2 whitespace-normal">
        <p className="font-medium">{name}</p>
        <p className="max-w-md text-xs text-muted-foreground">{t(`policy.categoryHints.${rule.category}`)}</p>
      </TableCell>
      <TableCell className="py-2">
        <Select
          value={rule.action}
          disabled={save.isPending}
          onValueChange={(value) => void change(value as ContentAction, rule.scope)}
        >
          <SelectTrigger className="h-8 w-32" aria-label={t('policy.rules.actionFor', { category: name })}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {contentActions.map((action) => (
              <SelectItem key={action} value={action}>
                {t(`policy.actions.${action}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </TableCell>
      <TableCell className="py-2">
        <Select
          value={rule.scope}
          disabled={save.isPending}
          onValueChange={(value) => void change(rule.action, value as ContentScope)}
        >
          <SelectTrigger className="h-8 w-40" aria-label={t('policy.rules.scopeFor', { category: name })}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {contentScopes.map((scope) => (
              <SelectItem key={scope} value={scope}>
                {t(`policy.scopes.${scope}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </TableCell>
      <TableCell className="py-2 text-xs whitespace-normal text-muted-foreground">
        {stamp(rule.updated_at)}
        {rule.updated_by?.name ? <span className="block">{rule.updated_by.name}</span> : null}
      </TableCell>
    </TableRow>
  )
}

function NewAccountCard({ days }: { days: number }) {
  const { t } = useTranslation()
  const id = useId()
  const save = useSetNewAccountDays()
  const [text, setText] = useState(String(days))
  const [checked, setChecked] = useState(false)
  const value = Number(text.trim())
  const valid = /^\d{1,2}$/.test(text.trim()) && value >= 0 && value <= NEW_ACCOUNT_DAYS_MAX
  return (
    <PolicyCard title={t('policy.newAccount.title')} subtitle={t('policy.newAccount.subtitle')}>
      <form
        className="flex flex-wrap items-start gap-3"
        noValidate
        onSubmit={(event) => {
          event.preventDefault()
          setChecked(true)
          if (!valid || value === days) return
          save
            .mutateAsync(value)
            .then(() => {
              toast.success(t('policy.newAccount.saved', { count: value }))
              setChecked(false)
            })
            .catch((error: unknown) => toast.error(policyErrorText(error)))
        }}
      >
        <div className="flex w-40 flex-col gap-1.5">
          <Label htmlFor={`${id}-days`}>{t('policy.newAccount.label')}</Label>
          <Input
            id={`${id}-days`}
            inputMode="numeric"
            value={text}
            aria-invalid={checked && !valid ? true : undefined}
            aria-describedby={`${id}-days-text`}
            onChange={(event) => setText(event.target.value)}
          />
        </div>
        <Button
          type="submit"
          size="sm"
          className="mt-6"
          disabled={save.isPending || (valid && value === days)}
        >
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('app.save')}
        </Button>
        <FieldText
          id={`${id}-days-text`}
          error={
            checked && !valid ? t('policy.newAccount.problem', { max: NEW_ACCOUNT_DAYS_MAX }) : undefined
          }
          hint={t('policy.newAccount.hint')}
        />
      </form>
    </PolicyCard>
  )
}

function RulesBody({ rules }: { rules: ContentRules }) {
  const { t } = useTranslation()
  return (
    <>
      <PolicyCard title={t('policy.rules.title')} subtitle={t('policy.rules.subtitle')}>
        <Table>
          <caption className="sr-only">{t('policy.rules.title')}</caption>
          <TableHeader>
            <TableRow>
              <TableHead>{t('policy.rules.category')}</TableHead>
              <TableHead>{t('policy.rules.action')}</TableHead>
              <TableHead>{t('policy.rules.scope')}</TableHead>
              <TableHead>{t('policy.rules.updated')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {sortRules(rules.categories).map((rule) => (
              <RuleRow key={rule.category} rule={rule} />
            ))}
          </TableBody>
        </Table>
        <ul className="flex max-w-3xl list-disc flex-col gap-1 pl-5 text-xs text-muted-foreground">
          <li>{t('policy.rules.noteActions')}</li>
          <li>{t('policy.rules.noteScope')}</li>
          <li>{t('policy.rules.noteExempt')}</li>
        </ul>
      </PolicyCard>
      <NewAccountCard key={rules.new_account_days} days={rules.new_account_days} />
    </>
  )
}

export function RulesTab() {
  const rules = useContentRules()
  return <QueryContent query={rules}>{(data) => <RulesBody rules={data} />}</QueryContent>
}
