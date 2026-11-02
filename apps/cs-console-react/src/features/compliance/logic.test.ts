import { describe, expect, it } from 'vitest'

import type { ChatMessage } from '@/features/conversation/types'

import {
  actionKey,
  auditCsv,
  caseAttention,
  casePresetRange,
  casesCsv,
  deadlineTone,
  detailsText,
  onTimePercent,
  policyDraftProblem,
  rangeFileSuffix,
  sha256Hex,
  transcriptFileName,
  transcriptText,
} from './logic'
import type { AuditEntry, CaseRow } from './types'

const row = (overrides: Partial<CaseRow> = {}): CaseRow => ({
  id: 't1',
  ticket_number: 'CS-20261031-0001',
  room_id: 'r1',
  version: 3,
  status: 'resolved',
  priority: 'P2',
  flags: ['complaint'],
  topic: 'account',
  topic_name: 'Akun',
  language: 'id',
  fake_cs: false,
  customer: { id: 'c1', display_name: 'Budi', username: 'budi' },
  agent: { id: 'a1', display_name: 'Rina', agent_code: 'CS-0045' },
  created_at: '2026-10-30T02:00:00Z',
  complaint_received_at: '2026-10-30T02:05:00Z',
  complaint_due_at: '2026-11-06T16:59:59Z',
  complaint_extended_at: null,
  resolved_at: '2026-11-07T03:00:00Z',
  closed_at: null,
  outcome: 'complaint',
  rating: null,
  deadline: { state: 'missed', business_days: 1 },
  review: { verdict: 'violation', note: 'Terlambat', created_at: '2026-11-08T01:00:00Z', reviewer: 'Kirana' },
  ...overrides,
})

const message = (overrides: Partial<ChatMessage>): ChatMessage => ({
  id: 'm',
  room_id: 'r1',
  sender_id: 'c1',
  sender_username: 'budi',
  sender_display_name: 'Budi',
  body: 'Halo',
  is_deleted: false,
  reply_to_id: null,
  reply_to_body: null,
  reply_to_sender_username: null,
  attachments: [],
  client_id: null,
  created_at: '2026-10-30T02:00:00Z',
  cursor: 'c',
  kind: 'text',
  payload: {},
  session_id: 't1',
  sender_role: 'customer',
  ...overrides,
})

