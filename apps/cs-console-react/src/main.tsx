import '@/lib/zod-config'
import '@/styles/globals.css'

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import { App } from '@/app/app'
import { ConfigError } from '@/app/config-error'
import { readEnv } from '@/config/env'
import { prepareLanguage } from '@/i18n'
import { initSupabase } from '@/lib/supabase'

const container = document.getElementById('root')
if (!container) throw new Error('Element #root is missing')

const root = createRoot(container)
const result = readEnv()

if (result.ok) initSupabase(result.env)

void prepareLanguage().then(() =>
  root.render(
    result.ok ? (
      <StrictMode>
        <App />
      </StrictMode>
    ) : (
      <ConfigError problems={result.problems} />
    ),
  ),
)
