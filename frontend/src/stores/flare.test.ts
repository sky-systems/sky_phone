import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useFlareStore } from '@/stores/flare'
import type {
  FlareBootstrap,
  FlareLike,
  FlareMatch,
  FlareProfile,
  FlareProfileDraft,
} from '@/types/flare'
import { nuiCall } from '@/utils/nui'

vi.mock('@/utils/nui', () => ({ nuiCall: vi.fn() }))

const mockNuiCall = vi.mocked(nuiCall)
const maya: FlareProfile = {
  age: 26,
  avatar: 0,
  bio: 'Ocean air and rooftop sunsets.',
  gender: 'woman',
  id: 11,
  interests: ['Beach days', 'Art'],
  lookingFor: 'longTerm',
  name: 'Maya',
  photoUrls: [],
}
const mayaLike: FlareLike = { ...maya, superLiked: true }
const bootstrap: FlareBootstrap = {
  likes: [mayaLike],
  matches: [],
  profile: {
    age: 27,
    avatar: 5,
    bio: 'Late-night drives and good coffee.',
    discoverable: true,
    gender: 'nonbinary',
    id: 1,
    interestedIn: 'everyone',
    interests: ['Music', 'Coffee'],
    lookingFor: 'dates',
    maxAge: 39,
    minAge: 21,
    name: 'Alex',
    photoMediaIds: [],
    photoUrls: [],
  },
  suggestions: [maya],
}

describe('flare store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    mockNuiCall.mockReset()
  })

  it('loads suggestions, incoming likes and own discovery state', async () => {
    mockNuiCall.mockResolvedValueOnce({ data: bootstrap, success: true })
    const flare = useFlareStore()

    expect(await flare.bootstrap()).toBe(true)
    expect(flare.profile?.discoverable).toBe(true)
    expect(flare.likes).toEqual([mayaLike])
    expect(flare.suggestions).toEqual([maya])
  })

  it('keeps matches available when Discovery is turned off', async () => {
    const hidden = {
      ...bootstrap,
      profile: { ...bootstrap.profile!, discoverable: false },
      suggestions: [],
    }
    mockNuiCall.mockResolvedValueOnce({ data: hidden, success: true })
    const flare = useFlareStore()

    expect(await flare.setDiscovery(false)).toBe(true)
    expect(flare.profile?.discoverable).toBe(false)
    expect(flare.suggestions).toEqual([])
    expect(mockNuiCall).toHaveBeenCalledWith('flare:set-discovery', {
      enabled: false,
    })
  })

  it('sends only Gallery media ids when profile photos are saved', async () => {
    const updated = {
      ...bootstrap,
      profile: {
        ...bootstrap.profile!,
        photoMediaIds: [42],
        photoUrls: ['https://cdn.example.test/profile.jpg'],
      },
    }
    const draft: FlareProfileDraft = {
      age: bootstrap.profile!.age,
      avatar: bootstrap.profile!.avatar,
      bio: bootstrap.profile!.bio,
      gender: bootstrap.profile!.gender,
      interestedIn: bootstrap.profile!.interestedIn,
      interests: [...bootstrap.profile!.interests],
      lookingFor: bootstrap.profile!.lookingFor,
      maxAge: bootstrap.profile!.maxAge,
      minAge: bootstrap.profile!.minAge,
      name: bootstrap.profile!.name,
      photoMediaIds: [42],
    }
    mockNuiCall.mockResolvedValueOnce({ data: updated, success: true })
    const flare = useFlareStore()

    expect(await flare.saveProfile(draft)).toBe(true)
    expect(mockNuiCall).toHaveBeenCalledWith('flare:save-profile', draft)
    expect(flare.profile?.photoUrls).toEqual([
      'https://cdn.example.test/profile.jpg',
    ])
  })

  it('uses a real Super Like and removes the target from both decks', async () => {
    const match: FlareMatch = {
      id: 'match-1',
      lastMessage: '',
      lastMessageAt: null,
      profile: maya,
      unread: 0,
    }
    mockNuiCall.mockResolvedValueOnce({ data: { match }, success: true })
    const flare = useFlareStore()
    flare.suggestions = [maya]
    flare.likes = [mayaLike]

    expect(await flare.swipe(maya.id, 'superlike')).toEqual(match)
    expect(flare.suggestions).toEqual([])
    expect(flare.likes).toEqual([])
    expect(flare.matches).toEqual([match])
    expect(mockNuiCall).toHaveBeenCalledWith('flare:swipe', {
      choice: 'superlike',
      targetId: maya.id,
    })
  })

  it('preserves the previous discovery state when the server rejects a toggle', async () => {
    mockNuiCall.mockResolvedValueOnce({
      error: 'invalid_discovery',
      success: false,
    })
    const flare = useFlareStore()
    flare.profile = bootstrap.profile

    expect(await flare.setDiscovery(false)).toBe(false)
    expect(flare.profile?.discoverable).toBe(true)
    expect(flare.error).toBe('invalid_discovery')
  })
})
