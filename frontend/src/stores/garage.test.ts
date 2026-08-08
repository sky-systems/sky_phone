import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useGarageStore } from '@/stores/garage'
import type { GarageOverview } from '@/types/garage'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const mockNuiCall = vi.mocked(nuiCall)
const overview: GarageOverview = {
  system: 'esx',
  valet: {
    account: 'bank',
    enabled: true,
    price: 750,
    vehicleTypes: {
      bike: true,
      boat: false,
      car: true,
      helicopter: false,
      plane: false,
    },
  },
  vehicles: [
    {
      body: 91,
      engine: 84,
      fuel: 67,
      id: 'SKY 204',
      kind: 'car',
      location: 'Legion Square',
      model: 'sultan',
      name: 'Karin Sultan',
      nickname: '',
      plate: 'SKY 204',
      status: 'garaged',
      vin: '',
    },
  ],
}

describe('garage store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads the owned vehicles from the server', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: overview, success: true })
    const garage = useGarageStore()

    expect(await garage.load()).toBe(true)
    expect(garage.overview).toEqual(overview)
    expect(mockNuiCall).toHaveBeenCalledWith('garage:vehicles')
  })

  it('keeps the previous garage data when refreshing fails', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'garage_unavailable',
      success: false,
    })
    const garage = useGarageStore()
    garage.overview = overview

    expect(await garage.load()).toBe(false)
    expect(garage.overview).toEqual(overview)
    expect(garage.error).toBe('garage_unavailable')
  })

  it('creates a server-backed valet order', async () => {
    const valet = {
      canCancel: true,
      cost: 750,
      distance: 1000,
      etaSeconds: 50,
      orderId: 'valet-1',
      plate: 'SKY 204',
      status: 'en_route' as const,
      vehicleName: 'Karin Sultan',
    }
    mockNuiCall.mockResolvedValueOnce({ data: valet, success: true })
    const garage = useGarageStore()

    expect(await garage.requestValet('SKY 204')).toBe(true)
    expect(garage.valet).toEqual(valet)
    expect(mockNuiCall).toHaveBeenCalledWith('garage:valet-request', {
      plate: 'SKY 204',
    })
  })

  it('cancels an active valet order and refreshes the garage', async () => {
    mockNuiCall
      .mockResolvedValueOnce({ data: null, success: true })
      .mockResolvedValueOnce({ data: overview, success: true })
    const garage = useGarageStore()

    expect(await garage.cancelValet()).toBe(true)
    expect(garage.valet).toBeNull()
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'garage:valet-cancel')
  })
})
