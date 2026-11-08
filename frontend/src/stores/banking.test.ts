import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useBankingStore } from '@/stores/banking'
import type { BankingOverview } from '@/types/banking'
import { nuiCall, type NuiResponse } from '@/utils/nui'

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

    const response = await banking.perform('transfer', 1000, '5551234567')

    expect(response.success).toBe(true)
    expect(banking.overview?.bank).toBe(23787)
    expect(mockNuiCall).toHaveBeenCalledWith('banking:transfer', {
      amount: 1000,
      phoneNumber: '5551234567',
    })
  })

  it('accepts a completed transfer without a replacement character overview', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const banking = useBankingStore()
    banking.error = 'request_failed'

    const response = await banking.perform('transfer', 200, '5551234567')

    expect(response.success).toBe(true)
    expect(banking.overview).toBeNull()
    expect(banking.error).toBe('')
  })

  it('keeps the previous overview and exposes server errors', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'insufficient_funds',
      success: false,
    })
    const banking = useBankingStore()
    banking.overview = overview

    await banking.perform('transfer', 50000, '5551234567')

    expect(banking.overview).toEqual(overview)
    expect(banking.error).toBe('insufficient_funds')
  })

  it('does not let an older overview response overwrite a newer transfer', async () => {
    let resolveOlder!: (response: NuiResponse<BankingOverview>) => void
    const olderResponse = new Promise<NuiResponse<BankingOverview>>(
      (resolve) => {
        resolveOlder = resolve
      },
    )
    const newest = { ...overview, bank: 23000 }
    mockNuiCall
      .mockReturnValueOnce(olderResponse)
      .mockResolvedValueOnce({ data: newest, success: true })
    const banking = useBankingStore()

    const olderRequest = banking.load()
    await banking.perform('transfer', 1787, '5551234567')
    resolveOlder({ data: { ...overview, bank: 1 }, success: true })
    await olderRequest

    expect(banking.overview).toEqual(newest)
    expect(banking.isLoading).toBe(false)
  })

  it('coalesces concurrent overview reloads into one NUI request', async () => {
    let resolveLoad!: (response: NuiResponse<BankingOverview>) => void
    mockNuiCall.mockReturnValueOnce(
      new Promise<NuiResponse<BankingOverview>>((resolve) => {
        resolveLoad = resolve
      }),
    )
    const banking = useBankingStore()

    const firstLoad = banking.load()
    const secondLoad = banking.load()
    resolveLoad({ data: overview, success: true })

    expect(await firstLoad).toBe(true)
    expect(await secondLoad).toBe(true)
    expect(mockNuiCall).toHaveBeenCalledTimes(1)
  })

  it('queues one fresh overview after a server-side balance change', async () => {
    let resolveActive!: (response: NuiResponse<BankingOverview>) => void
    mockNuiCall
      .mockReturnValueOnce(
        new Promise<NuiResponse<BankingOverview>>((resolve) => {
          resolveActive = resolve
        }),
      )
      .mockResolvedValueOnce({
        data: { ...overview, bank: overview.bank + 500 },
        success: true,
      })
    const banking = useBankingStore()

    const activeLoad = banking.load()
    const changedLoad = banking.load(false, true)
    const duplicateChangedLoad = banking.load(false, true)
    resolveActive({ data: overview, success: true })

    await activeLoad
    expect(await changedLoad).toBe(true)
    expect(await duplicateChangedLoad).toBe(true)
    expect(banking.overview?.bank).toBe(overview.bank + 500)
    expect(mockNuiCall).toHaveBeenCalledTimes(2)
  })

  it('limits manual refreshes without blocking automatic loads or transfers', async () => {
    const banking = useBankingStore()
    banking.cooldownUntil = Date.now() + 10_000
    mockNuiCall
      .mockResolvedValueOnce({ data: overview, success: true })
      .mockResolvedValueOnce({ data: overview, success: true })

    expect(await banking.load(true)).toBe(false)
    expect(await banking.load()).toBe(true)
    expect((await banking.perform('transfer', 100, '5551234567')).success).toBe(
      true,
    )
    expect(mockNuiCall).toHaveBeenCalledTimes(2)
  })
})
