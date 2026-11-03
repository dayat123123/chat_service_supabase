import { ImageIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { useAgent } from '@/features/auth/hooks'
import { moderationErrorText } from '@/lib/error-text'
import { stamp } from '@/lib/time'

import { metaKey, useContentMeta, useDecideHeld, useHeldContent } from '../hooks'
import { canEditHistory, heldAuthorName, heldDecisions } from '../logic'
import type { ContentMeta, ContentTarget, HeldContent, HeldDecision } from '../types'
import { EditHistoryButton } from './edit-history'
import { CategoryList, EditedMark, QueueHeader } from './moderation-ui'
import { ReasonDialog } from './shared'

const heldTarget = (row: HeldContent): ContentTarget => ({ type: row.target_type, id: row.target_id })

function HeldItem({
  row,
  history,
  meta,
  onUser,
  onDecide,
  onContent,
}: {
  row: HeldContent
  history: boolean
  meta: ContentMeta | undefined
  onUser: (id: string) => void
  onDecide: (decision: HeldDecision) => void
  onContent: (target: ContentTarget) => void
}) {
  const { t } = useTranslation()
  return (
    <li className="flex flex-col gap-2 border-b py-3">
      <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-muted-foreground">
        <span className="font-medium text-foreground">{t(`community.targets.${row.target_type}`)}</span>
        {row.stock_code ? <span className="font-mono">· ${row.stock_code}</span> : null}
        <span>· {stamp(row.created_at)}</span>
        <EditedMark editedAt={meta?.edited_at} />
        <span>· {t(`moderation.held.sources.${row.source}`)}</span>
        {row.attachments > 0 ? (
          <span className="inline-flex items-center gap-1">
            · <ImageIcon className="size-3.5" aria-hidden="true" />
            {t('moderation.held.attachments', { count: row.attachments })}
          </span>
        ) : null}
      </div>
      <CategoryList categories={row.categories} />
      <p className="text-row break-words whitespace-pre-wrap">{row.excerpt || '–'}</p>
      <div className="flex flex-wrap items-center justify-between gap-2">
        {row.author.id ? (
          <button
            type="button"
            onClick={() => onUser(row.author.id ?? '')}
            className="flex flex-wrap items-center gap-1.5 rounded-sm text-xs text-primary outline-none hover:underline focus-visible:ring-2 focus-visible:ring-ring/50"
          >
            {heldAuthorName(row)}
            {row.author.username ? (
              <span className="font-mono text-muted-foreground">@{row.author.username}</span>
            ) : null}
            {row.author.new_account ? (
              <span className="text-warning">{t('moderation.held.newAccount')}</span>
            ) : null}
            {row.author.trust_level !== null ? (
              <span className="text-muted-foreground">
                {t('community.trust', { level: row.author.trust_level })}
              </span>
            ) : null}
          </button>
        ) : (
          <span />
        )}
        <div className="flex flex-wrap gap-1.5">
          <Button size="xs" variant="ghost" onClick={() => onContent(heldTarget(row))}>
            {t('moderation.content.open')}
          </Button>
          {history && meta?.edited_at && (row.target_type === 'post' || row.target_type === 'comment') ? (
            <EditHistoryButton type={row.target_type} id={row.target_id} />
          ) : null}
          {heldDecisions.map((decision) => (
            <Button
              key={decision}
              size="xs"
              variant={decision === 'remove' ? 'destructive' : decision === 'approve' ? 'default' : 'outline'}
              onClick={() => onDecide(decision)}
            >
              {t(`moderation.held.decisions.${decision}`)}
            </Button>
          ))}
        </div>
      </div>
    </li>
  )
}

export function HeldQueue({
  onUser,
  onContent,
}: {
  onUser: (id: string) => void
  onContent: (target: ContentTarget) => void
}) {
  const { t } = useTranslation()
  const agent = useAgent()
  const held = useHeldContent()
  const metas = useContentMeta((held.data ?? []).map(heldTarget))
  const decide = useDecideHeld()
  const [acting, setActing] = useState<{ row: HeldContent; decision: HeldDecision } | null>(null)
  return (
    <div className="flex min-w-0 flex-col gap-3">
      <QueueHeader
        title={t('moderation.held.title')}
        hint={t('moderation.held.hint')}
        count={held.data?.length}
      />
      {held.isError ? (
        <ErrorState error={held.error} onRetry={() => void held.refetch()} />
      ) : !held.data ? (
        <ListSkeleton rows={4} />
      ) : held.data.length === 0 ? (
        <EmptyState title={t('moderation.held.empty')} />
      ) : (
        <ul className="border-t">
          {held.data.map((row) => (
            <HeldItem
              key={`${row.target_type}-${row.target_id}`}
              row={row}
              history={canEditHistory(agent.community_permissions, row.target_type)}
              meta={metas.get(metaKey(heldTarget(row)))}
              onUser={onUser}
              onDecide={(decision) => setActing({ row, decision })}
              onContent={onContent}
            />
          ))}
        </ul>
      )}
      <ReasonDialog
        key={acting ? `${acting.row.target_id}-${acting.decision}` : 'none'}
        open={acting !== null}
        title={acting ? t(`moderation.held.titles.${acting.decision}`) : ''}
        description={acting ? t(`moderation.held.bodies.${acting.decision}`) : undefined}
        label={t('community.reason')}
        action={acting ? t(`moderation.held.decisions.${acting.decision}`) : ''}
        destructive={acting?.decision === 'remove'}
        pending={decide.isPending}
        onClose={() => setActing(null)}
        onSubmit={(reason) => {
          if (!acting) return
          void decide
            .mutateAsync({
              type: acting.row.target_type,
              id: acting.row.target_id,
              action: acting.decision,
              reason,
            })
            .then(() => {
              toast.success(t(`moderation.held.done.${acting.decision}`))
              setActing(null)
            })
            .catch((error: unknown) => toast.error(moderationErrorText(error)))
        }}
      />
    </div>
  )
}
