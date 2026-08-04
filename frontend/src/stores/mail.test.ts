import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useMailStore } from '@/stores/mail'
import type { MailCounts, MailListItem } from '@/types/mail'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({
  nuiCall: vi.fn(),
}))

const mockNuiCall = vi.mocked(nuiCall)
const counts: MailCounts = {
  drafts: 1,
  inbox: 2,
  sent: 3,
  trash: 4,
  unread: 1,
}

function listItem(id: number): MailListItem {
  return {
    created_at: '2026-08-04 10:00:00',
    folder: 'inbox',
    id,
    is_read: false,
    message_id: `00000000-0000-0000-0000-${String(id).padStart(12, '0')}`,
    preview: 'Body',
    recipients: ['alex@ifruit.com'],
    sender: 'morgan@ifruit.com',
    subject: 'Plans',
  }
}

describe('mail store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('tracks search state and appends paginated mailbox results', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        data: { hasMore: true, items: [listItem(1)] },
        success: true,
      })
      .mockResolvedValueOnce({
        data: { hasMore: false, items: [listItem(2)] },
        success: true,
      })

    const mail = useMailStore()
    await mail.loadFolder('inbox', 'plans')
    await mail.loadFolder('inbox', 'plans', true)

    expect(mail.search).toBe('plans')
    expect(mail.items.map((item) => item.id)).toEqual([1, 2])
    expect(mail.hasMore).toBe(false)
    expect(mockNuiCall).toHaveBeenNthCalledWith(2, 'mail:list', {
      folder: 'inbox',
      offset: 1,
      search: 'plans',
    })
  })

  it('saves draft content and refreshes mailbox counts', async () => {
    mockNuiCall
      .mockResolvedValueOnce({ data: { id: 'draft-id' }, success: true })
      .mockResolvedValueOnce({ data: counts, success: true })

    const mail = useMailStore()
    const id = await mail.saveDraft({
      body: 'Body',
      recipients: ['alex@ifruit.com'],
      subject: 'Subject',
    })

    expect(id).toBe('draft-id')
    expect(mail.counts).toEqual(counts)
    expect(mockNuiCall).toHaveBeenNthCalledWith(1, 'mail:save-draft', {
      body: 'Body',
      id: undefined,
      recipients: ['alex@ifruit.com'],
      subject: 'Subject',
    })
  })

  it('logs out the active session and resets mailbox state', async () => {
    mockNuiCall
      .mockResolvedValueOnce({
        data: { counts, email: 'alex@ifruit.com' },
        success: true,
      })
      .mockResolvedValueOnce({
        data: { hasMore: true, items: [listItem(1)] },
        success: true,
      })
      .mockResolvedValueOnce({ success: true })

    const mail = useMailStore()
    await mail.login('alex', 'secret')
    await mail.loadFolder('sent', 'plans')
    await mail.logout()

    expect(mockNuiCall).toHaveBeenLastCalledWith('mail:logout')
    expect(mail.accountEmail).toBe('')
    expect(mail.folder).toBe('inbox')
    expect(mail.search).toBe('')
    expect(mail.items).toEqual([])
    expect(mail.hasMore).toBe(false)
  })
})
