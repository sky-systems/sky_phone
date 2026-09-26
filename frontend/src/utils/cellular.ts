import { reactive } from 'vue'

export type CellularState = {
  enabled: boolean
  bars: number
  hasSignal: boolean
  offlineApps: Record<string, boolean>
  onlineActions: Record<string, boolean>
  systemNamespaces: Record<string, boolean>
  cleanupActions: Record<string, boolean>
  appNamespaces: Record<string, string>
}

// Lua supplies the same policy that the server enforces. Preview starts online.
export const cellular = reactive<CellularState>({
  enabled: false,
  bars: 4,
  hasSignal: true,
  offlineApps: {},
  onlineActions: {},
  systemNamespaces: {},
  cleanupActions: {},
  appNamespaces: {},
})

export function appNeedsSignal(appId: string): boolean {
  return (
    cellular.enabled &&
    !cellular.hasSignal &&
    cellular.offlineApps[appId] !== true
  )
}

export function blocksCellularRequest(
  endpoint: string,
  data: Record<string, unknown> = {},
): boolean {
  if (!cellular.enabled || cellular.hasSignal) return false
  const namespace = endpoint.split(':')[0] ?? endpoint
  if (cellular.systemNamespaces[namespace] || cellular.cleanupActions[endpoint])
    return false
  if (cellular.onlineActions[endpoint]) return true
  const appId =
    namespace === 'custom-app' && typeof data.appId === 'string'
      ? data.appId
      : (cellular.appNamespaces[namespace] ?? namespace)
  return cellular.offlineApps[appId] !== true
}
