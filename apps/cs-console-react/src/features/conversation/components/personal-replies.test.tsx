import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'

import { ApiError } from '@/lib/errors'
import { agentFixture, messageFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { dismissToasts, Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { conversationApi } from '../api'
import type { SendRequest } from '../hooks'
import type { PersonalQuickReply, QuickReply, SendResult } from '../types'
import { Composer } from './composer'

const personal: PersonalQuickReply = {
  id: 'p1',
  scope: 'personal',
  shortcut: 'salam-pagi',
  title: 'Salam pagi saya',
  body: 'Pagi {nama}, saya {nama_cs} siap membantu.',
  updated_at: '2026-11-04T02:00:00.000Z',
}

const shared: QuickReply[] = [
  { id: 'g1', scope: 'global', shortcut: 'salam', title: 'Salam pembuka', body: 'Halo {nama}.' },
  { id: 'g2', scope: 'global', shortcut: 'tutup', title: 'Penutup', body: 'Terima kasih.' },
]

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    conversationApi: {
      ...actual.conversationApi,
      quickReplies: vi.fn(),
      myQuickReplies: vi.fn(),
      saveMyQuickReply: vi.fn(),
      deleteMyQuickReply: vi.fn(),
    },
  }
})

function setup() {
  const send = vi.fn<(request: SendRequest) => Promise<SendResult>>(() =>
    Promise.resolve({ status: 'sent', message: messageFixture() }),
  )
  const user = userEvent.setup()
  renderWithProviders(
    <>
      <Composer
        ticket={ticketFixture()}
        agent={agentFixture}
        replyTo={null}
        onCancelReply={vi.fn()}
        send={send}
        onTyping={vi.fn()}
        onStopTyping={vi.fn()}
      />
      <Toaster />
    </>,
  )
  return { send, user, box: screen.getByRole('textbox', { name: 'Balas' }) }
}

async function openManager(user: ReturnType<typeof userEvent.setup>, box: HTMLElement) {
  await user.type(box, '/')
  await user.click(await screen.findByRole('button', { name: 'Kelola balasan pribadi' }))
  return screen.findByRole('dialog', { name: 'Balasan cepat pribadi' }, { timeout: 5_000 })
}

