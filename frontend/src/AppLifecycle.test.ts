import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

import { createPinia, setActivePinia } from 'pinia'
import ts from 'typescript'
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
      ts.isFunctionDeclaration(node) &&
      ['hydratePhone', 'onMessage'].includes(node.name?.text ?? ''),
  )
  .map((node) => node.getText(parsed))
  .join('\n')
const executable = ts.transpileModule(`${handlers}\nonMessage`, {
  compilerOptions: { target: ts.ScriptTarget.ES2022 },
}).outputText

const payload: PhoneOpenPayload = {
  device: { data: {}, imei: '356938035643809', name: 'Phone', sim: null },
  token: 'authorized-session',
}

describe('phone root device lifecycle', () => {
  let onMessage: (event: { source: null; data: unknown }) => void

  beforeEach(() => {
    vi.stubGlobal('window', { matchMedia: () => ({ matches: false }) })
    setActivePinia(createPinia())
    const hydrate = vi.fn()
    onMessage = runInNewContext(executable, {
      window,
      isTrustedRootMessageSource,
      phone: usePhoneStore(),
      configurePhoneNumberFormat: vi.fn(),
      companies: { bindDeviceScope: vi.fn() },
      appCatalog: { externalApps: [] },
      notifications: { hydrate, hideDevicePreview: vi.fn() },
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
    }) as typeof onMessage
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
})
