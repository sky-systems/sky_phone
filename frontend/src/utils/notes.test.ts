import { describe, expect, it } from 'vitest'

import { parseNotes } from './notes'

describe('notes persistence', () => {
  it('returns valid notes and ignores malformed entries', () => {
    const valid = {
      body: 'Meet at Mission Row.',
      createdAt: 10,
      id: 'note-1',
      pinned: true,
      title: 'Shift briefing',
      updatedAt: 20,
    }

    expect(parseNotes(JSON.stringify([valid, { id: 'broken' }]))).toEqual([
      { ...valid, revision: 1 },
    ])
  })

  it('recovers from missing or invalid storage', () => {
    expect(parseNotes(null)).toEqual([])
    expect(parseNotes('{invalid')).toEqual([])
    expect(parseNotes('{}')).toEqual([])
  })
})
