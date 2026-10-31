import {
  CheckCircle2Icon,
  CircleAlertIcon,
  KeyRoundIcon,
  LinkIcon,
  PencilIcon,
  ShieldQuestionIcon,
  ToggleRightIcon,
  Trash2Icon,
} from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useAgent } from '@/features/auth/hooks'
import { errorText } from '@/lib/error-text'

import { useLinkedAccounts, useResetCredential, useSubmitApproval } from '../hooks'
import { legacyStamp, useNasabahLabels } from '../labels'
import {
  approvalPayload,
  canChangeStatus,
  canEditUser,
  canLinkAccounts,
  canResetCredentials,
  flagsOf,
  formFromUser,
  incompleteFields,
} from '../logic'
import type { OnlineUser } from '../types'
import { Confirm } from './confirm'
import { LinkDialog } from './link-dialog'
import { StatusDialog } from './status-dialog'
import { UserDialog } from './user-dialog'

type Pending = 'remove' | 'password' | 'pin' | null

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col gap-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-row break-words">{children}</dd>
    </div>
  )
}

function Verified({ ok }: { ok: boolean }) {
  const { t } = useTranslation()
  return ok ? (
    <span className="inline-flex items-center gap-1 text-xs text-success">
      <CheckCircle2Icon className="size-3.5" aria-hidden="true" />
      {t('nasabah.detail.verified')}
    </span>
  ) : (
    <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
      <ShieldQuestionIcon className="size-3.5" aria-hidden="true" />
      {t('nasabah.detail.unverified')}
    </span>
  )
}

