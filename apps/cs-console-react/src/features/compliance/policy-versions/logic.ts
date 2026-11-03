import { contentActions, numberSettings, type ContentAction } from '@/features/content-policy/types'

import {
  policySections,
  REASON_MAX,
  REASON_MIN,
  type DiffItem,
  type PolicyDiff,
  type PolicySection,
  type SectionDiff,
} from './types'

export type DiffEntry = SectionDiff & { section: PolicySection; items: DiffItem[] }

export function diffEntries(diff: PolicyDiff): DiffEntry[] {
  return policySections.flatMap((section) => {
    const entry = diff.sections[section]
    if (!entry) return []
    return [{ ...entry, section, items: entry.items ?? [] }]
  })
}

export const hiddenItems = (entry: DiffEntry) =>
  Math.max(0, entry.added + entry.removed + entry.changed - entry.items.length)

export function reasonProblem(reason: string): 'short' | 'long' | null {
  const length = reason.trim().length
  if (length < REASON_MIN) return 'short'
  if (length > REASON_MAX) return 'long'
  return null
}

const level = (action: ContentAction) => contentActions.indexOf(action)

export function outcomeShift(current: ContentAction, draft: ContentAction): 'stricter' | 'looser' | 'same' {
  const delta = level(draft) - level(current)
  if (delta > 0) return 'stricter'
  if (delta < 0) return 'looser'
  return 'same'
}

export const countDelta = (current: number, draft: number) => {
  const delta = draft - current
  if (delta === 0) return '±0'
  return delta > 0 ? `+${delta}` : `${delta}`
}

export type SettingLabel =
  | { kind: 'number'; id: (typeof numberSettings)[number]['id']; percent: boolean }
  | { kind: 'autoSlow' | 'autoHold' | 'windows' | 'newAccount' }
  | { kind: 'raw' }

export function settingLabel(key: string): SettingLabel {
  const number = numberSettings.find((item) => item.key === key)
  if (number) return { kind: 'number', id: number.id, percent: number.percent === true }
  switch (key) {
    case 'manipulation.auto_slow_mode':
      return { kind: 'autoSlow' }
    case 'manipulation.auto_hold_similar':
      return { kind: 'autoHold' }
    case 'rooms.busy_windows':
      return { kind: 'windows' }
    case 'safety.new_account_days':
      return { kind: 'newAccount' }
    default:
      return { kind: 'raw' }
  }
}

export const percentText = (value: unknown) =>
  typeof value === 'number' ? `${Math.round(value * 1000) / 10}%` : '–'

export function windowsText(value: unknown) {
  if (!Array.isArray(value) || value.length === 0) return '–'
  return value
    .map((window) =>
      Array.isArray(window) && window.length === 2 ? `${String(window[0])}–${String(window[1])}` : '?',
    )
    .join(', ')
}

export function scalarText(value: unknown): string {
  if (value === undefined || value === null) return '–'
  if (typeof value === 'string') return value
  if (typeof value === 'number' || typeof value === 'boolean') return String(value)
  return JSON.stringify(value)
}

export const objectValue = (value: unknown): Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {}

export function thresholdParts(value: unknown) {
  const limits = objectValue(value)
  return {
    hold: limits.hold === undefined ? null : percentText(limits.hold),
    block: limits.block === undefined ? null : percentText(limits.block),
  }
}
