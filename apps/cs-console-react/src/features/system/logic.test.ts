import { describe, expect, it } from 'vitest'

import {
  badgeView,
  emailProblems,
  evaluationStale,
  instanceState,
  optionsProblems,
  parseList,
  parsePort,
  passwordMode,
  recoveredUntil,
  repositoryDisk,
  runDuration,
  scheduleProblems,
  sentinelLive,
  stagingDisk,
  targetKindOf,
  targetProblems,
  telegramProblems,
  usageTone,
} from './logic'
import type { BackupScheduleInput, BackupTargetInput, EmailInput } from './types'

const saved = {
  endpoint: 'https://s3.example.co.id',
  bucket: 'olt-backup',
  prefix: 'prod',
  password_set: true,
  secret_set: true,
}

const target = (overrides: Partial<BackupTargetInput> = {}): BackupTargetInput => ({
  kind: 's3',
  endpoint: 'https://s3.example.co.id/',
  bucket: 'OLT-Backup',
  prefix: '/prod/',
  region: '',
  accessKeyId: 'AKIA123',
  secretAccessKey: '',
  password: '',
  ...overrides,
})

describe('status derivation', () => {
  it('marks disks at 80% as warning and 90% as critical', () => {
    expect(usageTone(0.79)).toBe('ok')
    expect(usageTone(0.8)).toBe('warn')
    expect(usageTone(0.9)).toBe('late')
  })

  it('shows unhandled critical alerts before warnings in the badge', () => {
    expect(badgeView({ critical: 2, warning: 4, open: 6 })).toEqual({
      count: 2,
      tone: 'late',
      severity: 'critical',
    })
    expect(badgeView({ critical: 0, warning: 4, open: 4 })).toEqual({
      count: 4,
      tone: 'warn',
      severity: 'warning',
    })
    expect(badgeView({ critical: 0, warning: 0, open: 3 })).toBeNull()
    expect(badgeView(undefined)).toBeNull()
  })

  it('flags an alert evaluator that stopped running', () => {
    const now = new Date('2026-11-03T03:10:00.000Z')
    expect(evaluationStale('2026-11-03T03:09:00.000Z', now)).toBe(false)
    expect(evaluationStale('2026-11-03T03:05:00.000Z', now)).toBe(true)
    expect(evaluationStale(null, now)).toBe(true)
  })

  it('treats instances without a recent heartbeat as not running', () => {
    expect(instanceState({ live: true, status: 'degraded' })).toBe('degraded')
    expect(instanceState({ live: false, status: 'ok' })).toBe('stale')
  })

  it('knows whether the sentinel reports probes and disks', () => {
    const instance = {
      instance: 's',
      version: null,
      started_at: null,
      last_seen_at: '',
      status: 'ok' as const,
      error: null,
      detail: null,
    }
    expect(sentinelLive({ services: [] })).toBe(false)
    expect(
      sentinelLive({
        services: [{ service: 'sentinel', label: 'x', instances: [{ ...instance, live: false }] }],
      }),
    ).toBe(false)
    expect(
      sentinelLive({
        services: [{ service: 'sentinel', label: 'x', instances: [{ ...instance, live: true }] }],
      }),
    ).toBe(true)
  })
})

describe('backup target', () => {
  it('locks the encryption password while the repository location stays the same', () => {
    expect(passwordMode(saved, target())).toBe('locked')
    expect(passwordMode(saved, target({ prefix: 'prod-2' }))).toBe('new_repository')
    expect(passwordMode({ ...saved, password_set: false }, target())).toBe('first')
  })

  it('needs no secrets to rotate other fields of an existing repository', () => {
    expect(targetProblems(target(), { confirm: '', acknowledged: false }, saved)).toEqual({})
  })

  it('requires the password, a matching confirmation, and the acknowledgement for a new repository', () => {
    expect(targetProblems(target({ prefix: 'baru' }), { confirm: '', acknowledged: false }, saved)).toEqual({
      password: 'required',
      acknowledged: 'required',
    })
    expect(
      targetProblems(
        target({ prefix: 'baru', password: 'pendek' }),
        { confirm: 'pendek', acknowledged: true },
        saved,
      ),
    ).toEqual({ password: 'length' })
    expect(
      targetProblems(
        target({ prefix: 'baru', password: 'password-backup-panjang' }),
        { confirm: 'password-backup-lain', acknowledged: true },
        saved,
      ),
    ).toEqual({ confirm: 'mismatch' })
  })

  it('requires the secret access key the first time and validates the location like the server', () => {
    const fresh = { endpoint: null, bucket: null, prefix: null, password_set: false, secret_set: false }
    expect(
      targetProblems(
        target({ endpoint: 'ftp://s3', bucket: 'Bucket_Salah', prefix: 'a//b', region: 'ID JKT' }),
        { confirm: 'password-backup-panjang', acknowledged: true },
        { ...fresh },
      ),
    ).toMatchObject({
      endpoint: 'invalid',
      bucket: 'invalid',
      prefix: 'invalid',
      region: 'invalid',
      secretAccessKey: 'required',
      password: 'required',
      confirm: 'mismatch',
    })
  })
})

