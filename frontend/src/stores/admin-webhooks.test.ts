import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAdminStore } from '@/stores/admin'
import type { AdminWebhooks } from '@/types/admin'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
const mockNuiCall = vi.mocked(nuiCall)
const options = {
  Enabled: true,
  Username: 'Sky Phone',
  AvatarUrl: '',
  QueueLimit: 1000,
  MaxAttempts: 5,
}
const data: AdminWebhooks = {
  revision: 4,
  settings: options,
  defaults: options,
  endpoints: [
    {
      path: 'Calls',
      category: 'Calls',
      configured: true,
      mode: 'custom',
      effectiveMode: 'custom',
    },
  ],
}

describe('Phonepanel webhook drafts', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads masked settings and sends only edited fields with their revision', async () => {
    const admin = useAdminStore()
    mockNuiCall.mockResolvedValueOnce({ success: true, data })
    expect(await admin.loadWebhooks()).toBe(true)
    admin.webhookDrafts.AvatarUrl = {
      path: 'AvatarUrl',
      value: 'https://example.invalid/avatar.png',
    }
    mockNuiCall.mockResolvedValueOnce({
      success: true,
      data: { ...data, revision: 5 },
    })
    expect((await admin.saveWebhooks()).success).toBe(true)
    expect(mockNuiCall).toHaveBeenLastCalledWith('admin:save-webhooks', {
      revision: 4,
      changes: [
        { path: 'AvatarUrl', value: 'https://example.invalid/avatar.png' },
      ],
    })
    expect(admin.webhookDrafts).toEqual({})
    expect(admin.actionKey).toBe('')
  })

  it('retains edits and the original revision on conflict until explicit reload', async () => {
    const admin = useAdminStore()
    admin.webhooks = data
    admin.webhookDrafts.Calls = {
      path: 'Calls',
      mode: 'custom',
      url: 'replacement-test-value',
    }
    mockNuiCall.mockResolvedValueOnce({
      success: false,
      error: 'revision_conflict',
    })
    expect((await admin.saveWebhooks()).error).toBe('revision_conflict')
    expect(admin.webhooks.revision).toBe(4)
    expect(admin.webhookDrafts.Calls.url).toBe('replacement-test-value')
    mockNuiCall.mockResolvedValueOnce({
      success: true,
      data: { ...data, revision: 5 },
    })
    await admin.loadWebhooks()
    expect(admin.webhookDrafts).toEqual({})
    expect(admin.webhooks.revision).toBe(5)
  })

  it('keeps empty replacement input explicit without inventing masked credentials', async () => {
    const admin = useAdminStore()
    admin.webhooks = data
    admin.webhookDrafts.Calls = { path: 'Calls', mode: 'custom' }
    mockNuiCall.mockResolvedValueOnce({
      success: false,
      error: 'request_failed',
    })
    await admin.saveWebhooks()
    expect(mockNuiCall).toHaveBeenLastCalledWith('admin:save-webhooks', {
      revision: 4,
      changes: [{ path: 'Calls', mode: 'custom' }],
    })
    expect(admin.webhookDrafts.Calls).toBeDefined()
  })
})
