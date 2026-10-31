import { describe, expect, it } from 'vitest'

import { cn } from './utils'

describe('cn', () => {
  it('keeps custom font sizes next to text colors', () => {
    expect(cn('text-row text-primary-foreground')).toBe('text-row text-primary-foreground')
    expect(cn('text-muted-foreground', 'text-label')).toBe('text-muted-foreground text-label')
  })

  it('still resolves conflicts inside the font size scale', () => {
    expect(cn('text-sm', 'text-row')).toBe('text-row')
    expect(cn('text-panel', 'text-xs')).toBe('text-xs')
  })

  it('treats the floating shadow as a shadow size', () => {
    expect(cn('shadow-none', 'shadow-float')).toBe('shadow-float')
  })
})
