import { existsSync, readFileSync } from 'node:fs'
import type { IncomingMessage, ServerResponse } from 'node:http'
import { fileURLToPath, URL } from 'node:url'

import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import type { Plugin } from 'vite'
import { defineConfig } from 'vitest/config'

function runtimeEnv(): Plugin {
  const body = () => {
    const keyFile = fileURLToPath(new URL('../../docker/secrets/anon_key', import.meta.url))
    const anonKey =
      process.env.SUPABASE_ANON_KEY ?? (existsSync(keyFile) ? readFileSync(keyFile, 'utf8').trim() : '')
    const env = {
      SUPABASE_URL: process.env.SUPABASE_URL ?? 'http://localhost:8000',
      SUPABASE_ANON_KEY: anonKey,
      APP_ENV: process.env.APP_ENV ?? 'development',
    }
    return `window.__CS_CONSOLE_ENV__ = ${JSON.stringify(env)};\n`
  }
  const serve = (req: IncomingMessage, res: ServerResponse, next: () => void) => {
    if (req.url?.split('?')[0] !== '/env.js') {
      next()
      return
    }
    res.setHeader('Content-Type', 'text/javascript; charset=utf-8')
    res.setHeader('Cache-Control', 'no-store')
    res.end(body())
  }
  return {
    name: 'cs-console-runtime-env',
    configureServer: (server) => {
      server.middlewares.use(serve)
    },
    configurePreviewServer: (server) => {
      server.middlewares.use(serve)
    },
  }
}

export default defineConfig({
  plugins: [react(), tailwindcss(), runtimeEnv()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  server: { port: 5175, strictPort: true },
  preview: { port: 4175, strictPort: true },
  build: {
    target: 'es2022',
    sourcemap: false,
    chunkSizeWarningLimit: 600,
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
    css: false,
    restoreMocks: true,
  },
})
