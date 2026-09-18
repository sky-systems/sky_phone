import './profiles.css'
import { computed, onBeforeUnmount, ref, watch, type Ref } from 'vue'
import { useRealtimeStore } from './store'
import type { LiveApp, LiveEntry } from './types'
import type LiveBroadcast from '@/components/LiveBroadcast.vue'

export function useLiveProfiles(app: LiveApp, authenticated: Ref<boolean>) {
  const realtime = useRealtimeStore()
  const live = ref<InstanceType<typeof LiveBroadcast> | null>(null)
  const entries = ref<LiveEntry[]>([])
  const byProfile = computed(
    () =>
      new Map(
        entries.value
          .filter((entry) => entry.profileId)
          .map((entry) => [String(entry.profileId), entry]),
      ),
  )
  let timer: number | undefined
  let revision = 0
  async function refresh(): Promise<void> {
    const request = ++revision
    if (!authenticated.value) {
      entries.value = []
      return
    }
    if (!realtime.config) await realtime.refreshConfig()
    if (!realtime.config?.enabled || !realtime.config[app]) {
      entries.value = []
      return
    }
    const result = await realtime.list(app)
    if (request === revision && authenticated.value) entries.value = result
  }
  function liveFor(id: string | number | undefined): LiveEntry | undefined {
    return id === undefined ? undefined : byProfile.value.get(String(id))
  }
  function joinLive(id: string | number | undefined): boolean {
    const entry = liveFor(id)
    if (!entry) return false
    void live.value?.open(entry.id)
    return true
  }
  watch(
    authenticated,
    () => {
      clearInterval(timer)
      void refresh()
      if (authenticated.value)
        timer = window.setInterval(() => void refresh(), 10000)
    },
    { immediate: true },
  )
  onBeforeUnmount(() => {
    revision++
    clearInterval(timer)
  })
  return { live, entries, liveFor, joinLive, refresh }
}
