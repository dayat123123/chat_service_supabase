import { useId, useMemo, useState, type ReactNode } from 'react'
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
import { cn } from '@/lib/utils'

import { useAccountCatalog, useSubmitApproval } from '../hooks'
import { useNasabahLabels } from '../labels'
import {
  approvalPayload,
  dateBounds,
  emptyForm,
  formFromUser,
  formProblems,
  has,
  linkChanges,
  needsSalesId,
  salesOptions,
  toggleFlag,
  withLoginType,
  type FormProblem,
} from '../logic'
import {
  CLIENT,
  DEMO,
  SALES,
  loginTypes,
  userFlags,
  type LoginType,
  type OnlineUser,
  type OnlineUserForm,
} from '../types'
import { AccountPicker } from './account-picker'
import { Confirm } from './confirm'

function Field({
  id,
  label,
  hint,
  problems,
  shown,
  children,
}: {
  id: string
  label: string
  hint?: string
  problems: FormProblem[]
  shown: FormProblem[]
  children: ReactNode
}) {
  const { t } = useTranslation()
  const visible = problems.filter((problem) => shown.includes(problem))
  return (
    <div className="flex flex-col gap-1.5">
      <Label htmlFor={id}>{label}</Label>
      {children}
      {visible.map((problem) => (
        <p key={problem} id={`${id}-error`} role="alert" className="text-xs text-destructive">
          {t(`nasabah.form.problems.${problem}`)}
        </p>
      ))}
      {hint && visible.length === 0 ? (
        <p id={`${id}-hint`} className="text-xs text-muted-foreground">
          {hint}
        </p>
      ) : null}
    </div>
  )
}

function invalid(id: string, problems: FormProblem[], shown: FormProblem[]) {
  const on = problems.some((problem) => shown.includes(problem))
  return { 'aria-invalid': on ? true : undefined, 'aria-describedby': on ? `${id}-error` : undefined }
}

