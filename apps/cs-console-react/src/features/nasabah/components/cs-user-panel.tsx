import { CheckIcon, KeyRoundIcon, LockIcon, MinusIcon, PencilIcon, Trash2Icon } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { Button } from '@/components/ui/button'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { errorText } from '@/lib/error-text'
import { cn } from '@/lib/utils'

import { useDeleteCsUser } from '../hooks'
import { legacyStamp, useNasabahLabels } from '../labels'
import { csFlags, type CsUser } from '../types'
import { Confirm } from './confirm'

const text = (value: string | null | undefined) => (value ?? '').trim()

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col gap-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-row break-words">{children}</dd>
    </div>
  )
}

export function TechnicalBadge() {
  const { t } = useTranslation()
  return (
    <span className="inline-flex items-center gap-1 rounded-sm border px-1.5 py-px text-xs text-muted-foreground">
      <LockIcon className="size-3" aria-hidden="true" />
      {t('nasabah.csUsers.technical')}
    </span>
  )
}

function CsUserBody({
  user,
  technical,
  actor,
  onEdit,
  onPassword,
  onClose,
}: {
  user: CsUser
  technical: boolean
  actor: string | undefined
  onEdit: () => void
  onPassword: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  const label = useNasabahLabels()
  const remove = useDeleteCsUser()
  const [confirming, setConfirming] = useState(false)
  const loginId = text(user.LoginId)
  const stamp = (when: string, by: string) => {
    const at = legacyStamp(when)
    return text(by) ? t('nasabah.csUsers.by', { when: at, by: text(by) }) : at
  }

  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-1 border-b px-5 pt-4 pr-12 pb-3">
        <h2 className="font-mono text-panel font-semibold">{loginId}</h2>
        <p className="flex flex-wrap items-center gap-2 text-row text-muted-foreground">
          <span className={user.Status === 1 ? 'text-success' : undefined}>
            {label.csStatus(user.Status)}
          </span>
          {technical ? <TechnicalBadge /> : null}
        </p>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <dl className="grid gap-x-6 gap-y-3 border-b px-5 py-4 sm:grid-cols-2">
          <Fact label={t('nasabah.csUsers.employee')}>{text(user.EmployeeId) || '–'}</Fact>
          <Fact label={t('nasabah.csUsers.email')}>{text(user.Email) || '–'}</Fact>
          <Fact label={t('nasabah.csUsers.lastLogin')}>
            {text(user.LastLogin) ? legacyStamp(user.LastLogin) : t('nasabah.csUsers.never')}
          </Fact>
          <Fact label={t('nasabah.csUsers.created')}>{stamp(user.Created, user.CreatedBy)}</Fact>
          {text(user.LastModified) ? (
            <Fact label={t('nasabah.csUsers.modified')}>{stamp(user.LastModified, user.ModifiedBy)}</Fact>
          ) : null}
        </dl>
        <div className="flex flex-wrap gap-2 border-b px-5 py-3">
          <Button variant="outline" size="sm" disabled={technical} onClick={onEdit}>
            <PencilIcon />
            {t('nasabah.csUsers.edit')}
          </Button>
          <Button variant="outline" size="sm" disabled={technical} onClick={onPassword}>
            <KeyRoundIcon />
            {t('nasabah.csUsers.password')}
          </Button>
          <Button variant="outline" size="sm" disabled={technical} onClick={() => setConfirming(true)}>
            <Trash2Icon />
            {t('nasabah.csUsers.remove')}
          </Button>
          <p className="w-full text-xs text-muted-foreground">
            {technical
              ? t('nasabah.csUsers.technicalNote')
              : actor
                ? t('nasabah.csUsers.actorNote', { actor })
                : null}
          </p>
        </div>
        <section className="flex flex-col gap-2 px-5 py-4" aria-labelledby="cs-flags-title">
          <h3 id="cs-flags-title" className="text-row font-semibold">
            {t('nasabah.csUsers.flags')}
          </h3>
          <ul className="grid gap-1.5 sm:grid-cols-2">
            {csFlags.map((flag) => {
              const on = (user.Permissions & (1 << flag.bit)) !== 0
              return (
                <li
                  key={flag.key}
                  className={cn('flex items-center gap-2 text-row', !on && 'text-muted-foreground')}
                >
                  {on ? (
                    <CheckIcon className="size-4 text-success" aria-hidden="true" />
                  ) : (
                    <MinusIcon className="size-4" aria-hidden="true" />
                  )}
                  <span>
                    {label.csFlag(flag.key)}
                    <span className="sr-only">
                      {' '}
                      ({on ? t('nasabah.csUsers.flagOn') : t('nasabah.csUsers.flagOff')})
                    </span>
                  </span>
                </li>
              )
            })}
          </ul>
        </section>
      </div>
      <Confirm
        open={confirming}
        title={t('nasabah.csUsers.confirm.removeTitle', { loginId })}
        body={t('nasabah.csUsers.confirm.removeBody')}
        action={t('nasabah.csUsers.remove')}
        destructive
        pending={remove.isPending}
        onConfirm={() =>
          remove.mutate(loginId, {
            onSuccess: () => {
              toast.success(t('nasabah.csUsers.toast.removed', { loginId }))
              setConfirming(false)
              onClose()
            },
            onError: (error) => {
              toast.error(errorText(error))
              setConfirming(false)
            },
          })
        }
        onClose={() => setConfirming(false)}
      />
    </div>
  )
}

export function CsUserPanel({
  user,
  technical,
  actor,
  onEdit,
  onPassword,
  onClose,
}: {
  user: CsUser | null
  technical: boolean
  actor: string | undefined
  onEdit: () => void
  onPassword: () => void
  onClose: () => void
}) {
  const { t } = useTranslation()
  return (
    <Sheet open={user !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('nasabah.tabs.cs_users')}
        closeLabel={t('app.close')}
        className="w-[min(560px,100vw)] bg-background"
      >
        {user ? (
          <CsUserBody
            key={user.LoginId}
            user={user}
            technical={technical}
            actor={actor}
            onEdit={onEdit}
            onPassword={onPassword}
            onClose={onClose}
          />
        ) : null}
      </SheetContent>
    </Sheet>
  )
}
