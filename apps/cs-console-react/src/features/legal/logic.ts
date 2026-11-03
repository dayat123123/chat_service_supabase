import type { WaitTone } from '@/lib/sla'
import { format } from '@/lib/time'

import {
  LEGAL_BODY_MAX,
  LEGAL_BODY_MIN,
  LEGAL_NOTE_MAX,
  LEGAL_NOTE_MIN,
  LEGAL_SUMMARY_MAX,
  LEGAL_TITLE_MAX,
  LEGAL_TITLE_MIN,
  legalKinds,
  type DraftInput,
  type DraftStatus,
  type LegalDocument,
  type LegalDraft,
  type LegalKind,
} from './types'

const wibInput = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/

export function wibInputToIso(value: string): string | null {
  const match = wibInput.exec(value.trim())
  if (!match) return null
  const time = Date.parse(`${value.trim()}:00+07:00`)
  if (Number.isNaN(time)) return null
  const iso = new Date(time).toISOString()
  return isoToWibInput(iso) === value.trim() ? iso : null
}

export function isoToWibInput(iso: string) {
  return format(iso, "yyyy-MM-dd'T'HH:mm")
}

export type DraftField = 'title' | 'body' | 'changeSummary' | 'effectiveAt'
export type DraftProblem = 'length' | 'invalid' | 'past'

export function draftProblems(
  input: Pick<DraftInput, 'title' | 'body' | 'changeSummary'> & { effectiveInput: string },
  now: Date = new Date(),
): Partial<Record<DraftField, DraftProblem>> {
  const problems: Partial<Record<DraftField, DraftProblem>> = {}
  const title = input.title.trim().length
  if (title < LEGAL_TITLE_MIN || title > LEGAL_TITLE_MAX) problems.title = 'length'
  const body = input.body.trim().length
  if (body < LEGAL_BODY_MIN || body > LEGAL_BODY_MAX) problems.body = 'length'
  if (input.changeSummary.trim().length > LEGAL_SUMMARY_MAX) problems.changeSummary = 'length'
  if (input.effectiveInput.trim()) {
    const iso = wibInputToIso(input.effectiveInput)
    if (!iso) problems.effectiveAt = 'invalid'
    else if (Date.parse(iso) <= now.getTime()) problems.effectiveAt = 'past'
  }
  return problems
}

export function validNote(note: string) {
  const length = note.trim().length
  return length >= LEGAL_NOTE_MIN && length <= LEGAL_NOTE_MAX
}

export function acceptanceRatio(accepted: number, activeUsers: number) {
  if (activeUsers <= 0) return null
  return Math.min(1, Math.max(0, accepted / activeUsers))
}

const statusTones: Record<DraftStatus, WaitTone | 'neutral'> = {
  draft: 'neutral',
  pending: 'warn',
  rejected: 'late',
  published: 'ok',
}

export function draftTone(status: DraftStatus) {
  return statusTones[status]
}

export function isAuthor(draft: Pick<LegalDraft, 'created_by_id' | 'updated_by_id' | 'submitted_by_id'>, me: string) {
  return draft.created_by_id === me || draft.updated_by_id === me || draft.submitted_by_id === me
}

export type ApproveState = 'allowed' | 'self' | 'blocked' | 'hidden'

export type DraftActions = {
  edit: boolean
  submit: boolean
  remove: boolean
  withdraw: boolean
  reject: boolean
  approve: ApproveState
}

export function draftActions(
  draft: Pick<LegalDraft, 'status' | 'created_by_id' | 'updated_by_id' | 'submitted_by_id'>,
  me: string,
  fourEyes: boolean,
): DraftActions {
  const open = draft.status === 'draft' || draft.status === 'rejected'
  const pending = draft.status === 'pending'
  const mine = isAuthor(draft, me)
  return {
    edit: open,
    submit: open,
    remove: open,
    withdraw: pending,
    reject: pending && !mine,
    approve: !pending ? 'hidden' : !mine ? 'allowed' : fourEyes ? 'blocked' : 'self',
  }
}

export function toggleRequired(current: readonly LegalKind[], kind: LegalKind, required: boolean) {
  const next = new Set(current)
  if (required) next.add(kind)
  else next.delete(kind)
  return legalKinds.filter((item) => next.has(item))
}

export function draftFromDocument(document: LegalDocument): Omit<DraftInput, 'id'> {
  return {
    kind: document.kind,
    title: document.title,
    body: document.body ?? '',
    changeSummary: '',
    effectiveAt: null,
  }
}

export function sortDrafts(drafts: LegalDraft[]) {
  const rank: Record<DraftStatus, number> = { pending: 0, rejected: 1, draft: 2, published: 3 }
  return [...drafts].sort(
    (a, b) => rank[a.status] - rank[b.status] || Date.parse(b.updated_at) - Date.parse(a.updated_at),
  )
}

export function bodyLines(body: string) {
  return body.replace(/\r\n?/g, '\n')
}

export const wibStamp = (value: string) => `${format(value, 'd MMM yyyy, HH.mm')} WIB`