function UserForm({ user, links, onDone }: { user: OnlineUser | null; links: string[]; onDone: () => void }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const label = useNasabahLabels()
  const submit = useSubmitApproval()
  const ids = useId()
  const perms = agent.nasabah_permissions
  const manager = has(perms, 'online_user.manage')
  const [form, setForm] = useState<OnlineUserForm>(() =>
    user ? formFromUser(user, links) : emptyForm(manager ? CLIENT : DEMO),
  )
  const [submitted, setSubmitted] = useState(false)
  const [confirming, setConfirming] = useState(false)
  const bounds = useMemo(() => dateBounds(), [])
  const catalog = useAccountCatalog(manager && (form.loginType === CLIENT || needsSalesId(form.loginType)))
  const codes = useMemo(() => salesOptions(catalog.data, form.loginType), [catalog.data, form.loginType])
  const problems = formProblems(form, perms, { previous: user, previousLinks: links, catalog: catalog.data })
  const shown = submitted ? problems : []
  const action = user ? 2 : 1
  const changes = linkChanges(action, form, links)
  const picker = manager && form.loginType === CLIENT
  const set = <K extends keyof OnlineUserForm>(key: K, value: OnlineUserForm[K]) =>
    setForm((current) => ({ ...current, [key]: value }))
  const id = (name: string) => `${ids}-${name}`
  const types = manager ? loginTypes : [DEMO]

  const send = () =>
    submit.mutate(approvalPayload(action, form, links), {
      onSuccess: () => {
        toast.success(t('nasabah.toast.submitted'))
        setConfirming(false)
        onDone()
      },
      onError: (error) => {
        toast.error(errorText(error))
        setConfirming(false)
      },
    })

  return (
    <form
      className="flex min-h-0 flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault()
        setSubmitted(true)
        if (problems.length === 0) setConfirming(true)
      }}
    >
      <DialogDescription>{t('nasabah.form.hint')}</DialogDescription>
      <div
        data-picker={picker || undefined}
        className={cn('grid gap-x-6 gap-y-5', picker && 'lg:min-h-96 lg:grid-cols-2')}
      >
        <div className="flex flex-col gap-5">
          <div className="grid gap-x-3 gap-y-3.5 sm:grid-cols-2">
            <Field id={id('login')} label={t('nasabah.form.loginId')} problems={['loginId']} shown={shown}>
              <Input
                id={id('login')}
                autoComplete="off"
                maxLength={50}
                disabled={user !== null}
                autoFocus={user === null}
                value={form.loginId}
                onChange={(event) => set('loginId', event.target.value)}
                {...invalid(id('login'), ['loginId'], shown)}
              />
            </Field>
            <Field id={id('type')} label={t('nasabah.form.loginType')} problems={['demoOnly']} shown={shown}>
              <Select
                value={String(form.loginType)}
                disabled={!manager}
                onValueChange={(value) =>
                  setForm((current) => withLoginType(current, Number(value) as LoginType, links))
                }
              >
                <SelectTrigger
                  id={id('type')}
                  className="w-full"
                  {...invalid(id('type'), ['demoOnly'], shown)}
                >
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
            </Field>
            <Field id={id('email')} label={t('nasabah.form.email')} problems={['email']} shown={shown}>
              <Input
                id={id('email')}
                type="email"
                autoComplete="off"
                maxLength={100}
                value={form.email}
                onChange={(event) => set('email', event.target.value)}
                {...invalid(id('email'), ['email'], shown)}
              />
            </Field>
            <Field id={id('phone')} label={t('nasabah.form.phone')} problems={['phone']} shown={shown}>
              <Input
                id={id('phone')}
                inputMode="tel"
                autoComplete="off"
                maxLength={21}
                placeholder={t('nasabah.form.phonePlaceholder')}
                value={form.phone}
                onChange={(event) => set('phone', event.target.value)}
                {...invalid(id('phone'), ['phone'], shown)}
              />
            </Field>
            <Field
              id={id('birth')}
              label={t('nasabah.form.birthDate')}
              problems={['birthDate']}
              shown={shown}
            >
              <Input
                id={id('birth')}
                type="date"
                min={bounds.birthMin}
                max={bounds.birthMax}
                value={form.birthDate}
                onChange={(event) => set('birthDate', event.target.value)}
                {...invalid(id('birth'), ['birthDate'], shown)}
              />
            </Field>
            {needsSalesId(form.loginType) ? (
              <Field
                id={id('code')}
                label={form.loginType === SALES ? t('nasabah.form.salesCode') : t('nasabah.form.branchCode')}
                hint={catalog.data ? t('nasabah.form.codeHint') : t('nasabah.form.codeLoading')}
                problems={['salesId', 'salesUnknown']}
                shown={shown}
              >
                <Input
                  id={id('code')}
                  autoComplete="off"
                  maxLength={50}
                  list={id('codes')}
                  value={form.salesId}
                  onChange={(event) => set('salesId', event.target.value)}
                  {...invalid(id('code'), ['salesId', 'salesUnknown'], shown)}
                />
                <datalist id={id('codes')}>
                  {codes.map((code) => (
                    <option key={code.id} value={code.id}>
                      {t('nasabah.form.codeOption', { count: code.count })}
                    </option>
                  ))}
                </datalist>
                {catalog.isError ? (
                  <Button
                    type="button"
                    variant="link"
                    size="xs"
                    className="self-start px-0"
                    onClick={() => void catalog.refetch()}
                  >
                    {errorText(catalog.error)}
                  </Button>
                ) : null}
              </Field>
            ) : null}
            {form.loginType === DEMO ? (
              <Field
                id={id('expired')}
                label={t('nasabah.form.accountExpired')}
                problems={['accountExpired']}
                shown={shown}
              >
                <Input
                  id={id('expired')}
                  type="date"
                  min={bounds.expiredMin}
                  max={bounds.expiredMax}
                  disabled={form.neverExpired}
                  value={form.neverExpired ? '' : form.accountExpired}
                  onChange={(event) => set('accountExpired', event.target.value)}
                  {...invalid(id('expired'), ['accountExpired'], shown)}
                />
                <label className="flex items-center gap-2 text-row">
                  <Checkbox
                    checked={form.neverExpired}
                    onCheckedChange={(value) => set('neverExpired', value === true)}
                  />
                  {t('nasabah.form.neverExpired')}
                </label>
              </Field>
            ) : null}
          </div>
          <fieldset className="flex flex-col gap-2">
            <legend className="text-sm font-medium">{t('nasabah.form.flags')}</legend>
            <p className="text-xs text-muted-foreground">{t('nasabah.form.flagsHint')}</p>
            <div className={cn('grid grid-cols-2 gap-x-3 gap-y-2', !picker && 'sm:grid-cols-3')}>
              {userFlags.map((flag) => (
                <label key={flag.key} className="flex items-center gap-2 text-row">
                  <Checkbox
                    checked={(form.flags & flag.bit) !== 0}
                    onCheckedChange={(value) =>
                      set('flags', toggleFlag(form.flags, flag.bit, value === true))
                    }
                  />
                  {label.flag(flag.key)}
                </label>
              ))}
            </div>
          </fieldset>
        </div>
        {picker ? (
          <section
            aria-labelledby={id('links')}
            className="flex min-h-0 flex-col gap-2 lg:h-0 lg:min-h-full lg:border-l lg:pl-6"
          >
            <div className="flex flex-col gap-0.5">
              <h3 id={id('links')} className="text-sm font-medium">
                {t('nasabah.form.links')}
              </h3>
              <p className="text-xs text-muted-foreground">{t('nasabah.form.linksHint')}</p>
            </div>
            <AccountPicker
              catalog={catalog}
              linked={links}
              selected={form.links}
              onChange={(next) => set('links', next)}
              className="max-h-72 lg:max-h-none"
            />
            {shown.includes('links') ? (
              <p role="alert" className="text-xs text-destructive">
                {t('nasabah.form.problems.links')}
              </p>
            ) : null}
          </section>
        ) : null}
      </div>
      <DialogFooter>
        <Button type="button" variant="ghost" disabled={submit.isPending} onClick={onDone}>
          {t('app.cancel')}
        </Button>
        <Button type="submit" disabled={submit.isPending}>
          {t('nasabah.form.submit')}
        </Button>
      </DialogFooter>
      <Confirm
        open={confirming}
        title={t('nasabah.form.confirmTitle', { loginId: form.loginId.trim() })}
        body={[
          t('nasabah.form.confirmBody'),
          changes.link.length > 0 ? t('nasabah.form.confirmLinked', { count: changes.link.length }) : '',
          changes.unlink.length > 0
            ? t('nasabah.form.confirmUnlinked', { count: changes.unlink.length })
            : '',
        ]
          .filter(Boolean)
          .join(' ')}
        action={t('nasabah.form.submit')}
        pending={submit.isPending}
        onConfirm={send}
        onClose={() => setConfirming(false)}
      />
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
      <DialogContent className="sm:max-w-2xl lg:has-[[data-picker]]:max-w-5xl" closeLabel={t('app.close')}>
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
