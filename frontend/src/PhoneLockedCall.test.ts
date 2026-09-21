import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

import { createPinia, setActivePinia } from 'pinia'
import ts from 'typescript'
import { computed, ref, type ComputedRef, type Ref } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useCallsStore } from '@/stores/calls'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneCall } from '@/types/phone'
import { nuiCall } from '@/utils/nui'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
vi.mock('@/utils/tones', () => ({
  playPhoneMediaTone: vi.fn(() => vi.fn()),
  playPhoneTone: vi.fn(() => vi.fn()),
  playPhoneVibration: vi.fn(() => vi.fn()),
}))

function parseSetup(path: string): ts.SourceFile {
  const source = readFileSync(new URL(path, import.meta.url), 'utf8')
  const script = source.match(
    /<script setup lang="ts">([\s\S]*?)<\/script>/,
  )?.[1]
  if (!script) throw new Error(`Setup script was not found in ${path}`)
  return ts.createSourceFile(path, script, ts.ScriptTarget.Latest, true)
}

const rootScript = parseSetup('./App.vue')
const rootHandlers = rootScript.statements
  .filter(
    (node) =>
      (ts.isFunctionDeclaration(node) &&
        [
          'onMessage',
          'unlockPhone',
          'finishUnlock',
          'completeUnlock',
          'submitUnlockPasscode',
          'cancelPasscode',
        ].includes(node.name?.text ?? '')) ||
      (ts.isVariableStatement(node) &&
        node.declarationList.declarations.some(
          (declaration) =>
            declaration.name.getText(rootScript) === 'lockedCallVisible',
        )),
  )
  .map((node) => node.getText(rootScript))
  .join('\n')
const executable = ts.transpileModule(
  `${rootHandlers}\n({ onMessage, lockedCallVisible, unlockPhone, submitUnlockPasscode, cancelPasscode })`,
  { compilerOptions: { target: ts.ScriptTarget.ES2022 } },
).outputText

const incomingCall: PhoneCall = {
  id: 'locked-call',
  direction: 'incoming',
  state: 'ringing',
  otherNumber: '5551110025',
  startedAt: 1,
  speakerSupported: true,
  muteSupported: true,
}

