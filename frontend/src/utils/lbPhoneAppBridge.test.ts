import { describe, expect, it } from 'vitest'
import { runInNewContext } from 'node:vm'

import type { ExternalPhoneAppDefinition } from '@/types/apps'
import {
  createLbPhoneFrameDocument,
  createLbPhoneHostSettings,
  getLbPhoneCallbackResource,
  getLbPhoneStorageKey,
  readLbPhoneStorage,
  usesLbPhoneHostRuntime,
  writeLbPhoneStorage,
} from '@/utils/lbPhoneAppBridge'
import { DEFAULT_PHONE_PREFERENCES } from '@/utils/preferences'

function externalApp(
  overrides: Partial<ExternalPhoneAppDefinition> = {},
): ExternalPhoneAppDefinition {
  return {
    bridgeMode: 'legacy',
    bundled: false,
    capabilities: [],
    category: 'games',
    compatibility: { provider: 'lb_phone', resourceName: 'snake_app' },
    component: null,
    defaultInstalled: true,
    description: 'Snake',
    developer: 'Example',
    dockOrder: null,
    gridOrder: 100,
    icon: {} as ExternalPhoneAppDefinition['icon'],
    iconClass: 'app-icon--custom',
    iconImage: 'https://cfx-nui-snake_app/ui/icon.png',
    id: 'snake-game' as ExternalPhoneAppDefinition['id'],
    kind: 'external',
    name: 'Snake',
    orientation: 'portrait',
    ownerResource: 'phone_adapter',
    readyTimeoutMs: 8000,
    removable: true,
    route: '/apps/snake-game' as ExternalPhoneAppDefinition['route'],
    ui: 'https://cfx-nui-snake_app/ui/dist/index.html',
    ...overrides,
  }
}

