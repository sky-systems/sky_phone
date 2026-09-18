import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

import { createPinia, setActivePinia } from 'pinia'
import ts from 'typescript'
import { computed, ref, type ComputedRef } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { usePhoneStore, type PhoneOpenPayload } from '@/stores/phone'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

// Execute the production message and hydration handlers with real phone state,
// without mounting every app, media player, and game in the phone shell.
const source = readFileSync(new URL('./App.vue', import.meta.url), 'utf8')
const script = source.match(/<script setup lang="ts">([\s\S]*?)<\/script>/)?.[1]
if (!script) throw new Error('Phone root setup script was not found')
const parsed = ts.createSourceFile(
  'App.ts',
  script,
  ts.ScriptTarget.Latest,
  true,
)
const handlers = parsed.statements
  .filter(
    (node) =>
      (ts.isFunctionDeclaration(node) &&
        ['hydratePhone', 'onMessage'].includes(node.name?.text ?? '')) ||
      (ts.isVariableStatement(node) &&
        node.declarationList.declarations.some(
          (declaration) => declaration.name.getText(parsed) === 'setupRequired',
        )),
  )
  .map((node) => node.getText(parsed))
  .join('\n')
const visibilityWatch = parsed.statements.find(
  (node) =>
    ts.isExpressionStatement(node) &&
    ts.isCallExpression(node.expression) &&
    node.expression.expression.getText(parsed) === 'watch' &&
    node.expression.arguments[0]?.getText(parsed) === '() => phone.isOpen',
)
if (!visibilityWatch || !ts.isExpressionStatement(visibilityWatch)) {
  throw new Error('Phone visibility watcher was not found')
}
const visibilityHandler = (
  visibilityWatch.expression as ts.CallExpression
).arguments[1]!.getText(parsed)
const executable = ts.transpileModule(
  `${handlers}\nconst onVisibilityChanged = ${visibilityHandler}\n({ onMessage, setupRequired, onVisibilityChanged })`,
  {
    compilerOptions: { target: ts.ScriptTarget.ES2022 },
  },
).outputText

const payload: PhoneOpenPayload = {
  device: { data: {}, imei: '356938035643809', name: 'Phone', sim: null },
  token: 'authorized-session',
}

