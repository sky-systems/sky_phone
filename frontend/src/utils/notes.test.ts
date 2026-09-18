import { describe, expect, it } from 'vitest'

import { parseNotes } from './notes'
import {
  noteBodyToEditorHtml,
  noteBodyToPlainText,
  serializeRichNoteBody,
} from './noteRichText'

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

describe('notes rich text', () => {
  it('keeps legacy plain text notes editable without interpreting HTML', () => {
    expect(noteBodyToEditorHtml('First line\n<b>not markup</b>')).toBe(
      '<p>First line<br>&lt;b&gt;not markup&lt;/b&gt;</p>',
    )
  })

  it('stores formatted notes and derives a clean preview', () => {
    const body = serializeRichNoteBody(
      '<h2>Briefing</h2><p><strong>Meet</strong> outside.</p><ul><li>Radio</li><li>Vest</li></ul>',
    )

    expect(noteBodyToEditorHtml(body)).toContain('<strong>Meet</strong>')
    expect(noteBodyToPlainText(body)).toBe(
      'Briefing\nMeet outside.\n• Radio\n• Vest',
    )
  })

  it('keeps encoded markup as literal preview text', () => {
    const body = serializeRichNoteBody(
      '<p>&lt;script&gt;literal&lt;/script&gt;</p>',
    )

    expect(noteBodyToPlainText(body)).toBe('<script>literal</script>')
  })
})
