import { defineStore } from 'pinia'

import {
  type Note,
  type NoteDraft,
  readNotes,
  writeNotes,
} from '@/utils/notes'

export const useNotesStore = defineStore('notes', {
  state: () => ({
    notes: readNotes(),
  }),
  actions: {
    createNote(draft: NoteDraft): Note {
      const now = Date.now()
      const note: Note = {
        ...draft,
        createdAt: now,
        id: `note-${now}-${Math.random().toString(36).slice(2, 9)}`,
        pinned: false,
        updatedAt: now,
      }
      this.notes.unshift(note)
      this.persist()
      return note
    },
    deleteNote(id: string): void {
      this.notes = this.notes.filter((note) => note.id !== id)
      this.persist()
    },
    persist(): void {
      writeNotes(this.notes)
    },
    togglePinned(id: string): void {
      const note = this.notes.find((candidate) => candidate.id === id)
      if (!note) return
      note.pinned = !note.pinned
      this.persist()
    },
    updateNote(id: string, draft: NoteDraft): void {
      const note = this.notes.find((candidate) => candidate.id === id)
      if (!note) return
      Object.assign(note, draft, { updatedAt: Date.now() })
      this.persist()
    },
  },
})
