import { MegaphoneIcon, PinIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

import { EmptyState, ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/controls'
import { useAgent } from '@/features/auth/hooks'
import { stamp } from '@/lib/time'

import { useCommunityPosts } from '../hooks'
import { excerpt, filterPosts, postFilters, type PostFilter } from '../logic'
import type { CommunityPost } from '../types'
import { PostComposer } from './post-composer'
import { PostSheet } from './post-sheet'
import { AccountChip, PostStatusText } from './shared'

function PostRow({ post, onOpen }: { post: CommunityPost; onOpen: () => void }) {
  const { t } = useTranslation()
  const when = post.published_at ?? post.publish_at ?? post.updated_at
  return (
    <li>
      <button
        type="button"
        onClick={onOpen}
        className="flex w-full flex-col gap-1.5 border-b px-1 py-3 text-left outline-none hover:bg-muted/50 focus-visible:ring-2 focus-visible:ring-ring/50 focus-visible:ring-inset"
      >
        <span className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1">
          <AccountChip account={post.account} />
          <PostStatusText status={post.status} />
        </span>
        <span className="flex items-start gap-2">
          {post.kind === 'announcement' ? (
            <MegaphoneIcon
              className="mt-0.5 size-4 shrink-0 text-primary"
              aria-label={t('community.kinds.announcement')}
            />
          ) : null}
          {post.pinned ? (
            <PinIcon
              className="mt-0.5 size-4 shrink-0 text-muted-foreground"
              aria-label={t('community.pinned')}
            />
          ) : null}
          <span className="min-w-0 text-row">
            {post.title ? <span className="font-medium">{post.title} · </span> : null}
            {excerpt(post.body)}
          </span>
        </span>
        <span className="text-xs text-muted-foreground">
          {[
            post.created_by?.name,
            post.status === 'scheduled' && post.publish_at
              ? t('community.scheduledAt', { time: stamp(post.publish_at) })
              : stamp(when),
            post.attachments.length > 0
              ? t('community.imageCount', { count: post.attachments.length })
              : null,
            post.notify ? t('community.withNotification') : null,
          ]
            .filter(Boolean)
            .join(' · ')}
        </span>
      </button>
    </li>
  )
}

export function StreamTab() {
  const { t } = useTranslation()
  const agent = useAgent()
  const posts = useCommunityPosts()
  const canWrite = agent.community_permissions.includes('community.post')
  const canPublish = agent.community_permissions.includes('community.publish')
  const [filter, setFilter] = useState<PostFilter>(canPublish ? 'review' : 'mine')
  const [selected, setSelected] = useState<string | null>(null)
  const [editing, setEditing] = useState<CommunityPost | null>(null)
  const [composing, setComposing] = useState(false)
  const rows = posts.data ? filterPosts(posts.data, filter, agent.id) : []
  const current = posts.data?.find((post) => post.id === selected) ?? null

  return (
    <section className="flex flex-col gap-3" aria-label={t('community.tabs.stream')}>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <ToggleGroup
          type="single"
          value={filter}
          onValueChange={(value) => {
            if ((postFilters as readonly string[]).includes(value)) setFilter(value as PostFilter)
          }}
          aria-label={t('community.filter')}
        >
          {postFilters.map((item) => (
            <ToggleGroupItem key={item} value={item}>
              {t(`community.postFilters.${item}`)}
            </ToggleGroupItem>
          ))}
        </ToggleGroup>
        {canWrite ? (
          <Button
            size="sm"
            onClick={() => {
              setEditing(null)
              setComposing(true)
            }}
          >
            <PlusIcon />
            {t('community.newPost')}
          </Button>
        ) : null}
      </div>
      {posts.isError ? (
        <ErrorState error={posts.error} onRetry={() => void posts.refetch()} />
      ) : !posts.data ? (
        <ListSkeleton rows={5} />
      ) : rows.length === 0 ? (
        <EmptyState title={t(`community.emptyPosts.${filter}`)} />
      ) : (
        <ul className="border-t">
          {rows.map((post) => (
            <PostRow key={post.id} post={post} onOpen={() => setSelected(post.id)} />
          ))}
        </ul>
      )}
      <PostSheet
        post={current}
        onClose={() => setSelected(null)}
        onEdit={(post) => {
          setSelected(null)
          setEditing(post)
          setComposing(true)
        }}
      />
      {composing ? (
        <PostComposer
          key={editing?.id ?? 'new'}
          post={editing}
          open
          onClose={(saved) => {
            setComposing(false)
            setEditing(null)
            if (saved) setSelected(saved.id)
          }}
        />
      ) : null}
    </section>
  )
}
