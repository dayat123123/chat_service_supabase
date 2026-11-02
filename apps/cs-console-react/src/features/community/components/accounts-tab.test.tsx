import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { AgentProfile } from '@/features/presence/types'
import type * as SupabaseModule from '@/lib/supabase'
import { agentFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { communityApi } from '../api'
import type { OfficialAccount } from '../types'
import { AccountsTab } from './accounts-tab'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    communityApi: {
      ...actual.communityApi,
      accounts: vi.fn(),
      saveAccount: vi.fn(),
      uploadAvatar: vi.fn(),
      removeAvatar: vi.fn(),
      findUsers: vi.fn(),
    },
  }
})

vi.mock('@/lib/supabase', async (importOriginal) => {
  const actual = await importOriginal<typeof SupabaseModule>()
  return {
    ...actual,
    appEnv: () => ({ supabaseUrl: 'http://localhost:8000', publicApiUrl: 'https://api.olt.test' }),
  }
})

const avatar = 'https://api.olt.test/storage/v1/object/public/avatars/acc-1/avatar-1.jpg'

const research: OfficialAccount = {
  id: 'acc-1',
  username: 'olt_research',
  display_name: 'OLT Research',
  avatar_url: avatar,
  bio: 'Riset harian',
  follower_count: 1200,
  post_count: 45,
  created_at: '2026-11-01T02:00:00.000Z',
  created_by: 'Sinta',
  disabled_at: null,
}

const manager: AgentProfile = {
  ...agentFixture,
  id: 'sinta',
  display_name: 'Sinta',
  roles: ['cs_super_admin'],
  community_permissions: ['community.accounts'],
}

function renderTab() {
  return renderWithProviders(
    <>
      <AccountsTab />
      <Toaster />
    </>,
    manager,
  )
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(communityApi.accounts).mockResolvedValue([research])
  vi.mocked(communityApi.removeAvatar).mockResolvedValue(undefined)
})

describe('AccountsTab', () => {
  it('creates an official account with a live preview of how it looks in the app', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.saveAccount).mockResolvedValue({ ...research, id: 'acc-2', avatar_url: null })
    renderTab()

    await user.click(await screen.findByRole('button', { name: 'Buat akun resmi' }))
    const dialog = screen.getByRole('dialog', { name: 'Buat akun resmi' })
    await user.click(within(dialog).getByRole('button', { name: 'Buat akun' }))
    expect(within(dialog).getByText('Nama tampilan 2–60 karakter')).toBeVisible()
    expect(communityApi.saveAccount).not.toHaveBeenCalled()

    await user.type(within(dialog).getByLabelText('Nama tampilan'), 'OLT Riset Pasar')
    await user.type(within(dialog).getByLabelText('Username'), '@riset pasar')
    expect(within(dialog).getByLabelText('Username')).toHaveValue('riset_pasar')
    const preview = within(dialog).getByRole('figure', { name: 'Tampilan di aplikasi' })
    expect(within(preview).getByText('OLT Riset Pasar')).toBeInTheDocument()
    expect(within(preview).getByText('@riset_pasar')).toBeInTheDocument()
    expect(within(preview).getByText('Resmi')).toBeInTheDocument()
    expect(within(dialog).getByText('15/60')).toBeInTheDocument()

    await user.click(within(dialog).getByRole('button', { name: 'Buat akun' }))

    await waitFor(() =>
      expect(communityApi.saveAccount).toHaveBeenCalledWith(null, {
        username: 'riset_pasar',
        display_name: 'OLT Riset Pasar',
        bio: null,
        avatar_url: null,
      }),
    )
    expect(communityApi.saveAccount).toHaveBeenCalledTimes(1)
    expect(communityApi.uploadAvatar).not.toHaveBeenCalled()
    expect(await screen.findByText('Akun resmi dibuat.')).toBeInTheDocument()
  })

  it('removes the photo and deletes the old file after saving', async () => {
    const user = userEvent.setup()
    vi.mocked(communityApi.saveAccount).mockResolvedValue({ ...research, avatar_url: null })
    renderTab()

    await user.click(await screen.findByRole('button', { name: 'Ubah' }))
    const dialog = screen.getByRole('dialog', { name: 'Ubah akun resmi' })
    await user.click(within(dialog).getByRole('button', { name: 'Hapus foto' }))
    expect(within(dialog).getByRole('button', { name: 'Batalkan' })).toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'Simpan' }))

    await waitFor(() =>
      expect(communityApi.saveAccount).toHaveBeenCalledWith('acc-1', {
        username: 'olt_research',
        display_name: 'OLT Research',
        bio: 'Riset harian',
        avatar_url: null,
      }),
    )
    await waitFor(() => expect(communityApi.removeAvatar).toHaveBeenCalledWith('acc-1', avatar))
    expect(await screen.findByText('Akun resmi disimpan.')).toBeInTheDocument()
  })

  it('warns that old mentions stop working when the username changes', async () => {
    const user = userEvent.setup()
    renderTab()

    await user.click(await screen.findByRole('button', { name: 'Ubah' }))
    const dialog = screen.getByRole('dialog', { name: 'Ubah akun resmi' })
    const username = within(dialog).getByLabelText('Username')
    await user.clear(username)
    await user.type(username, 'olt_riset')

    expect(
      within(dialog).getByText(
        'Mention lama yang memakai username sebelumnya tidak lagi mengarah ke akun ini.',
      ),
    ).toBeInTheDocument()
  })
})
