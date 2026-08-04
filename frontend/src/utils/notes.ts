export type Note = {
  body: string
  createdAt: number
  id: string
  pinned: boolean
  revision: number
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
    (note.revision === undefined ||
      (typeof note.revision === 'number' && Number.isFinite(note.revision))) &&
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
    return parsed.filter(isNote).map((note) => ({
      ...note,
      revision: note.revision ?? 1,
    }))
  } catch {
    return []
  }
}
