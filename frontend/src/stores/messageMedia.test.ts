import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it } from 'vitest'

import { useMessageMediaStore } from '@/stores/messageMedia'
import type { PhoneMedia } from '@/types/media'

const photo: PhoneMedia = {
  createdAt: 1_786_035_600,
  id: 17,
  mediaType: 'photo',
  url: 'https://media.example/photo.jpg',
}

describe('message media handoff', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('returns captured media to the requesting DarkChat conversation', () => {
    const store = useMessageMediaStore()
    store.begin('darkchat:conversation-id', 'photo', '/apps/darkchat')

    expect(store.complete(photo)).toBe('/apps/darkchat')
    expect(store.consume('darkchat:another-conversation')).toBeNull()
    expect(store.consume('darkchat:conversation-id')).toEqual(photo)
  })

  it('keeps the request active when the selected media type does not match', () => {
    const store = useMessageMediaStore()
    store.begin('4205550196', 'video')

    expect(store.complete(photo)).toBeNull()
    expect(store.request).toMatchObject({ mediaType: 'video', target: '4205550196' })
    expect(store.cancel()).toBe('/apps/messages')
  })
})
