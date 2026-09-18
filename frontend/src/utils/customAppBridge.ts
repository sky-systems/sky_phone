import type {
  CustomAppBridgeMode,
  SkyPhoneAppBridgeRequest,
  SkyPhoneAppBridgeResponse,
  SkyPhoneAppCapability,
} from '@/types/apps'
import type { NuiResponse } from '@/utils/nui'
import type { BuiltInNotificationSoundId } from '@/utils/preferences'

const STORAGE_KEY_PATTERN = /^[A-Za-z0-9._-]{1,64}$/
const NOTIFICATION_SOUNDS: ReadonlySet<BuiltInNotificationSoundId> = new Set([
  'chime',
  'signal',
  'soft',
])
const JSON_MAX_DEPTH = 8
const JSON_MAX_NODES = 512
const HANDLED_REQUEST_ID_LIMIT = 512
const STORAGE_VALUE_MAX_BYTES = 65_536
const DEEP_LINK_DATA_MAX_BYTES = 16_384

type JsonResult = { success: true; value: unknown } | { success: false }

export type CustomAppBridgeNotification = {
  appId: string
  route: string
  sound?: BuiltInNotificationSoundId
  subtitle?: string
  text: string
  title: string
}

export type CustomAppBridgeTarget = {
  external: boolean
  id: string
  route: string
}

export type CustomAppBridgeEffect =
  | { type: 'close' }
  | { route: string; type: 'open' }

export type CustomAppBridgeResult = {
  effect?: CustomAppBridgeEffect
  response: SkyPhoneAppBridgeResponse
}

