import type { ExternalPhoneAppDefinition } from '@/types/apps'
import type { PhonePreferencesV1 } from '@/utils/preferences'

const LB_PHONE_PROVIDER = 'lb_phone'
const RESOURCE_NAME_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/
const MAX_FRAME_DOCUMENT_BYTES = 1_048_576
const MAX_STORAGE_BYTES = 65_536
const MAX_STORAGE_ENTRIES = 128
const MAX_STORAGE_KEY_LENGTH = 512
const STORAGE_KEY_PREFIX = 'sky_phone:lb-app-storage:v1:'

export const LB_PHONE_STORAGE_MESSAGE_TYPE = 'sky-phone:lb-storage'

export type LbPhoneStorageSnapshot = Record<string, string>

export type LbPhoneHostSettings = {
  airplaneMode: boolean
  apps: string[][]
  display: {
    automatic: boolean
    brightness: number
    size: number
    theme: 'dark' | 'light'
  }
  doNotDisturb: boolean
  locale: string
  lockscreen: {
    color: string
    fontStyle: number
    layout: number
  }
  name: string
  notifications: Record<string, { enabled: boolean; sound: boolean }>
  phone: { showCallerId: boolean }
  security: { faceId: boolean; pinCode: boolean }
  sound: {
    ringtone: string
    silent: boolean
    texttone: string
    volume: number
  }
  storage: { total: number; used: number }
  streamerMode: boolean
  time: { twelveHourClock: boolean }
  version: string
  wallpaper: { background: string }
  weather: { celcius: boolean }
}

type LbPhoneFrameDocumentOptions = {
  appName: string
  localStorage: LbPhoneStorageSnapshot
  resourceName: string
  settings: LbPhoneHostSettings
  ui: string
}

type LbPhoneSettingsOptions = {
  deviceName: string
  isDarkMode: boolean
  language: string
  preferences: PhonePreferencesV1
  securityEnabled: boolean
}

