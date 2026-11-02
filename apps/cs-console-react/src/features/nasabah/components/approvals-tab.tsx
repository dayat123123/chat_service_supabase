import { SearchIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { ErrorState, ListSkeleton } from '@/components/states'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  ToggleGroup,
  ToggleGroupItem,
} from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useDebounced } from '@/hooks/use-now'
import { cn } from '@/lib/utils'

import { useApprovals } from '../hooks'
import { legacyStamp, useNasabahLabels } from '../labels'
import {
  approvalActions,
  approvalStatuses,
  type Approval,
  type ApprovalAction,
  type ApprovalFilter,
  type ApprovalStatus,
} from '../types'
import { ApprovalPanel } from './approval-panel'
import { Pager } from './pager'

const ALL = '-1'

const statusTone: Record<number, string> = {
  1: 'text-warning',
  2: 'text-success',
  0: 'text-danger',
  3: 'text-danger',
}

export function ApprovalsTab() {
  const { t } = useTranslation()
  const label = useNasabahLabels()
  const [page, setPage] = useState(1)
  const [status, setStatus] = useState<ApprovalStatus | -1>(1)
  const [action, setAction] = useState<ApprovalAction | -1>(-1)
  const [loginId, setLoginId] = useState('')
  const [submitter, setSubmitter] = useState('')
  const [selected, setSelected] = useState<Approval | null>(null)
  const debouncedLogin = useDebounced(loginId.trim(), 300)
  const debouncedSubmitter = useDebounced(submitter.trim(), 300)
  const filter: ApprovalFilter = { status, action, query: debouncedLogin }
  const approvals = useApprovals(page, filter, debouncedSubmitter, true)
  const rows = approvals.data?.rows ?? []
  const reset =
    <T,>(apply: (value: T) => void) =>
    (value: T) => {
      apply(value)
      setPage(1)
    }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <ToggleGroup
          type="single"
          value={String(status)}
          onValueChange={(value) => value && reset(setStatus)(Number(value) as ApprovalStatus | -1)}
          aria-label={t('nasabah.approvals.statusLabel')}
        >
          {approvalStatuses.map((value) => (
            <ToggleGroupItem key={value} value={String(value)}>
              {label.approvalStatus(value)}
            </ToggleGroupItem>
          ))}
          <ToggleGroupItem value={ALL}>{t('nasabah.approvalStatus.all')}</ToggleGroupItem>
        </ToggleGroup>
        <Select
          value={String(action)}
          onValueChange={(value) => reset(setAction)(Number(value) as ApprovalAction | -1)}
        >
          <SelectTrigger className="h-8 w-40" aria-label={t('nasabah.approvals.actionLabel')}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={ALL}>{t('nasabah.approvals.allActions')}</SelectItem>
            {approvalActions.map((value) => (
              <SelectItem key={value} value={String(value)}>
                {label.action(value)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <div className="relative w-full sm:w-52">
          <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
          <Input
            type="search"
            value={loginId}
            placeholder={t('nasabah.approvals.searchLoginId')}
            aria-label={t('nasabah.approvals.searchLoginId')}
            className="h-8 pl-8"
            onChange={(event) => reset(setLoginId)(event.target.value)}
          />
        </div>
        <Input
          type="search"
          value={submitter}
          placeholder={t('nasabah.approvals.searchSubmitter')}
          aria-label={t('nasabah.approvals.searchSubmitter')}
          className="h-8 w-full sm:w-44"
          onChange={(event) => reset(setSubmitter)(event.target.value)}
        />
      </div>
      {approvals.data ? (
        <div
          className={cn(
            'flex flex-col gap-3 transition-opacity',
            approvals.isPlaceholderData && 'opacity-60',
          )}
        >
          {rows.length > 0 ? (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('nasabah.approvals.colId')}</TableHead>
                  <TableHead>{t('nasabah.approvals.colLoginId')}</TableHead>
                  <TableHead>{t('nasabah.approvals.colAction')}</TableHead>
                  <TableHead>{t('nasabah.approvals.colType')}</TableHead>
                  <TableHead>{t('nasabah.approvals.colSubmitter')}</TableHead>
                  <TableHead>{t('nasabah.approvals.colSubmitted')}</TableHead>
                  <TableHead>{t('nasabah.approvals.colStatus')}</TableHead>
                  <TableHead>{t('nasabah.approvals.colDecision')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.map((approval) => (
                  <TableRow
                    key={approval.ApprovalId}
                    className="cursor-pointer"
                    onClick={() => setSelected(approval)}
                  >
                    <TableCell>
                      <button
                        type="button"
                        className="tabular rounded-sm text-xs outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
                        aria-label={t('nasabah.approvals.open', { id: approval.ApprovalId })}
                        onClick={(event) => {
                          event.stopPropagation()
                          setSelected(approval)
                        }}
                      >
                        #{approval.ApprovalId}
                      </button>
                    </TableCell>
                    <TableCell className="font-mono text-xs">{approval.LoginId}</TableCell>
                    <TableCell>{label.action(approval.ActionType)}</TableCell>
                    <TableCell>{label.loginType(approval.LoginType)}</TableCell>
                    <TableCell>{approval.CreatedBy || '–'}</TableCell>
                    <TableCell className="text-xs text-muted-foreground">
                      {legacyStamp(approval.Created)}
                    </TableCell>
                    <TableCell className={cn('text-xs font-medium', statusTone[approval.Status])}>
                      {label.approvalStatus(approval.Status)}
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground">
                      {approval.ApprovedBy
                        ? `${approval.ApprovedBy} · ${legacyStamp(approval.Approved)}`
                        : '–'}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          ) : (
            <p className="border-y py-6 text-center text-row text-muted-foreground">
              {t('nasabah.approvals.empty')}
            </p>
          )}
          <Pager
            page={approvals.data.page}
            totalPages={approvals.data.totalPages}
            summary={t('nasabah.approvals.count', { count: approvals.data.total })}
            onPage={setPage}
          />
        </div>
      ) : approvals.isError ? (
        <ErrorState error={approvals.error} onRetry={() => void approvals.refetch()} />
      ) : (
        <ListSkeleton rows={6} />
      )}
      <ApprovalPanel approval={selected} onClose={() => setSelected(null)} />
    </div>
  )
}
