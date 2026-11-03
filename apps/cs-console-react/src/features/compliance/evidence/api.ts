import { toApiError } from '@/lib/errors'
import { rpc, supabase } from '@/lib/supabase'

import { sha256Bytes } from './logic'
import {
  EVIDENCE_PAGE_SIZE,
  type EvidenceBundle,
  type EvidenceCursor,
  type EvidenceDetail,
  type EvidenceListFilter,
  type EvidencePage,
  type EvidenceStatus,
  type FileCheck,
  type VerifyResult,
} from './types'

const bucket = () => supabase().storage.from('evidence')

function withCustody<T extends { custody?: EvidenceStatus['custody'] | null }>(raw: T) {
  return { ...raw, custody: raw.custody ?? [] }
}

export const evidenceApi = {
  list: async (filter: EvidenceListFilter, cursor: EvidenceCursor | null): Promise<EvidencePage> => {
    const raw = await rpc<EvidencePage>('evidence_list', {
      p_query: filter.query.trim() || null,
      p_filter: filter.filter,
      p_source: filter.source,
      p_before_seq: cursor?.before_seq ?? null,
      p_limit: EVIDENCE_PAGE_SIZE,
    })
    return { ...raw, rows: raw.rows ?? [] }
  },
  detail: async (id: string): Promise<EvidenceDetail> => {
    const raw = await rpc<EvidenceDetail>('evidence_detail', { p_id: id })
    return {
      ...withCustody(raw),
      files_detail: raw.files_detail ?? [],
      reports: raw.reports ?? [],
      content: { ...raw.content, attachments: raw.content?.attachments ?? [] },
      context: raw.context ?? {},
    }
  },
  verify: async (id: string): Promise<VerifyResult> => {
    const raw = await rpc<VerifyResult>('evidence_verify', { p_id: id })
    return { ...raw, files: raw.files ?? [], status: withCustody(raw.status) }
  },
  fileChecked: (fileId: number, sha256: string) =>
    rpc<FileCheck>('evidence_file_checked', { p_file_id: fileId, p_sha256: sha256 }),
  setHold: async (id: string, hold: boolean, reason: string): Promise<EvidenceStatus> =>
    withCustody(await rpc<EvidenceStatus>('evidence_set_hold', { p_id: id, p_hold: hold, p_reason: reason })),
  exportBundle: async (id: string, purpose: string): Promise<EvidenceBundle> => {
    const raw = await rpc<EvidenceBundle>('evidence_export', { p_id: id, p_purpose: purpose })
    return { ...raw, files: raw.files ?? [] }
  },
  signedUrl: async (objectName: string, seconds: number) => {
    const { data, error } = await bucket().createSignedUrl(objectName, seconds)
    if (error) throw toApiError(error)
    return data.signedUrl
  },
  fileHash: async (objectName: string) => {
    const { data, error } = await bucket().download(objectName)
    if (error) throw toApiError(error)
    return sha256Bytes(await data.arrayBuffer())
  },
}