describe('LB Phone app bridge', () => {
  it('selects local LB documents without taking over query-driven apps', () => {
    expect(usesLbPhoneHostRuntime(externalApp())).toBe(true)
    expect(
      usesLbPhoneHostRuntime(
        externalApp({
          ui: 'https://cfx-nui-snake_app/ui/index.html?route=/dispatch',
        }),
      ),
    ).toBe(false)
    expect(
      usesLbPhoneHostRuntime(
        externalApp({ compatibility: { provider: '17mov' } }),
      ),
    ).toBe(false)
  })

  it('uses the declared callback resource and rejects malformed overrides', () => {
    expect(getLbPhoneCallbackResource(externalApp())).toBe('snake_app')
    expect(
      getLbPhoneCallbackResource(
        externalApp({
          compatibility: {
            provider: 'lb_phone',
            resourceName: '../wrong',
          },
        }),
      ),
    ).toBe('phone_adapter')
  })

  it('maps phone preferences into the LB settings contract', () => {
    const settings = createLbPhoneHostSettings({
      deviceName: 'Main phone',
      isDarkMode: true,
      language: 'de',
      preferences: DEFAULT_PHONE_PREFERENCES,
      securityEnabled: true,
    })

    expect(settings).toMatchObject({
      display: { brightness: 1, size: 1, theme: 'dark' },
      locale: 'de',
      name: 'Main phone',
      security: { pinCode: true },
    })
  })

  it('injects the LB runtime and asset base before the vendor bundle', () => {
    const html =
      '<!doctype html><html><head><script>globalThis.previewMode = !window.invokeNative</script><script type="module" src="/ui/dist/assets/index.js"></script></head><body></body></html>'
    const document = createLbPhoneFrameDocument(html, {
      appName: 'snake-game',
      localStorage: { theme: 'dark' },
      resourceName: 'snake_app',
      settings: createLbPhoneHostSettings({
        deviceName: '</script><script>window.injected=true</script>',
        isDarkMode: false,
        language: 'en',
        preferences: DEFAULT_PHONE_PREFERENCES,
        securityEnabled: false,
      }),
      ui: 'https://cfx-nui-snake_app/ui/dist/index.html',
    })

    expect(document.indexOf('<base href=')).toBeLessThan(
      document.indexOf('src="/ui/dist/assets/index.js"'),
    )
    expect(document).toContain('globalThis.fetchNui = async')
    expect(document).toContain('globalThis.onNuiEvent = globalThis.useNuiEvent')
    expect(document).toContain('globalThis.createCall = globalThis.CreateCall')
    expect(document).toContain('globalThis.createSMS = globalThis.CreateSMS')
    expect(document).toContain('globalThis.invokeNative = () => undefined')
    expect(document).toContain(
      "Object.defineProperty(globalThis, 'localStorage'",
    )
    expect(document).toContain('"localStorage":{"theme":"dark"}')
    expect(document).toContain('https://cfx-nui-snake_app/ui/dist/')
    expect(document).not.toContain('</script><script>window.injected=true')
    expect(document.indexOf('globalThis.invokeNative')).toBeLessThan(
      document.indexOf('globalThis.previewMode'),
    )

    const openingTag = '<script>'
    const runtimeStart = document.indexOf(openingTag)
    const runtimeEnd = document.indexOf(
      '</script>',
      runtimeStart + openingTag.length,
    )
    expect(runtimeStart).toBeGreaterThanOrEqual(0)
    expect(runtimeEnd).toBeGreaterThan(runtimeStart)

    const runtime = document.slice(runtimeStart + openingTag.length, runtimeEnd)
    expect(() => new Function(runtime)).not.toThrow()
  })

  it('applies the LB iframe layout contract before revealing vendor apps', () => {
    const document = createLbPhoneFrameDocument(
      '<!doctype html><html><head></head><body style="visibility:hidden"></body></html>',
      {
        appName: 'radio-app',
        localStorage: {},
        resourceName: 'lb-radioapp',
        settings: createLbPhoneHostSettings({
          deviceName: 'Main phone',
          isDarkMode: true,
          language: 'en',
          preferences: DEFAULT_PHONE_PREFERENCES,
          securityEnabled: false,
        }),
        ui: 'https://cfx-nui-lb-radioapp/ui/dist/index.html',
      },
    )
    const runtime = /<script>([\s\S]*?)<\/script>/i.exec(document)?.[1]
    expect(runtime).toBeTruthy()

    const messageListeners: Array<(event: { data: unknown }) => void> = []
    const readyListeners: Array<() => void> = []
    const documentElement = { dataset: {}, style: {} }
    const body = {
      dataset: {},
      style: { visibility: 'hidden' },
    }
    const sandbox = {
      addEventListener(
        eventName: string,
        listener: (event: { data: unknown }) => void,
      ) {
        if (eventName === 'message') messageListeners.push(listener)
      },
      componentsLoaded: undefined as boolean | undefined,
      console,
      document: {
        addEventListener(eventName: string, listener: () => void) {
          if (eventName === 'DOMContentLoaded') readyListeners.push(listener)
        },
        body,
        documentElement,
      },
      parent: { postMessage() {} },
    }

    runInNewContext(runtime ?? '', sandbox)
    expect(body.style.visibility).toBe('hidden')

    expect(readyListeners).toHaveLength(1)
    readyListeners[0]?.()
    expect(documentElement.style).toMatchObject({
      height: '100%',
      margin: '0',
      padding: '0',
      width: '100%',
    })
    expect(body.dataset).toMatchObject({ device: 'phone', theme: 'dark' })
    expect(body.style).toMatchObject({
      height: '100%',
      margin: '0',
      padding: '0',
      visibility: 'visible',
      width: '100%',
    })

    body.style.visibility = 'hidden'
    expect(messageListeners).toHaveLength(1)
    messageListeners[0]?.({ data: 'componentsLoaded' })
    expect(body.style.visibility).toBe('visible')
    expect(sandbox.componentsLoaded).toBe(true)
  })

  it('persists isolated LB localStorage snapshots without app changes', () => {
    const values = new Map<string, string>()
    const storage = {
      getItem: (key: string) => values.get(key) ?? null,
      setItem: (key: string, value: string) => values.set(key, value),
    }

    expect(
      writeLbPhoneStorage(storage, 'snake-game', {
        language: 'de',
        volume: '0.8',
      }),
    ).toBe(true)
    expect(values.has(getLbPhoneStorageKey('snake-game'))).toBe(true)
    expect(readLbPhoneStorage(storage, 'snake-game')).toEqual({
      language: 'de',
      volume: '0.8',
    })
    expect(writeLbPhoneStorage(storage, 'snake-game', { invalid: 5 })).toBe(
      false,
    )
  })
})
