import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogTitle,
} from '@/components/ui/dialog'
import { tabs } from '@/lib/tabs'

import { useAuth } from '../hooks'

const WARNING_SECONDS = 60
const ACTIVITY_EVENTS = ['pointerdown', 'keydown', 'wheel', 'touchstart', 'mousemove'] as const

export function IdleGuard({ minutes }: { minutes: number }) {
  const { t } = useTranslation()
  const signOut = useAuth((state) => state.signOut)
  const lastActivity = useRef(0)
  const lastBroadcast = useRef(0)
  const [remaining, setRemaining] = useState<number | null>(null)

  useEffect(() => {
    const limit = minutes * 60_000
    lastActivity.current = Date.now()
    const touch = (shared = false) => {
      const now = Date.now()
      lastActivity.current = now
      setRemaining(null)
      if (!shared && now - lastBroadcast.current > 5_000) {
        lastBroadcast.current = now
        tabs.send('activity', now)
      }
    }
    const onActivity = () => touch()
    ACTIVITY_EVENTS.forEach((name) => window.addEventListener(name, onActivity, { passive: true }))
    const stopListening = tabs.listen('activity', () => touch(true))
    const timer = window.setInterval(() => {
      const idle = Date.now() - lastActivity.current
      if (idle >= limit) {
        window.clearInterval(timer)
        void signOut('idle')
        return
      }
      const left = Math.ceil((limit - idle) / 1000)
      setRemaining(left <= WARNING_SECONDS ? left : null)
    }, 1_000)
    return () => {
      ACTIVITY_EVENTS.forEach((name) => window.removeEventListener(name, onActivity))
      stopListening()
      window.clearInterval(timer)
    }
  }, [minutes, signOut])

  return (
    <AlertDialog open={remaining !== null}>
      <AlertDialogContent>
        <AlertDialogTitle>{t('auth.idleTitle')}</AlertDialogTitle>
        <AlertDialogDescription aria-live="polite">
          {t('auth.idleBody', { seconds: remaining ?? 0 })}
        </AlertDialogDescription>
        <div className="flex justify-end">
          <AlertDialogAction
            onClick={() => {
              lastActivity.current = Date.now()
              setRemaining(null)
              tabs.send('activity', Date.now())
            }}
          >
            {t('auth.stayIn')}
          </AlertDialogAction>
        </div>
      </AlertDialogContent>
    </AlertDialog>
  )
}
