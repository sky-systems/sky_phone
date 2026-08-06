import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useMediaStore } from '@/stores/media'

const mocks = vi.hoisted(() => ({
  saveDeviceNamespace: vi.fn(),
}))

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))
vi.mock('@/stores/phone', () => ({
  usePhoneStore: () => ({ saveDeviceNamespace: mocks.saveDeviceNamespace }),
}))

describe('media store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.restoreAllMocks()
    mocks.saveDeviceNamespace.mockReset()
  })

  it('returns each captured photo and persists it in the shared gallery', () => {
    vi.spyOn(Date, 'now').mockReturnValue(123456789)
    const media = useMediaStore()

    const first = media.capture()
    const second = media.capture()

    expect(first.id).toBe('capture-123456789-1')
    expect(second.id).toBe('capture-123456789-2')
    expect(media.photos.slice(0, 2)).toEqual([second, first])
    expect(mocks.saveDeviceNamespace).toHaveBeenLastCalledWith('media', {
      captures: [second, first],
      claimedApps: [],
    })
  })
})
