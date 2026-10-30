import '@/lib/zod-config'
import '@/styles/globals.css'
import '@/i18n'

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import { App } from '@/app/app'
import { ConfigError } from '@/app/config-error'
import { readEnv } from '@/config/env'
import { initSupabase } from '@/lib/supabase'

const container = document.getElementById('root')
if (!container) throw new Error('Elemen #root tidak ada')

const root = createRoot(container)
const result = readEnv()

if (result.ok) {
  initSupabase(result.env)
  root.render(
    <StrictMode>
      <App />
    </StrictMode>,
  )
} else {
  root.render(<ConfigError problems={result.problems} />)
}