type CustomAppBridgeDependencies = {
  createNotification: (
    notification: CustomAppBridgeNotification,
  ) => string | null
  getSourceApp: () => { capabilities: readonly string[]; id: string }
  prepareExternalOpen: (appId: string, data?: unknown) => boolean
  resolveTarget: (appId: string) => CustomAppBridgeTarget | null
  storageCall: (
    endpoint: 'custom-app:storage:get' | 'custom-app:storage:set',
    payload: Record<string, unknown>,
  ) => Promise<NuiResponse>
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function hasOnlyKeys(
  value: Record<string, unknown>,
  allowedKeys: readonly string[],
): boolean {
  const allowed = new Set(allowedKeys)
  return Object.keys(value).every((key) => allowed.has(key))
}

function readText(value: unknown, maximumLength: number): string | null {
  if (typeof value !== 'string') return null
  const normalized = value.trim()
  return normalized.length > 0 && normalized.length <= maximumLength
    ? normalized
    : null
}

function cloneJsonValue(
  value: unknown,
  depth: number,
  state: { nodes: number; seen: WeakSet<object> },
): JsonResult {
  state.nodes += 1
  if (state.nodes > JSON_MAX_NODES || depth > JSON_MAX_DEPTH) {
    return { success: false }
  }
  if (
    value === null ||
    typeof value === 'boolean' ||
    typeof value === 'string'
  ) {
    return { success: true, value }
  }
  if (typeof value === 'number') {
    return Number.isFinite(value)
      ? { success: true, value }
      : { success: false }
  }
  if (typeof value !== 'object' || state.seen.has(value)) {
    return { success: false }
  }

  state.seen.add(value)
  if (Array.isArray(value)) {
    if (value.length > 128) return { success: false }
    const result: unknown[] = []
    for (const item of value) {
      const normalized = cloneJsonValue(item, depth + 1, state)
      if (!normalized.success) return normalized
      result.push(normalized.value)
    }
    state.seen.delete(value)
    return { success: true, value: result }
  }

  const prototype = Object.getPrototypeOf(value)
  if (prototype !== Object.prototype && prototype !== null) {
    return { success: false }
  }
  const entries = Object.entries(value)
  if (entries.length > 128) return { success: false }
  const result: Record<string, unknown> = {}
  for (const [key, item] of entries) {
    if (
      key.length < 1 ||
      key.length > 64 ||
      key === '__proto__' ||
      key === 'constructor' ||
      key === 'prototype'
    ) {
      return { success: false }
    }
    const normalized = cloneJsonValue(item, depth + 1, state)
    if (!normalized.success) return normalized
    result[key] = normalized.value
  }
  state.seen.delete(value)
  return { success: true, value: result }
}

function normalizeJsonValue(value: unknown, maximumBytes: number): JsonResult {
  const normalized = cloneJsonValue(value, 0, {
    nodes: 0,
    seen: new WeakSet(),
  })
  if (!normalized.success) return normalized

  const serialized = JSON.stringify(normalized.value)
  if (
    typeof serialized !== 'string' ||
    new TextEncoder().encode(serialized).byteLength > maximumBytes
  ) {
    return { success: false }
  }
  return normalized
}

function normalizeStorageGetPayload(payload: unknown): { key: string } | null {
  if (!isRecord(payload) || !hasOnlyKeys(payload, ['key'])) return null
  return typeof payload.key === 'string' &&
    STORAGE_KEY_PATTERN.test(payload.key)
    ? { key: payload.key }
    : null
}

function normalizeStorageSetPayload(
  payload: unknown,
): { key: string; revision: number; value: unknown } | null {
  if (
    !isRecord(payload) ||
    !hasOnlyKeys(payload, ['key', 'revision', 'value']) ||
    !Object.prototype.hasOwnProperty.call(payload, 'value') ||
    typeof payload.key !== 'string' ||
    !STORAGE_KEY_PATTERN.test(payload.key) ||
    typeof payload.revision !== 'number' ||
    !Number.isInteger(payload.revision) ||
    payload.revision < 0 ||
    payload.revision > 4_294_967_294
  ) {
    return null
  }

  const value = normalizeJsonValue(payload.value, STORAGE_VALUE_MAX_BYTES)
  return value.success
    ? { key: payload.key, revision: payload.revision, value: value.value }
    : null
}

function normalizeNotificationPayload(
  appId: string,
  payload: unknown,
): CustomAppBridgeNotification | null {
  if (
    !isRecord(payload) ||
    !hasOnlyKeys(payload, ['sound', 'subtitle', 'text', 'title'])
  ) {
    return null
  }

  const title = readText(payload.title, 80)
  const text = readText(payload.text, 240)
  if (!title || !text) return null

  const subtitle =
    payload.subtitle === undefined ? undefined : readText(payload.subtitle, 80)
  if (payload.subtitle !== undefined && !subtitle) return null
  const sound =
    payload.sound === undefined ||
    (typeof payload.sound === 'string' &&
      NOTIFICATION_SOUNDS.has(payload.sound as BuiltInNotificationSoundId))
      ? (payload.sound as BuiltInNotificationSoundId | undefined)
      : null
  if (sound === null) return null

  return {
    appId,
    route: `/apps/${appId}`,
    ...(sound ? { sound } : {}),
    ...(subtitle ? { subtitle } : {}),
    text,
    title,
  }
}

function normalizeOpenPayload(
  payload: unknown,
): { appId: string; data?: unknown } | null {
  if (
    !isRecord(payload) ||
    !hasOnlyKeys(payload, ['appId', 'data']) ||
    typeof payload.appId !== 'string' ||
    payload.appId.length < 1 ||
    payload.appId.length > 64
  ) {
    return null
  }
  if (!Object.prototype.hasOwnProperty.call(payload, 'data')) {
    return { appId: payload.appId }
  }

  const data = normalizeJsonValue(payload.data, DEEP_LINK_DATA_MAX_BYTES)
  if (!data.success || !isRecord(data.value)) return null
  return { appId: payload.appId, data: data.value }
}

function hasPermission(
  capabilities: readonly string[],
  permission: string,
): boolean {
  return capabilities.includes(permission)
}

function response(
  requestId: string,
  success: boolean,
  data?: unknown,
  error?: string,
): SkyPhoneAppBridgeResponse {
  return {
    ...(data === undefined ? {} : { data }),
    ...(error ? { error } : {}),
    requestId,
    success,
  }
}

export function getSkyPhoneAppCapabilities(
  permissions: readonly string[],
): SkyPhoneAppCapability[] {
  const capabilities: SkyPhoneAppCapability[] = []
  if (hasPermission(permissions, 'app.close')) capabilities.push('app.close')
  if (hasPermission(permissions, 'app.open')) capabilities.push('app.open')
  if (hasPermission(permissions, 'device.storage')) {
    capabilities.push('device.storage.get', 'device.storage.set')
  }
  if (hasPermission(permissions, 'locale.read'))
    capabilities.push('locale.read')
  if (hasPermission(permissions, 'notifications')) {
    capabilities.push('notification.create')
  }
  if (hasPermission(permissions, 'theme.read')) capabilities.push('theme.read')
  return capabilities
}

export function shouldReportCustomAppReady(
  bridgeMode: CustomAppBridgeMode,
  signal: 'bridge-ready' | 'frame-load',
): boolean {
  return bridgeMode === 'sky'
    ? signal === 'bridge-ready'
    : signal === 'frame-load'
}

export function getCustomAppFrameBootstrapMessages(
  compatibility: Readonly<Record<string, unknown>>,
): readonly unknown[] {
  if (compatibility.provider === 'lb_phone') {
    return ['componentsLoaded']
  }
  return []
}

export function createCustomAppBridgeRequestHandler(
  dependencies: CustomAppBridgeDependencies,
): {
  handle: (
    request: SkyPhoneAppBridgeRequest,
  ) => Promise<CustomAppBridgeResult | null>
} {
  const handledRequestIds = new Set<string>()
  const handledRequestOrder: string[] = []

  return {
    async handle(
      request: SkyPhoneAppBridgeRequest,
    ): Promise<CustomAppBridgeResult | null> {
      if (
        typeof request.requestId !== 'string' ||
        request.requestId.length < 1 ||
        request.requestId.length > 128 ||
        typeof request.method !== 'string' ||
        request.method.length < 1 ||
        request.method.length > 64 ||
        handledRequestIds.has(request.requestId)
      ) {
        return null
      }
      handledRequestIds.add(request.requestId)
      handledRequestOrder.push(request.requestId)
      if (handledRequestOrder.length > HANDLED_REQUEST_ID_LIMIT) {
        const expiredRequestId = handledRequestOrder.shift()
        if (expiredRequestId) handledRequestIds.delete(expiredRequestId)
      }

      const source = dependencies.getSourceApp()
      try {
        if (request.method === 'app.close') {
          return hasPermission(source.capabilities, 'app.close')
            ? {
                effect: { type: 'close' },
                response: response(request.requestId, true),
              }
            : {
                response: response(
                  request.requestId,
                  false,
                  undefined,
                  'permission_denied',
                ),
              }
        }

        if (
          request.method === 'device.storage.get' ||
          request.method === 'device.storage.set'
        ) {
          if (!hasPermission(source.capabilities, 'device.storage')) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'permission_denied',
              ),
            }
          }

          const storagePayload =
            request.method === 'device.storage.get'
              ? normalizeStorageGetPayload(request.payload)
              : normalizeStorageSetPayload(request.payload)
          if (!storagePayload) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'invalid_storage_request',
              ),
            }
          }

          const result = await dependencies.storageCall(
            request.method === 'device.storage.get'
              ? 'custom-app:storage:get'
              : 'custom-app:storage:set',
            { appId: source.id, ...storagePayload },
          )
          return {
            response: response(
              request.requestId,
              result.success,
              result.data,
              result.error,
            ),
          }
        }

        if (request.method === 'notification.create') {
          if (!hasPermission(source.capabilities, 'notifications')) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'permission_denied',
              ),
            }
          }
          const notification = normalizeNotificationPayload(
            source.id,
            request.payload,
          )
          if (!notification) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'invalid_notification',
              ),
            }
          }
          const notificationId = dependencies.createNotification(notification)
          return {
            response: response(request.requestId, true, { notificationId }),
          }
        }

        if (request.method === 'app.open') {
          if (!hasPermission(source.capabilities, 'app.open')) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'permission_denied',
              ),
            }
          }
          const openPayload = normalizeOpenPayload(request.payload)
          if (!openPayload) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'invalid_app_open',
              ),
            }
          }
          const target = dependencies.resolveTarget(openPayload.appId)
          if (!target) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'app_not_found',
              ),
            }
          }
          if (openPayload.data !== undefined && !target.external) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'open_data_not_supported',
              ),
            }
          }
          if (
            target.external &&
            !dependencies.prepareExternalOpen(target.id, openPayload.data)
          ) {
            return {
              response: response(
                request.requestId,
                false,
                undefined,
                'open_failed',
              ),
            }
          }
          return {
            effect: { route: target.route, type: 'open' },
            response: response(request.requestId, true, {
              appId: target.id,
            }),
          }
        }

        return {
          response: response(
            request.requestId,
            false,
            undefined,
            'unsupported_method',
          ),
        }
      } catch (error) {
        console.error(
          `[Custom apps] Bridge request failed for ${source.id}.`,
          error,
        )
        return {
          response: response(
            request.requestId,
            false,
            undefined,
            'request_failed',
          ),
        }
      }
    },
  }
}