function UserBody({ user, onClose }: { user: OnlineUser; onClose: () => void }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const label = useNasabahLabels()
  const perms = agent.nasabah_permissions
  const links = useLinkedAccounts(user.LoginId)
  const submit = useSubmitApproval()
  const reset = useResetCredential()
  const [editing, setEditing] = useState(false)
  const [linking, setLinking] = useState(false)
  const [pending, setPending] = useState<Pending>(null)
  const [changingStatus, setChangingStatus] = useState(false)
  const missing = incompleteFields(user)
  const linkIds = (links.data ?? []).map((link) => link.AccountId.trim()).filter(Boolean)
  const flags = flagsOf(user.Permissions)
  const email = user.Email.trim()

  const confirm = () => {
    if (pending === 'remove') {
      submit.mutate(approvalPayload(3, formFromUser(user, linkIds), linkIds), {
        onSuccess: () => {
          toast.success(t('nasabah.toast.submitted'))
          setPending(null)
          onClose()
        },
        onError: (error) => toast.error(errorText(error)),
      })
      return
    }
    if (pending === 'password' || pending === 'pin') {
      const kind = pending
      reset.mutate(
        { loginId: user.LoginId, kind },
        {
          onSuccess: () => {
            toast.success(
              kind === 'password' ? t('nasabah.toast.resetPassword') : t('nasabah.toast.resetPin'),
            )
            setPending(null)
          },
          onError: (error) => toast.error(errorText(error)),
        },
      )
    }
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-1 border-b px-5 pt-4 pr-12 pb-3">
        <h2 className="font-mono text-panel font-semibold">{user.LoginId}</h2>
        <p className="text-row text-muted-foreground">
          {label.loginType(user.LoginType)} · {label.status(user.Status)}
        </p>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        {missing.length > 0 ? (
          <section
            aria-labelledby="nasabah-incomplete-title"
            className="flex flex-wrap items-start gap-3 border-b bg-warning/10 px-5 py-3"
          >
            <CircleAlertIcon className="mt-0.5 size-4 shrink-0 text-warning" aria-hidden="true" />
            <div className="flex min-w-0 flex-1 flex-col gap-0.5">
              <h3 id="nasabah-incomplete-title" className="text-row font-semibold">
                {t('nasabah.incomplete.title')}
              </h3>
              <p className="text-xs text-muted-foreground">
                {t('nasabah.incomplete.body', { fields: missing.map(label.incomplete).join(', ') })}
              </p>
            </div>
            {canEditUser(perms, user) ? (
              <Button size="sm" variant="outline" disabled={!links.data} onClick={() => setEditing(true)}>
                <PencilIcon />
                {t('nasabah.incomplete.fix')}
              </Button>
            ) : null}
          </section>
        ) : null}
        <dl className="grid gap-x-6 gap-y-3 border-b px-5 py-4 sm:grid-cols-2">
          <Fact label={t('nasabah.detail.email')}>
            <span className="flex flex-col">
              {email || '–'}
              {email ? <Verified ok={user.IsEmailApproved === 1} /> : null}
            </span>
          </Fact>
          <Fact label={t('nasabah.detail.phone')}>
            <span className="flex flex-col">
              {user.PhoneNumber || '–'}
              {user.PhoneNumber ? <Verified ok={user.IsPhoneNumberApproved === 1} /> : null}
            </span>
          </Fact>
          <Fact label={t('nasabah.detail.birthDate')}>{legacyStamp(user.BirthDate, 'd MMM yyyy')}</Fact>
          <Fact label={t('nasabah.detail.created')}>{legacyStamp(user.Created)}</Fact>
          {user.SalesId ? <Fact label={t('nasabah.detail.salesId')}>{user.SalesId}</Fact> : null}
          {user.AccountExpired ? (
            <Fact label={t('nasabah.detail.expired')}>{legacyStamp(user.AccountExpired)}</Fact>
          ) : null}
          <Fact label={t('nasabah.detail.retries')}>
            {t('nasabah.detail.retryValue', { password: user.ErrorPwdRetry, pin: user.ErrorPinRetry })}
          </Fact>
          <Fact label={t('nasabah.detail.flags')}>{label.flagList(flags)}</Fact>
        </dl>
        <div className="flex flex-wrap gap-2 border-b px-5 py-3">
          {canEditUser(perms, user) ? (
            <Button variant="outline" size="sm" onClick={() => setEditing(true)} disabled={!links.data}>
              <PencilIcon />
              {t('nasabah.detail.edit')}
            </Button>
          ) : null}
          {canChangeStatus(perms) ? (
            <Button variant="outline" size="sm" onClick={() => setChangingStatus(true)}>
              <ToggleRightIcon />
              {t('nasabah.status.action')}
            </Button>
          ) : null}
          {canLinkAccounts(perms, user) ? (
            <Button variant="outline" size="sm" onClick={() => setLinking(true)} disabled={!links.data}>
              <LinkIcon />
              {t('nasabah.detail.link')}
            </Button>
          ) : null}
          {canResetCredentials(perms) ? (
            <>
              <Button variant="outline" size="sm" disabled={!email} onClick={() => setPending('password')}>
                <KeyRoundIcon />
                {t('nasabah.detail.resetPassword')}
              </Button>
              <Button variant="outline" size="sm" disabled={!email} onClick={() => setPending('pin')}>
                <KeyRoundIcon />
                {t('nasabah.detail.resetPin')}
              </Button>
            </>
          ) : null}
          {canEditUser(perms, user) ? (
            <Button variant="outline" size="sm" disabled={!links.data} onClick={() => setPending('remove')}>
              <Trash2Icon />
              {t('nasabah.detail.remove')}
            </Button>
          ) : null}
          {canResetCredentials(perms) && !email ? (
            <p className="w-full text-xs text-muted-foreground">{t('nasabah.confirm.noEmail')}</p>
          ) : null}
        </div>
        <section className="flex flex-col gap-2 px-5 py-4" aria-labelledby="nasabah-links-title">
          <h3 id="nasabah-links-title" className="text-row font-semibold">
            {t('nasabah.detail.linked')}
          </h3>
          {links.isError ? (
            <ErrorState error={links.error} onRetry={() => void links.refetch()} />
          ) : !links.data ? (
            <ListSkeleton rows={2} />
          ) : links.data.length === 0 ? (
            <p className="text-row text-muted-foreground">{t('nasabah.detail.linkedEmpty')}</p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('nasabah.detail.colAccount')}</TableHead>
                  <TableHead>{t('nasabah.detail.colName')}</TableHead>
                  <TableHead>{t('nasabah.detail.colLinkedAt')}</TableHead>
                  <TableHead>{t('nasabah.detail.colLinkedBy')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {links.data.map((link) => (
                  <TableRow key={link.AccountId}>
                    <TableCell className="font-mono text-xs">{link.AccountId}</TableCell>
                    <TableCell className="max-w-56 truncate">{link.AccountName || '–'}</TableCell>
                    <TableCell className="text-xs text-muted-foreground">
                      {legacyStamp(link.Created)}
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground">{link.CreatedBy || '–'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </section>
      </div>
      <UserDialog open={editing} user={user} links={linkIds} onClose={() => setEditing(false)} />
      <LinkDialog
        open={linking}
        user={user}
        links={linkIds}
        names={Object.fromEntries(
          (links.data ?? []).map((link) => [link.AccountId.trim(), link.AccountName]),
        )}
        onClose={() => setLinking(false)}
      />
      <StatusDialog user={changingStatus ? user : null} onClose={() => setChangingStatus(false)} />
      <Confirm
        open={pending !== null}
        title={
          pending === 'remove'
            ? t('nasabah.confirm.removeTitle', { loginId: user.LoginId })
            : pending === 'password'
              ? t('nasabah.confirm.resetPasswordTitle', { loginId: user.LoginId })
              : t('nasabah.confirm.resetPinTitle', { loginId: user.LoginId })
        }
        body={
          pending === 'remove' ? t('nasabah.confirm.removeBody') : t('nasabah.confirm.resetBody', { email })
        }
        action={
          pending === 'remove'
            ? t('nasabah.detail.remove')
            : pending === 'password'
              ? t('nasabah.detail.resetPassword')
              : t('nasabah.detail.resetPin')
        }
        destructive
        pending={submit.isPending || reset.isPending}
        onConfirm={confirm}
        onClose={() => setPending(null)}
      />
    </div>
  )
}

export function UserPanel({ user, onClose }: { user: OnlineUser | null; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Sheet open={user !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('nasabah.tabs.users')}
        closeLabel={t('app.close')}
        className="w-[min(680px,100vw)] bg-background"
      >
        {user ? <UserBody key={user.LoginId} user={user} onClose={onClose} /> : null}
      </SheetContent>
    </Sheet>
  )
}
