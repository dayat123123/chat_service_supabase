import { useEffect } from 'react'

import { runCommand, useOverlays } from '@/features/command/bus'

function typingTarget(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) return false
  if (target.isContentEditable) return true
  const tag = target.tagName
  return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT'
}

function overlayOpen() {
  return (
    document.querySelector('[role="dialog"][data-state="open"], [role="alertdialog"][data-state="open"]') !==
    null
  )
}

export function useGlobalHotkeys(enabledTicketKeys: boolean) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const { setPalette, setShortcuts, palette } = useOverlays.getState()
      const mod = event.ctrlKey || event.metaKey
      if (mod && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        setPalette(!palette)
        return
      }
      if (mod && event.key === 'Enter') {
        if (runCommand('send')) event.preventDefault()
        return
      }
      if (event.altKey || mod || event.repeat || typingTarget(event.target) || overlayOpen()) return
      if (event.key === '?') {
        event.preventDefault()
        setShortcuts(true)
        return
      }
      if (!enabledTicketKeys) return
      const command = (
        { j: 'next', k: 'previous', a: 'claim', r: 'focusReply', n: 'focusNote', e: 'resolve' } as const
      )[event.key.toLowerCase() as 'j']
      if (command && runCommand(command)) event.preventDefault()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [enabledTicketKeys])
}
