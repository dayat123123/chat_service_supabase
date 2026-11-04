import { MAX_REPLY_BODY, MAX_REPLY_TITLE, type QuickReply } from './types'

export type SlashToken = { start: number; end: number; query: string }

export function slashToken(value: string, caret: number): SlashToken | null {
  const before = value.slice(0, caret)
  const match = /(^|\s)\/([\w-]*)$/.exec(before)
  if (!match) return null
  const query = match[2] ?? ''
  return { start: caret - query.length - 1, end: caret, query }
}

export function filterQuickReplies(replies: QuickReply[], query: string, limit = 8) {
  const q = query.trim().toLowerCase()
  if (!q) return replies.slice(0, limit)
  const scored = replies
    .map((reply) => {
      const shortcut = reply.shortcut.toLowerCase()
      const title = reply.title.toLowerCase()
      const body = reply.body.toLowerCase()
      const score = shortcut.startsWith(q)
        ? 0
        : shortcut.includes(q)
          ? 1
          : title.includes(q)
            ? 2
            : body.includes(q)
              ? 3
              : 9
      return { reply, score }
    })
    .filter((item) => item.score < 9)
    .sort((a, b) => a.score - b.score || a.reply.shortcut.localeCompare(b.reply.shortcut))
  return scored.slice(0, limit).map((item) => item.reply)
}

export function fillVariables(
  body: string,
  values: { customer: string; ticketNumber: string; agent: string },
) {
  return body
    .replaceAll('{nama}', values.customer)
    .replaceAll('{nomor_tiket}', values.ticketNumber)
    .replaceAll('{nama_cs}', values.agent)
}

export function applyQuickReply(value: string, token: SlashToken, text: string) {
  const next = value.slice(0, token.start) + text + value.slice(token.end)
  return { value: next, caret: token.start + text.length }
}

export const isPersonalReply = (reply: Pick<QuickReply, 'scope'>) => reply.scope === 'personal'

export type QuickReplyGroups = { personal: QuickReply[]; shared: QuickReply[] }

export function groupQuickReplies(replies: QuickReply[], query: string, limit = 8): QuickReplyGroups {
  return {
    personal: filterQuickReplies(replies.filter(isPersonalReply), query, limit),
    shared: filterQuickReplies(
      replies.filter((reply) => !isPersonalReply(reply)),
      query,
      limit,
    ),
  }
}

export const flattenGroups = (groups: QuickReplyGroups) => [...groups.personal, ...groups.shared]

const shortcutPattern = /^[a-z0-9_-]{2,32}$/

export function replyDraftProblems(draft: { title: string; body: string; shortcut: string }) {
  const title = draft.title.trim()
  const body = draft.body.trim()
  const shortcut = draft.shortcut.trim()
  return {
    title: title.length === 0 || title.length > MAX_REPLY_TITLE,
    body: body.length === 0 || body.length > MAX_REPLY_BODY,
    shortcut: shortcut !== '' && !shortcutPattern.test(shortcut),
  }
}
