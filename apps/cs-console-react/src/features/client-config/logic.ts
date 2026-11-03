import {
  FLAG_DESCRIPTION_MAX,
  FLAG_USERS_MAX,
  KILL_REASON_MAX,
  KILL_REASON_MIN,
  RESERVED_FLAG,
  type FeatureFlag,
  type FlagDraft,
} from './types'

const flagKeyPattern = /^[a-z][a-z0-9_.]{1,49}$/
const versionPattern = /^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$/
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export type FlagField = 'key' | 'percentage' | 'users' | 'version' | 'description'
export type FlagProblem =
  'required' | 'format' | 'reserved' | 'exists' | 'range' | 'invalid' | 'tooMany' | 'length'
export type FlagProblems = Partial<Record<FlagField, FlagProblem>>

export const normalizeFlagKey = (value: string) => value.trim().toLowerCase()

export function versionValid(value: string) {
  return versionPattern.test(value.trim())
}

export function parseUserIds(text: string) {
  const items = [
    ...new Set(
      text
        .split(/[\s,;]+/)
        .map((item) => item.trim().toLowerCase())
        .filter(Boolean),
    ),
  ]
  return {
    ids: items.filter((item) => uuidPattern.test(item)),
    invalid: items.filter((item) => !uuidPattern.test(item)),
  }
}

export function flagProblems(
  draft: FlagDraft,
  options: { isNew: boolean; existing: string[]; invalidUsers: string[] },
): FlagProblems {
  const problems: FlagProblems = {}
  const key = normalizeFlagKey(draft.key)
  if (options.isNew) {
    if (key === '') problems.key = 'required'
    else if (key === RESERVED_FLAG) problems.key = 'reserved'
    else if (!flagKeyPattern.test(key)) problems.key = 'format'
    else if (options.existing.includes(key)) problems.key = 'exists'
  }
  if (!Number.isInteger(draft.percentage) || draft.percentage < 0 || draft.percentage > 100)
    problems.percentage = 'range'
  if (options.invalidUsers.length > 0) problems.users = 'invalid'
  else if (draft.user_ids.length > FLAG_USERS_MAX) problems.users = 'tooMany'
  if (draft.min_app_version !== null && !versionValid(draft.min_app_version)) problems.version = 'format'
  if ((draft.description ?? '').length > FLAG_DESCRIPTION_MAX) problems.description = 'length'
  return problems
}

export function flagDraft(flag: FeatureFlag | null): FlagDraft {
  return flag
    ? {
        key: flag.key,
        enabled: flag.enabled,
        percentage: flag.percentage,
        user_ids: flag.user_ids,
        platforms: flag.platforms,
        min_app_version: flag.min_app_version,
        description: flag.description,
      }
    : {
        key: '',
        enabled: false,
        percentage: 100,
        user_ids: [],
        platforms: [],
        min_app_version: null,
        description: null,
      }
}

export const collapseSpaces = (value: string) => value.replace(/\s+/g, ' ').trim()

export function killReasonValid(reason: string) {
  const text = collapseSpaces(reason)
  return text.length >= KILL_REASON_MIN && text.length <= KILL_REASON_MAX
}

export function phraseMatches(typed: string, phrase: string) {
  return collapseSpaces(typed).toLocaleUpperCase('id') === phrase.toLocaleUpperCase('id')
}

export function rolloutLabel(flag: Pick<FeatureFlag, 'enabled' | 'percentage' | 'user_ids'>) {
  if (!flag.enabled) return 'off' as const
  if (flag.percentage >= 100) return 'all' as const
  if (flag.percentage === 0) return flag.user_ids.length > 0 ? ('users' as const) : ('none' as const)
  return 'partial' as const
}
