import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAdminStore } from '@/stores/admin'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))
const request = vi.mocked(nuiCall)

beforeEach(() => {
  setActivePinia(createPinia())
  request.mockReset()
})

describe('admin inspection contracts', () => {
  it('keeps the newest player selection when an earlier detail request finishes late', async () => {
    const admin = useAdminStore()
    let finishFirst!: (value: {
      success: boolean
      data: { source: number }
    }) => void
    request.mockReturnValueOnce(
      new Promise((resolve) => {
        finishFirst = resolve
      }),
    )
    request.mockResolvedValueOnce({ success: true, data: { source: 2 } })
    const first = admin.openPlayer(1)
    expect(await admin.openPlayer(2)).toBe(true)
    finishFirst({ success: true, data: { source: 1 } })
    await first
    expect(admin.selectedPlayer?.source).toBe(2)
    expect(admin.detailLoading).toBe(false)
  })

  it('cannot restore protected player data after the selection has been closed', async () => {
    const admin = useAdminStore()
    let finish!: (value: { success: boolean; data: { source: number } }) => void
    request.mockReturnValueOnce(
      new Promise((resolve) => {
        finish = resolve
      }),
    )
    const pending = admin.openPlayer(1)
    admin.closePlayer()
    finish({ success: true, data: { source: 1 } })
    await pending
    expect(admin.selectedPlayer).toBeNull()
    expect(admin.detailLoading).toBe(false)
  })

  it('sends the selected target on content reads and removals and leaves global scope optional', async () => {
    const admin = useAdminStore()
    request.mockResolvedValue({ success: true })
    await admin.loadSocialPosts('feather', 'caption', 2, 17)
    expect(request).toHaveBeenLastCalledWith('admin:social-posts', {
      platform: 'feather',
      query: 'caption',
      page: 2,
      targetSource: 17,
    })
    await admin.deleteSocialPost('feather', 'post-1', 17)
    expect(request).toHaveBeenLastCalledWith('admin:delete-social-post', {
      platform: 'feather',
      id: 'post-1',
      targetSource: 17,
    })
    await admin.loadPhoneActivity({
      source: 17,
      beforeId: '9007199254740993',
      category: 'Feather',
    })
    expect(request).toHaveBeenLastCalledWith('admin:phone-activity', {
      source: 17,
      beforeId: '9007199254740993',
      category: 'Feather',
    })
  })

  it('refreshes statistics without reloading the player directory or protected data', async () => {
    const admin = useAdminStore()
    admin.error = 'existing_error'
    admin.revealedCredentials.device = {
      email: 'test@example.test',
      password: 'test',
    }
    const stats = { ...admin.stats, devices: 9 }
    request.mockResolvedValue({ success: true, data: stats })
    expect(await admin.loadStatistics()).toBe(true)
    expect(request).toHaveBeenCalledOnce()
    expect(request).toHaveBeenCalledWith('admin:statistics')
    expect(admin.stats.devices).toBe(9)
    expect(admin.error).toBe('existing_error')
    expect(admin.revealedCredentials.device).toBeDefined()
    expect(admin.statisticsLoading).toBe(false)
  })
})