const LB_PHONE_RUNTIME_SOURCE = String.raw`
const listeners = new Map();
const settingsListeners = new Set();
const resourcePattern = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/;
const eventPattern = /^[A-Za-z0-9][A-Za-z0-9:._/-]{0,127}$/;

function createStorage(initialValues, onChange) {
  const values = new Map(Object.entries(initialValues ?? {}));
  const snapshot = () => Object.fromEntries(values);
  const storage = {
    clear() {
      if (values.size === 0) return;
      values.clear();
      onChange(snapshot());
    },
    getItem(key) {
      const normalizedKey = String(key);
      return values.has(normalizedKey) ? values.get(normalizedKey) : null;
    },
    key(index) {
      const normalizedIndex = Number(index);
      if (!Number.isInteger(normalizedIndex) || normalizedIndex < 0) return null;
      return Array.from(values.keys())[normalizedIndex] ?? null;
    },
    removeItem(key) {
      if (!values.delete(String(key))) return;
      onChange(snapshot());
    },
    setItem(key, value) {
      values.set(String(key), String(value));
      onChange(snapshot());
    }
  };
  Object.defineProperty(storage, 'length', {
    enumerable: true,
    get: () => values.size
  });
  return storage;
}

const localStorageBridge = createStorage(config.localStorage, (storage) => {
  globalThis.parent.postMessage({
    appId: config.appName,
    protocolVersion: 1,
    storage,
    type: '${LB_PHONE_STORAGE_MESSAGE_TYPE}'
  }, '*');
});
Object.defineProperty(globalThis, 'localStorage', {
  configurable: true,
  enumerable: true,
  value: localStorageBridge
});
Object.defineProperty(globalThis, 'sessionStorage', {
  configurable: true,
  enumerable: true,
  value: createStorage({}, () => undefined)
});

function applySettings(nextSettings) {
  globalThis.settings = nextSettings;
  const theme = nextSettings?.display?.theme === 'dark' ? 'dark' : 'light';
  document.documentElement.dataset.theme = theme;
  if (document.body) document.body.dataset.theme = theme;
}

globalThis.resourceName = config.resourceName;
globalThis.appName = config.appName;
globalThis.components = globalThis.components ?? {};
// Official LB app templates use this binding to distinguish live NUI from browser preview mode.
if (typeof globalThis.invokeNative !== 'function') {
  globalThis.invokeNative = () => undefined;
}
globalThis.GetParentResourceName = () => config.resourceName;
globalThis.fetchNui = async (eventName, data, requestedResource) => {
  if (typeof eventName !== 'string' || !eventPattern.test(eventName) || eventName.includes('..')) {
    throw new TypeError('Invalid NUI callback name');
  }

  const targetResource = typeof requestedResource === 'string'
    ? requestedResource
    : config.resourceName;
  if (!resourcePattern.test(targetResource)) {
    throw new TypeError('Invalid NUI callback resource');
  }

  const response = await fetch('https://' + targetResource + '/' + eventName, {
    body: JSON.stringify(data === undefined ? {} : data),
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    method: 'POST'
  });
  if (!response.ok) {
    throw new Error('NUI callback failed with HTTP ' + response.status);
  }

  const body = await response.text();
  return body ? JSON.parse(body) : null;
};
globalThis.onNuiEvent = globalThis.useNuiEvent = (eventName, callback) => {
  if (typeof eventName !== 'string' || !eventPattern.test(eventName) || typeof callback !== 'function') {
    throw new TypeError('Invalid NUI event listener');
  }
  const callbacks = listeners.get(eventName) ?? new Set();
  callbacks.add(callback);
  listeners.set(eventName, callbacks);
};
globalThis.onSettingsChange = (callback) => {
  if (typeof callback !== 'function') throw new TypeError('Invalid settings listener');
  settingsListeners.add(callback);
};
globalThis.getSettings = async () => globalThis.settings;

globalThis.addEventListener('message', (event) => {
  const message = event.data;
  if (!message || typeof message !== 'object') return;

  if (message.type === 'sky-phone:lb-settings') {
    applySettings(message.settings);
    for (const callback of settingsListeners) callback(globalThis.settings);
    return;
  }

  const eventName = typeof message.action === 'string'
    ? message.action
    : typeof message.type === 'string'
      ? message.type
      : null;
  if (!eventName) return;
  const data = Object.prototype.hasOwnProperty.call(message, 'data')
    ? message.data
    : message;
  for (const callback of listeners.get(eventName) ?? []) callback(data);
});

applySettings(config.settings);
document.addEventListener('DOMContentLoaded', () => applySettings(globalThis.settings), { once: true });
`

function escapeAttribute(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

function serializeForInlineScript(value: unknown): string {
  return JSON.stringify(value)
    .replace(/</g, '\\u003c')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029')
}

function normalizeStorageSnapshot(
  value: unknown,
): LbPhoneStorageSnapshot | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null
  }

  const entries = Object.entries(value)
  if (entries.length > MAX_STORAGE_ENTRIES) return null

  const normalized: LbPhoneStorageSnapshot = {}
  for (const [key, item] of entries) {
    if (
      key.length > MAX_STORAGE_KEY_LENGTH ||
      typeof item !== 'string' ||
      key === '__proto__' ||
      key === 'constructor' ||
      key === 'prototype'
    ) {
      return null
    }
    normalized[key] = item
  }

  return new TextEncoder().encode(JSON.stringify(normalized)).byteLength <=
    MAX_STORAGE_BYTES
    ? normalized
    : null
}

export function getLbPhoneStorageKey(appName: string): string {
  if (!RESOURCE_NAME_PATTERN.test(appName)) {
    throw new Error('invalid_lb_phone_storage_app')
  }
  return `${STORAGE_KEY_PREFIX}${appName}`
}

