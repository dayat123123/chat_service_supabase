import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'

import {
  RadioGroup,
  RadioGroupItem,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/controls'
import { Input } from '@/components/ui/input'
import { useDebounced } from '@/hooks/use-now'
import { formatNumber } from '@/lib/time'

import { useAudienceSize } from '../hooks'
import { segmentProblem, segmentQuery, type SegmentInput } from '../logic'
import {
  audiencePlatforms,
  audiences,
  type AudiencePlatform,
  type AudienceQuery,
  type OfficialAccount,
} from '../types'

function useDebouncedQuery(query: AudienceQuery) {
  const key = useDebounced(JSON.stringify(query), 400)
  return useMemo(() => JSON.parse(key) as AudienceQuery, [key])
}

export function SegmentFields({
  value,
  onChange,
  accounts,
  touched,
}: {
  value: SegmentInput
  onChange: (next: SegmentInput) => void
  accounts: OfficialAccount[]
  touched: boolean
}) {
  const { t } = useTranslation()
  const query = segmentQuery(value)
  const problem = segmentProblem(query)
  const debounced = useDebouncedQuery(query)
  const settled = JSON.stringify(query) === JSON.stringify(debounced)
  const size = useAudienceSize(debounced, segmentProblem(debounced) === null)
  const set = (patch: Partial<SegmentInput>) => onChange({ ...value, ...patch })
  const error =
    touched && problem
      ? problem === 'stock'
        ? t('community.errors.stockInvalid')
        : t(`moderation.segments.problems.${problem}`)
      : undefined
  return (
    <fieldset className="flex flex-col gap-2 rounded-lg border p-3">
      <legend className="px-1 text-sm font-medium">{t('moderation.segments.label')}</legend>
      <RadioGroup
        value={value.audience}
        onValueChange={(next) => set({ audience: next as SegmentInput['audience'] })}
        className="grid gap-x-4 gap-y-2 sm:grid-cols-3"
      >
        {audiences.map((item) => (
          <label key={item} className="flex items-center gap-2 text-row">
            <RadioGroupItem value={item} />
            {t(`moderation.segments.options.${item}`)}
          </label>
        ))}
      </RadioGroup>
      {value.audience === 'stock' ? (
        <Input
          aria-label={t('community.stockCode')}
          className="w-48"
          maxLength={13}
          placeholder="BBCA"
          value={value.stock}
          aria-invalid={error ? true : undefined}
          onChange={(event) => set({ stock: event.target.value })}
        />
      ) : null}
      {value.audience === 'new_users' || value.audience === 'inactive' ? (
        <Input
          aria-label={t('moderation.segments.days')}
          className="w-48"
          inputMode="numeric"
          maxLength={3}
          value={value.days}
          aria-invalid={error ? true : undefined}
          onChange={(event) => set({ days: event.target.value })}
        />
      ) : null}
      {value.audience === 'platform' ? (
        <Select
          value={value.platform ?? undefined}
          onValueChange={(next) => set({ platform: next as AudiencePlatform })}
        >
          <SelectTrigger aria-label={t('moderation.segments.platform')} className="w-48">
            <SelectValue placeholder={t('moderation.segments.choosePlatform')} />
          </SelectTrigger>
          <SelectContent>
            {audiencePlatforms.map((item) => (
              <SelectItem key={item} value={item}>
                {t(`moderation.segments.platforms.${item}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      ) : null}
      {value.audience === 'followers' ? (
        <Select value={value.account_id ?? undefined} onValueChange={(next) => set({ account_id: next })}>
          <SelectTrigger aria-label={t('moderation.segments.account')} className="w-full sm:w-80">
            <SelectValue placeholder={t('moderation.segments.chooseAccount')} />
          </SelectTrigger>
          <SelectContent>
            {accounts.map((item) => (
              <SelectItem key={item.id} value={item.id}>
                {item.display_name ?? item.username}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      ) : null}
      {error ? <p className="text-xs text-destructive">{error}</p> : null}
      <p className="text-xs text-muted-foreground">{t(`moderation.segments.hints.${value.audience}`)}</p>
      <p className="text-xs text-muted-foreground" role="status">
        {problem !== null
          ? null
          : !settled || size.data === undefined
            ? t('community.audienceCounting')
            : t('community.audienceSize', { count: size.data, formatted: formatNumber(size.data) })}
      </p>
    </fieldset>
  )
}
