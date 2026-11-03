import { useTranslation } from 'react-i18next'

import { campaignSegment, type SegmentInput } from './logic'
import type { Campaign } from './types'

export function segmentInput(campaign: Campaign | null): SegmentInput {
  return {
    audience: campaign?.audience ?? 'all',
    stock: campaign?.audience_stock ?? '',
    days: String(campaign?.audience_days ?? 30),
    platform: campaign?.audience_platform ?? null,
    account_id: campaign?.audience_account?.id ?? null,
  }
}

export function useSegmentText() {
  const { t } = useTranslation()
  return (campaign: Campaign) => {
    const segment = campaignSegment(campaign)
    switch (segment.audience) {
      case 'stock':
        return t('moderation.segments.value.stock', { code: segment.stock ?? '' })
      case 'new_users':
      case 'inactive':
        return t(`moderation.segments.value.${segment.audience}`, { days: segment.days ?? 0 })
      case 'platform':
        return t('moderation.segments.value.platform', {
          platform: segment.platform ? t(`moderation.segments.platforms.${segment.platform}`) : '–',
        })
      case 'followers':
        return t('moderation.segments.value.followers', { name: segment.account_name ?? '–' })
      default:
        return t('moderation.segments.value.all')
    }
  }
}
