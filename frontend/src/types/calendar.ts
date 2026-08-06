export type CalendarEvent = {
  endsAt: number
  id: string
  note: string
  remindedAt: number | null
  reminderMinutes: number | null
  revision: number
  startsAt: number
  title: string
}

export type CalendarEventDraft = {
  endsAt: number
  note: string
  reminderMinutes: number | null
  startsAt: number
  title: string
}
