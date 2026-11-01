import { createPinia, setActivePinia } from 'pinia'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { useKnowayStore } from '@/stores/knoway'
import type { KnowayQuote, KnowayRide, KnowayState } from '@/types/knoway'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const call = vi.mocked(nuiCall)
const policy = { beforeStart: true, afterStart: false, technical: true }
const quote: KnowayQuote = {
  id: 'quote-1',
  pickup: { coords: { x: 200, y: -800, z: 30 }, label: 'Pillbox Hill' },
  destination: { coords: { x: -1035, y: -2730, z: 20 }, label: 'Airport' },
  price: 84,
  currency: '$',
  distanceMeters: 4000,
  durationSeconds: 360,
  expiresAt: 2_000_000_120,
  refundPolicy: policy,
}
const ride: KnowayRide = {
  ...quote,
  id: 'ride-1',
  status: 'approaching',
  createdAt: 2_000_000_000,
  vehicle: {
    model: 'configured-e-stride',
    plate: 'KNOWAY01',
    netId: 20,
    driverNetId: 21,
  },
}
const state: KnowayState = {
  activeRide: ride,
  available: true,
  currency: '$',
  refundPolicy: policy,
}

describe('KnoWay bookings', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    call.mockReset()
    vi.useFakeTimers()
    vi.setSystemTime(2_000_000_000_000)
  })

  afterEach(() => vi.useRealTimers())

  it('restores a running ride and its agreed refund policy after reopening', async () => {
    const store = useKnowayStore()
    store.quote = quote
    call.mockResolvedValueOnce({
      success: true,
      data: { ...state, available: false },
    })

    expect(await store.bootstrap()).toBe(true)
    expect(store.activeRide).toEqual(ride)
    expect(store.available).toBe(false)
    expect(store.hasActiveRide).toBe(true)
    expect(store.quote).toBeNull()
    expect(store.refundPolicy).toEqual(policy)
  })

  it('quotes only the chosen destination; price and pickup come from the server', async () => {
    call.mockResolvedValueOnce({ success: true, data: quote })
    const store = useKnowayStore()

    expect(await store.createQuote(quote.destination)).toBe(true)
    expect(call).toHaveBeenCalledWith('knoway:quote', {
      destination: quote.destination,
    })
    expect(store.quote).toEqual(quote)
  })

  it('books using the accepted quote id without sending a client-calculated fare', async () => {
    call.mockResolvedValueOnce({ success: true, data: state })
    const store = useKnowayStore()
    store.quote = quote

    expect(await store.requestRide()).toBe(true)
    expect(call).toHaveBeenCalledWith('knoway:request', { quoteId: quote.id })
    expect(store.quote).toBeNull()
    expect(store.activeRide?.id).toBe(ride.id)
  })

  it('prevents a second booking while the first response is outstanding', async () => {
    let resolve!: (value: { success: boolean; data: KnowayState }) => void
    call.mockImplementationOnce(
      () =>
        new Promise((done) => {
          resolve = done
        }),
    )
    const store = useKnowayStore()
    store.quote = quote

    const pending = store.requestRide()
    expect(await store.requestRide()).toBe(false)
    expect(call).toHaveBeenCalledTimes(1)
    resolve({ success: true, data: state })
    expect(await pending).toBe(true)
    expect(store.isActionPending).toBe(false)
  })

  it('expires a displayed quote before any booking request is sent', async () => {
    const store = useKnowayStore()
    store.quote = { ...quote, expiresAt: 1_999_999_999 }

    expect(await store.requestRide()).toBe(false)
    expect(call).not.toHaveBeenCalled()
    expect(store.quote).toBeNull()
    expect(store.error).toBe('quote_expired')
  })

  it('retains the server error and fresh state when starting outside the vehicle fails', async () => {
    call.mockResolvedValueOnce({
      success: false,
      error: 'not_in_vehicle',
      data: state,
    })
    const store = useKnowayStore()
    store.activeRide = { ...ride, status: 'waiting' }

    expect(await store.performAction('start')).toBe(false)
    expect(call).toHaveBeenCalledWith('knoway:start', { rideId: ride.id })
    expect(store.error).toBe('not_in_vehicle')
    expect(store.isActionPending).toBe(false)
    expect(store.activeRide).toEqual(ride)
  })

  it('keeps an active booking when the UI tries to dismiss it', () => {
    const store = useKnowayStore()
    store.activeRide = ride
    store.dismissRide()
    expect(store.activeRide).toEqual(ride)
    store.applyUpdate({ activeRide: { ...ride, status: 'arrived' } })
    store.dismissRide()
    expect(store.activeRide).toBeNull()
  })

  it('ignores a stale polling response after a newer realtime update', async () => {
    let resolve!: (value: { success: boolean; data: KnowayState }) => void
    call.mockImplementationOnce(
      () =>
        new Promise((done) => {
          resolve = done
        }),
    )
    const store = useKnowayStore()
    store.activeRide = ride

    const pending = store.refreshState()
    store.applyUpdate({ activeRide: { ...ride, status: 'driving' } })
    resolve({ success: true, data: state })
    await pending
    expect(store.activeRide?.status).toBe('driving')
  })

  it('does not overwrite a confirmed cancellation with an earlier polling snapshot', async () => {
    let resolve!: (value: { success: boolean; data: KnowayState }) => void
    call.mockImplementationOnce(
      () =>
        new Promise((done) => {
          resolve = done
        }),
    )
    const store = useKnowayStore()
    store.activeRide = ride
    const poll = store.refreshState()
    call.mockResolvedValueOnce({
      success: true,
      data: {
        activeRide: { ...ride, status: 'cancelled', refundStatus: 'refunded' },
      },
    })

    expect(await store.performAction('cancel')).toBe(true)
    resolve({ success: true, data: state })
    await poll
    expect(store.activeRide?.status).toBe('cancelled')
    expect(store.activeRide?.refundStatus).toBe('refunded')
  })

  it('preserves an existing booking when a refresh cannot reach the server', async () => {
    call.mockResolvedValueOnce({ success: false, error: 'no_signal' })
    const store = useKnowayStore()
    store.activeRide = ride
    await store.refreshState()
    expect(store.activeRide).toEqual(ride)
  })
})
