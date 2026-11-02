import { act, fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useAuth } from '@/features/auth/hooks'
import type * as PresenceApiModule from '@/features/presence/api'
import { presenceApi } from '@/features/presence/api'
import type { AgentProfile } from '@/features/presence/types'
import { agentFixture, messageFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'
import { dismissToasts, findToast, Toaster } from '@/test/toast'

import type * as ApiModule from '../api'
import { conversationApi } from '../api'
import type { SendRequest } from '../hooks'
import type { SendResult } from '../types'
import { Composer } from './composer'

vi.mock('@/features/presence/api', async (importOriginal) => {
  const actual = await importOriginal<typeof PresenceApiModule>()
  return { ...actual, presenceApi: { ...actual.presenceApi, setStatus: vi.fn() } }
})

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    conversationApi: {
      ...actual.conversationApi,
      quickReplies: vi.fn(() =>
        Promise.resolve([
          {
            id: 'q1',
            scope: 'global',
            shortcut: 'salam',
            title: 'Salam pembuka',
            body: 'Halo {nama}, saya {nama_cs}. Tiket {nomor_tiket}.',
          },
        ]),
      ),
      addNote: vi.fn(() => Promise.resolve({})),
    },
  }
})

function setup(agent: AgentProfile = agentFixture) {
  const send = vi.fn<(request: SendRequest) => Promise<SendResult>>(() =>
    Promise.resolve({ status: 'sent', message: messageFixture() }),
  )
  const user = userEvent.setup()
  renderWithProviders(
    <>
      <Composer
        ticket={ticketFixture()}
        agent={agent}
        replyTo={null}
        onCancelReply={vi.fn()}
        send={send}
        onTyping={vi.fn()}
        onStopTyping={vi.fn()}
      />
      <Toaster />
    </>,
    agent,
  )
  return { send, user, box: screen.getByRole('textbox', { name: 'Balas' }) }
}

const offlineAgent: AgentProfile = { ...agentFixture, status: 'offline' }