describe('incoming calls on a locked phone', () => {
  let isLocked: Ref<boolean>
  let passcodeVisible: Ref<boolean>
  let loadUnlockedPhoneData: ReturnType<typeof vi.fn>
  let runtime: {
    onMessage: (event: { source: null; data: unknown }) => void
    lockedCallVisible: ComputedRef<boolean>
    unlockPhone: () => void
    submitUnlockPasscode: (passcode: string) => Promise<void>
    cancelPasscode: () => void
  }

  beforeEach(() => {
    vi.useFakeTimers()
    vi.stubGlobal('window', {
      matchMedia: () => ({ matches: false }),
      setTimeout,
      clearTimeout,
    })
    setActivePinia(createPinia())
    vi.mocked(nuiCall).mockResolvedValue({ success: true, data: [] })
    const phone = usePhoneStore()
    phone.open({
      device: { imei: '356938035643809', name: 'Phone', sim: null, data: {} },
      token: 'authorized-session',
      security: { enabled: true, length: 4, lockedUntil: 0 },
    })
    isLocked = ref(true)
    passcodeVisible = ref(false)
    loadUnlockedPhoneData = vi.fn()
    runtime = runInNewContext(executable, {
      window,
      computed,
      phone,
      calls: useCallsStore(),
      isTrustedRootMessageSource,
      isLocked,
      isUnlocking: ref(false),
      passcodeVisible,
      passcodeRequired: ref(true),
      passcodeBusy: ref(false),
      passcodeError: ref(''),
      passcodeResetKey: ref(0),
      passcodeRetrySeconds: ref(0),
      pendingUnlockRoute: ref(null),
      controlCenterOpened: ref(false),
      unlockTimer: undefined,
      loadUnlockedPhoneData,
    })
  })

  afterEach(() => {
    vi.clearAllMocks()
    vi.clearAllTimers()
    vi.useRealTimers()
    vi.unstubAllGlobals()
  })

  it('shows incoming and connected call controls without unlocking the device', async () => {
    runtime.onMessage({
      source: null,
      data: { type: 'call:incoming', data: incomingCall },
    })
    expect(runtime.lockedCallVisible.value).toBe(true)
    expect(isLocked.value).toBe(true)

    await useCallsStore().answer()
    expect(useCallsStore().activeCall?.state).toBe('connected')
    expect(runtime.lockedCallVisible.value).toBe(true)
    expect(isLocked.value).toBe(true)
    expect(loadUnlockedPhoneData).not.toHaveBeenCalled()
    expect(nuiCall).not.toHaveBeenCalledWith(
      'security:unlock',
      expect.anything(),
    )
  })

  it('returns to the locked screen after declining or hanging up', async () => {
    for (const action of ['decline', 'hangup'] as const) {
      useCallsStore().applyCallState(incomingCall)
      await useCallsStore()[action]()
      expect(runtime.lockedCallVisible.value).toBe(false)
      expect(isLocked.value).toBe(true)
    }
  })

  it('keeps the ongoing call restricted when unlocking is cancelled or rejected', async () => {
    useCallsStore().applyCallState({ ...incomingCall, state: 'connected' })
    runtime.unlockPhone()
    expect(passcodeVisible.value).toBe(true)
    expect(isLocked.value).toBe(true)

    vi.mocked(nuiCall).mockResolvedValueOnce({
      success: false,
      error: 'invalid_passcode',
    })
    await runtime.submitUnlockPasscode('9999')
    expect(passcodeVisible.value).toBe(true)
    expect(isLocked.value).toBe(true)
    runtime.cancelPasscode()
    expect(passcodeVisible.value).toBe(false)
    expect(runtime.lockedCallVisible.value).toBe(true)
    expect(useCallsStore().activeCall?.state).toBe('connected')
    expect(loadUnlockedPhoneData).not.toHaveBeenCalled()
  })

  it('allows other apps only after the server accepts the passcode, keeping the call active', async () => {
    useCallsStore().applyCallState({ ...incomingCall, state: 'connected' })
    runtime.unlockPhone()
    vi.mocked(nuiCall).mockResolvedValueOnce({ success: true })
    await runtime.submitUnlockPasscode('1234')
    expect(nuiCall).toHaveBeenCalledWith('security:unlock', {
      passcode: '1234',
    })
    expect(isLocked.value).toBe(false)
    expect(passcodeVisible.value).toBe(false)
    expect(runtime.lockedCallVisible.value).toBe(false)
    expect(useCallsStore().activeCall?.state).toBe('connected')
    await vi.advanceTimersByTimeAsync(720)
    expect(loadUnlockedPhoneData).toHaveBeenCalledOnce()
  })

  it('does not show the locked call overlay for a closed or unlocked phone', () => {
    useCallsStore().applyCallState(incomingCall)
    isLocked.value = false
    expect(runtime.lockedCallVisible.value).toBe(false)
    isLocked.value = true
    usePhoneStore().endDeviceSession()
    expect(runtime.lockedCallVisible.value).toBe(false)
  })

  it('starts the locked call timer without loading contacts, recents, or private deep links', async () => {
    const script = parseSetup('./views/apps/PhoneApp.vue')
    const mounted = script.statements.find(
      (node) =>
        ts.isExpressionStatement(node) &&
        ts.isCallExpression(node.expression) &&
        node.expression.expression.getText(script) === 'onMounted',
    )
    if (!mounted) throw new Error('Phone app mounted hook was not found')
    const code = ts.transpileModule(mounted.getText(script), {
      compilerOptions: { target: ts.ScriptTarget.ES2022 },
    }).outputText
    const updateCallElapsed = vi.fn()
    const bootstrap = vi.fn()
    const consumeMany = vi.fn()
    const setInterval = vi.fn()
    let mount: (() => Promise<void>) | undefined
    runInNewContext(code, {
      onMounted: (callback: () => Promise<void>) => {
        mount = callback
      },
      props: { locked: true },
      calls: { bootstrap },
      mediaPicker: { consumeMany },
      window: { setInterval },
      updateCallElapsed,
      callClock: null,
    })
    await mount?.()
    expect(updateCallElapsed).toHaveBeenCalledOnce()
    expect(setInterval).toHaveBeenCalledWith(updateCallElapsed, 500)
    expect(bootstrap).not.toHaveBeenCalled()
    expect(consumeMany).not.toHaveBeenCalled()
  })
})
