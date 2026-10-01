import { Grid2X2 } from 'lucide-vue-next'
import { defineStore } from 'pinia'
import { markRaw } from 'vue'

import {
  BUILTIN_PHONE_APP_IDS,
  getPhoneApp,
  isExternalPhoneApp,
  isValidExternalPhoneAppId,
  PHONE_APPS,
  replaceExternalPhoneApps,
} from '@/config/apps'
import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import type {
  CustomAppHostMessage,
  CustomAppOpenRequest,
  BuiltinPhoneAppId,
  ExternalPhoneAppDefinition,
  PhoneAppCategory,
  CustomAppStoreOptions,
} from '@/types/apps'

const APP_CATEGORIES: ReadonlySet<PhoneAppCategory> = new Set([
  'games',
  'productivity',
  'shopping',
  'social',
  'utilities',
])
const MAX_PENDING_MESSAGES = 50
const ICON_BACKGROUND_HEX_PATTERN =
  /^#(?:[\da-f]{3}|[\da-f]{4}|[\da-f]{6}|[\da-f]{8})$/i
const ICON_BACKGROUND_NAMED_PATTERN = /^[a-z]{3,32}$/i
const ICON_BACKGROUND_FUNCTION_PATTERN =
  /^(?:rgb|rgba|hsl|hsla)\([\d\s.,%+\-/degraturn]+\)$/i

function readRecord(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null
}

function readRequiredString(
  source: Record<string, unknown>,
  key: string,
  maximumLength: number,
): string | null {
  const value = source[key]
  if (typeof value !== 'string') return null
  const normalized = value.trim()
  return normalized && normalized.length <= maximumLength ? normalized : null
}

function readOptionalString(
  source: Record<string, unknown>,
  key: string,
  maximumLength: number,
): string {
  const value = source[key]
  if (typeof value !== 'string') return ''
  return value.trim().slice(0, maximumLength)
}

