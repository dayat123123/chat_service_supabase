import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import type * as SupabaseModule from '@/lib/supabase'

import { nasabahApi } from './api'

const getSession = vi.fn()

vi.mock('@/lib/supabase', async (importOriginal) => {
  const actual = await importOriginal<typeof SupabaseModule>()
  return { ...actual, supabase: () => ({ auth: { getSession } }) }
})

const fetchMock = vi.fn<typeof fetch>()

function reply(status: number, body: unknown) {
  fetchMock.mockResolvedValueOnce(
    new Response(typeof body === 'string' ? body : JSON.stringify(body), { status }),
  )
}

describe('nasabahApi', () => {
  beforeEach(() => {
    getSession.mockResolvedValue({ data: { session: { access_token: 'console-token' } } })
    fetchMock.mockReset()
    vi.stubGlobal('fetch', fetchMock)
  })
  afterEach(() => vi.unstubAllGlobals())

  it('calls the same-origin gateway with the console session and search params', async () => {
    reply(200, {
      data: [{ LoginId: 'budi' }],
      message: 'ok',
      pagination: { current_page: 2, per_page: 30, total_items: 31, total_pages: 2 },
    })
    const page = await nasabahApi.users(2, ' budi@olt ')
    const [url, init] = fetchMock.mock.calls[0] ?? []
    expect(url).toBe('/api-nasabah/online/get-list-online-user?page=2&size=30&email=budi%40olt')
    expect((init?.headers as Record<string, string>).Authorization).toBe('Bearer console-token')
    expect(page).toMatchObject({ total: 31, totalPages: 2, rows: [{ LoginId: 'budi' }] })
  })

  it('treats the legacy "No data available" body as an empty page', async () => {
    reply(200, '{"message": "No data available"}')
    expect(await nasabahApi.openings(1, { loginId: '', custId: 'C1' })).toMatchObject({ rows: [], total: 0 })
    expect(fetchMock.mock.calls[0]?.[0]).toBe(
      '/api-nasabah/online/get-list-opening-rekening-online-user?page=1&size=30&custId=C1',
    )
  })

  it('sends decisions with only the fields the gateway trusts', async () => {
    reply(200, { message: 'Success to create approval.', data: null })
    await nasabahApi.decide({ ApprovalId: 41, LoginId: 'budi' }, false)
    expect(JSON.parse(fetchMock.mock.calls[0]?.[1]?.body as string)).toEqual({
      ApprovalId: 41,
      LoginId: 'budi',
      Status: 0,
    })
  })

  it('maps gateway codes and keeps legacy messages', async () => {
    reply(403, { code: 'self_approval', message: 'The submitter of an approval cannot decide it' })
    await expect(nasabahApi.decide({ ApprovalId: 1, LoginId: 'x' }, true)).rejects.toMatchObject({
      code: 'self_approval',
      status: 403,
    })
    reply(409, { message: 'Failed, loginId budi is exist.', data: null })
    await expect(nasabahApi.submit({ LoginId: 'budi' })).rejects.toMatchObject({
      code: 'conflict',
      detail: 'Failed, loginId budi is exist.',
    })
    reply(500, '')
    await expect(nasabahApi.catalog()).rejects.toMatchObject({ code: 'upstream_error' })
  })

  it('changes an online user status with the reason', async () => {
    reply(200, { message: 'Success update status online user for loginId budi.', data: null })
    await nasabahApi.setStatus(' budi ', 3, ' Akses mencurigakan dari luar negeri ')
    const [url, init] = fetchMock.mock.calls[0] ?? []
    expect(url).toBe('/api-nasabah/online/update-status-online-user')
    expect(init?.method).toBe('PUT')
    expect(JSON.parse(init?.body as string)).toEqual({
      LoginId: 'budi',
      Status: 3,
      Reason: 'Akses mencurigakan dari luar negeri',
    })
  })

  it('refuses to call the gateway without a console session', async () => {
    getSession.mockResolvedValue({ data: { session: null } })
    await expect(nasabahApi.catalog()).rejects.toMatchObject({ code: 'session_expired' })
    expect(fetchMock).not.toHaveBeenCalled()
  })
})
