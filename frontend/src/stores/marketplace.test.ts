import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useMarketplaceStore } from '@/stores/marketplace'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

const mockNuiCall = vi.mocked(nuiCall)

describe('marketplace store offers', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('sends an offer and refreshes conversations and counts', async () => {
    mockNuiCall
      .mockResolvedValueOnce({ data: { id: 7 }, success: true })
      .mockResolvedValueOnce({ data: [], success: true })
      .mockResolvedValueOnce({ data: { active: 1, unread: 0 }, success: true })

    const marketplace = useMarketplaceStore()
    const response = await marketplace.makeOffer('inquiry-id', 175000)

    expect(response).toEqual({ data: { id: 7 }, success: true })
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'marketplace:make-offer', {
      amount: 175000,
      inquiryId: 'inquiry-id',
    })
    expect(mockNuiCall).toHaveBeenCalledWith('marketplace:list-inquiries')
    expect(mockNuiCall).toHaveBeenCalledWith('marketplace:counts')
  })

  it('does not refresh state when an offer response is rejected by the server', async () => {
    mockNuiCall.mockResolvedValueOnce({ error: 'offer_conflict', success: false })

    const marketplace = useMarketplaceStore()
    const response = await marketplace.respondOffer('inquiry-id', 'accepted')

    expect(response).toEqual({ error: 'offer_conflict', success: false })
    expect(mockNuiCall).toHaveBeenCalledTimes(1)
    expect(mockNuiCall).toHaveBeenCalledWith('marketplace:respond-offer', {
      action: 'accepted',
      inquiryId: 'inquiry-id',
    })
  })
})
