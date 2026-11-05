import { fitImage } from '@/features/conversation/clipboard'
import { toApiError } from '@/lib/errors'
import { appEnv, rpc, supabase } from '@/lib/supabase'
import { uuid } from '@/lib/utils'

import {
  BANNER_IMAGE_MAX_BYTES,
  type AppBanner,
  type AppPlatform,
  type BannerDraft,
  type BannerSettings,
  type BannerStatsDetail,
  type ClientConfig,
} from './types'

function normalize(raw: ClientConfig): ClientConfig {
  return {
    kill_switch: raw.kill_switch,
    flags: (raw.flags ?? []).map((flag) => ({
      ...flag,
      user_ids: flag.user_ids ?? [],
      platforms: flag.platforms ?? [],
    })),
    min_versions: raw.min_versions ?? [],
  }
}

export const clientConfigApi = {
  config: async () => normalize(await rpc<ClientConfig>('admin_feature_flags')),
  toggleFlag: async (key: string, enabled: boolean) =>
    normalize(await rpc<ClientConfig>('admin_toggle_feature_flag', { p_key: key, p_enabled: enabled })),
  setKillSwitch: async (enabled: boolean, reason: string) =>
    normalize(await rpc<ClientConfig>('admin_set_kill_switch', { p_enabled: enabled, p_reason: reason })),
  setMinVersion: async (platform: AppPlatform, version: string | null) =>
    normalize(
      await rpc<ClientConfig>('admin_set_min_version', { p_platform: platform, p_min_version: version }),
    ),
}

const emptyStats = { impressions: 0, clicks: 0, dismissals: 0, unique_viewers: 0, ctr: null }

function normalizeBanner(raw: AppBanner): AppBanner {
  return {
    ...raw,
    body: raw.body ?? '',
    platforms: raw.platforms ?? [],
    display: raw.display ?? 'strip',
    image_path: raw.image_path ?? null,
    image_url: raw.image_url ?? null,
    cta_label: raw.cta_label ?? null,
    frequency: raw.frequency ?? 'once',
    audience: raw.audience ?? 'all',
    audience_days: raw.audience_days ?? 7,
    stats: raw.stats ?? emptyStats,
  }
}

const imageExtension: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
}

export const BANNER_BUCKET = 'app-banners'

export function bannerImageUrl(path: string) {
  return `${appEnv().publicApiUrl ?? appEnv().supabaseUrl}/storage/v1/object/public/${BANNER_BUCKET}/${path}`
}

export const bannersApi = {
  list: async () => ((await rpc<AppBanner[] | null>('admin_banners')) ?? []).map(normalizeBanner),
  save: async (id: string | null, draft: BannerDraft) =>
    normalizeBanner(
      await rpc<AppBanner>('admin_save_banner', {
        p_id: id,
        p_title: draft.title,
        p_body: draft.body,
        p_link_url: draft.link_url,
        p_level: draft.level,
        p_starts_at: draft.starts_at,
        p_ends_at: draft.ends_at,
        p_platforms: draft.platforms,
        p_min_app_version: draft.min_app_version,
        p_max_app_version: draft.max_app_version,
        p_dismissible: draft.dismissible,
        p_priority: draft.priority,
        p_display: draft.display,
        p_image_url: draft.display === 'popup' ? draft.image_url : null,
        p_cta_label: draft.link_url ? draft.cta_label : null,
        p_frequency: draft.display === 'popup' ? draft.frequency : 'once',
        p_audience: draft.audience,
        p_audience_days: draft.audience_days,
      }),
    ),
  remove: (id: string) => rpc<{ id: string; deleted: boolean }>('admin_delete_banner', { p_id: id }),
  stats: async (id: string) => {
    const raw = await rpc<BannerStatsDetail>('admin_banner_stats', { p_id: id })
    return { ...raw, days: raw.days ?? [] }
  },
  settings: async () => {
    const raw = await rpc<BannerSettings>('admin_banner_settings')
    return {
      ...raw,
      deep_link_schemes: raw.deep_link_schemes ?? [],
      forbidden_schemes: raw.forbidden_schemes ?? [],
    }
  },
  setLinkSchemes: async (schemes: string[]) => {
    const raw = await rpc<BannerSettings>('admin_set_banner_link_schemes', { p_schemes: schemes })
    return {
      ...raw,
      deep_link_schemes: raw.deep_link_schemes ?? [],
      forbidden_schemes: raw.forbidden_schemes ?? [],
    }
  },
  uploadImage: async (image: Blob) => {
    const original = image instanceof File ? image : new File([image], 'banner.jpg', { type: image.type })
    const file = await fitImage(original, BANNER_IMAGE_MAX_BYTES)
    const path = `${uuid()}.${imageExtension[file.type] ?? 'jpg'}`
    const { error } = await supabase()
      .storage.from(BANNER_BUCKET)
      .upload(path, file, { contentType: file.type })
    if (error) throw toApiError(error)
    return bannerImageUrl(path)
  },
}
