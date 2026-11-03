import {
  booleanSettings,
  BUSY_WINDOWS_KEY,
  contentCategories,
  imageCategories,
  MAX_BUSY_WINDOWS,
  numberSettings,
  type ContentRule,
  type DomainMatch,
  type ImageCategory,
  type ImageLimits,
  type ImageThresholds,
  type ManipulationSettings,
} from './types'

const domainPattern = /^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$/
const keywordPattern = /^[a-z0-9][a-z0-9-]{2,29}$/
const termPattern = /^[a-z0-9]+( [a-z0-9]+)*$/
const timePattern = /^([01][0-9]|2[0-3]):[0-5][0-9]$/

export function sortRules(rules: ContentRule[]) {
  const rank = (rule: ContentRule) => contentCategories.indexOf(rule.category)
  return [...rules].sort((a, b) => rank(a) - rank(b))
}

export function cleanDomain(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/^[a-z][a-z0-9+.-]*:\/\//, '')
    .replace(/[/?#:].*$/, '')
    .replace(/^www\./, '')
}

export function domainEntry(value: string, match: DomainMatch) {
  return match === 'keyword' ? value.trim().toLowerCase() : cleanDomain(value)
}

export function domainProblem(value: string, match: DomainMatch): 'required' | 'invalid' | null {
  if (value === '') return 'required'
  if (match === 'keyword') return keywordPattern.test(value) ? null : 'invalid'
  return value.length <= 253 && domainPattern.test(value) ? null : 'invalid'
}

export const normalizeTerm = (value: string) => value.trim().replace(/\s+/g, ' ').toLowerCase()

export function termProblem(term: string, min: number): 'length' | 'characters' | null {
  if (term.length < min || term.length > 50) return 'length'
  return termPattern.test(term) ? null : 'characters'
}

export type LimitText = { hold: string; block: string }
export type ThresholdForm = Record<ImageCategory, LimitText>
export type ThresholdIssue = 'hold' | 'block' | 'order'
export type ThresholdProblems = {
  categories: Partial<Record<ImageCategory, ThresholdIssue>>
  pornRequired: boolean
}

const percentFrom = (fraction: number | undefined) =>
  fraction === undefined ? '' : String(Math.round(fraction * 10000) / 100)

export function thresholdForm(thresholds: ImageThresholds['thresholds']): ThresholdForm {
  return Object.fromEntries(
    imageCategories.map((category) => [
      category,
      { hold: percentFrom(thresholds[category]?.hold), block: percentFrom(thresholds[category]?.block) },
    ]),
  ) as ThresholdForm
}

export function parsePercent(text: string): number | null | 'invalid' {
  const value = text.trim().replace(',', '.')
  if (value === '') return null
  if (!/^\d{1,3}(\.\d{1,2})?$/.test(value)) return 'invalid'
  const number = Number(value)
  return number >= 0 && number <= 100 ? number : 'invalid'
}

export function thresholdProblems(form: ThresholdForm): ThresholdProblems {
  const categories: ThresholdProblems['categories'] = {}
  for (const category of imageCategories) {
    const hold = parsePercent(form[category].hold)
    const block = parsePercent(form[category].block)
    if (hold === 'invalid') categories[category] = 'hold'
    else if (block === 'invalid') categories[category] = 'block'
    else if (hold !== null && block !== null && hold > block) categories[category] = 'order'
  }
  const porn = form.porn
  const pornRequired =
    parsePercent(porn.hold) === null && parsePercent(porn.block) === null && categories.porn === undefined
  return { categories, pornRequired }
}

export const thresholdsValid = (problems: ThresholdProblems) =>
  !problems.pornRequired && Object.keys(problems.categories).length === 0

export function thresholdPayload(form: ThresholdForm): ImageThresholds['thresholds'] {
  const payload: ImageThresholds['thresholds'] = {}
  for (const category of imageCategories) {
    const limits: ImageLimits = {}
    const hold = parsePercent(form[category].hold)
    const block = parsePercent(form[category].block)
    if (typeof hold === 'number') limits.hold = Math.round(hold * 100) / 10000
    if (typeof block === 'number') limits.block = Math.round(block * 100) / 10000
    if (limits.hold !== undefined || limits.block !== undefined) payload[category] = limits
  }
  return payload
}

export function sameThresholds(a: ImageThresholds['thresholds'], b: ImageThresholds['thresholds']) {
  return imageCategories.every(
    (category) => a[category]?.hold === b[category]?.hold && a[category]?.block === b[category]?.block,
  )
}

export type BusyWindow = { start: string; end: string }

export type ManipulationForm = {
  numbers: Record<string, string>
  booleans: Record<string, boolean>
  windows: BusyWindow[]
}

const numberText = (value: unknown, percent?: boolean) => {
  if (typeof value !== 'number') return ''
  return percent ? String(Math.round(value * 10000) / 100) : String(value)
}

export function manipulationForm(settings: ManipulationSettings): ManipulationForm {
  const windows = Array.isArray(settings[BUSY_WINDOWS_KEY]) ? (settings[BUSY_WINDOWS_KEY] as unknown[]) : []
  return {
    numbers: Object.fromEntries(
      numberSettings.map((setting) => [setting.id, numberText(settings[setting.key], setting.percent)]),
    ),
    booleans: Object.fromEntries(
      booleanSettings.map((setting) => [setting.id, settings[setting.key] === true]),
    ),
    windows: windows
      .filter((item): item is [string, string] => Array.isArray(item) && item.length === 2)
      .map(([start, end]) => ({ start: String(start), end: String(end) })),
  }
}

function parseNumber(text: string, setting: (typeof numberSettings)[number]): number | null {
  const value = text.trim().replace(',', '.')
  if (!/^\d+(\.\d+)?$/.test(value)) return null
  const raw = Number(value)
  const number = setting.percent ? Math.round(raw * 100) / 10000 : raw
  if (setting.integer && !Number.isInteger(number)) return null
  return number >= setting.min && number <= setting.max ? number : null
}

export type ManipulationProblems = { numbers: string[]; windows: number[]; tooManyWindows: boolean }

export function manipulationProblems(form: ManipulationForm): ManipulationProblems {
  return {
    numbers: numberSettings
      .filter((setting) => parseNumber(form.numbers[setting.id] ?? '', setting) === null)
      .map((setting) => setting.id),
    windows: form.windows
      .map((window, index) =>
        timePattern.test(window.start) && timePattern.test(window.end) && window.start < window.end
          ? -1
          : index,
      )
      .filter((index) => index >= 0),
    tooManyWindows: form.windows.length > MAX_BUSY_WINDOWS,
  }
}

export const manipulationValid = (problems: ManipulationProblems) =>
  problems.numbers.length === 0 && problems.windows.length === 0 && !problems.tooManyWindows

export function manipulationChanges(
  settings: ManipulationSettings,
  form: ManipulationForm,
): ManipulationSettings {
  const changes: ManipulationSettings = {}
  for (const setting of numberSettings) {
    const value = parseNumber(form.numbers[setting.id] ?? '', setting)
    if (value !== null && value !== settings[setting.key]) changes[setting.key] = value
  }
  for (const setting of booleanSettings) {
    const value = form.booleans[setting.id] ?? false
    if (value !== (settings[setting.key] === true)) changes[setting.key] = value
  }
  const windows = form.windows.map((window) => [window.start, window.end])
  if (JSON.stringify(windows) !== JSON.stringify(settings[BUSY_WINDOWS_KEY] ?? []))
    changes[BUSY_WINDOWS_KEY] = windows
  return changes
}
