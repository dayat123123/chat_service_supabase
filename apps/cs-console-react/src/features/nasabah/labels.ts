import { useTranslation } from 'react-i18next'

import { formatDay } from '@/lib/time'

import type { IncompleteField, NasabahPermission, UserFlag } from './types'

const loginTypeKeys = ['demo', 'client', 'sales', 'branch', 'csAll', 'csBranch'] as const
const statusKeys = ['inactive', 'active', 'suspendTrading', 'suspendLogin'] as const
const actionKeys: Record<number, 'create' | 'update' | 'delete'> = { 1: 'create', 2: 'update', 3: 'delete' }
const approvalStatusKeys: Record<number, 'pending' | 'approved' | 'rejected'> = {
  0: 'rejected',
  1: 'pending',
  2: 'approved',
  3: 'rejected',
}

export function legacyStamp(value: string | null | undefined, pattern = 'd MMM yyyy, HH.mm') {
  const text = (value ?? '').trim()
  if (!/^\d{4}-\d{2}-\d{2}/.test(text)) return text || '–'
  const iso = text.length > 10 ? text.slice(0, 19).replace(' ', 'T') : text
  try {
    return formatDay(iso, text.length > 10 ? pattern : 'd MMM yyyy')
  } catch {
    return text
  }
}

export function useNasabahLabels() {
  const { t } = useTranslation()
  return {
    loginType: (value: number) => {
      const key = loginTypeKeys[value]
      return key ? t(`nasabah.loginTypes.${key}`) : String(value)
    },
    status: (value: number) => {
      const key = statusKeys[value]
      return key ? t(`nasabah.statuses.${key}`) : String(value)
    },
    flag: (key: UserFlag) => t(`nasabah.flags.${key}`),
    action: (value: number) => {
      const key = actionKeys[value]
      return key ? t(`nasabah.actions.${key}`) : String(value)
    },
    approvalStatus: (value: number) => {
      const key = approvalStatusKeys[value]
      return key ? t(`nasabah.approvalStatus.${key}`) : String(value)
    },
    permission: (value: NasabahPermission) =>
      t(`nasabah.permissions.${value.replace('.', '_') as 'online_user_view'}`),
    incomplete: (key: IncompleteField) => t(`nasabah.incomplete.${key}`),
  }
}
