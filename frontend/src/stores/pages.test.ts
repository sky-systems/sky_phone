import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { usePagesStore } from '@/stores/pages'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
const mockNuiCall = vi.mocked(nuiCall)

describe('Local Pages store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('shares only the CityMarkt listing id with the server', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: { id: 'post-id' }, success: true })
    const response = await usePagesStore().shareCityMarkt('listing-id')
    expect(response.success).toBe(true)
    expect(mockNuiCall).toHaveBeenCalledWith('pages:share-citymarkt', {
      listingId: 'listing-id',
    })
  })

  it('updates a successful like locally', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const pages = usePagesStore()
    pages.items = [{ id: 'post-id', is_liked: false, like_count: 2 } as never]
    await pages.react('post-id', 'like', true)
    expect(pages.items[0]?.is_liked).toBe(true)
    expect(pages.items[0]?.like_count).toBe(3)
  })
})
