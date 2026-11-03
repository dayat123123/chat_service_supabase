import {
  BANNER_BODY_MAX,
  BANNER_LINK_MAX,
  BANNER_PRIORITY_MAX,
  BANNER_TITLE_MAX,
  KILL_REASON_MAX,
  KILL_REASON_MIN,
  knownFlags,
  type AppBanner,
  type BannerDraft,
  type FeatureFlag,
  type FeatureRow,
} from './types'

const versionPattern = /^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$/

export function versionValid(value: string) {
  return versionPattern.test(value.trim())
}

export function featureRows(flags: FeatureFlag[]): FeatureRow[] {
  return knownFlags.map((key) => {
    const flag = flags.find((item) => item.key === key)
    return {
      key,
      enabled: flag?.enabled ?? false,
      updated_by: flag?.updated_by ?? null,
      updated_at: flag?.updated_at ?? null,
    }
  })
}

export const collapseSpaces = (value: string) => value.replace(/\s+/g, ' ').trim()

export function killReasonValid(reason: string) {
  const text = collapseSpaces(reason)
  return text.length >= KILL_REASON_MIN && text.length <= KILL_REASON_MAX
}

export function phraseMatches(typed: string, phrase: string) {
  return collapseSpaces(typed).toLocaleUpperCase('id') === phrase.toLocaleUpperCase('id')
}

export type BannerField =
  'title' | 'body' | 'link' | 'minVersion' | 'maxVersion' | 'priority' | 'starts' | 'ends'
export type BannerProblem = 'required' | 'length' | 'format' | 'range' | 'order'
export type BannerProblems = Partial<Record<BannerField, BannerProblem>>

const linkPattern = /^https?:\/\/\S+$/

export function compareVersions(a: string, b: string) {
  const left = a.trim().split('.').map(Number)
  const right = b.trim().split('.').map(Number)
  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    const diff = (left[index] ?? 0) - (right[index] ?? 0)
    if (diff !== 0) return diff
  }
  return 0
}

export function bannerProblems(
  draft: BannerDraft,
  inputs: { startsText: string; endsText: string },
): BannerProblems {
  const problems: BannerProblems = {}
  const title = draft.title.trim()
  if (title === '') problems.title = 'required'
  else if (title.length > BANNER_TITLE_MAX) problems.title = 'length'
  if (draft.body.trim().length > BANNER_BODY_MAX) problems.body = 'length'
  if (draft.link_url !== null) {
    if (!linkPattern.test(draft.link_url)) problems.link = 'format'
    else if (draft.link_url.length > BANNER_LINK_MAX) problems.link = 'length'
  }
  if (draft.min_app_version !== null && !versionValid(draft.min_app_version)) problems.minVersion = 'format'
  if (draft.max_app_version !== null && !versionValid(draft.max_app_version)) problems.maxVersion = 'format'
  else if (
    !problems.minVersion &&
    draft.min_app_version !== null &&
    draft.max_app_version !== null &&
    compareVersions(draft.min_app_version, draft.max_app_version) > 0
  )
    problems.maxVersion = 'order'
  if (!Number.isInteger(draft.priority) || draft.priority < 0 || draft.priority > BANNER_PRIORITY_MAX)
    problems.priority = 'range'
  if (inputs.startsText.trim() !== '' && draft.starts_at === null) problems.starts = 'format'
  if (inputs.endsText.trim() !== '' && draft.ends_at === null) problems.ends = 'format'
  else if (draft.ends_at !== null) {
    const start = draft.starts_at ?? new Date().toISOString()
    if (Date.parse(draft.ends_at) <= Date.parse(start)) problems.ends = 'order'
  }
  return problems
}

export function bannerDraft(banner: AppBanner | null): BannerDraft {
  return banner
    ? {
        title: banner.title,
        body: banner.body,
        link_url: banner.link_url,
        level: banner.level,
        starts_at: banner.starts_at,
        ends_at: banner.ends_at,
        platforms: banner.platforms,
        min_app_version: banner.min_app_version,
        max_app_version: banner.max_app_version,
        dismissible: banner.dismissible,
        priority: banner.priority,
      }
    : {
        title: '',
        body: '',
        link_url: null,
        level: 'info',
        starts_at: null,
        ends_at: null,
        platforms: [],
        min_app_version: null,
        max_app_version: null,
        dismissible: true,
        priority: 0,
      }
}