describe('local folder target', () => {
  const local = { ...target(), kind: 'local' as const, endpoint: '', bucket: '', accessKeyId: '' }
  const savedLocal = {
    kind: 'local' as const,
    endpoint: null,
    bucket: null,
    prefix: null,
    password_set: true,
    secret_set: false,
  }

  it('needs only the encryption password, not the S3 fields', () => {
    const fresh = { ...savedLocal, password_set: false }
    expect(targetProblems(local, { confirm: '', acknowledged: false }, fresh)).toEqual({
      password: 'required',
      acknowledged: 'required',
    })
    expect(
      targetProblems(
        { ...local, password: 'password-backup-panjang' },
        { confirm: 'password-backup-panjang', acknowledged: true },
        fresh,
      ),
    ).toEqual({})
  })

  it('locks the password of the same folder and treats a kind switch as a new repository', () => {
    expect(passwordMode(savedLocal, local)).toBe('locked')
    expect(targetProblems(local, { confirm: '', acknowledged: false }, savedLocal)).toEqual({})
    expect(passwordMode(saved, local)).toBe('new_repository')
    expect(passwordMode(savedLocal, target())).toBe('new_repository')
  })

  it('asks for the S3 secret again when moving from the local folder to S3', () => {
    expect(
      targetProblems(
        target({ password: 'password-backup-panjang' }),
        { confirm: 'password-backup-panjang', acknowledged: true },
        { ...savedLocal, secret_set: true },
      ),
    ).toEqual({ secretAccessKey: 'required' })
  })

  it('reads the kind with s3 as the fallback and the local repository disk', () => {
    expect(targetKindOf({})).toBe('s3')
    expect(targetKindOf({ kind: 'local' })).toBe('local')
    expect(
      repositoryDisk({
        summary: {
          configured: true,
          target: null,
          live: true,
          last_base: null,
          last_files: null,
          last_restore_test: null,
          state: { repository_disk: { total_bytes: 200, avail_bytes: 50 } },
        },
      }),
    ).toEqual({ total: 200, avail: 50, used: 0.75 })
  })
})

describe('backup schedule', () => {
  const schedule: BackupScheduleInput = {
    baseTime: '02:00',
    offsiteMinutes: 5,
    retentionDaily: 7,
    retentionWeekly: 4,
    retentionMonthly: 6,
    walDays: 7,
    restoreTest: true,
    restoreTestWeekday: 0,
    restoreTestTime: '04:00',
  }

  it('accepts the defaults', () => {
    expect(scheduleProblems(schedule)).toEqual({})
  })

  it('rejects values outside the database limits', () => {
    expect(
      scheduleProblems({
        ...schedule,
        baseTime: '25:00',
        offsiteMinutes: 0,
        retentionDaily: 61,
        retentionWeekly: Number.NaN,
        walDays: 36,
        restoreTestWeekday: 7,
      }),
    ).toEqual({
      baseTime: 'invalid',
      offsiteMinutes: 'invalid',
      retentionDaily: 'invalid',
      retentionWeekly: 'invalid',
      walDays: 'invalid',
      restoreTestWeekday: 'invalid',
    })
  })
})

describe('backup runs', () => {
  it('reads duration, recovery point, and staging disk', () => {
    expect(
      runDuration({ started_at: '2026-11-03T01:00:00.000Z', finished_at: '2026-11-03T01:04:30.000Z' }),
    ).toBe(270_000)
    expect(runDuration({ finished_at: '2026-11-03T01:04:30.000Z' })).toBeNull()
    expect(recoveredUntil({ detail: { recovered_until: '2026-11-03T00:59:00.000Z' } })).toBe(
      '2026-11-03T00:59:00.000Z',
    )
    expect(recoveredUntil({ detail: {} })).toBeNull()
    expect(
      stagingDisk({
        summary: {
          configured: true,
          target: null,
          live: true,
          last_base: null,
          last_files: null,
          last_restore_test: null,
          state: { disk: { total_bytes: 100, avail_bytes: 25 } },
        },
      }),
    ).toEqual({
      total: 100,
      avail: 25,
      used: 0.75,
    })
  })
})

describe('alert channels', () => {
  it('splits chat IDs and recipients on lines, commas, or spaces', () => {
    expect(parseList('-1001\n@ops_team, -1001  42')).toEqual(['-1001', '@ops_team', '42'])
  })

  it('checks Telegram tokens and chat IDs, and needs both before enabling', () => {
    expect(telegramProblems({ enabled: true, chatIds: [], botToken: '' }, false)).toEqual({
      enabled: 'incomplete',
    })
    expect(telegramProblems({ enabled: true, chatIds: ['-1001234567890'], botToken: '' }, true)).toEqual({})
    expect(telegramProblems({ enabled: false, chatIds: ['halo'], botToken: 'bukan-token' }, false)).toEqual({
      botToken: 'invalid',
      chatIds: 'invalid',
    })
    expect(
      telegramProblems(
        {
          enabled: false,
          chatIds: ['1', '2', '3', '4', '5', '6'],
          botToken: '123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsawQ',
        },
        false,
      ),
    ).toEqual({ chatIds: 'too_many' })
  })

  it('checks SMTP settings like the server', () => {
    const email: EmailInput = {
      enabled: true,
      host: 'smtp.example.co.id',
      port: 587,
      security: 'starttls',
      username: 'ops',
      from: 'alert@example.co.id',
      to: ['ops@example.co.id'],
      password: null,
    }
    expect(emailProblems(email)).toEqual({})
    expect(emailProblems({ ...email, to: [] })).toEqual({ enabled: 'incomplete' })
    expect(emailProblems({ ...email, from: 'bukan email', port: parsePort('70000') })).toEqual({
      from: 'invalid',
      port: 'invalid',
    })
    expect(emailProblems({ ...email, port: parsePort('abc') }).port).toBe('invalid')
    expect(parsePort('')).toBeNull()
  })

  it('checks the alert label and web console address', () => {
    expect(optionsProblems('OLT Produksi', 'https://cs.example.co.id/')).toEqual({})
    expect(optionsProblems('', 'cs.example.co.id')).toEqual({ label: 'length', consoleUrl: 'invalid' })
  })
})
