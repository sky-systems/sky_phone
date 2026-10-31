import { describe, expect, it } from 'vitest'

import {
  adminActivityPreview,
  adminErrorText,
  adminMediaUrl,
  formatAdminTimestamp,
} from '@/utils/adminRecords'

describe('admin content presentation', () => {
  it('formats oxmysql epoch milliseconds, numeric strings and SQL datetime text as readable local dates', () => {
    const epoch = new Date('2026-10-31T12:34:56Z').getTime()
    const expected = new Intl.DateTimeFormat('de-DE', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    }).format(new Date(epoch))
    expect(formatAdminTimestamp(epoch, 'de-DE')).toBe(expected)
    expect(formatAdminTimestamp(String(epoch), 'de-DE')).toBe(expected)
    expect(formatAdminTimestamp('2026-10-31 12:34:56', 'de-DE')).toContain(
      '31.10.2026',
    )
    expect(formatAdminTimestamp('2026-10-31 12:34:56', 'de-DE')).toContain(
      '12:34:56',
    )
    expect(formatAdminTimestamp(epoch, 'en-US')).not.toContain(String(epoch))
    expect(formatAdminTimestamp('invalid', 'de-DE')).toBe('—')
    expect(formatAdminTimestamp(null, 'de-DE')).toBe('—')
  })
  it('uses localized request failure text for transport errors without locale keys', () => {
    const translate = (key: string) =>
      key === 'AdminPanel.errors.request_failed' ? 'Request failed' : key
    expect(adminErrorText('503 Service unavailable', translate)).toBe(
      'Request failed',
    )
  })
  it('accepts HTTP media and rejects script/data URLs or credential-bearing URLs', () => {
    expect(adminMediaUrl('https://media.example.test/post.jpg')).toBe(
      'https://media.example.test/post.jpg',
    )
    for (const value of [
      'javascript:alert(1)',
      'data:image/svg+xml,test',
      'file:///test',
      'https://user:secret@example.test/a',
      'invalid',
    ]) {
      expect(adminMediaUrl(value)).toBeUndefined()
    }
  })

  it('previews only text from the allowlisted request rather than rendering structured input', () => {
    expect(
      adminActivityPreview({
        request: { body: '<img onerror=evil()>', title: 'title' },
      }),
    ).toBe('<img onerror=evil()>')
    expect(
      adminActivityPreview({ request: { body: {}, caption: 'A caption' } }),
    ).toBe('A caption')
    expect(adminActivityPreview({ result: { body: 'different record' } })).toBe(
      '',
    )
  })
})
