import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

import { ROOM_MOD_PAGE, roomModeratorsApi } from './api'
import type { RoomModActionCursor, RoomModSettings } from './types'

export const roomModKeys = {
  all: ['community', 'room-mods'] as const,
  list: (code: string) => ['community', 'room-mods', 'list', code] as const,
  candidates: (code: string, query: string) => ['community', 'room-mods', 'candidates', code, query] as const,
  actions: (code: string | null) => ['community', 'room-mods', 'actions', code ?? '*'] as const,
  settings: ['community', 'room-mods', 'settings'] as const,
}

const live = { refetchInterval: 30_000, staleTime: 10_000 }

export function useRoomModerators(code: string) {
  return useQuery({
    queryKey: roomModKeys.list(code),
    queryFn: () => roomModeratorsApi.list(code),
    retry: false,
    ...live,
  })
}

export function useRoomModCandidates(code: string, query: string) {
  const text = query.trim()
  return useQuery({
    queryKey: roomModKeys.candidates(code, text),
    queryFn: () => roomModeratorsApi.candidates(code, text),
    enabled: text.length >= 2,
    placeholderData: (previous) => previous,
    retry: false,
  })
}

export function useRoomModActions(code: string | null) {
  return useInfiniteQuery({
    queryKey: roomModKeys.actions(code),
    queryFn: ({ pageParam }) => roomModeratorsApi.actions(code, pageParam),
    initialPageParam: null as RoomModActionCursor | null,
    getNextPageParam: (page): RoomModActionCursor | null => {
      const last = page.items.at(-1)
      return page.items.length >= ROOM_MOD_PAGE && last ? { created_at: last.created_at, id: last.id } : null
    },
    retry: false,
    ...live,
  })
}

function useRoomModMutation<TArgs, TResult>(run: (args: TArgs) => Promise<TResult>) {
  const client = useQueryClient()
  return useMutation({
    mutationFn: run,
    onSettled: () => {
      void client.invalidateQueries({ queryKey: roomModKeys.all })
      void client.invalidateQueries({ queryKey: ['community', 'room'] })
    },
  })
}

export const useAppointRoomModerator = () =>
  useRoomModMutation((args: { code: string; userId: string; note: string | null }) =>
    roomModeratorsApi.appoint(args.code, args.userId, args.note),
  )

export const useRemoveRoomModerator = () =>
  useRoomModMutation((args: { code: string; userId: string; reason: string }) =>
    roomModeratorsApi.remove(args.code, args.userId, args.reason),
  )

export const useUndoRoomModAction = () =>
  useRoomModMutation((args: { id: string; note: string }) => roomModeratorsApi.undo(args.id, args.note))

export const useSaveRoomModSettings = () =>
  useRoomModMutation((values: Partial<RoomModSettings>) => roomModeratorsApi.saveSettings(values))