export function readLbPhoneStorage(
  storage: Pick<Storage, 'getItem'>,
  appName: string,
): LbPhoneStorageSnapshot {
  const serialized = storage.getItem(getLbPhoneStorageKey(appName))
  if (serialized === null) return {}

  const normalized = normalizeStorageSnapshot(JSON.parse(serialized))
  if (!normalized) throw new Error('invalid_lb_phone_storage')
  return normalized
}

export function writeLbPhoneStorage(
  storage: Pick<Storage, 'setItem'>,
  appName: string,
  value: unknown,
): boolean {
  const normalized = normalizeStorageSnapshot(value)
  if (!normalized) return false

  storage.setItem(getLbPhoneStorageKey(appName), JSON.stringify(normalized))
  return true
}

export function usesLbPhoneHostRuntime(
  app: ExternalPhoneAppDefinition,
): boolean {
  if (app.compatibility.provider !== LB_PHONE_PROVIDER) return false

  const url = new URL(app.ui)
  return url.protocol === 'https:' && url.search === ''
}

export function getLbPhoneCallbackResource(
  app: ExternalPhoneAppDefinition,
): string {
  const configured = app.compatibility.resourceName
  return typeof configured === 'string' &&
    RESOURCE_NAME_PATTERN.test(configured)
    ? configured
    : app.ownerResource
}

export function createLbPhoneHostSettings(
  options: LbPhoneSettingsOptions,
): LbPhoneHostSettings {
  const preferences = options.preferences.settings
  return {
    airplaneMode: preferences.airplaneMode,
    apps: [],
    display: {
      automatic: preferences.appearanceMode === 'automatic',
      brightness: preferences.screenBrightness / 100,
      size: preferences.phoneScale / 100,
      theme: options.isDarkMode ? 'dark' : 'light',
    },
    doNotDisturb: preferences.focusMode,
    locale: options.language,
    lockscreen: { color: '#ffffff', fontStyle: 0, layout: 0 },
    name: options.deviceName,
    notifications: Object.fromEntries(
      Object.entries(preferences.notifications).map(([appId, settings]) => [
        appId,
        { enabled: settings.enabled, sound: settings.sounds },
      ]),
    ),
    phone: { showCallerId: true },
    security: { faceId: false, pinCode: options.securityEnabled },
    sound: {
      ringtone: preferences.ringtone,
      silent:
        preferences.notificationVolume === 0 &&
        preferences.ringtoneVolume === 0,
      texttone: preferences.notificationSound,
      volume: preferences.notificationVolume / 100,
    },
    storage: { total: 0, used: 0 },
    streamerMode: preferences.streamerMode,
    time: { twelveHourClock: false },
    version: 'sky_phone',
    wallpaper: { background: preferences.wallpaper },
    weather: { celcius: true },
  }
}

export function createLbPhoneFrameDocument(
  html: string,
  options: LbPhoneFrameDocumentOptions,
): string {
  if (
    new TextEncoder().encode(html).byteLength > MAX_FRAME_DOCUMENT_BYTES ||
    !RESOURCE_NAME_PATTERN.test(options.resourceName)
  ) {
    throw new Error('invalid_lb_phone_frame_document')
  }

  const head = /<head(?:\s[^>]*)?>/i.exec(html)
  if (!head) throw new Error('invalid_lb_phone_frame_document')

  const baseUrl = new URL('.', options.ui).href
  const config = serializeForInlineScript({
    appName: options.appName,
    localStorage: options.localStorage,
    resourceName: options.resourceName,
    settings: options.settings,
  })
  const injection = `<base href="${escapeAttribute(baseUrl)}"><script>(() => { const config = ${config};${LB_PHONE_RUNTIME_SOURCE}\n})();<\/script>`
  const insertionPoint = head.index + head[0].length
  return `${html.slice(0, insertionPoint)}${injection}${html.slice(insertionPoint)}`
}
