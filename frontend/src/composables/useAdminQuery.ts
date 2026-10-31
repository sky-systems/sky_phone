import { getCurrentScope, onScopeDispose, ref, shallowRef } from 'vue'

import type { NuiResponse } from '@/utils/nui'

// Views can change player/platform while an earlier request is still in flight.
export function useAdminQuery<T>() {
  const data = shallowRef<T | null>(null)
  const loading = ref(false)
  const error = ref('')
  let generation = 0
  let disposed = false

  function invalidate(): void {
    generation += 1
    data.value = null
    error.value = ''
    loading.value = false
  }

  async function load(
    request: () => Promise<NuiResponse<T>>,
  ): Promise<boolean> {
    if (disposed) return false
    const current = ++generation
    loading.value = true
    error.value = ''
    try {
      const response = await request()
      if (current !== generation) return false
      if (!response.success || !response.data) {
        error.value = response.error ?? 'request_failed'
        return false
      }
      data.value = response.data
      return true
    } catch (cause) {
      if (current === generation) {
        console.error('[sky_phone] Admin records request failed.', cause)
        error.value = 'request_failed'
      }
      return false
    } finally {
      if (current === generation) loading.value = false
    }
  }

  if (getCurrentScope())
    onScopeDispose(() => {
      disposed = true
      invalidate()
    })
  return { data, loading, error, load, invalidate }
}
