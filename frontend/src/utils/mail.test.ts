import { describe, expect, it } from 'vitest'

import type { MailMessage } from '@/types/mail'
import {
  buildForwardDraft,
  buildReplyDraft,
  filterMailAddressInput,
  filterMailRecipientInput,
  mailPlainText,
  normalizeMailAddress,
  parseMailRecipients,
} from '@/utils/mail'

const message: MailMessage = {
  body: 'Meet at Legion Square.',
  created_at: '2026-08-04 10:00:00',
  folder: 'inbox',
  id: 1,
  is_read: true,
  message_id: '00000000-0000-0000-0000-000000000001',
  preview: 'Meet at Legion Square.',
  recipients: ['alex@ifruit.com', 'jamie@ifruit.com'],
  sender: 'morgan@ifruit.com',
  subject: 'Plans',
}

describe('mail addresses', () => {
  it('filters account fields to the supported email character set', () => {
    expect(filterMailAddressInput('Al+ex! ä@ifruit.com<script>')).toBe(
      'Alex@ifruit.comscript',
    )
    expect(filterMailAddressInput('sky.user_name-2@ifruit.com')).toBe(
      'sky.user_name-2@ifruit.com',
    )
  })

  it('keeps separators but filters recipient-list special characters', () => {
    expect(
      filterMailRecipientInput(
        'alex@ifruit.com, jamie+tag@ifruit.com; müller@ifruit.com',
      ),
    ).toBe('alex@ifruit.com, jamietag@ifruit.com; mller@ifruit.com')
  })

  it('normalizes local parts and the iFruit domain', () => {
    expect(normalizeMailAddress(' Sky.User ')).toBe('sky.user@ifruit.com')
    expect(normalizeMailAddress('sky.user@ifruit.com')).toBe(
      'sky.user@ifruit.com',
    )
  })

  it('rejects invalid addresses and deduplicates recipients', () => {
    expect(normalizeMailAddress('ab')).toBeNull()
    expect(normalizeMailAddress('.user')).toBeNull()
    expect(normalizeMailAddress('user@example.com')).toBeNull()
    expect(parseMailRecipients('Alex, alex@ifruit.com; Jamie')).toEqual([
      'alex@ifruit.com',
      'jamie@ifruit.com',
    ])
  })
})

describe('mail compose helpers', () => {
  it('builds reply and reply-all drafts without the current account', () => {
    expect(buildReplyDraft(message, 'alex@ifruit.com').recipients).toEqual([
      'morgan@ifruit.com',
    ])
    expect(
      buildReplyDraft(message, 'alex@ifruit.com', true).recipients,
    ).toEqual(['morgan@ifruit.com', 'jamie@ifruit.com'])
    expect(buildReplyDraft(message, 'alex@ifruit.com').body).toContain(
      '> Meet at Legion Square.',
    )
  })

  it('builds forward content and avoids duplicate subject prefixes', () => {
    const forwarded = buildForwardDraft(message)
    expect(forwarded.recipients).toEqual([])
    expect(forwarded.subject).toBe('Fwd: Plans')
    expect(forwarded.body).toContain('**From:** morgan@ifruit.com')
  })

  it('turns formatted markdown into a compact mailbox preview', () => {
    expect(
      mailPlainText('## Update\n\n**Ready** [details](https://ifruit.com).'),
    ).toBe('Update Ready details.')
    expect(mailPlainText('<script>alert(1)</script> Hello')).toBe(
      'alert(1) Hello',
    )
  })
})
