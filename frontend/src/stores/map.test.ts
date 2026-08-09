import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useMapStore } from '@/stores/map'
import type { MapMarker } from '@/types/map'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const mockNuiCall = vi.mocked(nuiCall)
const marker: MapMarker = {
  color: 'blue',
  coords: { x: -75.2, y: -818.9, z: 0 },
  id: 'marker-1',
  label: 'Meeting point',
}

describe('map store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads persistent markers', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: [marker], success: true })
    const map = useMapStore()

    expect(await map.load()).toBe(true)
    expect(map.markers).toEqual([marker])
    expect(mockNuiCall).toHaveBeenCalledWith('map:markers')
  })

  it('adds a marker returned by the server', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: marker, success: true })
    const map = useMapStore()
    const input = {
      color: marker.color,
      coords: marker.coords,
      label: marker.label,
    }

    expect((await map.create(input)).success).toBe(true)
    expect(map.markers).toEqual([marker])
    expect(mockNuiCall).toHaveBeenCalledWith('map:create-marker', input)
  })

  it('only removes a marker after server confirmation', async () => {
    mockNuiCall
      .mockResolvedValueOnce({ error: 'request_failed', success: false })
      .mockResolvedValueOnce({ success: true })
    const map = useMapStore()
    map.markers = [marker]

    await map.remove(marker.id)
    expect(map.markers).toEqual([marker])

    await map.remove(marker.id)
    expect(map.markers).toEqual([])
  })
})
