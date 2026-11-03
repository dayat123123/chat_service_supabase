import { rpc } from '@/lib/supabase'

import type { AppBanner, AppPlatform, BannerDraft, ClientConfig } from './types'

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

function normalizeBanner(raw: AppBanner): AppBanner {
  return { ...raw, body: raw.body ?? '', platforms: raw.platforms ?? [] }
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
      }),
    ),
  remove: (id: string) => rpc<{ id: string; deleted: boolean }>('admin_delete_banner', { p_id: id }),
}
