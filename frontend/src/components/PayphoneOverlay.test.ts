import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'

import ts from 'typescript'
import { computed, nextTick, ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

const source = readFileSync(
  new URL('./PayphoneOverlay.vue', import.meta.url),
  'utf8',
)
const setup = source.match(/<script setup lang="ts">([\s\S]*?)<\/script>/)?.[1]
if (!setup) throw new Error('Payphone setup script is missing')
const parsed = ts.createSourceFile(
  'PayphoneOverlay.ts',
  setup,
  ts.ScriptTarget.Latest,
  true,
)
const executable = ts.transpileModule(
  parsed.statements
    .filter((statement) => !ts.isImportDeclaration(statement))
    .map((statement) => statement.getText(parsed))
    .join('\n') + '\n;({ appendDigit, onMessage })',
  { compilerOptions: { target: ts.ScriptTarget.ES2022 } },
).outputText

function createPayphone() {
  const stops: Array<ReturnType<typeof vi.fn>> = []
  const playPhoneEffect = vi.fn(() => {
    const stop = vi.fn()
    stops.push(stop)
    return stop
  })
  let unmount: () => void = () => undefined
  const host = { removeEventListener: vi.fn(), clearInterval: vi.fn() }
  const runtime = runInNewContext(executable, {
    computed,
    nextTick,
    ref,
    onMounted: vi.fn(),
    onBeforeUnmount: (callback: () => void) => {
      unmount = callback
    },
    isTrustedRootMessageSource: (source: unknown) => source === host,
    nuiCall: vi.fn(async () => ({ success: true })),
    playPhoneEffect,
    window: host,
  }) as {
    appendDigit: (digit: string) => void
    onMessage: (event: { source: unknown; data: { type: string } }) => void
  }
  return { host, playPhoneEffect, runtime, stops, unmount: () => unmount() }
}

describe('payphone synthesized keypad audio', () => {
  it('replaces the preceding key tone and releases the last tone on unmount', () => {
    const phone = createPayphone()
    phone.runtime.appendDigit('1')
    phone.runtime.appendDigit('2')
    expect(phone.playPhoneEffect).toHaveBeenCalledTimes(2)
    expect(phone.playPhoneEffect).toHaveBeenLastCalledWith('button', 55, false)
    expect(phone.stops[0]).toHaveBeenCalledOnce()
    expect(phone.stops[1]).not.toHaveBeenCalled()
    phone.unmount()
    expect(phone.stops[1]).toHaveBeenCalledOnce()
  })

  it('stops audio on a trusted close without letting foreign messages interrupt it', () => {
    const phone = createPayphone()
    phone.runtime.appendDigit('3')
    phone.runtime.onMessage({ source: {}, data: { type: 'payphone:close' } })
    expect(phone.stops[0]).not.toHaveBeenCalled()
    phone.runtime.onMessage({
      source: phone.host,
      data: { type: 'payphone:close' },
    })
    expect(phone.stops[0]).toHaveBeenCalledOnce()
    phone.unmount()
    expect(phone.stops[0]).toHaveBeenCalledOnce()
  })
})
