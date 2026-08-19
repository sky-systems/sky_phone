import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const viewSource = readFileSync(
  new URL('./SkyPicApp.vue', import.meta.url),
  'utf8',
)
const storeSource = readFileSync(
  new URL('../../stores/skypic.ts', import.meta.url),
  'utf8',
)
const typeSource = readFileSync(
  new URL('../../types/skypic.ts', import.meta.url),
  'utf8',
)

describe('SkyPic frontend contract', () => {
  it('uses Sky UI and exposes the camera-first four-tab shell', () => {
    expect(viewSource).toContain("from '@/ui'")
    expect(viewSource).not.toContain("from 'konsta/vue'")
    expect(viewSource).toContain("const activeTab = ref<Tab>('camera')")
    expect(viewSource).toContain(
      "type Tab = 'camera' | 'chats' | 'friends' | 'stories'",
    )
    expect(viewSource).toContain("activeTab === 'camera'")
    expect(viewSource).toContain("activeTab === 'chats'")
    expect(viewSource).toContain("activeTab === 'stories'")
    expect(viewSource).toContain("activeTab === 'friends'")
    expect(viewSource.match(/<SkyTabButton/g)).toHaveLength(4)
  })

  it('uses the shared Camera and Gallery media handoff with a bounded draft', () => {
    expect(viewSource).toContain('mediaPicker.begin(')
    expect(viewSource).toContain("'skypic-draft'")
    expect(viewSource).toContain('`/apps/skypic?compose=${purpose}`')
    expect(viewSource).toContain(
      "mediaPicker.consumeMany<SkyPicMediaDraftContext>('skypic-draft')",
    )
    expect(viewSource).toContain('path: `/apps/${source}`')
    expect(viewSource).toContain('query: { mediaAttachment: mediaType }')
    expect(viewSource).toContain("type MediaSource = 'camera' | 'photos'")
  })

  it('keeps profile editing parse-safe and composer inputs canonical', () => {
    expect(viewSource).toContain('function toggleProfileEditor(): void')
    expect(viewSource.match(/@click="toggleProfileEditor"/g)).toHaveLength(2)
    expect(viewSource).toContain('const MAX_CAPTION_LENGTH = 160')
    expect(viewSource).toContain(':maxlength="MAX_CAPTION_LENGTH"')
    expect(viewSource).toContain('.slice(0, MAX_CAPTION_LENGTH)')
    expect(viewSource).not.toContain('maxlength="240"')
    expect(viewSource).toContain('const MAX_TEXT_OVERLAY_LENGTH = 160')
    expect(viewSource).toContain(':maxlength="MAX_TEXT_OVERLAY_LENGTH"')
    expect(storeSource).toContain('MAX_TEXT_OVERLAY_CHARACTERS = 160')
    expect(viewSource).toContain(
      'avatarSeed: Math.floor(Math.random() * 360) + 1',
    )
  })

  it('keeps direct and story secrets behind explicit release callbacks', () => {
    const snapBlock = typeSource.match(
      /export type SkyPicSnap = \{([\s\S]*?)\n\}/,
    )?.[1]
    const openedSnapBlock = typeSource.match(
      /export type SkyPicOpenedSnap = \{([\s\S]*?)\n\}/,
    )?.[1]
    const storyBlock = typeSource.match(
      /export type SkyPicStory = \{([\s\S]*?)\n\}/,
    )?.[1]
    const viewedStoryBlock = typeSource.match(
      /export type SkyPicViewedStory = \{([\s\S]*?)\n\}/,
    )?.[1]

    expect(snapBlock).toBeTruthy()
    expect(snapBlock).not.toMatch(/\burl\b|caption|textOverlay|overlayColor/)
    expect(openedSnapBlock).toMatch(/\burl: string\b/)
    expect(openedSnapBlock).toMatch(/caption: string/)
    expect(openedSnapBlock).toMatch(/textOverlay: string/)
    expect(openedSnapBlock).toMatch(/overlayColor: string/)
    expect(storyBlock).not.toMatch(/\burl\b|caption|textOverlay|overlayColor/)
    expect(viewedStoryBlock).toMatch(/\burl: string\b/)
    expect(storeSource).toContain("'skypic:open-snap'")
    expect(storeSource).toContain("'skypic:replay-snap'")
    expect(storeSource).toContain("'skypic:view-story'")
    expect(viewSource).toContain('store.clearOpenedSnap()')
    expect(viewSource).toContain('store.clearViewedStory()')
  })

  it('implements all agreed callback names exactly', () => {
    const callbacks = [
      'skypic:bootstrap',
      'skypic:create-profile',
      'skypic:update-profile',
      'skypic:search',
      'skypic:add-friend',
      'skypic:respond-friend',
      'skypic:remove-friend',
      'skypic:block',
      'skypic:send-snap',
      'skypic:open-snap',
      'skypic:replay-snap',
      'skypic:publish-story',
      'skypic:stories',
      'skypic:view-story',
      'skypic:story-viewers',
      'skypic:remove-story',
      'skypic:thread',
      'skypic:send-message',
      'skypic:mark-thread',
      'skypic:save-message',
      'skypic:delete-message',
    ]
    callbacks.forEach((callback) =>
      expect(storeSource).toContain("'" + callback + "'"),
    )
  })

  it('reacts to query-only notification and media-return deep links', () => {
    expect(viewSource).toContain('() => route.query')
    expect(viewSource).toContain('{ deep: true }')
    expect(viewSource).toContain('query.compose')
    expect(viewSource).toContain('query.profileId')
    expect(viewSource).toContain('query.friendship')
    expect(viewSource).toContain('query.snap')
    expect(viewSource).toContain('query.story')
    expect(viewSource).toContain('conversationForProfile(profileId)')
    expect(viewSource).toContain(
      'if (!requestedFriendship && store.activeFriendshipId)',
    )
    expect(viewSource).toContain("chatBody.value = ''")
  })

  it('only opens incoming direct snaps', () => {
    const canOpenBlock = viewSource.match(
      /function snapCanOpen\(snap: SkyPicSnap\): boolean \{([\s\S]*?)\n\}/,
    )?.[1]

    expect(canOpenBlock).toContain("snap.direction === 'received'")
    expect(canOpenBlock).toContain('snap.allowReplay')
  })

  it('implements server-authorized story replies', () => {
    expect(typeSource).toContain('canReply: boolean')
    expect(viewSource).toContain('store.viewedStory.canReply')
    expect(viewSource).toContain('stories.replyPlaceholder')
    expect(viewSource).toContain(
      'store.sendMessage(friendshipId, body, story.id)',
    )
    expect(viewSource).toContain('@focus="pauseStoryCountdown"')
    expect(viewSource).toContain('@blur="resumeStoryCountdown"')
    expect(storeSource).toContain('...(storyId ? { storyId } : {})')
  })

  it('renders outgoing requests with a cancellable relationship action', () => {
    expect(viewSource).toContain('store.outgoingRequests')
    expect(viewSource).toContain('cancelFriendRequest(request)')
    expect(viewSource).toContain("'friends.cancelRequest'")
    expect(storeSource).toContain("'skypic:remove-friend'")
  })

  it('has timer cleanup, conditional scroll owners and accessible controls', () => {
    expect(viewSource).toContain('beginCountdown(')
    expect(viewSource).toContain('clearSnapTimer()')
    expect(viewSource).toContain('clearStoryTimer()')
    expect(viewSource).toContain('onBeforeUnmount(')
    expect(viewSource).toContain('<SkyScrollArea')
    expect(viewSource).toContain('with-tabbar')
    expect(viewSource).toContain('var(--sky-touch-target)')
    expect(viewSource).toContain(':focus-visible')
    expect(viewSource).toContain('@media (prefers-reduced-motion: reduce)')
    expect(viewSource).toContain('aria-modal="true"')
  })

  it('starts viewer timers only after media readiness and closes sheets safely', () => {
    expect(viewSource).toContain(
      "prepareViewerMedia('snap', snap.durationSeconds)",
    )
    expect(viewSource).toContain(
      "prepareViewerMedia('story', story.durationSeconds)",
    )
    expect(viewSource).toContain("handleViewerMediaReady('snap')")
    expect(viewSource).toContain("handleViewerMediaReady('story')")
    expect(viewSource).toContain("handleViewerVideoCanPlay('snap', $event)")
    expect(viewSource).toContain("handleViewerVideoCanPlay('story', $event)")
    expect(viewSource).toContain('await video.play()')
    expect(viewSource).toContain('mediaLoading.value = true')
    expect(viewSource).toContain('mediaError.value = true')
    expect(viewSource).toContain('pauseStoryCountdown()')
    expect(viewSource).toContain('storyViewerSheetOpen.value = false')
  })

  it('guards stale tab, story and viewer-sheet requests', () => {
    expect(viewSource).toContain(
      'navigationRequest !== threadNavigationRequest',
    )
    expect(viewSource).toContain('activeTab.value !== next')
    expect(viewSource).toContain(
      'if (!appMounted || store.storyViewing) return',
    )
    expect(viewSource).toContain('const requestId = ++storyNavigationRequest')
    expect(viewSource).toContain('const requestId = ++storyViewerRequest')
    expect(viewSource).toContain('store.viewedStory?.id === story.id')
    expect(storeSource).toContain("error: 'story_view_in_progress'")
    expect(storeSource).toContain('requestId !== storyRequest')
    expect(storeSource).toContain('requestId !== storyViewersRequest')
    expect(viewSource).toContain('if (!appMounted) return')
    expect(viewSource).toContain('threadNavigationRequest += 1')
    expect(viewSource).toContain('store.closeThread()')
  })

  it('bounds discovery search and clears failed results', () => {
    expect(viewSource).toContain('const MAX_SEARCH_CHARACTERS = 64')
    expect(viewSource).toContain("slice(0, MAX_SEARCH_CHARACTERS).join('')")
    expect(viewSource).toContain('@update:model-value="updateSearchQuery"')
    expect(viewSource).toContain('notify(errorText(store.error ?? undefined))')
    expect(storeSource).toContain('searchResults.value = []')
  })

  it('deduplicates concurrent account bootstraps', () => {
    expect(storeSource).toContain(
      'bootstrapInFlight?.session === requestSession',
    )
    expect(storeSource).toContain('return bootstrapInFlight.promise')
    expect(storeSource).toContain(
      'bootstrapInFlight = { promise, session: requestSession, token }',
    )
  })
})
