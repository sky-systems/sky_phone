import { describe, expect, it } from 'vitest'

import type { ExternalPhoneAppDefinition } from '@/types/apps'
import {
  createLbPhoneFrameDocument,
  createLbPhoneHostSettings,
  getLbPhoneCallbackResource,
  usesLbPhoneHostRuntime,
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
      '<!doctype html><html><head><script type="module" src="/ui/dist/assets/index.js"></script></head><body></body></html>'
    const document = createLbPhoneFrameDocument(html, {
      appName: 'snake-game',
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
    expect(document).toContain('https://cfx-nui-snake_app/ui/dist/')
    expect(document).not.toContain('</script><script>window.injected=true')

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
})
