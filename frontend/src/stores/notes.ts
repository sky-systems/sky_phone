import { defineStore } from 'pinia'

import { nuiCall } from '@/utils/nui'
import { type Note, type NoteDraft } from '@/utils/notes'
import { cloneJsonData } from '@/utils/clone'

export const useNotesStore = defineStore('notes', {
  state: () => ({
    notes: [] as Note[],
  }),
  actions: {
    createNote(draft: NoteDraft): Note {
      const now = Date.now()
      const note: Note = {
        ...draft,
        createdAt: now,
        id: `note-${now}-${Math.random().toString(36).slice(2, 9)}`,
        pinned: false,
        revision: 1,
        updatedAt: now,
      }
      this.notes.unshift(note)
      void this.createRemote(note)
      return note
    },
    deleteNote(id: string): void {
      this.notes = this.notes.filter((note) => note.id !== id)
      void nuiCall<Note[]>('notes:delete', { id }).then((response) => {
        if (response.success && response.data) this.hydrate(response.data)
      })
    },
    hydrate(notes: Note[]): void {
      this.notes = cloneJsonData(notes)
    },
    async createRemote(note: Note): Promise<void> {
      const response = await nuiCall<Note[]>('notes:create', note)
      if (response.data) this.hydrate(response.data)
    },
    togglePinned(id: string): void {
      const note = this.notes.find((candidate) => candidate.id === id)
      if (!note) return
      note.pinned = !note.pinned
      void this.updateRemote(note)
    },
    updateNote(id: string, draft: NoteDraft): void {
      const note = this.notes.find((candidate) => candidate.id === id)
      if (!note) return
      Object.assign(note, draft, { updatedAt: Date.now() })
      void this.updateRemote(note)
    },
    async updateRemote(note: Note): Promise<void> {
      const response = await nuiCall<Note[]>('notes:update', note)
      if (response.data) this.hydrate(response.data)
    },
  },
})
