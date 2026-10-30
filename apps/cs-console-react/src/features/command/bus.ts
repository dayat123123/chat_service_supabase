import { useEffect } from 'react'
import { create } from 'zustand'

export type ConsoleCommand =
  | 'next'
  | 'previous'
  | 'claim'
  | 'focusReply'
  | 'focusNote'
  | 'resolve'
  | 'release'
  | 'transfer'
  | 'waitCustomer'
  | 'send'

const handlers = new Map<ConsoleCommand, Set<() => void>>()

export function runCommand(command: ConsoleCommand) {
  const set = handlers.get(command)
  if (!set || set.size === 0) return false
  set.forEach((handler) => handler())
  return true
}

export function hasCommand(command: ConsoleCommand) {
  return (handlers.get(command)?.size ?? 0) > 0
}

export function useCommandHandler(command: ConsoleCommand, handler: (() => void) | null) {
  useEffect(() => {
    if (!handler) return
    const set = handlers.get(command) ?? new Set()
    set.add(handler)
    handlers.set(command, set)
    useCommandRegistry.setState((state) => ({ version: state.version + 1 }))
    return () => {
      set.delete(handler)
      useCommandRegistry.setState((state) => ({ version: state.version + 1 }))
    }
  }, [command, handler])
}

export const useCommandRegistry = create<{ version: number }>(() => ({ version: 0 }))

type Overlays = {
  palette: boolean
  shortcuts: boolean
  setPalette: (open: boolean) => void
  setShortcuts: (open: boolean) => void
}

export const useOverlays = create<Overlays>((set) => ({
  palette: false,
  shortcuts: false,
  setPalette: (palette) => set({ palette }),
  setShortcuts: (shortcuts) => set({ shortcuts }),
}))
