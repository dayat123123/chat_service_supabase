import { tabs } from '@/lib/tabs'

export type AlertSound = 'ticket' | 'message'

const players = new Map<AlertSound, HTMLAudioElement>()

export function pageInBackground() {
  return document.hidden || !document.hasFocus()
}

export function playSound(sound: AlertSound, force = false) {
  if (!force && !tabs.isLeader()) return
  let player = players.get(sound)
  if (!player) {
    player = new Audio(`/sounds/${sound}.wav`)
    players.set(sound, player)
  }
  player.currentTime = 0
  void player.play().catch(() => undefined)
}

export function notificationPermission(): NotificationPermission | 'unsupported' {
  return typeof Notification === 'undefined' ? 'unsupported' : Notification.permission
}

export async function requestNotificationPermission() {
  if (typeof Notification === 'undefined') return 'unsupported' as const
  return Notification.requestPermission()
}

export function browserNotify(options: { title: string; body: string; tag?: string; onClick?: () => void }) {
  if (!tabs.isLeader() || notificationPermission() !== 'granted') return
  const notification = new Notification(options.title, { body: options.body, tag: options.tag })
  notification.onclick = () => {
    window.focus()
    notification.close()
    options.onClick?.()
  }
}
