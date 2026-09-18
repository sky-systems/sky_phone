import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

import { createPinia, setActivePinia } from 'pinia'
import ts from 'typescript'
import { ref, type Ref } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useAppStoreStore } from '@/stores/app-store'
import { usePhoneStore } from '@/stores/phone'
import { nuiCall, type NuiResponse } from '@/utils/nui'
import { PHONE_SETUP_LAST_STEP } from '@/utils/preferences'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
const mockNuiCall = vi.mocked(nuiCall)

// Exercise the production click handlers and real persistence queues without
// mounting unrelated setup pages, security controls, or the entire phone shell.
const source = readFileSync(
  new URL('./PhoneSetupAssistant.vue', import.meta.url),
  'utf8',
)
const script = source.match(/<script setup lang="ts">([\s\S]*?)<\/script>/)?.[1]
if (!script) throw new Error('Setup Assistant script was not found')
const parsed = ts.createSourceFile(
  'Setup.ts',
  script,
  ts.ScriptTarget.Latest,
  true,
)
const handlers = parsed.statements
  .filter(
    (node) =>
      ts.isFunctionDeclaration(node) &&
      ['continueSetup', 'finish'].includes(node.name?.text ?? ''),
  )
  .map((node) => node.getText(parsed))
  .join('\n')
const executable = ts.transpileModule(`${handlers}\n({ continueSetup })`, {
  compilerOptions: { target: ts.ScriptTarget.ES2022 },
}).outputText

describe('Setup Assistant app selection completion', () => {
  let continueSetup: () => Promise<void>
  let emit: ReturnType<typeof vi.fn>
  let selectedApps: Ref<string[]>
  let busy: Ref<boolean>
  let error: Ref<string>

  beforeEach(() => {
    vi.stubGlobal('window', { matchMedia: () => ({ matches: false }) })
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
    mockNuiCall.mockImplementation(async (_endpoint, data) => ({
      success: true,
      data: { revision: Number(data?.revision ?? 0) + 1 },
    }))
    usePhoneStore().open({
      device: {
        data: {
          settings: {
            payload: {
              version: 1,
              settings: { setupCompleted: false, setupStep: 8 },
            },
            revision: 4,
          },
        },
        imei: '356938035643809',
        name: 'Phone',
        sim: null,
      },
      token: 'authorized-session',
    })
    emit = vi.fn()
    selectedApps = ref(['banking', 'garage', 'skyride'])
    busy = ref(false)
    error = ref('')
    const runtime = runInNewContext(executable, {
      phone: usePhoneStore(),
      appStore: useAppStoreStore(),
      emit,
      selectedApps,
      setupCompleteBusy: busy,
      setupCompleteError: error,
      step: ref(8),
    }) as { continueSetup: typeof continueSetup }
    continueSetup = runtime.continueSetup
  })

  afterEach(async () => {
    await usePhoneStore().flushDevicePersistence()
    vi.unstubAllGlobals()
  })

  it('waits for selected apps to save before completing setup and ignores double clicks', async () => {
    let acknowledge!: (response: NuiResponse<{ revision: number }>) => void
    mockNuiCall.mockReturnValueOnce(
      new Promise((resolve) => {
        acknowledge = resolve
      }),
    )

    const completion = continueSetup()
    await Promise.resolve()
    await continueSetup()
    try {
      expect(busy.value).toBe(true)
      expect(mockNuiCall).toHaveBeenCalledTimes(1)
      expect(mockNuiCall.mock.calls[0]?.[1]?.namespace).toBe('apps')
      expect(usePhoneStore().preferences.settings.setupCompleted).toBe(false)
      expect(emit).not.toHaveBeenCalled()
    } finally {
      acknowledge({ success: true, data: { revision: 1 } })
    }
    await completion

    const saves = mockNuiCall.mock.calls.map(([, data]) => data)
    expect(saves.map((data) => data?.namespace)).toEqual([
      'apps',
      'apps',
      'apps',
      'settings',
    ])
    expect(saves[2]?.payload).toMatchObject({ claimedApps: selectedApps.value })
    expect(usePhoneStore().preferences.settings.setupCompleted).toBe(true)
    expect(usePhoneStore().preferences.settings.setupStep).toBe(
      PHONE_SETUP_LAST_STEP,
    )
    expect(emit).toHaveBeenCalledExactlyOnceWith('complete')
    expect(busy.value).toBe(false)
  })

  it('keeps setup open after a rejected app save and persists that app again on retry', async () => {
    mockNuiCall.mockResolvedValueOnce({
      success: false,
      error: 'request_failed',
    })

    await continueSetup()

    expect(usePhoneStore().preferences.settings.setupCompleted).toBe(false)
    expect(emit).not.toHaveBeenCalled()
    expect(error.value).toBe(usePhoneStore().t('Setup.ready.saveFailed'))
    expect(busy.value).toBe(false)
    expect(mockNuiCall).toHaveBeenCalledTimes(1)

    await continueSetup()

    expect(mockNuiCall.mock.calls[1]?.[1]?.namespace).toBe('apps')
    expect(emit).toHaveBeenCalledExactlyOnceWith('complete')
    expect(error.value).toBe('')
  })

  it('reports a rejected completion save and allows a successful retry', async () => {
    selectedApps.value = []
    mockNuiCall.mockResolvedValueOnce({
      success: false,
      error: 'request_failed',
    })

    await continueSetup()

    expect(usePhoneStore().preferences.settings.setupCompleted).toBe(false)
    expect(error.value).toBe(usePhoneStore().t('Setup.ready.saveFailed'))
    expect(emit).not.toHaveBeenCalled()
    expect(busy.value).toBe(false)

    await continueSetup()

    expect(emit).toHaveBeenCalledExactlyOnceWith('complete')
    expect(usePhoneStore().preferences.settings.setupCompleted).toBe(true)
  })

  it('completes with no optional apps selected', async () => {
    selectedApps.value = []

    await continueSetup()

    expect(mockNuiCall).toHaveBeenCalledTimes(1)
    expect(mockNuiCall.mock.calls[0]?.[1]?.namespace).toBe('settings')
    expect(emit).toHaveBeenCalledExactlyOnceWith('complete')
  })
})
