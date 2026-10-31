import { screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import { messageFixture } from '@/test/fixtures'
import { renderWithProviders } from '@/test/render'

import { MessageBubble } from './message-bubble'

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
})
