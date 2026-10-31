import { useMutation, useQuery } from '@tanstack/react-query'
import { useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { useAgent, useAuth } from '@/features/auth/hooks'
import { errorText } from '@/lib/error-text'
import { toApiError } from '@/lib/errors'
import { readJson, writeJson, writeLocal } from '@/lib/storage'
import { appEnv, cachedAccessToken } from '@/lib/supabase'
import { tabs } from '@/lib/tabs'

import { presenceApi } from './api'
import { atCapacity, type AgentStatus } from './types'

const HEARTBEAT_MS = 20_000
const OFFLINE_CHECK_MS = 60_000
const RESUME_KEY = 'resume-status'

export function useSetStatus() {
  const updateAgent = useAuth((state) => state.updateAgent)
  return useMutation({
    mutationFn: ({ status, reason }: { status: AgentStatus; reason?: string }) =>
      presenceApi.setStatus(status, reason),
    onSuccess: (agent) => updateAgent(agent),
    onError: (error) => toast.error(errorText(error)),
  })
}

export function useClaimGate() {
  const agent = useAgent()
  const { t } = useTranslation()
  const needsOnline = agent.status !== 'online'
  const reason = needsOnline
    ? t('tickets.needOnline', { status: t(`presence.${agent.status}`) })
    : atCapacity(agent)
      ? t('tickets.atCapacity')
      : null
  return { canClaim: reason === null, needsOnline, reason }
}

export function useOnlineAgents(enabled: boolean) {
  return useQuery({
    queryKey: ['agents', 'online'],
    queryFn: presenceApi.onlineAgents,
    enabled,
    staleTime: 10_000,
  })
}

export function useHeartbeat() {
  const agent = useAgent()
  const updateAgent = useAuth((state) => state.updateAgent)
  const signOut = useAuth((state) => state.signOut)
  useEffect(() => {
    let running = false
    const beat = async () => {
      if (running || !tabs.isLeader()) return
      running = true
      try {
        const current = useAuth.getState().phase
        if (current.kind !== 'ready') return
        if (current.agent.status === 'offline') {
          await presenceApi.me()
          return
        }
        const active = await presenceApi.heartbeat()
        const latest = useAuth.getState().phase
        if (latest.kind === 'ready' && latest.agent.active_tickets !== active) {
          updateAgent({ ...latest.agent, active_tickets: active })
        }
      } catch (error) {
        if (toApiError(error).code === 'agent_required') void signOut('notStaff')
      } finally {
        running = false
      }
    }
    const timer = window.setInterval(
      () => void beat(),
      agent.status === 'offline' ? OFFLINE_CHECK_MS : HEARTBEAT_MS,
    )
    return () => window.clearInterval(timer)
  }, [agent.status, signOut, updateAgent])
}

export function useStatusOnClose() {
  const agent = useAgent()
  useEffect(() => {
    const onHide = (event: PageTransitionEvent) => {
      if (event.persisted || tabs.otherTabs() > 0) return
      const current = useAuth.getState().phase
      if (current.kind !== 'ready' || current.agent.status === 'offline' || current.agent.active_tickets > 0)
        return
      const token = cachedAccessToken()
      if (!token) return
      writeJson(RESUME_KEY, { status: current.agent.status, at: Date.now() })
      const env = appEnv()
      void fetch(`${env.supabaseUrl}/rest/v1/rpc/agent_set_status`, {
        method: 'POST',
        keepalive: true,
        headers: {
          apikey: env.anonKey,
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Content-Profile': 'cs_api',
        },
        body: JSON.stringify({ p_status: 'offline', p_reason: null }),
      }).catch(() => undefined)
    }
    window.addEventListener('pagehide', onHide)
    return () => window.removeEventListener('pagehide', onHide)
  }, [agent.id])
}

export function useResumeStatus() {
  const { mutate } = useSetStatus()
  const status = useAgent().status
  const checked = useRef(false)
  useEffect(() => {
    if (checked.current) return
    checked.current = true
    const saved = readJson<{ status: AgentStatus; at: number } | null>(RESUME_KEY, null)
    writeLocal(RESUME_KEY, null)
    const navigation = performance.getEntriesByType('navigation')[0] as
      PerformanceNavigationTiming | undefined
    if (!saved || navigation?.type !== 'reload' || Date.now() - saved.at > 60_000) return
    if (status === 'offline' && saved.status !== 'offline') mutate({ status: saved.status })
  }, [mutate, status])
}
