import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { agentFixture, messageFixture, ticketFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { conversationApi } from '../api'
import type { SendRequest } from '../hooks'
import type { SendResult } from '../types'
import { Composer } from './composer'

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

function setup() {
  const send = vi.fn<(request: SendRequest) => Promise<SendResult>>(() =>
    Promise.resolve({ status: 'sent', message: messageFixture() }),
  )
  const user = userEvent.setup()
  renderWithProviders(
    <Composer
      ticket={ticketFixture()}
      agent={agentFixture}
      replyTo={null}
      onCancelReply={vi.fn()}
      send={send}
      onTyping={vi.fn()}
      onStopTyping={vi.fn()}
    />,
  )
  return { send, user, box: screen.getByRole('textbox', { name: 'Balas' }) }
}

describe('Composer', () => {
  beforeEach(() => vi.clearAllMocks())

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

  it('keeps a draft per ticket', async () => {
    const { user, box } = setup()
    await user.type(box, 'Draf belum dikirim')
    expect(
      window.localStorage.getItem(`cs-console.draft.${agentFixture.id}.${ticketFixture().id}.reply`),
    ).toBe('Draf belum dikirim')
  })
})
