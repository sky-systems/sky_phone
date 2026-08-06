import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useBankingStore } from '@/stores/banking'
import type { BankingOverview } from '@/types/banking'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const mockNuiCall = vi.mocked(nuiCall)
const overview: BankingOverview = {
  bank: 24787,
  cash: 2350,
  currency: '$',
  playerId: 42,
  playerName: 'Alex Morgan',
  transactions: [],
}

describe('banking store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads the server-authoritative banking overview', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: overview, success: true })
    const banking = useBankingStore()

    expect(await banking.load()).toBe(true)
    expect(banking.overview).toEqual(overview)
    expect(mockNuiCall).toHaveBeenCalledWith('banking:overview')
  })

  it('updates balances after a successful transfer', async () => {
    const updated = { ...overview, bank: 23787 }
    mockNuiCall.mockResolvedValueOnce({ data: updated, success: true })
    const banking = useBankingStore()

    const response = await banking.perform('transfer', 1000, 17)

    expect(response.success).toBe(true)
    expect(banking.overview?.bank).toBe(23787)
    expect(mockNuiCall).toHaveBeenCalledWith('banking:transfer', {
      amount: 1000,
      target: 17,
    })
  })

  it('keeps the previous overview and exposes server errors', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'insufficient_funds',
      success: false,
    })
    const banking = useBankingStore()
    banking.overview = overview

    await banking.perform('withdraw', 50000)

    expect(banking.overview).toEqual(overview)
    expect(banking.error).toBe('insufficient_funds')
  })
})
