import { rpc } from '@/lib/supabase'

import type { AppPlatform, ClientConfig, FlagDraft } from './types'

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
  setFlag: async (draft: FlagDraft) =>
    normalize(
      await rpc<ClientConfig>('admin_set_feature_flag', {
        p_key: draft.key,
        p_enabled: draft.enabled,
        p_percentage: draft.percentage,
        p_user_ids: draft.user_ids,
        p_platforms: draft.platforms,
        p_min_app_version: draft.min_app_version,
        p_description: draft.description,
      }),
    ),
  deleteFlag: async (key: string) =>
    normalize(await rpc<ClientConfig>('admin_delete_feature_flag', { p_key: key })),
  setKillSwitch: async (enabled: boolean, reason: string) =>
    normalize(await rpc<ClientConfig>('admin_set_kill_switch', { p_enabled: enabled, p_reason: reason })),
  setMinVersion: async (platform: AppPlatform, version: string | null) =>
    normalize(
      await rpc<ClientConfig>('admin_set_min_version', { p_platform: platform, p_min_version: version }),
    ),
}
