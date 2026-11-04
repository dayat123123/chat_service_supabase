import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach, vi } from 'vitest'

import { loadStrings } from '@/i18n'

await loadStrings('platform', 'policy', 'moderation', 'labels', 'replies')

class ResizeObserverStub {
  observe() {}
  unobserve() {}
  disconnect() {}
}

if (!('ResizeObserver' in window)) {
  Object.defineProperty(window, 'ResizeObserver', { value: ResizeObserverStub, writable: true })
}

if (!window.matchMedia) {
  Object.defineProperty(window, 'matchMedia', {
    writable: true,
    value: (query: string) => ({
      matches: false,
      media: query,
      onchange: null,
      addEventListener: () => undefined,
      removeEventListener: () => undefined,
      addListener: () => undefined,
      removeListener: () => undefined,
      dispatchEvent: () => false,
    }),
  })
}

function stub(target: object, name: string, value: unknown) {
  if (!(name in target)) Object.defineProperty(target, name, { value, writable: true, configurable: true })
}

stub(Element.prototype, 'scrollIntoView', vi.fn())
stub(Element.prototype, 'hasPointerCapture', () => false)
stub(Element.prototype, 'setPointerCapture', vi.fn())
stub(Element.prototype, 'releasePointerCapture', vi.fn())
stub(
  URL,
  'createObjectURL',
  vi.fn(() => 'blob:test'),
)
stub(URL, 'revokeObjectURL', vi.fn())

afterEach(() => {
  cleanup()
  window.localStorage.clear()
  window.sessionStorage.clear()
})