describe('phone root device lifecycle', () => {
  let onMessage: (event: { source: null; data: unknown }) => void
  let setupRequired: ComputedRef<boolean>
  let showNotification: ReturnType<typeof vi.fn>
  let onVisibilityChanged: (isOpen: boolean) => void
  const isLocked = ref(false)

  beforeEach(() => {
    vi.stubGlobal('window', { matchMedia: () => ({ matches: false }) })
    setActivePinia(createPinia())
    const hydrate = vi.fn()
    showNotification = vi.fn()
    isLocked.value = false
    const runtime = runInNewContext(executable, {
      window,
      computed,
      isLocked,
      isDevelopment: false,
      developmentLockScreenPreview: false,
      faceIdRequest: 0,
      unlockTimer: undefined,
      ...Object.fromEntries(
        [
          'faceIdVisible',
          'faceIdBusy',
          'passcodeRequired',
          'unlockedServicesLoaded',
          'controlCenterOpened',
          'isUnlocking',
          'passcodeVisible',
          'passcodeBusy',
          'passcodeError',
          'passcodeResetKey',
          'passcodeRetrySeconds',
          'pendingUnlockRoute',
        ].map((name) => [name, ref(0)]),
      ),
      weather: { start: vi.fn() },
      router: { replace: vi.fn() },
      loadUnlockedPhoneData: vi.fn(),
      startPasscodeLock: vi.fn(),
      isTrustedRootMessageSource,
      phone: usePhoneStore(),
      configurePhoneNumberFormat: vi.fn(),
      companies: { bindDeviceScope: vi.fn() },
      appCatalog: { externalApps: [] },
      notifications: {
        hydrate,
        hideDevicePreview: vi.fn(),
        show: showNotification,
      },
      account: { hydrate },
      appAuth: { hydrate },
      notes: { hydrate },
      memos: { hydrate },
      clock: { hydrate },
      games: { hydrate },
      media: { hydrate },
      appStore: { hydrate },
      widgets: { hydrate },
      route: { params: {} },
      openHomeRequested: { value: false },
      activitySuspended: { value: false },
      syncNavigationState: () => Promise.resolve(),
      nuiCall: vi.fn(),
    }) as {
      onMessage: typeof onMessage
      setupRequired: typeof setupRequired
      onVisibilityChanged: typeof onVisibilityChanged
    }
    onMessage = runtime.onMessage
    setupRequired = runtime.setupRequired
    onVisibilityChanged = runtime.onVisibilityChanged
  })

  afterEach(() => vi.unstubAllGlobals())

  it('does not open a phone from an unsolicited device update', () => {
    onMessage({ source: null, data: { type: 'device:updated', data: payload } })
    expect(usePhoneStore().isOpen).toBe(false)
    expect(usePhoneStore().deviceSessionToken).toBeNull()
  })

  it('keeps a closed session closed when an earlier update arrives late', () => {
    onMessage({ source: null, data: { type: 'app:open', data: payload } })
    expect(usePhoneStore().isOpen).toBe(true)
    onMessage({ source: null, data: { type: 'app:close' } })
    onMessage({ source: null, data: { type: 'device:updated', data: payload } })
    expect(usePhoneStore().isOpen).toBe(false)
    expect(usePhoneStore().deviceSessionToken).toBeNull()
  })

  it('continues to hydrate an open phone', () => {
    onMessage({ source: null, data: { type: 'app:open', data: payload } })
    onMessage({
      source: null,
      data: {
        type: 'device:updated',
        data: {
          ...payload,
          device: { ...payload.device, name: 'Updated phone' },
        },
      },
    })
    expect(usePhoneStore().isOpen).toBe(true)
    expect(usePhoneStore().device?.name).toBe('Updated phone')
  })

  it('shows a cold-start notification without opening Setup Assistant', () => {
    const notification = { appId: 'messages', title: 'Messages', text: 'Hello' }

    onMessage({
      source: null,
      data: { type: 'notification:show', data: notification },
    })

    expect(showNotification).toHaveBeenCalledWith(notification)
    expect(usePhoneStore().isOpen).toBe(false)
    expect(usePhoneStore().preferences.settings.setupCompleted).toBe(false)
    expect(setupRequired.value).toBe(false)
  })

  it('shows unfinished setup only while the phone is explicitly open', () => {
    onMessage({ source: null, data: { type: 'app:open', data: payload } })
    expect(setupRequired.value).toBe(true)

    onMessage({ source: null, data: { type: 'app:close' } })
    onMessage({
      source: null,
      data: {
        type: 'notification:show',
        data: { appId: 'messages', title: 'Messages', text: 'Hello again' },
      },
    })

    expect(showNotification).toHaveBeenCalledOnce()
    expect(setupRequired.value).toBe(false)
    expect(usePhoneStore().preferences.settings.setupCompleted).toBe(false)

    onMessage({ source: null, data: { type: 'app:open', data: payload } })
    expect(setupRequired.value).toBe(true)
  })

  it('keeps Setup Assistant hidden when a configured phone opens', () => {
    onMessage({
      source: null,
      data: {
        type: 'app:open',
        data: {
          ...payload,
          device: {
            ...payload.device,
            data: {
              settings: {
                payload: { version: 1, settings: { setupCompleted: true } },
                revision: 1,
              },
            },
          },
        },
      },
    })

    expect(usePhoneStore().isOpen).toBe(true)
    expect(setupRequired.value).toBe(false)
  })

  it('requires unlocking before resuming unfinished setup on a protected phone', () => {
    onMessage({
      source: null,
      data: {
        type: 'app:open',
        data: {
          ...payload,
          security: { enabled: true, length: 6, lockedUntil: 0 },
          device: {
            ...payload.device,
            data: {
              settings: {
                payload: {
                  version: 1,
                  settings: { setupCompleted: false, setupStep: 8 },
                },
                revision: 4,
              },
            },
          },
        },
      },
    })
    onVisibilityChanged(true)

    expect(isLocked.value).toBe(true)
    expect(setupRequired.value).toBe(false)

    isLocked.value = false
    expect(setupRequired.value).toBe(true)
    expect(usePhoneStore().preferences.settings.setupStep).toBe(8)
  })

  it('starts setup immediately on a new phone without a passcode', () => {
    onMessage({ source: null, data: { type: 'app:open', data: payload } })
    onVisibilityChanged(true)

    expect(isLocked.value).toBe(false)
    expect(setupRequired.value).toBe(true)
  })
})
