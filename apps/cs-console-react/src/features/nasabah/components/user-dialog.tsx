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
import { useAgent } from '@/features/auth/hooks'
import { errorText } from '@/lib/error-text'

import { useSubmitApproval } from '../hooks'
import { useNasabahLabels } from '../labels'
import {
  approvalPayload,
  emptyForm,
  formFromUser,
  formProblems,
  has,
  needsSalesId,
  toggleFlag,
  type FormProblem,
} from '../logic'
import {
  DEMO,
  loginTypes,
  userFlags,
  userStatuses,
  type LoginType,
  type OnlineUser,
  type OnlineUserForm,
  type UserStatus,
} from '../types'

function Problem({ id, problems, of }: { id: string; problems: FormProblem[]; of: FormProblem }) {
  const { t } = useTranslation()
  if (!problems.includes(of)) return null
  return (
    <p id={id} role="alert" className="text-xs text-destructive">
      {t(`nasabah.form.problems.${of}`)}
    </p>
  )
}

function UserForm({ user, links, onDone }: { user: OnlineUser | null; links: string[]; onDone: () => void }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const label = useNasabahLabels()
  const submit = useSubmitApproval()
  const perms = agent.nasabah_permissions
  const demoOnly = !has(perms, 'online_user.manage')
  const [form, setForm] = useState<OnlineUserForm>(() =>
    user ? formFromUser(user, links) : emptyForm(demoOnly ? DEMO : 1),
  )
  const [shown, setShown] = useState<FormProblem[]>([])
  const set = <K extends keyof OnlineUserForm>(key: K, value: OnlineUserForm[K]) =>
    setForm((current) => ({ ...current, [key]: value }))
  const types = demoOnly ? [DEMO] : loginTypes

  return (
    <form
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        const problems = formProblems(form, perms)
        setShown(problems)
        if (problems.length > 0) return
        submit.mutate(approvalPayload(user ? 2 : 1, form, links), {
          onSuccess: () => {
            toast.success(t('nasabah.toast.submitted'))
            onDone()
          },
          onError: (error) => toast.error(errorText(error)),
        })
      }}
    >
      <DialogDescription>{t('nasabah.form.hint')}</DialogDescription>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="nasabah-login-id">{t('nasabah.form.loginId')}</Label>
          <Input
            id="nasabah-login-id"
            autoComplete="off"
            maxLength={50}
            disabled={user !== null}
            autoFocus={user === null}
            aria-invalid={shown.includes('loginId') ? true : undefined}
            value={form.loginId}
            onChange={(event) => set('loginId', event.target.value)}
          />
          <Problem id="nasabah-login-id-error" problems={shown} of="loginId" />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="nasabah-login-type">{t('nasabah.form.loginType')}</Label>
          <Select
            value={String(form.loginType)}
            onValueChange={(value) => set('loginType', Number(value) as LoginType)}
          >
            <SelectTrigger id="nasabah-login-type" className="w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {types.map((type) => (
                <SelectItem key={type} value={String(type)}>
                  {label.loginType(type)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Problem id="nasabah-login-type-error" problems={shown} of="demoOnly" />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="nasabah-email">{t('nasabah.form.email')}</Label>
          <Input
            id="nasabah-email"
            type="email"
            autoComplete="off"
            aria-invalid={shown.includes('email') ? true : undefined}
            value={form.email}
            onChange={(event) => set('email', event.target.value)}
          />
          <Problem id="nasabah-email-error" problems={shown} of="email" />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="nasabah-phone">{t('nasabah.form.phone')}</Label>
          <Input
            id="nasabah-phone"
            inputMode="tel"
            autoComplete="off"
            maxLength={20}
            value={form.phone}
            onChange={(event) => set('phone', event.target.value)}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="nasabah-birth-date">{t('nasabah.form.birthDate')}</Label>
          <Input
            id="nasabah-birth-date"
            type="date"
            value={form.birthDate}
            onChange={(event) => set('birthDate', event.target.value)}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="nasabah-status">{t('nasabah.form.status')}</Label>
          <Select
            value={String(form.status)}
            onValueChange={(value) => set('status', Number(value) as UserStatus)}
          >
            <SelectTrigger id="nasabah-status" className="w-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {userStatuses.map((status) => (
                <SelectItem key={status} value={String(status)}>
                  {label.status(status)}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        {needsSalesId(form.loginType) ? (
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="nasabah-sales-id">{t('nasabah.form.salesId')}</Label>
            <Input
              id="nasabah-sales-id"
              autoComplete="off"
              maxLength={20}
              aria-invalid={shown.includes('salesId') ? true : undefined}
              value={form.salesId}
              onChange={(event) => set('salesId', event.target.value)}
            />
            <Problem id="nasabah-sales-id-error" problems={shown} of="salesId" />
          </div>
        ) : null}
        {form.loginType === DEMO ? (
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="nasabah-expired">{t('nasabah.form.accountExpired')}</Label>
            <Input
              id="nasabah-expired"
              type="datetime-local"
              aria-invalid={shown.includes('accountExpired') ? true : undefined}
              value={form.accountExpired}
              onChange={(event) => set('accountExpired', event.target.value)}
            />
            <Problem id="nasabah-expired-error" problems={shown} of="accountExpired" />
          </div>
        ) : null}
      </div>
      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1.5 text-sm font-medium">{t('nasabah.form.flags')}</legend>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
          {userFlags.map((flag) => (
            <label key={flag.key} className="flex items-center gap-2 text-row">
              <Checkbox
                checked={(form.flags & flag.bit) !== 0}
                onCheckedChange={(value) => set('flags', toggleFlag(form.flags, flag.bit, value === true))}
              />
              {label.flag(flag.key)}
            </label>
          ))}
        </div>
      </fieldset>
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={submit.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={submit.isPending}>
          {submit.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
          {t('nasabah.form.submit')}
        </Button>
      </DialogFooter>
    </form>
  )
}

export function UserDialog({
  open,
  user,
  links,
  onClose,
}: {
  open: boolean
  user: OnlineUser | null
  links: string[]
  onClose: () => void
}) {
  const { t } = useTranslation()
  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>
            {user ? t('nasabah.form.editTitle', { loginId: user.LoginId }) : t('nasabah.form.createTitle')}
          </DialogTitle>
        </DialogHeader>
        {open ? <UserForm key={user?.LoginId ?? 'new'} user={user} links={links} onDone={onClose} /> : null}
      </DialogContent>
    </Dialog>
  )
}
