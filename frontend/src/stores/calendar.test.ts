import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useCalendarStore } from '@/stores/calendar'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
const mockNuiCall = vi.mocked(nuiCall)

describe('calendar store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads a bounded calendar range', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: [], success: true })
    const calendar = useCalendarStore()

    expect(await calendar.load(1_000_000, 2_000_000)).toBe(true)
    expect(mockNuiCall).toHaveBeenCalledWith('calendar:list', {
      endsAt: 2000,
      startsAt: 1000,
    })
  })

  it('sends server timestamps and revisions when updating', async () => {
    mockNuiCall.mockResolvedValueOnce({ success: true })
    const calendar = useCalendarStore()

    await calendar.update(
      {
        endsAt: 0,
        id: 'event-id',
        note: '',
        remindedAt: null,
        reminderMinutes: null,
        revision: 4,
        startsAt: 0,
        title: '',
      },
      {
        endsAt: 2_000_000,
        note: 'Bring documents',
        reminderMinutes: 60,
        startsAt: 1_000_000,
        title: 'Meeting',
      },
    )

    expect(mockNuiCall).toHaveBeenCalledWith('calendar:update', {
      endsAt: 2000,
      id: 'event-id',
      note: 'Bring documents',
      reminderMinutes: 60,
      revision: 4,
      startsAt: 1000,
      title: 'Meeting',
    })
  })
})