function readIconBackground(value: unknown): string {
  if (typeof value !== 'string') return ''
  const normalized = value.trim()
  if (!normalized || normalized.length > 192) return ''

  return ICON_BACKGROUND_HEX_PATTERN.test(normalized) ||
    ICON_BACKGROUND_NAMED_PATTERN.test(normalized) ||
    ICON_BACKGROUND_FUNCTION_PATTERN.test(normalized) ||
    /^linear-gradient\(-?\d+(?:\.\d+)?deg,(?:#[\da-f]{3,8},){1,7}#[\da-f]{3,8}\)$/i.test(
      normalized,
    )
    ? normalized
    : ''
}

function readHttpsUrl(value: unknown): string | null {
  if (typeof value !== 'string' || value.length > 2048) return null

  try {
    const parsed = new URL(value)
    if (parsed.protocol !== 'https:' || parsed.username || parsed.password) {
      return null
    }
    return parsed.href
  } catch {
    return null
  }
}

function readCapabilities(value: unknown): string[] {
  if (!Array.isArray(value)) return []

  const capabilities: string[] = []
  for (const capability of value) {
    if (
      typeof capability === 'string' &&
      /^[a-z][a-z0-9._-]{1,63}$/.test(capability) &&
      !capabilities.includes(capability)
    ) {
      capabilities.push(capability)
    }
  }
  return capabilities
}

function readCompatibilityValue(value: unknown, depth = 0): unknown {
  if (
    value === null ||
    typeof value === 'boolean' ||
    (typeof value === 'number' && Number.isFinite(value))
  ) {
    return value
  }
  if (typeof value === 'string') return value.slice(0, 256)
  if (depth >= 2) return undefined
  if (Array.isArray(value)) {
    return value
      .slice(0, 32)
      .map((item) => readCompatibilityValue(item, depth + 1))
      .filter((item) => item !== undefined)
  }

  const source = readRecord(value)
  if (!source) return undefined
  const result: Record<string, unknown> = {}
  for (const [key, item] of Object.entries(source).slice(0, 32)) {
    if (!/^[A-Za-z0-9_.-]{1,64}$/.test(key)) continue
    const normalized = readCompatibilityValue(item, depth + 1)
    if (normalized !== undefined) result[key] = normalized
  }
  return result
}

function readCompatibility(value: unknown): Record<string, unknown> {
  const source = readRecord(value)
  if (!source) return {}
  return (readCompatibilityValue(source) as Record<string, unknown>) ?? {}
}

function readStoreOptions(value: unknown): CustomAppStoreOptions {
  const source = readRecord(value)
  if (!source) return {}
  const options: CustomAppStoreOptions = {}
  for (const field of ['price', 'size', 'rating'] as const) {
    const number = source[field]
    if (
      typeof number === 'number' &&
      Number.isFinite(number) &&
      number >= 0 &&
      number <= 2147483647
    ) {
      if (field === 'rating' && (number < 1 || number > 5)) continue
      if (field === 'price' && !Number.isInteger(number)) continue
      options[field] = number
    }
  }
  for (const field of ['inAppStore', 'disableInAppNotifications'] as const) {
    if (typeof source[field] === 'boolean') options[field] = source[field]
  }
  for (const field of ['allowedJobs', 'disabledJobs'] as const) {
    const jobs = readRecord(source[field])
    if (!jobs) continue
    options[field] = Object.fromEntries(
      Object.entries(jobs).filter(
        ([name, grade]) =>
          /^[\w-]{1,64}$/.test(name) &&
          typeof grade === 'number' &&
          Number.isInteger(grade) &&
          grade >= 0 &&
          grade <= 9999,
      ),
    ) as Record<string, number>
  }
  if (Array.isArray(source.screenshots)) {
    options.screenshots = source.screenshots
      .slice(0, 8)
      .map(readHttpsUrl)
      .filter((url): url is string => url !== null)
  }
  const banner = readRecord(source.banner)
  const imageUrl = readHttpsUrl(banner?.imageUrl)
  if (imageUrl)
    options.banner = {
      imageUrl,
      background: readIconBackground(banner?.background),
    }
  return options
}

export function normalizeExternalPhoneApp(
  value: unknown,
  fallbackOrder = 0,
): ExternalPhoneAppDefinition | null {
  const source = readRecord(value)
  if (!source) return null

  const id = readRequiredString(source, 'id', 64)
  const name = readRequiredString(source, 'name', 64)
  const ownerResource = readRequiredString(source, 'ownerResource', 128)
  const actionApp = source.launchMode === 'action'
  const ui = actionApp ? '' : readHttpsUrl(source.ui)
  const icon = readHttpsUrl(source.icon)
  if (
    !id ||
    !isValidExternalPhoneAppId(id) ||
    BUILTIN_PHONE_APP_IDS.has(id as BuiltinPhoneAppId) ||
    !name ||
    !ownerResource ||
    !/^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(ownerResource) ||
    (!actionApp && !ui) ||
    !icon
  ) {
    return null
  }

  const category = APP_CATEGORIES.has(source.category as PhoneAppCategory)
    ? (source.category as PhoneAppCategory)
    : 'utilities'
  const bundled = source.bundled === true
  const gridOrder =
    typeof source.gridOrder === 'number' &&
    Number.isFinite(source.gridOrder) &&
    source.gridOrder >= 0
      ? Math.floor(source.gridOrder)
      : 1000 + fallbackOrder
  const iconBackground = readIconBackground(source.iconBackground)

  return {
    bridgeMode:
      source.bridgeMode === 'sky' || source.bridgeMode === 'legacy'
        ? source.bridgeMode
        : bundled
          ? 'sky'
          : 'legacy',
    bundled,
    capabilities: readCapabilities(source.capabilities ?? source.permissions),
    category,
    component: null,
    compatibility: readCompatibility(source.compatibility),
    defaultInstalled: source.defaultInstalled === true,
    description: readOptionalString(source, 'description', 320),
    developer: readOptionalString(source, 'developer', 96),
    dockOrder: null,
    gridOrder,
    icon: markRaw(Grid2X2),
    ...(iconBackground ? { iconBackground } : {}),
    iconClass: 'app-icon--custom',
    iconImage: icon,
    id,
    kind: 'external',
    launchMode: actionApp ? 'action' : 'frame',
    store: readStoreOptions(source.store),
    name,
    orientation: source.orientation === 'landscape' ? 'landscape' : 'portrait',
    ownerResource,
    readyTimeoutMs:
      typeof source.readyTimeoutMs === 'number' &&
      Number.isFinite(source.readyTimeoutMs) &&
      source.readyTimeoutMs >= 1000 &&
      source.readyTimeoutMs <= 30_000
        ? Math.floor(source.readyTimeoutMs)
        : 8000,
    removable: source.removable !== false,
    route: `/apps/${id}`,
    ui: ui ?? '',
  }
}

export const useAppCatalogStore = defineStore('app-catalog', {
  state: () => ({
    externalApps: [] as ExternalPhoneAppDefinition[],
    hostMessages: {} as Record<string, CustomAppHostMessage[]>,
    nextSequence: 1,
    openRequests: {} as Record<string, CustomAppOpenRequest>,
  }),
  getters: {
    apps: () => PHONE_APPS,
  },
  actions: {
    replaceCatalog(payload: unknown): void {
      const source = readRecord(payload)
      if (!source || !Array.isArray(source.apps)) {
        console.error('[Custom apps] Ignored an invalid catalog payload.')
        return
      }

      const seenIds = new Set<string>()
      const apps: ExternalPhoneAppDefinition[] = []
      for (const [index, value] of source.apps.entries()) {
        const app = normalizeExternalPhoneApp(value, index)
        if (!app) {
          console.error(
            `[Custom apps] Ignored invalid catalog entry at index ${index}.`,
          )
          continue
        }
        if (seenIds.has(app.id)) {
          console.error(`[Custom apps] Ignored duplicate app id: ${app.id}`)
          continue
        }
        seenIds.add(app.id)
        apps.push(app)
      }

      this.externalApps = apps
      replaceExternalPhoneApps(apps)

      for (const appId of Object.keys(this.hostMessages)) {
        if (!seenIds.has(appId)) delete this.hostMessages[appId]
      }
      for (const appId of Object.keys(this.openRequests)) {
        if (!seenIds.has(appId)) delete this.openRequests[appId]
      }

      usePhoneStore().ensureAppNotificationPreferences(
        apps.map((app) => app.id),
      )
      useAppStoreStore().reconcileCatalog()
    },
    queueHostMessage(appId: string, payload: unknown): boolean {
      const app = getPhoneApp(appId)
      if (!isExternalPhoneApp(app)) {
        console.error(
          `[Custom apps] Message target is not registered: ${appId}`,
        )
        return false
      }

      const messages = this.hostMessages[appId] ?? []
      messages.push({ payload, sequence: this.nextSequence })
      this.nextSequence += 1
      if (messages.length > MAX_PENDING_MESSAGES) {
        console.error(
          `[Custom apps] Pending message limit reached for ${appId}; dropped the oldest message.`,
        )
      }
      this.hostMessages[appId] = messages.slice(-MAX_PENDING_MESSAGES)
      return true
    },
    consumeHostMessages(appId: string, throughSequence: number): void {
      const remaining = (this.hostMessages[appId] ?? []).filter(
        (message) => message.sequence > throughSequence,
      )
      if (remaining.length) this.hostMessages[appId] = remaining
      else delete this.hostMessages[appId]
    },
    requestOpen(appId: string, data?: unknown): boolean {
      const app = getPhoneApp(appId)
      if (!isExternalPhoneApp(app)) {
        console.error(`[Custom apps] Open target is not registered: ${appId}`)
        return false
      }

      this.openRequests[appId] = {
        ...(data === undefined ? {} : { data }),
        sequence: this.nextSequence,
      }
      this.nextSequence += 1
      return true
    },
    consumeOpenRequest(appId: string, sequence: number): void {
      if (this.openRequests[appId]?.sequence === sequence) {
        delete this.openRequests[appId]
      }
    },
  },
})