describe('Composer', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    window.localStorage.clear()
  })
  afterEach(dismissToasts)

  it('sends on Enter and clears the box', async () => {
    const { send, user, box } = setup()
    await user.type(box, 'Halo kak')
    expect(screen.getByText('8/4000')).toBeInTheDocument()
    await user.keyboard('{Enter}')
    await waitFor(() => expect(send).toHaveBeenCalledTimes(1))
    expect(send.mock.calls[0]?.[0]).toMatchObject({ body: 'Halo kak', files: [], replyTo: null })
    expect(box).toHaveValue('')
  })

  it('adds a new line on Shift+Enter without sending', async () => {
    const { send, user, box } = setup()
    await user.type(box, 'Baris satu{Shift>}{Enter}{/Shift}Baris dua')
    expect(box).toHaveValue('Baris satu\nBaris dua')
    expect(send).not.toHaveBeenCalled()
  })

  it('blocks requests for OTP, PIN or passwords before sending', async () => {
    const { send, user, box } = setup()
    await user.type(box, 'Mohon kirimkan kode OTP Anda')
    expect(screen.getByRole('alert')).toHaveTextContent('CS tidak boleh meminta OTP')
    expect(screen.getByRole('button', { name: 'Kirim' })).toBeDisabled()
    await user.keyboard('{Enter}')
    expect(send).not.toHaveBeenCalled()
  })

  it('inserts a quick reply with variables filled in', async () => {
    const { user, box } = setup()
    await user.type(box, '/sal')
    const option = await screen.findByRole('option', { name: /salam/i })
    expect(option).toHaveAttribute('aria-selected', 'true')
    await user.keyboard('{Enter}')
    expect(box).toHaveValue('Halo Budi Santoso, saya Rina. Tiket CS-000123.')
  })

  it('saves internal notes through the note endpoint', async () => {
    const { send, user } = setup()
    await user.click(screen.getByRole('tab', { name: /Catatan internal/ }))
    expect(screen.getByText('Tidak terlihat nasabah')).toBeInTheDocument()
    const note = screen.getByRole('textbox', { name: 'Catatan internal' })
    await user.type(note, 'Nasabah minta ditelepon balik')
    await user.keyboard('{Enter}')
    await waitFor(() =>
      expect(conversationApi.addNote).toHaveBeenCalledWith('Nasabah minta ditelepon balik', {
        ticketId: ticketFixture().id,
      }),
    )
    expect(send).not.toHaveBeenCalled()
  })

  it('offers only help links and quick options as special messages', async () => {
    const { send, user } = setup()
    await user.click(screen.getByRole('button', { name: 'Kirim lainnya' }))
    const items = await screen.findAllByRole('menuitem')
    expect(items.map((item) => item.textContent)).toEqual(['Tautan bantuan', 'Pilihan cepat'])
    await user.click(screen.getByRole('menuitem', { name: 'Pilihan cepat' }))
    const dialog = await screen.findByRole('dialog', { name: 'Kirim pilihan cepat' })
    await user.type(within(dialog).getByLabelText('Pertanyaan'), 'Dana sudah masuk?')
    await user.type(within(dialog).getByRole('textbox', { name: 'Pilihan 1' }), 'Sudah')
    await user.type(within(dialog).getByRole('textbox', { name: 'Pilihan 2' }), 'Belum')
    await user.click(within(dialog).getByRole('button', { name: 'Kirim' }))
    await waitFor(() =>
      expect(send).toHaveBeenCalledWith({
        body: 'Dana sudah masuk?',
        kind: 'quick_reply',
        payload: { options: ['Sudah', 'Belum'] },
      }),
    )
  })

  it('locks the reply box while Offline but keeps the draft and offers to go Online', async () => {
    window.localStorage.setItem(
      `cs-console.draft.${offlineAgent.id}.${ticketFixture().id}.reply`,
      'Draf sebelum Offline',
    )
    const { send, user, box } = setup(offlineAgent)

    expect(screen.getByRole('status')).toHaveTextContent(
      'Anda sedang Offline. Ubah ke Online untuk mengetik dan mengirim balasan.',
    )
    expect(box).toBeDisabled()
    expect(box).toHaveValue('Draf sebelum Offline')
    for (const name of ['Lampirkan gambar atau PDF', 'Sisipkan balasan cepat', 'Kirim lainnya', 'Kirim']) {
      expect(screen.getByRole('button', { name })).toBeDisabled()
    }

    await user.type(box, 'tambahan')
    expect(box).toHaveValue('Draf sebelum Offline')
    expect(send).not.toHaveBeenCalled()
  })

  it('unlocks the reply box after going Online from the hint', async () => {
    vi.mocked(presenceApi.setStatus).mockResolvedValue({ ...agentFixture, status: 'online' })
    const { user, box } = setup(offlineAgent)

    await user.click(screen.getByRole('button', { name: 'Ubah ke Online' }))

    expect(presenceApi.setStatus).toHaveBeenCalledWith('online', undefined)
    await waitFor(() => expect(box).toBeEnabled())
    expect(screen.queryByRole('status')).not.toBeInTheDocument()
  })

  it('guards special messages if the agent goes Offline while the dialog is open', async () => {
    const { send, user } = setup()
    await user.click(screen.getByRole('button', { name: 'Kirim lainnya' }))
    await user.click(await screen.findByRole('menuitem', { name: 'Pilihan cepat' }))
    const dialog = await screen.findByRole('dialog', { name: 'Kirim pilihan cepat' })
    await user.type(within(dialog).getByLabelText('Pertanyaan'), 'Dana sudah masuk?')
    await user.type(within(dialog).getByRole('textbox', { name: 'Pilihan 1' }), 'Sudah')
    await user.type(within(dialog).getByRole('textbox', { name: 'Pilihan 2' }), 'Belum')
    act(() => useAuth.getState().updateAgent(offlineAgent))
    await user.click(within(dialog).getByRole('button', { name: 'Kirim' }))

    await findToast('Anda sedang Offline. Ubah ke Online dulu untuk membalas nasabah.')
    expect(send).not.toHaveBeenCalled()
  })

  it('still saves internal notes while Offline', async () => {
    const { user } = setup(offlineAgent)
    await user.click(screen.getByRole('tab', { name: /Catatan internal/ }))
    expect(screen.queryByRole('status')).not.toBeInTheDocument()
    await user.type(screen.getByRole('textbox', { name: 'Catatan internal' }), 'Telepon balik besok')
    await user.keyboard('{Enter}')
    await waitFor(() => expect(conversationApi.addNote).toHaveBeenCalledTimes(1))
  })

  it('attaches PDFs and refuses videos with a clear reason', async () => {
    const { send, user } = setup()
    const input = document.querySelector<HTMLInputElement>('input[type="file"]')
    expect(input?.accept).toContain('application/pdf')
    fireEvent.change(input!, { target: { files: [new File(['x'], 'rekaman.mp4', { type: 'video/mp4' })] } })
    expect(await findToast(/^rekaman\.mp4 tidak didukung/)).toBeVisible()

    const pdf = new File([new Uint8Array(2048)], 'Bukti Transfer.pdf', { type: 'application/pdf' })
    fireEvent.change(input!, { target: { files: [pdf] } })
    expect(screen.getByText('Bukti Transfer.pdf')).toBeVisible()
    expect(screen.getByText('2 KB')).toBeVisible()
    await user.click(screen.getByRole('button', { name: 'Kirim' }))
    await waitFor(() => expect(send).toHaveBeenCalledTimes(1))
    expect(send.mock.calls[0]?.[0]?.files?.map((item) => item.file)).toEqual([pdf])
  })

  it('keeps a draft per ticket', async () => {
    const { user, box } = setup()
    await user.type(box, 'Draf belum dikirim')
    expect(
      window.localStorage.getItem(`cs-console.draft.${agentFixture.id}.${ticketFixture().id}.reply`),
    ).toBe('Draf belum dikirim')
  })
})
