import { AuthError, FunctionsHttpError } from '@supabase/supabase-js'

export class ApiError extends Error {
  readonly code: string
  readonly status: number | undefined
  readonly detail: string | undefined

  constructor(code: string, detail?: string, status?: number) {
    super(detail ?? code)
    this.name = 'ApiError'
    this.code = code
    this.detail = detail
    this.status = status
  }

  get isStale() {
    return this.code === 'stale_ticket'
  }
}

type PostgrestLike = { code?: string | null; message?: string | null; details?: string | null }

function isPostgrestLike(value: unknown): value is PostgrestLike {
  return typeof value === 'object' && value !== null && 'message' in value && 'code' in value
}

export function fromPostgrest(error: PostgrestLike, status?: number): ApiError {
  const code = error.code ?? ''
  const message = error.message ?? ''
  if (code.startsWith('PT')) {
    return new ApiError(message || 'unknown', error.details ?? undefined, Number(code.slice(2)) || status)
  }
  if (code === 'PGRST301' || code === 'PGRST302' || code === 'PGRST303') {
    return new ApiError('session_expired', undefined, 401)
  }
  if (code.startsWith('PGRST0')) return new ApiError('unavailable', undefined, 503)
  if (!code && /fetch|network|load failed/i.test(message)) return new ApiError('network')
  if (status === 401) return new ApiError('session_expired', undefined, 401)
  return new ApiError(code || 'unknown', message || undefined, status)
}

export function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error
  if (error instanceof AuthError) {
    return new ApiError(error.code ?? 'auth_failed', error.message, error.status)
  }
  if (error instanceof FunctionsHttpError) return new ApiError('unavailable', undefined, 502)
  if (error instanceof TypeError && /fetch|network|load failed/i.test(error.message))
    return new ApiError('network')
  if (isPostgrestLike(error)) return fromPostgrest(error)
  return new ApiError('unknown', error instanceof Error ? error.message : undefined)
}

export async function fromFunctionError(error: unknown): Promise<ApiError> {
  if (error instanceof FunctionsHttpError) {
    const response = error.context as Response
    if (response.status === 401) return new ApiError('session_expired', undefined, 401)
    try {
      const body = (await response.json()) as { code?: unknown; message?: unknown }
      if (typeof body.code === 'string') {
        return new ApiError(
          body.code,
          typeof body.message === 'string' ? body.message : undefined,
          response.status,
        )
      }
    } catch {
      return new ApiError('unavailable', undefined, response.status)
    }
    return new ApiError('unavailable', undefined, response.status)
  }
  return toApiError(error)
}
