import { Link } from '@tanstack/react-router'
import { ArrowUpRightIcon, CheckCircle2Icon, ShieldQuestionIcon } from 'lucide-react'
import { useId, useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState } from '@/components/states'
import { Button } from '@/components/ui/button'
import { AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/controls'
import { Skeleton } from '@/components/ui/primitives'
import { useAgent } from '@/features/auth/hooks'
import { toApiError } from '@/lib/errors'
import { cn } from '@/lib/utils'

import { useOnlineUserProfile, useTicketLogin } from '../hooks'
import { legacyStamp, useNasabahLabels } from '../labels'
import { canViewProfiles, flagsOf } from '../logic'
import type { OnlineUserProfile, ProfileAccount } from '../types'

const VISIBLE_ACCOUNTS = 4

const statusTone: Record<number, string> = {
  0: 'border-border text-muted-foreground',
  1: 'border-success/40 text-success',
  2: 'border-warning/40 text-warning',
  3: 'border-danger/40 text-danger',
}

function Loading() {
  return (
    <div className="flex flex-col gap-2.5 py-1" aria-busy="true">
      <Skeleton className="h-2 w-1/2" />
      <Skeleton className="h-2 w-3/4" />
      <Skeleton className="h-2 w-2/3" />
    </div>
  )
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="grid grid-cols-[7.5rem_minmax(0,1fr)] gap-2 py-1">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="min-w-0 text-row break-words">{children}</dd>
    </div>
  )
}

function Verified({ ok }: { ok: boolean }) {
  const { t } = useTranslation()
  return ok ? (
    <CheckCircle2Icon
      className="ml-1 inline size-3.5 align-[-2px] text-success"
      aria-label={t('nasabah.detail.verified')}
    />
  ) : (
    <ShieldQuestionIcon
      className="ml-1 inline size-3.5 align-[-2px] text-muted-foreground"
      aria-label={t('nasabah.detail.unverified')}
    />
  )
}

function Accounts({ accounts }: { accounts: ProfileAccount[] }) {
  const { t } = useTranslation()
  const titleId = useId()
  const [all, setAll] = useState(false)
  const shown = all ? accounts : accounts.slice(0, VISIBLE_ACCOUNTS)
  return (
    <div className="flex flex-col gap-1 pt-2">
      <h4 id={titleId} className="text-xs font-medium text-muted-foreground">
        {t('customer.accountLinked', { count: accounts.length })}
      </h4>
      {accounts.length === 0 ? (
        <p className="text-row text-muted-foreground">{t('customer.accountNoLinked')}</p>
      ) : (
        <ul aria-labelledby={titleId} className="divide-y rounded-md border bg-background">
          {shown.map((account) => {
            const extra = [
              account.RDNAccount
                ? t('customer.accountRdn', { bank: account.RDNBank, account: account.RDNAccount })
                : '',
              account.InvestorNo ? t('customer.accountSid', { sid: account.InvestorNo }) : '',
            ].filter(Boolean)
            return (
              <li key={account.AccountId} className="flex flex-col gap-0.5 px-2.5 py-2">
                <div className="flex items-baseline gap-2">
                  <span className="font-mono text-xs">{account.AccountId}</span>
                  <span className="min-w-0 flex-1 truncate text-row">{account.AccountName || '–'}</span>
                  {account.Branch ? (
                    <span className="text-xs text-muted-foreground">{account.Branch}</span>
                  ) : null}
                </div>
                {extra.length > 0 ? (
                  <span className="tabular truncate text-xs text-muted-foreground">{extra.join(' · ')}</span>
                ) : null}
              </li>
            )
          })}
        </ul>
      )}
      {accounts.length > VISIBLE_ACCOUNTS ? (
        <Button variant="ghost" size="xs" className="self-start" onClick={() => setAll((value) => !value)}>
          {all ? t('customer.accountShowLess') : t('customer.accountShowAll', { count: accounts.length })}
        </Button>
      ) : null}
    </div>
  )
}

function Profile({ profile }: { profile: OnlineUserProfile }) {
  const { t } = useTranslation()
  const label = useNasabahLabels()
  const flags = flagsOf(profile.Permissions)
  return (
    <section
      aria-label={t('customer.accountOf', { loginId: profile.LoginId })}
      className="flex flex-col gap-1 pb-2"
    >
      <div className="flex flex-wrap items-center gap-2">
        <span className="font-mono text-row font-medium">{profile.LoginId}</span>
        <span className="text-xs text-muted-foreground">{label.loginType(profile.LoginType)}</span>
        <span
          className={cn(
            'rounded-sm border px-1.5 py-px text-xs font-medium',
            statusTone[profile.Status] ?? statusTone[0],
          )}
        >
          {label.status(profile.Status)}
        </span>
        <Link
          to="/nasabah"
          search={{ q: profile.LoginId }}
          className="ml-auto inline-flex items-center gap-1 rounded-sm text-xs text-muted-foreground outline-none hover:text-foreground focus-visible:ring-2 focus-visible:ring-ring/50"
        >
          {t('customer.accountOpen')}
          <ArrowUpRightIcon className="size-3.5" aria-hidden="true" />
        </Link>
      </div>
      <dl className="flex flex-col">
        <Row label={t('nasabah.detail.email')}>
          {profile.Email || '–'}
          {profile.Email ? <Verified ok={profile.IsEmailApproved === 1} /> : null}
        </Row>
        <Row label={t('nasabah.detail.phone')}>
          {profile.PhoneNumber || '–'}
          {profile.PhoneNumber ? <Verified ok={profile.IsPhoneNumberApproved === 1} /> : null}
        </Row>
        <Row label={t('nasabah.detail.birthDate')}>{legacyStamp(profile.BirthDate, 'd MMM yyyy')}</Row>
        {profile.SalesId ? <Row label={t('nasabah.detail.salesId')}>{profile.SalesId}</Row> : null}
        <Row label={t('nasabah.detail.created')}>{legacyStamp(profile.Created, 'd MMM yyyy')}</Row>
        <Row label={t('nasabah.detail.retries')}>
          {t('nasabah.detail.retryValue', { password: profile.ErrorPwdRetry, pin: profile.ErrorPinRetry })}
        </Row>
        <Row label={t('nasabah.detail.flags')}>{label.flagList(flags)}</Row>
      </dl>
      <Accounts accounts={profile.Accounts ?? []} />
    </section>
  )
}

export function CustomerAccount({ ticketId }: { ticketId: string }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const allowed = canViewProfiles(agent.nasabah_permissions)
  const login = useTicketLogin(ticketId, allowed)
  const loginId = login.data?.login_id
  const profile = useOnlineUserProfile(allowed ? loginId : undefined)

  if (!allowed || (profile.isError && toApiError(profile.error).status === 404)) return null
  return (
    <AccordionItem value="account">
      <AccordionTrigger>{t('customer.account')}</AccordionTrigger>
      <AccordionContent>
        {login.isError ? (
          <ErrorState error={login.error} onRetry={() => void login.refetch()} />
        ) : !loginId || profile.isPending ? (
          <Loading />
        ) : profile.isError ? (
          <ErrorState error={profile.error} onRetry={() => void profile.refetch()} />
        ) : (
          <Profile profile={profile.data} />
        )}
      </AccordionContent>
    </AccordionItem>
  )
}
