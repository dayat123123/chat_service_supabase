import { LoaderCircleIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import {
  Checkbox,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { errorText } from '@/lib/error-text'

import { useSaveCsUser } from '../hooks'
import { useNasabahLabels } from '../labels'
import { csFormFromUser, csFormProblems, emptyCsForm, toggleFlag, type CsFormProblem } from '../logic'
import {
  ALL_CS_FLAGS,
  csFlags,
  csUserStatuses,
  type CreatedCsUser,
  type CsUser,
  type CsUserForm,
} from '../types'

function Problem({ problems, of }: { problems: CsFormProblem[]; of: CsFormProblem }) {
  const { t } = useTranslation()
  if (!problems.includes(of)) return null
  return (
    <p role="alert" className="text-xs text-destructive">
      {t(`nasabah.csUsers.form.problems.${of}`)}
    </p>
  )
}

function CsUserFormBody({
  user,
  onDone,
  onCreated,
}: {
  user: CsUser | null
  onDone: () => void
  onCreated: (loginId: string, result: CreatedCsUser) => void
}) {
  const { t } = useTranslation()
  const label = useNasabahLabels()
  const save = useSaveCsUser()
  const [form, setForm] = useState<CsUserForm>(() => (user ? csFormFromUser(user) : emptyCsForm()))
  const [shown, setShown] = useState<CsFormProblem[]>([])
  const set = <K extends keyof CsUserForm>(key: K, value: CsUserForm[K]) =>
    setForm((current) => ({ ...current, [key]: value }))
  const create = user === null
  const statuses: number[] = (csUserStatuses as readonly number[]).includes(form.status)
    ? [...csUserStatuses]
    : [...csUserStatuses, form.status]

  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        const problems = csFormProblems(form)
        setShown(problems)
        if (problems.length > 0) return
        save.mutate(
          { form, create },
          {
            onSuccess: (result) => {
              const loginId = form.loginId.trim()
              toast.success(t('nasabah.csUsers.toast.saved', { loginId }))
              onDone()
              if (create) onCreated(loginId, result)
            },
            onError: (error) => toast.error(errorText(error)),
          },
        )
      }}
    >
      <DialogDescription>
        {create ? t('nasabah.csUsers.form.createHint') : t('nasabah.csUsers.form.editHint')}
      </DialogDescription>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="cs-login-id">{t('nasabah.csUsers.form.loginId')}</Label>
          <Input
            id="cs-login-id"
            autoComplete="off"
            maxLength={50}
            disabled={!create}
            autoFocus={create}
            aria-invalid={shown.includes('loginId') ? true : undefined}
            value={form.loginId}
            onChange={(event) => set('loginId', event.target.value)}
          />
          <Problem problems={shown} of="loginId" />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="cs-employee-id">{t('nasabah.csUsers.form.employeeId')}</Label>
          <Input
            id="cs-employee-id"
            autoComplete="off"
            maxLength={50}
            autoFocus={!create}
            aria-invalid={shown.includes('employeeId') ? true : undefined}
            value={form.employeeId}
            onChange={(event) => set('employeeId', event.target.value)}
          />
          <Problem problems={shown} of="employeeId" />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="cs-email">{t('nasabah.csUsers.form.email')}</Label>
          <Input
            id="cs-email"
            type="email"
            autoComplete="off"
            maxLength={255}
            aria-invalid={shown.includes('email') ? true : undefined}
            value={form.email}
            onChange={(event) => set('email', event.target.value)}
          />
          <Problem problems={shown} of="email" />
        </div>
        {create ? null : (
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="cs-status">{t('nasabah.csUsers.form.status')}</Label>
            <Select value={String(form.status)} onValueChange={(value) => set('status', Number(value))}>
              <SelectTrigger id="cs-status" className="w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {statuses.map((status) => (
                  <SelectItem key={status} value={String(status)}>
                    {label.csStatus(status)}
                    {status !== 0 && status !== 1 ? ` (${status})` : ''}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        )}
      </div>
      <div role="group" aria-labelledby="cs-flags-legend" className="flex flex-col gap-2">
        <div className="flex flex-wrap items-center gap-1">
          <span id="cs-flags-legend" className="mr-auto text-sm font-medium">
            {t('nasabah.csUsers.form.flags')}
          </span>
          <Button type="button" variant="ghost" size="xs" onClick={() => set('permissions', ALL_CS_FLAGS)}>
            {t('nasabah.csUsers.form.allFlags')}
          </Button>
          <Button type="button" variant="ghost" size="xs" onClick={() => set('permissions', 0)}>
            {t('nasabah.csUsers.form.noFlags')}
          </Button>
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          {csFlags.map((flag) => (
            <label key={flag.key} className="flex items-center gap-2 text-row">
              <Checkbox
                checked={(form.permissions & (1 << flag.bit)) !== 0}
                onCheckedChange={(value) =>
                  set('permissions', toggleFlag(form.permissions, 1 << flag.bit, value === true))
                }
              />
              {label.csFlag(flag.key)}
            </label>
          ))}
        </div>
        <Problem problems={shown} of="permissions" />
      </div>
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={save.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={save.isPending}>
          {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {create ? t('nasabah.csUsers.form.submitCreate') : t('nasabah.csUsers.form.submitEdit')}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function CsUserDialog({
  open,
  user,
  onClose,
  onCreated,
}: {
  open: boolean
  user: CsUser | null
  onClose: () => void
  onCreated: (loginId: string, result: CreatedCsUser) => void
}) {
  const { t } = useTranslation()
  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>
            {user
              ? t('nasabah.csUsers.form.editTitle', { loginId: user.LoginId.trim() })
              : t('nasabah.csUsers.form.createTitle')}
          </DialogTitle>
        </DialogHeader>
        {open ? (
          <CsUserFormBody key={user?.LoginId ?? 'new'} user={user} onDone={onClose} onCreated={onCreated} />
        ) : null}
      </DialogContent>
    </Dialog>
  )
}
