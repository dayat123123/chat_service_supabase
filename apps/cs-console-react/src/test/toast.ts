import { screen } from '@testing-library/react'
import { toast } from 'sonner'

export { Toaster } from 'sonner'

export async function findToast(text: string | RegExp) {
  const message = await screen.findByText(text, { selector: '[data-sonner-toast] *' })
  const element = message.closest<HTMLElement>('[data-sonner-toast]')
  if (!element) throw new Error(`Toast "${String(text)}" not found`)
  return element
}

export function dismissToasts() {
  toast.dismiss()
}
