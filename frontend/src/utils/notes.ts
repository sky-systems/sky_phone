export const NOTES_STORAGE_KEY = 'sky_phone.notes.v1'

export type Note = {
  body: string
  createdAt: number
  id: string
  pinned: boolean
  title: string
  updatedAt: number
}

export type NoteDraft = Pick<Note, 'body' | 'title'>

function isNote(value: unknown): value is Note {
  if (!value || typeof value !== 'object') return false
  const note = value as Partial<Note>
  return (
    typeof note.body === 'string' &&
    typeof note.createdAt === 'number' &&
    Number.isFinite(note.createdAt) &&
    typeof note.id === 'string' &&
    Boolean(note.id) &&
    typeof note.pinned === 'boolean' &&
    typeof note.title === 'string' &&
    typeof note.updatedAt === 'number' &&
    Number.isFinite(note.updatedAt)
  )
}

export function parseNotes(raw: string | null): Note[] {
  if (!raw) return []

  try {
    const parsed = JSON.parse(raw) as unknown
    if (!Array.isArray(parsed)) return []
    return parsed.filter(isNote)
  } catch {
    return []
  }
}

export function readNotes(): Note[] {
  return parseNotes(window.localStorage.getItem(NOTES_STORAGE_KEY))
}

export function writeNotes(notes: Note[]): void {
  window.localStorage.setItem(NOTES_STORAGE_KEY, JSON.stringify(notes))
}
