import { CheckIcon, XIcon } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Sheet, SheetContent } from '@/components/ui/overlay'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useAgent } from '@/features/auth/hooks'
import { errorText } from '@/lib/error-text'
import { cn } from '@/lib/utils'

import { useApprovalLinks, useDecideApproval, useLinkedAccounts } from '../hooks'
import { legacyStamp, useNasabahLabels } from '../labels'
import { canDecide, flagsOf, has, isSelfSubmitted } from '../logic'
import type { Approval, LinkedAccount } from '../types'
import { Confirm } from './confirm'

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex min-w-0 flex-col gap-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-row break-words">{children || '–'}</dd>
    </div>
  )
}

function Accounts({
  title,
  rows,
  error,
  loading,
  empty,
  onRetry,
  action,
}: {
  title: string
  rows: (LinkedAccount & { ActionType?: number })[]
  error: unknown
  loading: boolean
  empty: string
  onRetry: () => void
  action?: (value: number) => string
}) {
  const { t } = useTranslation()
  return (
    <section className="flex flex-col gap-2">
      <h3 className="text-row font-semibold">{title}</h3>
      {error ? (
        <ErrorState error={error} onRetry={onRetry} />
      ) : loading ? (
        <ListSkeleton rows={2} />
      ) : rows.length === 0 ? (
        <p className="text-row text-muted-foreground">{empty}</p>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('nasabah.detail.colAccount')}</TableHead>
              <TableHead>{t('nasabah.detail.colName')}</TableHead>
              {action ? <TableHead>{t('nasabah.approvals.colAction')}</TableHead> : null}
              <TableHead>{t('nasabah.detail.colLinkedBy')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.map((row) => (
              <TableRow key={`${row.AccountId}-${row.ActionType ?? ''}`}>
                <TableCell className="font-mono text-xs">{row.AccountId}</TableCell>
                <TableCell className="max-w-56 truncate">{row.AccountName || '–'}</TableCell>
                {action ? (
                  <TableCell
                    className={cn(
                      'text-xs font-medium',
                      row.ActionType === 2 ? 'text-danger' : 'text-success',
                    )}
                  >
                    {action(row.ActionType ?? 0)}
                  </TableCell>
                ) : null}
                <TableCell className="text-xs text-muted-foreground">{row.CreatedBy || '–'}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </section>
  )
}

function ApprovalBody({ approval, onClose }: { approval: Approval; onClose: () => void }) {
  const { t } = useTranslation()
  const agent = useAgent()
  const label = useNasabahLabels()
  const changes = useApprovalLinks(approval.ApprovalId)
  const current = useLinkedAccounts(approval.ActionType === 1 ? undefined : approval.LoginId)
  const decide = useDecideApproval()
  const [decision, setDecision] = useState<'approve' | 'reject' | null>(null)
  const perms = agent.nasabah_permissions
  const allowed = canDecide(perms, approval, agent.agent_code)
  const own = isSelfSubmitted(approval, agent.agent_code)
  const blocked =
    approval.Status === 1 && !allowed && has(perms, 'online_user.approve', 'online_user.approve_own')
  const flags = flagsOf(approval.Permissions)

  return (
    <div className="flex h-full min-h-0 flex-col">
      <header className="flex flex-col gap-1 border-b px-5 pt-4 pr-12 pb-3">
        <h2 className="text-panel font-semibold">
          {t('nasabah.approvals.detailTitle', { id: approval.ApprovalId })}
        </h2>
        <p className="text-row text-muted-foreground">
          {label.action(approval.ActionType)} · <span className="font-mono">{approval.LoginId}</span> ·{' '}
          {label.approvalStatus(approval.Status)}
        </p>
      </header>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <dl className="grid gap-x-6 gap-y-3 border-b px-5 py-4 sm:grid-cols-2">
          <Fact label={t('nasabah.form.loginType')}>{label.loginType(approval.LoginType)}</Fact>
          <Fact label={t('nasabah.detail.email')}>{approval.Email}</Fact>
          <Fact label={t('nasabah.detail.phone')}>{approval.PhoneNumber}</Fact>
          <Fact label={t('nasabah.detail.birthDate')}>{legacyStamp(approval.BirthDate, 'd MMM yyyy')}</Fact>
          {approval.SalesId ? <Fact label={t('nasabah.detail.salesId')}>{approval.SalesId}</Fact> : null}
          {approval.AccountExpired ? (
            <Fact label={t('nasabah.detail.expired')}>{legacyStamp(approval.AccountExpired)}</Fact>
          ) : null}
          <Fact label={t('nasabah.detail.flags')}>{label.flagList(flags)}</Fact>
          <Fact label={t('nasabah.approvals.colSubmitter')}>
            {approval.CreatedBy} · {legacyStamp(approval.Created)}
          </Fact>
          {approval.ApprovedBy ? (
            <Fact label={t('nasabah.approvals.colDecision')}>
              {approval.ApprovedBy} · {legacyStamp(approval.Approved)}
            </Fact>
          ) : null}
        </dl>
        {allowed || blocked ? (
          <div className="flex flex-wrap items-center gap-2 border-b px-5 py-3">
            <Button size="sm" disabled={!allowed} onClick={() => setDecision('approve')}>
              <CheckIcon />
              {t('nasabah.approvals.approve')}
            </Button>
            <Button size="sm" variant="outline" disabled={!allowed} onClick={() => setDecision('reject')}>
              <XIcon />
              {t('nasabah.approvals.reject')}
            </Button>
            {blocked ? (
              <p className="w-full text-xs text-muted-foreground">
                {own ? t('nasabah.approvals.selfNote') : t('nasabah.approvals.othersNote')}
              </p>
            ) : null}
          </div>
        ) : null}
        <div className="flex flex-col gap-5 px-5 py-4">
          <Accounts
            title={t('nasabah.approvals.changes')}
            rows={changes.data ?? []}
            error={changes.isError ? changes.error : null}
            loading={!changes.data}
            empty={t('nasabah.approvals.changesEmpty')}
            onRetry={() => void changes.refetch()}
            action={(value) =>
              value === 2 ? t('nasabah.approvals.unlinkAction') : t('nasabah.approvals.linkAction')
            }
          />
          {approval.ActionType !== 1 ? (
            <Accounts
              title={t('nasabah.approvals.currentLinks')}
              rows={current.data ?? []}
              error={current.isError ? current.error : null}
              loading={!current.data}
              empty={t('nasabah.detail.linkedEmpty')}
              onRetry={() => void current.refetch()}
            />
          ) : null}
        </div>
      </div>
      <Confirm
        open={decision !== null}
        title={
          decision === 'approve'
            ? t('nasabah.approvals.approveTitle', { id: approval.ApprovalId })
            : t('nasabah.approvals.rejectTitle', { id: approval.ApprovalId })
        }
        body={decision === 'approve' ? t('nasabah.approvals.approveBody') : t('nasabah.approvals.rejectBody')}
        action={decision === 'approve' ? t('nasabah.approvals.approve') : t('nasabah.approvals.reject')}
        destructive={decision === 'reject'}
        pending={decide.isPending}
        onConfirm={() => {
          const approve = decision === 'approve'
          decide.mutate(
            { approval, approve },
            {
              onSuccess: () => {
                toast.success(approve ? t('nasabah.toast.approved') : t('nasabah.toast.rejected'))
                setDecision(null)
                onClose()
              },
              onError: (error) => {
                toast.error(errorText(error))
                setDecision(null)
              },
            },
          )
        }}
        onClose={() => setDecision(null)}
      />
    </div>
  )
}

export function ApprovalPanel({ approval, onClose }: { approval: Approval | null; onClose: () => void }) {
  const { t } = useTranslation()
  return (
    <Sheet open={approval !== null} onOpenChange={(open) => !open && onClose()}>
      <SheetContent
        title={t('nasabah.tabs.approvals')}
        closeLabel={t('app.close')}
        className="w-[min(680px,100vw)] bg-background"
      >
        {approval ? <ApprovalBody key={approval.ApprovalId} approval={approval} onClose={onClose} /> : null}
      </SheetContent>
    </Sheet>
  )
}