describe('personal quick replies in the composer', () => {
  beforeAll(async () => {
    await import('./personal-replies-dialog')
  })

  beforeEach(() => {
    vi.clearAllMocks()
    window.localStorage.clear()
    vi.mocked(conversationApi.quickReplies).mockResolvedValue([personal, ...shared])
    vi.mocked(conversationApi.myQuickReplies).mockResolvedValue([personal])
  })
  afterEach(dismissToasts)

  it('shows Pribadi and Bersama groups and searches both', async () => {
    const { user, box } = setup()
    await user.type(box, '/sal')
    const list = await screen.findByRole('listbox', { name: 'Balasan cepat' })
    const groups = within(list).getAllByRole('group')
    expect(groups.map((group) => group.getAttribute('aria-labelledby'))).toHaveLength(2)
    expect(within(groups[0]!).getByText('Pribadi')).toBeInTheDocument()
    expect(within(groups[0]!).getByRole('option', { name: /salam-pagi/ })).toBeInTheDocument()
    expect(within(groups[1]!).getByText('Bersama')).toBeInTheDocument()
    expect(within(groups[1]!).getByRole('option', { name: /Salam pembuka/ })).toBeInTheDocument()
    expect(within(list).queryByRole('option', { name: /Penutup/ })).not.toBeInTheDocument()
  })

  it('keeps arrow keys and Enter working across both groups', async () => {
    const { user, box } = setup()
    await user.type(box, '/sal')
    const options = await screen.findAllByRole('option')
    expect(options[0]).toHaveAttribute('aria-selected', 'true')
    await user.keyboard('{ArrowDown}')
    expect(screen.getAllByRole('option')[1]).toHaveAttribute('aria-selected', 'true')
    await user.keyboard('{ArrowDown}')
    expect(screen.getAllByRole('option')[0]).toHaveAttribute('aria-selected', 'true')
    await user.keyboard('{Enter}')
    expect(box).toHaveValue('Pagi Budi Santoso, saya Rina siap membantu.')
  })

  it('inserts personal text into the box so sending still goes through the normal checks', async () => {
    vi.mocked(conversationApi.quickReplies).mockResolvedValue([
      { ...personal, body: 'Mohon kirimkan kode OTP Anda' },
    ])
    const { send, user, box } = setup()
    await user.type(box, '/salam-p')
    await user.keyboard('{Enter}')
    expect(box).toHaveValue('Mohon kirimkan kode OTP Anda')
    expect(screen.getByRole('alert')).toHaveTextContent('CS tidak boleh meminta OTP')
    await user.keyboard('{Enter}')
    expect(send).not.toHaveBeenCalled()
  })

  it('creates a personal reply from the picker', async () => {
    vi.mocked(conversationApi.saveMyQuickReply).mockResolvedValue({ ...personal, id: 'p2', title: 'Refund' })
    const { user, box } = setup()
    const dialog = await openManager(user, box)
    expect(await within(dialog).findByText('Salam pagi saya')).toBeInTheDocument()
    expect(within(dialog).getByText('1/50 balasan')).toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'Tambah balasan' }))
    await user.type(screen.getByLabelText('Judul'), 'Refund')
    await user.type(screen.getByLabelText('Isi balasan'), 'Dana kembali dalam 3 hari kerja.')
    await user.click(screen.getByRole('button', { name: 'Simpan' }))
    await waitFor(() =>
      expect(conversationApi.saveMyQuickReply).toHaveBeenCalledWith({
        id: null,
        title: 'Refund',
        body: 'Dana kembali dalam 3 hari kerja.',
        shortcut: '',
      }),
    )
    expect(await screen.findByRole('dialog', { name: 'Balasan cepat pribadi' })).toBeInTheDocument()
  })

  it('edits and deletes a personal reply', async () => {
    vi.mocked(conversationApi.saveMyQuickReply).mockResolvedValue({ ...personal, title: 'Salam baru' })
    vi.mocked(conversationApi.deleteMyQuickReply).mockResolvedValue({ deleted: true })
    const { user, box } = setup()
    const dialog = await openManager(user, box)
    await user.click(await within(dialog).findByRole('button', { name: 'Ubah Salam pagi saya' }))
    const title = screen.getByLabelText('Judul')
    await user.clear(title)
    await user.type(title, 'Salam baru')
    await user.click(screen.getByRole('button', { name: 'Simpan' }))
    await waitFor(() =>
      expect(conversationApi.saveMyQuickReply).toHaveBeenCalledWith(
        expect.objectContaining({ id: 'p1', title: 'Salam baru', shortcut: 'salam-pagi' }),
      ),
    )
    const list = await screen.findByRole('dialog', { name: 'Balasan cepat pribadi' })
    await user.click(await within(list).findByRole('button', { name: 'Hapus Salam pagi saya' }))
    await user.click(within(list).getByRole('button', { name: 'Ya, hapus' }))
    await waitFor(() => expect(conversationApi.deleteMyQuickReply).toHaveBeenCalledWith('p1'))
  })

  it('blocks secret requests and shows server errors in the form', async () => {
    vi.mocked(conversationApi.saveMyQuickReply).mockRejectedValue(
      new ApiError('duplicate_shortcut', 'Pintasan sudah dipakai balasan lain', 409),
    )
    const { user, box } = setup()
    const dialog = await openManager(user, box)
    await user.click(within(dialog).getByRole('button', { name: 'Tambah balasan' }))
    await user.type(screen.getByLabelText('Judul'), 'Verifikasi')
    await user.type(screen.getByLabelText('Isi balasan'), 'Berikan PIN Anda')
    expect(screen.getByRole('alert')).toHaveTextContent('tidak boleh meminta OTP, PIN, atau password')
    await user.click(screen.getByRole('button', { name: 'Simpan' }))
    expect(conversationApi.saveMyQuickReply).not.toHaveBeenCalled()
    const body = screen.getByLabelText('Isi balasan')
    await user.clear(body)
    await user.type(body, 'Mohon tunggu sebentar')
    await user.type(screen.getByLabelText('Pintasan (opsional)'), 'salam-pagi')
    await user.click(screen.getByRole('button', { name: 'Simpan' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Pintasan sudah dipakai balasan pribadi lain')
  })

  it('disables adding at the 50 reply limit', async () => {
    vi.mocked(conversationApi.myQuickReplies).mockResolvedValue(
      Array.from({ length: 50 }, (_, index) => ({ ...personal, id: `p${index}`, shortcut: `r-${index}` })),
    )
    const { user, box } = setup()
    const dialog = await openManager(user, box)
    expect(await within(dialog).findByText('50/50 balasan')).toBeInTheDocument()
    expect(within(dialog).getByRole('button', { name: 'Tambah balasan' })).toBeDisabled()
    expect(within(dialog).getByRole('status')).toHaveTextContent('Batas 50 balasan pribadi tercapai')
  })
})