describe('compliance logic', () => {
  it('maps deadline states to tones and counts cases needing attention', () => {
    expect(['running', 'due_soon', 'overdue', 'met', 'missed'].map((s) => deadlineTone(s as never))).toEqual([
      'ok',
      'warn',
      'late',
      'ok',
      'late',
    ])
    expect(caseAttention({ overdue: 2, due_soon: 3 })).toBe(5)
    expect(caseAttention(undefined)).toBe(0)
  })

  it('reports on-time share only when complaints finished', () => {
    expect(onTimePercent({ met: 0, total: 0 })).toBeNull()
    expect(onTimePercent({ met: 2, total: 3 })).toBe(67)
  })

  it('builds preset periods in Jakarta calendar days', () => {
    const today = new Date(2026, 9, 31)
    expect(casePresetRange('all', today)).toBeNull()
    expect(casePresetRange('month', today)).toEqual({ from: '2026-10-02', to: '2026-10-31' })
    expect(casePresetRange('quarter', today)).toEqual({ from: '2026-10-01', to: '2026-10-31' })
    expect(casePresetRange('year', today)).toEqual({ from: '2026-01-01', to: '2026-10-31' })
    expect(rangeFileSuffix(null, today)).toBe('semua-2026-10-31')
    expect(rangeFileSuffix({ from: '2026-10-01', to: '2026-10-31' }, today)).toBe('2026-10-01-2026-10-31')
  })

  it('labels only known audit actions', () => {
    expect(actionKey('ticket.transfer_accept')).toBe('compliance.actions.ticket_transfer_accept')
    expect(actionKey('compliance.review')).toBe('compliance.actions.compliance_review')
    expect(actionKey('something.new')).toBeNull()
  })

  it('formats timestamps inside audit details when a formatter is given', () => {
    expect(
      detailsText(
        { from: '2026-11-09T16:59:59.999999+00:00', days: 10 },
        (value) => `<${value.slice(0, 10)}>`,
      ),
    ).toBe('from: <2026-11-09> · days: 10')
  })

  it('renders audit details compactly without empty values', () => {
    expect(
      detailsText({ key: 'assignment.mode', reason: null, flags: [], extra: {}, tags: ['a'], count: 2 }),
    ).toBe('key: assignment.mode · tags: ["a"] · count: 2')
  })

  it('shows field changes in audit details as old and new values', () => {
    expect(
      detailsText({
        username: 'olt_research',
        changes: {
          display_name: { from: 'OLT Research', to: 'OLT Riset' },
          bio: { from: null, to: 'Riset' },
          avatar: 'added',
        },
      }),
    ).toBe(
      'username: olt_research · changes: display_name OLT Research → OLT Riset, bio – → Riset, avatar added',
    )
  })

  it('exports the complaint register with translated values and late days', () => {
    const csv = casesCsv(
      [row(), row({ id: 't2', deadline: { state: 'met', business_days: 0 }, review: null })],
      {
        header: (column) => column,
        kind: (item) => item.flags.join('+'),
        status: (status) => `status:${status}`,
        deadline: (state) => `deadline:${state}`,
        verdict: (verdict) => `verdict:${verdict}`,
        yes: 'ya',
      },
    )
    const lines = csv.replace('﻿', '').trimEnd().split('\r\n')
    expect(lines[0]).toBe(
      'ticket,customer,username,kind,fakeCs,topic,status,agent,agentCode,created,received,due,extended,finished,deadline,lateDays,outcome,review,reviewer,reviewedAt',
    )
    expect(lines[1]).toBe(
      'CS-20261031-0001,Budi,budi,complaint,,Akun,status:resolved,Rina,CS-0045,2026-10-30 09:00,2026-10-30 09:05,2026-11-06 23:59,,2026-11-07 10:00,deadline:missed,1,complaint,verdict:violation,Kirana,2026-11-08 08:00',
    )
    expect(lines[2]).toContain('deadline:met,,complaint,,,')
  })

  it('exports audit rows with actor codes and neutralized formulas', () => {
    const entry: AuditEntry = {
      id: 1,
      created_at: '2026-10-31T03:00:00Z',
      action: 'setting.update',
      actor_type: 'agent',
      actor_roles: ['cs_super_admin'],
      actor: { id: 'a', display_name: 'Sinta', agent_code: 'CS-0241' },
      ticket: null,
      customer: null,
      details: { key: '=cmd' },
    }
    const csv = auditCsv([entry], { header: (column) => column, action: () => 'Ubah pengaturan' })
    expect(csv.trimEnd().split('\r\n')[1]).toBe(
      '2026-10-31 10:00:00,Sinta,CS-0241,agent,Ubah pengaturan,setting.update,,,key: =cmd',
    )
  })

  it('writes a chronological transcript with notes and a stable SHA-256', async () => {
    const text = transcriptText(
      {
        notes: [
          {
            id: 'n1',
            session_id: 't1',
            kind: 'note',
            body: 'Cek mutasi',
            created_at: '2026-10-30T02:01:00Z',
            author: { display_name: 'Rina', agent_code: 'CS-0045' },
          },
        ],
      },
      [
        message({
          id: 'm2',
          created_at: '2026-10-30T02:02:00Z',
          sender_role: 'agent',
          sender_display_name: 'Rina',
          body: 'Baik',
        }),
        message({ id: 'm1', attachments: [{ path: 'rooms/r1/x.png' }] }),
        message({
          id: 'm3',
          created_at: '2026-10-30T02:03:00Z',
          sender_role: 'system',
          kind: 'system',
          body: 'Tiket ditutup',
        }),
      ],
      {
        title: 'TRANSKRIP CS-20261031-0001',
        fields: [
          { label: 'Nasabah', value: 'Budi' },
          { label: 'Tenggat', value: null },
        ],
        customer: 'Nasabah',
        agent: 'CS',
        system: 'Sistem',
        note: 'Catatan internal',
        attachment: 'lampiran',
        deleted: '(dihapus)',
      },
    )
    expect(text.split('\n')).toEqual([
      'TRANSKRIP CS-20261031-0001',
      'Nasabah : Budi',
      'Tenggat : –',
      '-'.repeat(60),
      '[2026-10-30 09:00:00 WIB] Budi (Nasabah): Halo [lampiran: 1]',
      '[2026-10-30 09:01:00 WIB] Catatan internal – Rina: Cek mutasi',
      '[2026-10-30 09:02:00 WIB] Rina (CS): Baik',
      '[2026-10-30 09:03:00 WIB] Sistem: Tiket ditutup',
      '',
    ])
    expect(await sha256Hex('abc')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
    expect(transcriptFileName('CS-20261031-0001', 'ba7816bf8f01cfea414140de')).toBe(
      'transkrip-CS-20261031-0001-ba7816bf8f01.txt',
    )
  })

  it('validates policy drafts against the allowed range', () => {
    expect(policyDraftProblem('5', 1, 20)).toBeNull()
    expect(policyDraftProblem('0', 1, 20)).toBe('outOfRange')
    expect(policyDraftProblem('2.5', 1, 20)).toBe('invalid')
    expect(policyDraftProblem('', 1, 20)).toBe('invalid')
  })
})
