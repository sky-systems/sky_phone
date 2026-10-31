import { describe, expect, it, vi } from 'vitest'
import { effectScope } from 'vue'

import { useAdminQuery } from '@/composables/useAdminQuery'
import type { NuiResponse } from '@/utils/nui'

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((settle) => {
    resolve = settle
  })
  return { promise, resolve }
}

describe('admin record requests', () => {
  it('does not replace a newly selected player with an earlier response', async () => {
    const records = useAdminQuery<string[]>()
    const first = deferred<NuiResponse<string[]>>()
    const second = deferred<NuiResponse<string[]>>()
    const oldRequest = records.load(() => first.promise)
    records.invalidate()
    const currentRequest = records.load(() => second.promise)
    first.resolve({ success: true, data: ['old player'] })
    expect(await oldRequest).toBe(false)
    expect(records.data.value).toBeNull()
    expect(records.loading.value).toBe(true)
    second.resolve({ success: true, data: ['current player'] })
    expect(await currentRequest).toBe(true)
    expect(records.data.value).toEqual(['current player'])
  })

  it('ignores an old failure without hiding an active load and preserves data on failed pagination', async () => {
    const records = useAdminQuery<string[]>()
    const first = deferred<NuiResponse<string[]>>()
    const oldRequest = records.load(() => first.promise)
    await records.load(async () => ({ success: true, data: ['page one'] }))
    first.resolve({ success: false, error: 'not_authorized' })
    await oldRequest
    expect(records.error.value).toBe('')
    expect(
      await records.load(async () => ({
        success: false,
        error: 'request_timeout',
      })),
    ).toBe(false)
    expect(records.data.value).toEqual(['page one'])
    expect(records.error.value).toBe('request_timeout')
  })

  it('discards in-flight results after its view closes', async () => {
    const scope = effectScope()
    const records = scope.run(() => useAdminQuery<string[]>())!
    const pending = deferred<NuiResponse<string[]>>()
    const request = records.load(() => pending.promise)
    scope.stop()
    pending.resolve({ success: true, data: ['closed view'] })
    expect(await request).toBe(false)
    expect(records.data.value).toBeNull()
    expect(records.loading.value).toBe(false)
    const lateRefresh = vi.fn(async () => ({
      success: true,
      data: ['late refresh'],
    }))
    expect(await records.load(lateRefresh)).toBe(false)
    expect(lateRefresh).not.toHaveBeenCalled()
  })
})
