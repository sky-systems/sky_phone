import { defineStore } from 'pinia'

import type { CalendarEvent, CalendarEventDraft } from '@/types/calendar'
import { nuiCall } from '@/utils/nui'

function toServerDraft(draft: CalendarEventDraft): Record<string, unknown> {
  return {
    endsAt: Math.floor(draft.endsAt / 1000),
    note: draft.note,
    reminderMinutes: draft.reminderMinutes,
    startsAt: Math.floor(draft.startsAt / 1000),
    title: draft.title,
  }
}

export const useCalendarStore = defineStore('calendar', {
  state: () => ({
    error: '' as string,
    events: [] as CalendarEvent[],
    loading: false,
  }),
  actions: {
    async create(draft: CalendarEventDraft): Promise<boolean> {
      const response = await nuiCall<{ id: string }>(
        'calendar:create',
        toServerDraft(draft),
      )
      this.error = response.success ? '' : (response.error ?? 'default')
      return response.success
    },
    async deleteEvent(id: string): Promise<boolean> {
      const response = await nuiCall('calendar:delete', { id })
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success) {
        this.events = this.events.filter((event) => event.id !== id)
      }
      return response.success
    },
    async load(startsAt: number, endsAt: number): Promise<boolean> {
      this.loading = true
      const response = await nuiCall<CalendarEvent[]>('calendar:list', {
        endsAt: Math.floor(endsAt / 1000),
        startsAt: Math.floor(startsAt / 1000),
      })
      this.loading = false
      this.error = response.success ? '' : (response.error ?? 'default')
      if (response.success) this.events = response.data ?? []
      return response.success
    },
    async update(
      event: CalendarEvent,
      draft: CalendarEventDraft,
    ): Promise<boolean> {
      const response = await nuiCall('calendar:update', {
        ...toServerDraft(draft),
        id: event.id,
        revision: event.revision,
      })
      this.error = response.success ? '' : (response.error ?? 'default')
      return response.success
    },
  },
})
