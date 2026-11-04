import type { AccountDialog } from '../types'
import { ChangePasswordDialog } from './change-password-dialog'
import { PerformanceDialog } from './performance-dialog'
import { ProfileDialog } from './profile-dialog'
import { SignOutEverywhereDialog } from './sign-out-everywhere-dialog'

export function AccountDialogs({ dialog, onClose }: { dialog: AccountDialog | null; onClose: () => void }) {
  return (
    <>
      {dialog === 'profile' ? <ProfileDialog open onClose={onClose} /> : null}
      {dialog === 'performance' ? <PerformanceDialog open onClose={onClose} /> : null}
      {dialog === 'password' ? <ChangePasswordDialog open onClose={onClose} /> : null}
      {dialog === 'signOutEverywhere' ? <SignOutEverywhereDialog open onClose={onClose} /> : null}
    </>
  )
}
