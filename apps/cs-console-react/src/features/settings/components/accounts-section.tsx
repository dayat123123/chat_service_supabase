import { zodResolver } from '@hookform/resolvers/zod'
import { CheckIcon, CopyIcon, LoaderCircleIcon, ShieldCheckIcon, UserPlusIcon } from 'lucide-react'
import { useState } from 'react'
import { Controller, useForm, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'

import { StatusDot } from '@/components/badges'
import { Button } from '@/components/ui/button'
import {
  Checkbox,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@/components/ui/controls'
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Tooltip } from '@/components/ui/menu'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useAgent } from '@/features/auth/hooks'
import { useNasabahLabels } from '@/features/nasabah/labels'
import { nasabahPermissions } from '@/features/nasabah/types'
import { errorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'
import { stamp } from '@/lib/time'
import { cn } from '@/lib/utils'

import { useAccounts, useAdminOptions, useResetPassword, useSaveAccount } from '../hooks'
import { isStaffRole, staffRoles, type CreatedAccount, type StaffAccount } from '../types'
import { ActiveBadge, FieldMessage, FormError, QueryContent, SectionFrame } from './settings-ui'

const emailPattern = /^[^\s@]{1,64}@[A-Za-z0-9.-]{1,190}\.[A-Za-z]{2,24}$/

type Message =
  'settings.invalidEmail' | 'settings.invalidName' | 'settings.rolesRequired' | 'settings.requiredField'

const editSchema = z.object({
  email: z.string().trim(),
  display_name: z.string().trim().min(2, 'settings.invalidName').max(40, 'settings.invalidName'),
  roles: z.array(z.string()).min(1, 'settings.rolesRequired'),
  team: z.string().min(1, 'settings.requiredField'),
  limit: z
    .string()
    .trim()
    .refine((value) => /^\d{1,2}$/.test(value) && Number(value) >= 1 && Number(value) <= 20),
  active: z.boolean(),
  nasabah: z.array(z.string()),
})

const createSchema = editSchema.extend({
  email: z.string().trim().regex(emailPattern, 'settings.invalidEmail'),
})

type AccountForm = z.infer<typeof editSchema>

type IssuedPassword = CreatedAccount & { reason: 'created' | 'reset' }

const resetErrors: Record<
  string,
  'settings.resetDisabled' | 'settings.resetNotFound' | 'settings.resetForbidden'
> = {
  agent_disabled: 'settings.resetDisabled',
  agent_not_found: 'settings.resetNotFound',
  role_forbidden: 'settings.resetForbidden',
}

function RoleLabel({ role }: { role: string }) {
  const { t } = useTranslation()
  return <>{isStaffRole(role) ? t(`roles.${role}`) : role}</>
}

function AccountDialog({
  account,
  open,
  onClose,
  onCreated,
}: {
  account: StaffAccount | null
  open: boolean
  onClose: () => void
  onCreated: (created: CreatedAccount) => void
}) {
  const { t } = useTranslation()
  const me = useAgent()
  const nasabahLabel = useNasabahLabels()
  const options = useAdminOptions()
  const save = useSaveAccount()
  const editing = account !== null
  const self = account?.id === me.id
  const teams = options.data?.teams ?? []
  const form = useForm<AccountForm>({
    resolver: zodResolver(editing ? editSchema : createSchema),
    defaultValues: {
      email: account?.email ?? '',
      display_name: account?.display_name ?? '',
      roles: account ? account.roles.filter(isStaffRole) : ['cs_agent'],
      team: account?.team ?? 'general',
      limit: String(account?.max_active_tickets ?? 5),
      active: account ? account.disabled_at === null : true,
      nasabah: account?.nasabah_permissions ?? [],
    },
  })
  const errors = form.formState.errors
  const active = useWatch({ control: form.control, name: 'active' })
  const disabling = editing && !active && account.disabled_at === null
  const message = (value?: string) => (value ? t(value as Message) : undefined)

  const submit = form.handleSubmit(async (values) => {
    const draft = {
      ...(editing ? {} : { email: values.email.trim().toLowerCase() }),
      display_name: values.display_name.trim(),
      roles: staffRoles.filter((role) => values.roles.includes(role)),
      team: values.team,
      max_active_tickets: Number(values.limit),
      disabled: !values.active,
    }
    try {
      const nasabah = nasabahPermissions.filter((permission) => values.nasabah.includes(permission))
      const result = await save.mutateAsync({ id: account?.id ?? null, draft, nasabah })
      onClose()
      if ('temporary_password' in result && typeof result.temporary_password === 'string') {
        onCreated({ agent: result.agent, temporary_password: result.temporary_password })
      }
    } catch {
      return
    }
  })

  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent className="sm:max-w-lg" closeLabel={t('app.close')} aria-describedby={undefined}>
        <DialogHeader>
          <DialogTitle>
            {editing
              ? t('settings.editAccountTitle', { name: account.display_name })
              : t('settings.addAccountTitle')}
          </DialogTitle>
        </DialogHeader>
        <form className="flex flex-col gap-4" onSubmit={(event) => void submit(event)} noValidate>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="account-email">{t('auth.email')}</Label>
            <Input
              id="account-email"
              type="email"
              autoComplete="off"
              disabled={editing}
              autoFocus={!editing}
              aria-invalid={errors.email ? true : undefined}
              {...form.register('email')}
            />
            <FieldMessage
              error={message(errors.email?.message)}
              hint={editing ? undefined : t('settings.staffEmailHint')}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="account-name">{t('settings.displayName')}</Label>
            <Input
              id="account-name"
              maxLength={40}
              autoFocus={editing}
              aria-invalid={errors.display_name ? true : undefined}
              {...form.register('display_name')}
            />
            <FieldMessage
              error={message(errors.display_name?.message)}
              hint={t('settings.displayNameHint')}
            />
          </div>
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1.5 text-sm font-medium">{t('settings.roles')}</legend>
            <Controller
              control={form.control}
              name="roles"
              render={({ field }) => (
                <div className="grid grid-cols-2 gap-2">
                  {staffRoles.map((role) => {
                    const locked = self && role === 'cs_super_admin'
                    const checked = field.value.includes(role)
                    return (
                      <label
                        key={role}
                        className={cn(
                          'flex items-center gap-2 rounded-md border px-3 py-2 text-sm',
                          checked && 'border-primary/50 bg-primary/5',
                          locked && 'opacity-60',
                        )}
                      >
                        <Checkbox
                          checked={checked}
                          disabled={locked}
                          onCheckedChange={(value) =>
                            field.onChange(
                              value === true
                                ? [...field.value, role]
                                : field.value.filter((item) => item !== role),
                            )
                          }
                        />
                        <RoleLabel role={role} />
                      </label>
                    )
                  })}
                </div>
              )}
            />
            <FieldMessage error={message(errors.roles?.message)} />
          </fieldset>
          <div className="grid grid-cols-[1fr_auto] gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="account-team">{t('settings.team')}</Label>
              <Controller
                control={form.control}
                name="team"
                render={({ field }) => (
                  <Select
                    value={teams.some((team) => team.code === field.value) ? field.value : undefined}
                    onValueChange={field.onChange}
                  >
                    <SelectTrigger id="account-team" className="w-full">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {teams.map((team) => (
                        <SelectItem key={team.code} value={team.code}>
                          {team.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
            </div>
            <div className="flex w-40 flex-col gap-1.5">
              <Label htmlFor="account-limit">{t('settings.ticketLimit')}</Label>
              <Input
                id="account-limit"
                inputMode="numeric"
                maxLength={2}
                aria-invalid={errors.limit ? true : undefined}
                {...form.register('limit')}
              />
              <FieldMessage
                error={errors.limit ? t('settings.numberRange', { min: 1, max: 20 }) : undefined}
              />
            </div>
          </div>
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-1 text-sm font-medium">{t('settings.nasabahAccess')}</legend>
            <p className="text-xs text-muted-foreground">{t('settings.nasabahHint')}</p>
            <Controller
              control={form.control}
              name="nasabah"
              render={({ field }) => (
                <div className="flex flex-col gap-1.5">
                  {nasabahPermissions.map((permission) => (
                    <label key={permission} className="flex items-center gap-2 text-row">
                      <Checkbox
                        checked={field.value.includes(permission)}
                        onCheckedChange={(value) =>
                          field.onChange(
                            value === true
                              ? [...field.value, permission]
                              : field.value.filter((item) => item !== permission),
                          )
                        }
                      />
                      {nasabahLabel.permission(permission)}
                    </label>
                  ))}
                </div>
              )}
            />
          </fieldset>
          {editing ? (
            <div className="flex flex-col gap-2">
              <Controller
                control={form.control}
                name="active"
                render={({ field }) => (
                  <label className="flex items-center justify-between gap-3 text-sm font-medium">
                    {t('settings.accountActive')}
                    <Switch checked={field.value} disabled={self} onCheckedChange={field.onChange} />
                  </label>
                )}
              />
              {self ? <p className="text-xs text-muted-foreground">{t('settings.selfLocked')}</p> : null}
              {disabling ? (
                <p role="alert" className="text-row text-destructive">
                  {t('settings.disableWarning', { count: account.active_tickets })}
                </p>
              ) : null}
            </div>
          ) : null}
          <FormError error={save.error} />
          <DialogFooter>
            <Button type="button" variant="ghost" disabled={save.isPending} onClick={onClose}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" variant={disabling ? 'destructive' : 'default'} disabled={save.isPending}>
              {save.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {editing ? t('app.save') : t('settings.createAccount')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function ResetPasswordDialog({
  account,
  onClose,
  onReset,
}: {
  account: StaffAccount
  onClose: () => void
  onReset: (reset: CreatedAccount) => void
}) {
  const { t } = useTranslation()
  const reset = useResetPassword()
  const known = reset.error ? resetErrors[toApiError(reset.error).code] : undefined
  return (
    <AlertDialog open onOpenChange={(open) => !open && !reset.isPending && onClose()}>
      <AlertDialogContent className="sm:max-w-md">
        <AlertDialogTitle>
          {t('settings.resetPasswordTitle', { name: account.display_name })}
        </AlertDialogTitle>
        <AlertDialogDescription>
          {t('settings.resetPasswordBody', { name: account.display_name })}
        </AlertDialogDescription>
        {reset.error ? (
          <p role="alert" className="text-row text-destructive">
            {known ? t(known) : errorText(reset.error)}
          </p>
        ) : null}
        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <AlertDialogCancel disabled={reset.isPending}>{t('app.cancel')}</AlertDialogCancel>
          <Button
            variant="destructive"
            disabled={reset.isPending}
            onClick={() =>
              reset.mutate(account.id, {
                onSuccess: (result) => {
                  onClose()
                  onReset(result)
                },
              })
            }
          >
            {reset.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
            {t('settings.resetPassword')}
          </Button>
        </div>
      </AlertDialogContent>
    </AlertDialog>
  )
}

function PasswordDialog({ issued, onClose }: { issued: IssuedPassword | null; onClose: () => void }) {
  const { t } = useTranslation()
  const [copied, setCopied] = useState(false)
  const copy = (password: string) => {
    void navigator.clipboard
      .writeText(password)
      .then(() => setCopied(true))
      .catch(() => setCopied(false))
  }
  const created = issued?.reason === 'created'
  return (
    <Dialog
      open={issued !== null}
      onOpenChange={(open) => {
        if (open) return
        setCopied(false)
        onClose()
      }}
    >
      <DialogContent className="sm:max-w-md" onInteractOutside={(event) => event.preventDefault()}>
        {issued ? (
          <>
            <DialogHeader>
              <ShieldCheckIcon className="size-5 text-success" aria-hidden="true" />
              <DialogTitle>
                {created ? t('settings.accountCreatedTitle') : t('settings.passwordResetTitle')}
              </DialogTitle>
              <DialogDescription>
                {t(created ? 'settings.accountCreatedBody' : 'settings.passwordResetBody', {
                  name: `${issued.agent.display_name} (${issued.agent.agent_code})`,
                })}
              </DialogDescription>
            </DialogHeader>
            <dl className="flex flex-col gap-3 text-sm">
              <div>
                <dt className="text-xs font-medium text-muted-foreground">{t('auth.email')}</dt>
                <dd className="select-all">{issued.agent.email}</dd>
              </div>
              <div>
                <dt className="text-xs font-medium text-muted-foreground">
                  {t('settings.temporaryPassword')}
                </dt>
                <dd className="flex items-center gap-2">
                  <code className="flex-1 rounded-md bg-muted px-2 py-1.5 font-mono text-base tracking-wider select-all">
                    {issued.temporary_password}
                  </code>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => copy(issued.temporary_password)}
                  >
                    {copied ? <CheckIcon /> : <CopyIcon />}
                    {copied ? t('app.copied') : t('app.copy')}
                  </Button>
                </dd>
              </div>
            </dl>
            <p className="text-xs text-muted-foreground">
              {created ? t('settings.accountCreatedSteps') : t('settings.passwordResetSteps')}
            </p>
            <DialogFooter>
              <Button
                type="button"
                onClick={() => {
                  setCopied(false)
                  onClose()
                }}
              >
                {t('app.done')}
              </Button>
            </DialogFooter>
          </>
        ) : null}
      </DialogContent>
    </Dialog>
  )
}

function AccountsTable({
  accounts,
  meId,
  onEdit,
  onReset,
}: {
  accounts: StaffAccount[]
  meId: string
  onEdit: (account: StaffAccount) => void
  onReset: (account: StaffAccount) => void
}) {
  const { t } = useTranslation()
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('settings.colAgent')}</TableHead>
          <TableHead>{t('auth.email')}</TableHead>
          <TableHead>{t('settings.colRoles')}</TableHead>
          <TableHead>{t('settings.colTeam')}</TableHead>
          <TableHead className="text-right">{t('settings.colTicketLimit')}</TableHead>
          <TableHead>{t('settings.colStatus')}</TableHead>
          <TableHead>
            <span className="sr-only">{t('settings.colActions')}</span>
          </TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {accounts.map((account) => (
          <TableRow key={account.id} className={cn(account.disabled_at && 'text-muted-foreground')}>
            <TableCell className="font-medium">
              {account.display_name}{' '}
              <span className="font-normal text-muted-foreground">({account.agent_code})</span>
            </TableCell>
            <TableCell>{account.email ?? '–'}</TableCell>
            <TableCell>
              {account.roles.map((role, index) => (
                <span key={role}>
                  {index > 0 ? ', ' : null}
                  <RoleLabel role={role} />
                </span>
              ))}
            </TableCell>
            <TableCell>{account.team ?? '–'}</TableCell>
            <TableCell className="tabular text-right">
              {account.active_tickets}/{account.max_active_tickets}
            </TableCell>
            <TableCell>
              {account.disabled_at ? (
                <Tooltip content={t('settings.disabledSince', { time: stamp(account.disabled_at) })}>
                  <span
                    tabIndex={0}
                    className="rounded-sm outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                  >
                    <ActiveBadge active={false} inactiveLabel={t('settings.accountDisabled')} />
                  </span>
                </Tooltip>
              ) : (
                <span className="inline-flex items-center gap-1.5">
                  <StatusDot status={account.status} />
                  {t(`presence.${account.status}`)}
                </span>
              )}
            </TableCell>
            <TableCell className="text-right whitespace-nowrap">
              {account.disabled_at === null && account.id !== meId ? (
                <Button
                  variant="ghost"
                  size="xs"
                  aria-label={`${t('settings.resetPassword')} ${account.display_name}`}
                  onClick={() => onReset(account)}
                >
                  {t('settings.resetPassword')}
                </Button>
              ) : null}
              <Button variant="ghost" size="xs" onClick={() => onEdit(account)}>
                {t('app.edit')}
              </Button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

export function AccountsSection() {
  const { t } = useTranslation()
  const me = useAgent()
  const accounts = useAccounts()
  const [editing, setEditing] = useState<{ account: StaffAccount | null; key: number } | null>(null)
  const [resetting, setResetting] = useState<StaffAccount | null>(null)
  const [issued, setIssued] = useState<IssuedPassword | null>(null)
  const open = (account: StaffAccount | null) => setEditing({ account, key: Date.now() })
  return (
    <SectionFrame
      title={t('settings.accounts')}
      description={t('settings.accountsDescription')}
      action={
        <Button onClick={() => open(null)}>
          <UserPlusIcon />
          {t('settings.addAccount')}
        </Button>
      }
    >
      <QueryContent query={accounts}>
        {(items) => <AccountsTable accounts={items} meId={me.id} onEdit={open} onReset={setResetting} />}
      </QueryContent>
      {editing ? (
        <AccountDialog
          key={editing.key}
          account={editing.account}
          open
          onClose={() => setEditing(null)}
          onCreated={(created) => setIssued({ ...created, reason: 'created' })}
        />
      ) : null}
      {resetting ? (
        <ResetPasswordDialog
          key={resetting.id}
          account={resetting}
          onClose={() => setResetting(null)}
          onReset={(reset) => setIssued({ ...reset, reason: 'reset' })}
        />
      ) : null}
      <PasswordDialog issued={issued} onClose={() => setIssued(null)} />
    </SectionFrame>
  )
}
