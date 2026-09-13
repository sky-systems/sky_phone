import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useCityWarnStore } from '@/stores/citywarn'
import type { CityWarnAlert, CityWarnBootstrap } from '@/types/citywarn'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
vi.mock('@/stores/phone', () => ({
  usePhoneStore: () => ({ device: null, saveDeviceNamespace: vi.fn() }),
}))

const mockNuiCall = vi.mocked(nuiCall)

function alert(overrides: Partial<CityWarnAlert> = {}): CityWarnAlert {
  return {
    area: {
      centerX: 100,
      centerY: 200,
      label: 'Mission Row',
      radius: 500,
      type: 'radius',
    },
    authorName: 'Alex Morgan',
    body: 'Avoid the area.',
    category: 'police',
    createdAt: Date.now(),
    expiresAt: Date.now() + 60_000,
    id: 'alert-1',
    instructions: 'Use another route.',
    revision: 1,
    severity: 'danger',
    sourceLabel: 'LSPD',
    startsAt: Date.now(),
    status: 'active',
    title: 'Police operation',
    updatedAt: Date.now(),
    updates: [],
    ...overrides,
  }
}

const bootstrap: CityWarnBootstrap = {
  active: [alert()],
  archive: [],
  context: {
    allowedCategories: ['police'],
    canCityWide: true,
    canPublish: true,
    gradeLabel: 'Sergeant',
    jobLabel: 'LSPD',
    maximumSeverity: 'extreme',
    onDuty: true,
    requiresDuty: true,
  },
  onlinePlayers: 42,
}

describe('CityWarn store', () => {
  it('applies category colors on bootstrap and live configuration updates without creating an alert', async () => {
    setActivePinia(createPinia())
    const store = useCityWarnStore()
    mockNuiCall.mockResolvedValueOnce({
      success: true,
      data: { ...bootstrap, categoryColors: { police: '#123456' } },
    })
    await store.load()
    expect(store.categoryColors.police).toBe('#123456')
    store.applyEvent({ categoryColors: { police: '#abcdef', fire: '#ff0000' } })
    expect(store.categoryColors.police).toBe('#abcdef')
    expect(store.categoryColors.fire).toBe('#ff0000')
    expect(store.active).toHaveLength(1)
  })
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads server-authoritative alerts and publishing context', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: bootstrap, success: true })
    const citywarn = useCityWarnStore()

    expect(await citywarn.load()).toBe(true)
    expect(citywarn.active).toEqual(bootstrap.active)
    expect(citywarn.context?.canPublish).toBe(true)
    expect(citywarn.onlinePlayers).toBe(42)
    expect(mockNuiCall).toHaveBeenCalledWith('citywarn:bootstrap')
  })

  it('filters warnings by category, severity and location preference', () => {
    const citywarn = useCityWarnStore()
    const policeRadius = alert()
    const cityWide = alert({
      area: {
        centerX: null,
        centerY: null,
        label: 'Los Santos',
        radius: null,
        type: 'city',
      },
      category: 'public_safety',
      severity: 'extreme',
    })

    citywarn.preferences.categories.police = false
    expect(citywarn.accepts(policeRadius)).toBe(false)
    citywarn.preferences.categories.police = true
    citywarn.preferences.minimumSeverity = 'extreme'
    expect(citywarn.accepts(policeRadius)).toBe(false)
    citywarn.preferences.locationAlerts = false
    expect(citywarn.accepts(cityWide)).toBe(true)
  })
})
