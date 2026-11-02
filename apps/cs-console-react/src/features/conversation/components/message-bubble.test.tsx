import { screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'

import { messageFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import type * as ApiModule from '../api'
import { conversationApi } from '../api'
import { MessageBubble } from './message-bubble'

vi.mock('../api', async (importOriginal) => {
  const actual = await importOriginal<typeof ApiModule>()
  return {
    ...actual,
    conversationApi: {
      ...actual.conversationApi,
      signedUrl: vi.fn((path: string, bucket: string) =>
        Promise.resolve(`https://cs.test/${bucket}/${path}`),
      ),
    },
  }
})

describe('MessageBubble', () => {
  it('renders legacy card and unknown kinds as plain text', () => {
    renderWithProviders(
      <>
        <MessageBubble
          message={messageFixture({
            id: 'c1',
            kind: 'card',
            body: 'Order ORD-20261030-88412',
            payload: { card: 'order', ref: 'ORD-20261030-88412' },
            sender_role: 'agent',
          })}
          staff
          first
          last
          read={false}
          trustedHost={() => false}
        />
        <MessageBubble
          message={messageFixture({ id: 'u1', kind: 'sticker', body: 'Terima kasih kak' })}
          staff={false}
          first
          last
          read={false}
          trustedHost={() => false}
        />
      </>,
    )
    expect(screen.getByText('Order ORD-20261030-88412')).toBeInTheDocument()
    expect(screen.getByText('Terima kasih kak')).toBeInTheDocument()
    expect(screen.queryByRole('button')).not.toBeInTheDocument()
  })

  it('shows PDFs as a file card that opens in a new tab', async () => {
    renderWithProviders(
      <MessageBubble
        message={messageFixture({
          id: 'd1',
          body: 'Bukti transfer',
          attachments: [
            {
              bucket: 'cs-documents',
              path: 'rooms/r1/u1/a.pdf',
              mime: 'application/pdf',
              name: 'Bukti Transfer.pdf',
              size: 182000,
            },
          ],
        })}
        staff={false}
        first
        last
        read={false}
        trustedHost={() => false}
      />,
    )
    const link = await screen.findByRole('link', { name: 'Buka Bukti Transfer.pdf' })
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', 'noopener noreferrer')
    await vi.waitFor(() =>
      expect(link).toHaveAttribute('href', 'https://cs.test/cs-documents/rooms/r1/u1/a.pdf'),
    )
    expect(screen.getByText('PDF · 178 KB')).toBeInTheDocument()
    expect(conversationApi.signedUrl).toHaveBeenCalledWith('rooms/r1/u1/a.pdf', 'cs-documents')
  })
})
