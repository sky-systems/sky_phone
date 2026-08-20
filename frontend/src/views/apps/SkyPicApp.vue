<script setup lang="ts">
import {
  Bookmark,
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  CirclePlay,
  Eye,
  Image as ImageIcon,
  Images,
  LogOut,
  MessageCircle,
  Palette,
  Plus,
  RotateCcw,
  Search,
  Send,
  Settings,
  Shield,
  Timer,
  Trash2,
  UserRound,
  UsersRound,
  Video,
  X,
} from 'lucide-vue-next'
import {
  computed,
  onBeforeUnmount,
  onMounted,
  reactive,
  ref,
  watch,
  type CSSProperties,
} from 'vue'
import { useRoute, useRouter, type LocationQuery } from 'vue-router'

import AccountLogoutDialog from '@/components/account/AccountLogoutDialog.vue'
import AppProfileAuth from '@/components/account/AppProfileAuth.vue'
import FullEmojiPicker from '@/components/FullEmojiPicker.vue'
import { useAccountStore } from '@/stores/account'
import { useAppAuthStore } from '@/stores/app-auth'
import {
  useMessageMediaStore,
  type MediaSelectionResult,
} from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import {
  isValidSkyPicHandle,
  normalizeSkyPicHandle,
  useSkyPicStore,
} from '@/stores/skypic'
import type { MediaType, PhoneMedia } from '@/types/media'
import type {
  SkyPicDraftPurpose,
  SkyPicFriend,
  SkyPicFriendRequest,
  SkyPicMediaDraftContext,
  SkyPicMessage,
  SkyPicProfileSummary,
  SkyPicSnap,
  SkyPicStory,
  SkyPicStoryPrivacy,
  SkyPicThreadMediaDraftContext,
} from '@/types/skypic'
import {
  SkyAppPage,
  SkyBadge,
  SkyButton,
  SkyCheckbox,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkyField,
  SkyGlass,
  SkyMessage,
  SkyMessagebar,
  SkyMessages,
  SkyNavbar,
  SkyNotification,
  SkyRange,
  SkyScrollArea,
  SkySearchbar,
  SkySegmented,
  SkySegmentedButton,
  SkySheet,
  SkySpinner,
  SkyTabBar,
  SkyTabButton,
  SkyToggle,
} from '@/ui'

type Tab = 'camera' | 'chats' | 'friends' | 'stories'
type MediaSource = 'camera' | 'photos'
type ViewerKind = 'snap' | 'story'
type ThreadEntry =
  | { createdAt: string; id: string; kind: 'message'; value: SkyPicMessage }
  | { createdAt: string; id: string; kind: 'snap'; value: SkyPicSnap }
type SkyPicAuthMediaContext = {
  handle: string
  mode: 'login' | 'register'
  selectedPhoto: PhoneMedia | null
}

const MAX_CAPTION_LENGTH = 160
const MAX_MESSAGE_CHARACTERS = 2_000
const MAX_SEARCH_CHARACTERS = 64
const MAX_SNAP_RECIPIENTS = 20
const MAX_THREAD_ATTACHMENTS = 10
const MAX_TEXT_OVERLAY_LENGTH = 160

const phone = usePhoneStore()
const account = useAccountStore()
const appAuth = useAppAuthStore()
const store = useSkyPicStore()
const mediaPicker = useMessageMediaStore()
const route = useRoute()
const router = useRouter()

const activeTab = ref<Tab>('camera')
const capturePurpose = ref<SkyPicDraftPurpose>('snap')
const captureMediaType = ref<MediaType>('photo')
const composerMedia = ref<PhoneMedia | null>(null)
const composerPurpose = ref<SkyPicDraftPurpose>('snap')
const caption = ref('')
const textOverlay = ref('')
const overlayColor = ref('#ffffff')
const durationSeconds = ref(5)
const allowReplay = ref(true)
const selectedRecipientIds = ref<string[]>([])
const publishing = ref(false)
const authMode = ref<'login' | 'register'>('register')
const authHandle = ref('')
const authPhoto = ref<PhoneMedia | null>(null)
const authSubmitting = ref(false)
const authError = ref('')
const hasSkyPicAccount = ref(false)

const onboarding = reactive({
  avatarSeed: Math.floor(Math.random() * 360) + 1,
  displayName: '',
  handle: '',
})
const profileDraft = reactive({
  allowStoryReplies: true,
  bio: '',
  displayName: '',
  handle: '',
  showInQuickAdd: true,
  storyPrivacy: 'friends' as SkyPicStoryPrivacy,
})
const onboardingSubmitting = ref(false)
const profileEditing = ref(false)
const profileSaving = ref(false)

const searchQuery = ref('')
const highlightedProfileId = ref('')
const chatBody = ref('')
const pendingThreadMedia = ref<PhoneMedia[]>([])
const threadAttachmentMenuOpen = ref(false)
const threadEmojiOpen = ref(false)
const threadSending = ref(false)
const logoutDialogOpen = ref(false)
const deleteAccountDialogOpen = ref(false)
const accountActionPending = ref(false)
const storyReply = ref('')
const feedback = ref('')
const storyViewerSheetOpen = ref(false)
const storyViewerSheetStoryId = ref('')
const snapRemaining = ref(0)
const snapProgress = ref(100)
const storyRemaining = ref(0)
const storyProgress = ref(100)
const bootstrapped = ref(false)
const bootstrapFailed = ref(false)
const mediaLoading = ref(false)
const mediaError = ref(false)
const activeViewerKind = ref<ViewerKind | null>(null)
let feedbackTimer: number | null = null
let searchTimer: number | null = null
let snapTimer: number | null = null
let storyTimer: number | null = null
let mediaPlayRequest = 0
let storyNavigationRequest = 0
let storyViewerRequest = 0
let threadNavigationRequest = 0
let appMounted = false

const isDarkPage = computed(
  () =>
    activeTab.value === 'camera' ||
    Boolean(composerMedia.value) ||
    Boolean(store.openedSnap) ||
    Boolean(store.viewedStory) ||
    phone.isDarkMode,
)
const isAuthenticated = computed(() => appAuth.isSignedIn('skypic'))
const authSubmitEnabled = computed(
  () => Boolean(account.email) && isValidSkyPicHandle(authHandle.value),
)
const threadComposerHasContent = computed(
  () => Boolean(chatBody.value.trim()) || pendingThreadMedia.value.length > 0,
)
const incomingSnaps = computed(() =>
  store.inbox.filter((snap) => snap.direction === 'received'),
)
const ownStories = computed(() =>
  store.stories.filter((story) => story.isOwner),
)
const communityStories = computed(() =>
  store.stories.filter((story) => !story.isOwner),
)
const viewedStorySummary = computed(
  () =>
    store.stories.find((story) => story.id === store.viewedStory?.id) ?? null,
)
const viewedStoryFriendshipId = computed(() =>
  store.viewedStory
    ? conversationForProfile(store.viewedStory.author.id)
    : null,
)
const selectedRecipients = computed(() =>
  store.friends.filter((friend) =>
    selectedRecipientIds.value.includes(friend.profile.id),
  ),
)
const canPublish = computed(
  () =>
    Boolean(composerMedia.value) &&
    (composerPurpose.value === 'story' ||
      selectedRecipientIds.value.length > 0) &&
    !publishing.value,
)
const threadTimeline = computed<ThreadEntry[]>(() =>
  [
    ...store.threadMessages.map((message) => ({
      createdAt: message.createdAt,
      id: `message-${message.id}`,
      kind: 'message' as const,
      value: message,
    })),
    ...store.threadSnaps.map((snap) => ({
      createdAt: snap.createdAt,
      id: `snap-${snap.id}`,
      kind: 'snap' as const,
      value: snap,
    })),
  ].sort((a, b) => timestamp(a.createdAt) - timestamp(b.createdAt)),
)

function t(key: string, replacements?: Record<string, string>): string {
  return phone.t(`Apps.skypic.${key}`, replacements)
}

function queryValue(value: unknown): string {
  return Array.isArray(value) ? String(value[0] ?? '') : String(value ?? '')
}

function timestamp(value: string | null | undefined): number {
  const parsed = value ? Date.parse(value) : 0
  return Number.isFinite(parsed) ? parsed : 0
}

function relativeTime(value: string | null | undefined): string {
  const elapsed = Math.max(
    1,
    Math.floor((Date.now() - timestamp(value)) / 1000),
  )
  if (elapsed < 60) return t('time.seconds', { count: String(elapsed) })
  if (elapsed < 3600) {
    return t('time.minutes', { count: String(Math.floor(elapsed / 60)) })
  }
  if (elapsed < 86_400) {
    return t('time.hours', { count: String(Math.floor(elapsed / 3600)) })
  }
  return t('time.days', { count: String(Math.floor(elapsed / 86_400)) })
}

function initials(
  profile: Pick<SkyPicProfileSummary, 'displayName' | 'handle'>,
): string {
  return (
    profile.displayName.trim().slice(0, 2) ||
    profile.handle.trim().slice(0, 2) ||
    'SP'
  ).toUpperCase()
}

function avatarStyle(
  profile: Pick<SkyPicProfileSummary, 'avatarSeed'>,
): CSSProperties {
  const hue = Math.abs(Number(profile.avatarSeed) || 0) % 360
  return {
    background: `linear-gradient(145deg, hsl(${hue} 78% 58%), hsl(${(hue + 52) % 360} 78% 42%))`,
  }
}

function notify(message: string): void {
  if (feedbackTimer !== null) window.clearTimeout(feedbackTimer)
  feedback.value = message
  feedbackTimer = window.setTimeout(() => {
    feedback.value = ''
    feedbackTimer = null
  }, 2800)
}

function errorText(error?: string): string {
  return t(`errors.${error || 'default'}`)
}

function syncProfileDraft(): void {
  if (!store.profile) return
  Object.assign(profileDraft, {
    allowStoryReplies: store.profile.allowStoryReplies,
    bio: store.profile.bio,
    displayName: store.profile.displayName,
    handle: store.profile.handle,
    showInQuickAdd: store.profile.showInQuickAdd,
    storyPrivacy: store.profile.storyPrivacy,
  })
}

function toggleProfileEditor(): void {
  profileEditing.value = !profileEditing.value
  if (profileEditing.value) syncProfileDraft()
}

function switchAuthMode(mode: 'login' | 'register'): void {
  authMode.value = mode
  authError.value = ''
  authPhoto.value = null
}

function displayNameFromHandle(handle: string): string {
  const displayName = handle
    .split(/[._]+/)
    .filter(Boolean)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(' ')
  return Array.from(displayName || handle)
    .slice(0, 40)
    .join('')
}

function openAuthMedia(source: MediaSource): void {
  mediaPicker.begin(
    'skypic-auth-avatar',
    'photo',
    `/apps/skypic?auth=${authMode.value}`,
    1,
    {
      handle: authHandle.value,
      mode: authMode.value,
      selectedPhoto: authPhoto.value,
    } satisfies SkyPicAuthMediaContext,
  )
  void router.push({
    path: `/apps/${source}`,
    query: { mediaAttachment: 'photo' },
  })
}

function consumeAuthMediaDraft(): boolean {
  const selection =
    mediaPicker.consumeMany<SkyPicAuthMediaContext>('skypic-auth-avatar')
  if (!selection) return false
  authMode.value = selection.context?.mode ?? authMode.value
  authHandle.value = selection.context?.handle ?? authHandle.value
  authPhoto.value =
    selection.media[0] ?? selection.context?.selectedPhoto ?? null
  return true
}

async function submitAuthentication(): Promise<void> {
  if (authSubmitting.value) return
  authError.value = ''
  const handle = normalizeSkyPicHandle(authHandle.value)
  if (!account.email) {
    authError.value = errorText('not_authenticated')
    return
  }
  if (!isValidSkyPicHandle(handle)) {
    authError.value = errorText('invalid_handle')
    return
  }

  authSubmitting.value = true
  if (authMode.value === 'login') {
    const loaded = await store.bootstrap()
    authSubmitting.value = false
    if (!loaded || !store.profile || store.profile.handle !== handle) {
      authError.value = errorText('profile_not_found')
      hasSkyPicAccount.value = Boolean(store.profile)
      store.resetSession()
      return
    }
    hasSkyPicAccount.value = true
    appAuth.signIn('skypic', account.email)
    authHandle.value = ''
    authPhoto.value = null
    syncProfileDraft()
    await applyRouteQuery(route.query)
    return
  }

  if (hasSkyPicAccount.value || store.profile) {
    authSubmitting.value = false
    authError.value = errorText('profile_exists')
    return
  }
  const response = await store.createProfile({
    ...(authPhoto.value ? { avatarMediaId: authPhoto.value.id } : {}),
    avatarSeed: onboarding.avatarSeed,
    displayName: displayNameFromHandle(handle),
    handle,
  })
  authSubmitting.value = false
  if (!response.success) {
    authError.value = errorText(response.error)
    return
  }
  appAuth.signIn('skypic', account.email)
  hasSkyPicAccount.value = true
  authHandle.value = ''
  authPhoto.value = null
  syncProfileDraft()
  await store.bootstrap()
}

async function submitOnboarding(): Promise<void> {
  const handle = normalizeSkyPicHandle(onboarding.handle)
  if (!isValidSkyPicHandle(handle)) {
    notify(errorText('invalid_handle'))
    return
  }
  if (!onboarding.displayName.trim()) {
    notify(t('errors.profile_required'))
    return
  }
  onboardingSubmitting.value = true
  const response = await store.createProfile({
    avatarSeed: onboarding.avatarSeed,
    displayName: onboarding.displayName,
    handle,
  })
  onboardingSubmitting.value = false
  if (!response.success) {
    notify(errorText(response.error))
    return
  }
  appAuth.signIn('skypic', account.email)
  await store.bootstrap()
  syncProfileDraft()
}

function resetAccountUiState(accountExists: boolean): void {
  threadNavigationRequest += 1
  storyNavigationRequest += 1
  storyViewerRequest += 1
  mediaPlayRequest += 1
  clearSnapTimer()
  clearStoryTimer()
  profileEditing.value = false
  profileSaving.value = false
  logoutDialogOpen.value = false
  deleteAccountDialogOpen.value = false
  authMode.value = accountExists ? 'login' : 'register'
  authHandle.value = ''
  authPhoto.value = null
  authError.value = ''
  pendingThreadMedia.value = []
  threadAttachmentMenuOpen.value = false
  threadEmojiOpen.value = false
  threadSending.value = false
  chatBody.value = ''
  searchQuery.value = ''
  highlightedProfileId.value = ''
  selectedRecipientIds.value = []
  storyReply.value = ''
  storyViewerSheetOpen.value = false
  storyViewerSheetStoryId.value = ''
  activeViewerKind.value = null
  mediaLoading.value = false
  mediaError.value = false
  snapRemaining.value = 0
  snapProgress.value = 100
  storyRemaining.value = 0
  storyProgress.value = 100
  resetComposer()
  store.closeThread()
  store.clearOpenedSnap()
  store.clearViewedStory()
  hasSkyPicAccount.value = accountExists
  activeTab.value = 'camera'
}

function handleLoggedOut(): void {
  resetAccountUiState(true)
  store.resetSession()
}

async function deleteSkyPicAccount(): Promise<void> {
  if (accountActionPending.value) return
  accountActionPending.value = true
  const deleted = await store.deleteAccount()
  accountActionPending.value = false
  if (!deleted) {
    notify(errorText(store.error ?? undefined))
    return
  }
  appAuth.signOut('skypic')
  resetAccountUiState(false)
  await router.replace({ path: '/apps/skypic', query: { tab: 'camera' } })
}

async function saveProfile(): Promise<void> {
  if (!store.profile || profileSaving.value) return
  profileSaving.value = true
  const response = await store.updateProfile({
    allowStoryReplies: profileDraft.allowStoryReplies,
    avatarMediaId: store.profile.avatarMediaId,
    avatarSeed: store.profile.avatarSeed,
    bio: profileDraft.bio,
    displayName: profileDraft.displayName,
    handle: profileDraft.handle,
    showInQuickAdd: profileDraft.showInQuickAdd,
    storyPrivacy: profileDraft.storyPrivacy,
  })
  profileSaving.value = false
  if (!response.success) {
    notify(errorText(response.error))
    return
  }
  profileEditing.value = false
  notify(t('profile.saved'))
}

function beginCapture(
  source: MediaSource,
  mediaType: MediaType,
  purpose: SkyPicDraftPurpose = capturePurpose.value,
  recipientIds = selectedRecipientIds.value,
): void {
  mediaPicker.begin(
    'skypic-draft',
    mediaType,
    `/apps/skypic?compose=${purpose}`,
    1,
    {
      purpose,
      recipientIds: [...recipientIds],
    } satisfies SkyPicMediaDraftContext,
  )
  void router.push({
    path: `/apps/${source}`,
    query: { mediaAttachment: mediaType },
  })
}

function consumeMediaDraft(): boolean {
  const result =
    mediaPicker.consumeMany<SkyPicMediaDraftContext>('skypic-draft')
  const media = result?.media[0]
  if (!media) return false

  composerMedia.value = media
  composerPurpose.value =
    result.context?.purpose ??
    (queryValue(route.query.compose) === 'story' ? 'story' : 'snap')
  selectedRecipientIds.value = [
    ...new Set(result.context?.recipientIds ?? selectedRecipientIds.value),
  ].slice(0, MAX_SNAP_RECIPIENTS)
  caption.value = ''
  textOverlay.value = ''
  overlayColor.value = '#ffffff'
  durationSeconds.value = 5
  allowReplay.value = true
  return true
}

function openThreadMedia(source: MediaSource, mediaType: MediaType): void {
  const conversation = store.activeConversation
  if (!conversation) return
  const hasVideo = pendingThreadMedia.value.some(
    (media) => media.mediaType === 'video',
  )
  if (
    (mediaType === 'video' && pendingThreadMedia.value.length > 0) ||
    (mediaType === 'photo' && hasVideo)
  ) {
    notify(
      t('chats.attachmentLimit', {
        count: String(MAX_THREAD_ATTACHMENTS),
      }),
    )
    return
  }
  const remainingSlots =
    mediaType === 'photo'
      ? MAX_THREAD_ATTACHMENTS - pendingThreadMedia.value.length
      : 1
  if (remainingSlots < 1) {
    notify(
      t('chats.attachmentLimit', {
        count: String(MAX_THREAD_ATTACHMENTS),
      }),
    )
    return
  }

  threadAttachmentMenuOpen.value = false
  threadEmojiOpen.value = false
  mediaPicker.begin(
    'skypic-thread-media',
    mediaType,
    `/apps/skypic?tab=chats&friendship=${encodeURIComponent(conversation.friendshipId)}`,
    source === 'photos' && mediaType === 'photo' ? remainingSlots : 1,
    {
      body: chatBody.value,
      friendshipId: conversation.friendshipId,
      pendingMedia: [...pendingThreadMedia.value],
    } satisfies SkyPicThreadMediaDraftContext,
  )
  void router.push({
    path: `/apps/${source}`,
    query: { mediaAttachment: mediaType },
  })
}

function restoreThreadMediaSelection(
  selection: MediaSelectionResult<SkyPicThreadMediaDraftContext> | null,
): boolean {
  if (!selection) return false
  const context = selection.context
  if (
    !context?.friendshipId ||
    !store.friends.some(
      (friend) => friend.friendshipId === context.friendshipId,
    )
  ) {
    pendingThreadMedia.value = []
    return false
  }
  chatBody.value = Array.from(context.body ?? '')
    .slice(0, MAX_MESSAGE_CHARACTERS)
    .join('')
  const selectedVideo = selection.media.find(
    (media) => media.mediaType === 'video',
  )
  if (selectedVideo) {
    pendingThreadMedia.value = [selectedVideo]
    return true
  }

  const seen = new Set<number>()
  pendingThreadMedia.value = [
    ...(context.pendingMedia ?? []),
    ...selection.media,
  ]
    .filter((media) => {
      if (media.mediaType !== 'photo' || seen.has(media.id)) return false
      seen.add(media.id)
      return true
    })
    .slice(0, MAX_THREAD_ATTACHMENTS)
  return true
}

function consumeThreadMediaDraft(): boolean {
  return restoreThreadMediaSelection(
    mediaPicker.consumeMany<SkyPicThreadMediaDraftContext>(
      'skypic-thread-media',
    ),
  )
}

function toggleThreadAttachmentMenu(): void {
  threadAttachmentMenuOpen.value = !threadAttachmentMenuOpen.value
  threadEmojiOpen.value = false
}

function openThreadEmojiPicker(): void {
  threadAttachmentMenuOpen.value = false
  threadEmojiOpen.value = true
}

function appendThreadEmoji(emoji: string): void {
  updateChatBody(`${chatBody.value}${emoji}`)
}

function removeThreadMedia(mediaId: number): void {
  if (threadSending.value) return
  pendingThreadMedia.value = pendingThreadMedia.value.filter(
    (media) => media.id !== mediaId,
  )
}

function moveThreadMedia(index: number, direction: -1 | 1): void {
  if (threadSending.value) return
  const target = index + direction
  if (target < 0 || target >= pendingThreadMedia.value.length) return
  const ordered = [...pendingThreadMedia.value]
  ;[ordered[index], ordered[target]] = [ordered[target], ordered[index]]
  pendingThreadMedia.value = ordered
}

function resetComposer(): void {
  composerMedia.value = null
  caption.value = ''
  textOverlay.value = ''
  overlayColor.value = '#ffffff'
  durationSeconds.value = 5
  allowReplay.value = true
  publishing.value = false
}

function cancelComposer(): void {
  const next = composerPurpose.value === 'story' ? 'stories' : 'camera'
  resetComposer()
  void setTab(next)
}

function toggleRecipient(profileId: string): void {
  if (selectedRecipientIds.value.includes(profileId)) {
    selectedRecipientIds.value = selectedRecipientIds.value.filter(
      (id) => id !== profileId,
    )
    return
  }
  if (selectedRecipientIds.value.length >= MAX_SNAP_RECIPIENTS) {
    notify(
      t('composer.recipientLimit', {
        count: String(MAX_SNAP_RECIPIENTS),
      }),
    )
    return
  }
  selectedRecipientIds.value = [...selectedRecipientIds.value, profileId]
}

function recipientSelectionDisabled(profileId: string): boolean {
  return (
    selectedRecipientIds.value.length >= MAX_SNAP_RECIPIENTS &&
    !selectedRecipientIds.value.includes(profileId)
  )
}

function boundedMessage(value: string, localeKey: string): string {
  const characters = Array.from(value)
  if (characters.length <= MAX_MESSAGE_CHARACTERS) return value
  notify(
    t(localeKey, {
      count: String(MAX_MESSAGE_CHARACTERS),
    }),
  )
  return characters.slice(0, MAX_MESSAGE_CHARACTERS).join('')
}

function updateChatBody(value: string): void {
  chatBody.value = boundedMessage(value, 'chats.messageLimit')
}

function updateStoryReply(value: string): void {
  storyReply.value = boundedMessage(value, 'stories.replyLimit')
}

async function publishComposer(): Promise<void> {
  const media = composerMedia.value
  if (!media || !canPublish.value) return
  publishing.value = true
  const common = {
    caption: caption.value.trim().slice(0, MAX_CAPTION_LENGTH),
    durationSeconds: durationSeconds.value,
    mediaId: media.id,
    mediaType: media.mediaType,
    overlayColor: overlayColor.value,
    textOverlay: Array.from(textOverlay.value)
      .slice(0, MAX_TEXT_OVERLAY_LENGTH)
      .join(''),
  }
  const response =
    composerPurpose.value === 'story'
      ? await store.publishStory(common)
      : await store.sendSnap({
          ...common,
          allowReplay: allowReplay.value,
          recipientIds: selectedRecipientIds.value.slice(
            0,
            MAX_SNAP_RECIPIENTS,
          ),
        })
  publishing.value = false
  if (!response.success) {
    notify(errorText(response.error))
    return
  }

  const publishedPurpose = composerPurpose.value
  resetComposer()
  selectedRecipientIds.value = []
  notify(
    t(
      publishedPurpose === 'story'
        ? 'composer.storyPublished'
        : 'composer.sent',
    ),
  )
  await setTab(publishedPurpose === 'story' ? 'stories' : 'chats')
}

async function setTab(next: Tab): Promise<void> {
  if (!appMounted) return
  const navigationRequest = ++threadNavigationRequest
  storyViewerRequest += 1
  storyViewerSheetOpen.value = false
  if (next !== 'stories' && (store.storyViewing || store.viewedStory)) {
    storyNavigationRequest += 1
    store.clearViewedStory()
  }
  if (
    activeTab.value !== next &&
    (store.activeFriendshipId || store.threadLoading)
  ) {
    store.closeThread()
    chatBody.value = ''
    pendingThreadMedia.value = []
    threadAttachmentMenuOpen.value = false
    threadEmojiOpen.value = false
  }
  activeTab.value = next
  if (next === 'stories') await store.loadStories()
  if (
    !appMounted ||
    navigationRequest !== threadNavigationRequest ||
    activeTab.value !== next
  ) {
    return
  }
  await router.replace({ path: '/apps/skypic', query: { tab: next } })
}

function conversationForProfile(profileId: string): string | null {
  return (
    store.conversations.find(
      (conversation) => conversation.profile.id === profileId,
    )?.friendshipId ??
    store.friends.find((friend) => friend.profile.id === profileId)
      ?.friendshipId ??
    null
  )
}

async function openThread(friendshipId: string): Promise<void> {
  if (!appMounted) return
  const navigationRequest = ++threadNavigationRequest
  activeTab.value = 'chats'
  if (store.activeFriendshipId !== friendshipId) {
    const opened = await store.openThread(friendshipId)
    if (!appMounted || navigationRequest !== threadNavigationRequest) return
    if (!opened) {
      notify(errorText(store.error ?? undefined))
      return
    }
  }
  if (
    !appMounted ||
    navigationRequest !== threadNavigationRequest ||
    store.activeFriendshipId !== friendshipId
  ) {
    return
  }
  const marked = await store.markThread(friendshipId)
  if (
    !marked ||
    !appMounted ||
    navigationRequest !== threadNavigationRequest ||
    store.activeFriendshipId !== friendshipId
  ) {
    return
  }
  await router.replace({
    path: '/apps/skypic',
    query: { friendship: friendshipId, tab: 'chats' },
  })
}

function closeThread(): void {
  threadNavigationRequest += 1
  store.closeThread()
  chatBody.value = ''
  pendingThreadMedia.value = []
  threadAttachmentMenuOpen.value = false
  threadEmojiOpen.value = false
  void router.replace({ path: '/apps/skypic', query: { tab: 'chats' } })
}

async function submitMessage(): Promise<void> {
  const friendshipId = store.activeFriendshipId
  const recipientId = store.activeConversation?.profile.id
  const body = boundedMessage(chatBody.value, 'chats.messageLimit')
  chatBody.value = body
  if (
    !friendshipId ||
    !recipientId ||
    !threadComposerHasContent.value ||
    threadSending.value
  ) {
    return
  }
  threadSending.value = true
  threadAttachmentMenuOpen.value = false
  threadEmojiOpen.value = false

  const queuedMedia = [...pendingThreadMedia.value]
  if (queuedMedia.length) {
    const video = queuedMedia.length === 1 ? queuedMedia[0] : null
    const response =
      video?.mediaType === 'video'
        ? await store.sendSnap({
            allowReplay: true,
            caption: '',
            durationSeconds: 5,
            mediaId: video.id,
            mediaType: 'video',
            overlayColor: '#ffffff',
            recipientIds: [recipientId],
            textOverlay: '',
          })
        : await store.sendSnap({
            allowReplay: true,
            caption: '',
            durationSeconds: 5,
            mediaIds: queuedMedia.map((media) => media.id),
            overlayColor: '#ffffff',
            recipientIds: [recipientId],
            textOverlay: '',
          })
    if (!response.success) {
      threadSending.value = false
      notify(errorText(response.error))
      return
    }
    pendingThreadMedia.value = []
    notify(t('chats.photoAttachmentsSent'))
  }

  if (body.trim()) {
    const response = await store.sendMessage(friendshipId, body)
    if (!response.success) {
      threadSending.value = false
      notify(errorText(response.error))
      return
    }
    chatBody.value = ''
  }
  threadSending.value = false
}

function messageKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Enter' || event.shiftKey) return
  event.preventDefault()
  void submitMessage()
}

async function toggleSaved(message: SkyPicMessage): Promise<void> {
  if (!(await store.saveMessage(message.id, !message.savedAt))) {
    notify(errorText(store.error ?? undefined))
  }
}

async function deleteMessage(message: SkyPicMessage): Promise<void> {
  if (!(await store.deleteMessage(message.id, message.direction === 'sent'))) {
    notify(errorText(store.error ?? undefined))
  }
}

function clearSnapTimer(): void {
  if (snapTimer !== null) window.clearInterval(snapTimer)
  snapTimer = null
}

function clearStoryTimer(): void {
  if (storyTimer !== null) window.clearInterval(storyTimer)
  storyTimer = null
}

function pauseStoryCountdown(): void {
  clearStoryTimer()
}

function beginCountdown(
  duration: number,
  remaining: typeof snapRemaining,
  progress: typeof snapProgress,
  close: () => void,
  kind: 'snap' | 'story',
): void {
  if (kind === 'snap') clearSnapTimer()
  else clearStoryTimer()
  const seconds = Math.max(1, Math.min(10, duration || 5))
  const startedAt = performance.now()
  remaining.value = seconds
  progress.value = 100
  const timer = window.setInterval(() => {
    const elapsed = (performance.now() - startedAt) / 1000
    remaining.value = Math.max(0, seconds - elapsed)
    progress.value = Math.max(0, 100 - (elapsed / seconds) * 100)
    if (elapsed >= seconds) close()
  }, 100)
  if (kind === 'snap') snapTimer = timer
  else storyTimer = timer
}

function resumeStoryCountdown(): void {
  if (
    !store.viewedStory ||
    mediaLoading.value ||
    mediaError.value ||
    storyRemaining.value <= 0
  ) {
    return
  }
  beginCountdown(
    storyRemaining.value,
    storyRemaining,
    storyProgress,
    closeStoryViewer,
    'story',
  )
}

function prepareViewerMedia(kind: ViewerKind, duration: number): void {
  mediaPlayRequest += 1
  activeViewerKind.value = kind
  mediaLoading.value = true
  mediaError.value = false
  const seconds = Math.max(1, Math.min(10, duration || 5))
  if (kind === 'snap') {
    clearSnapTimer()
    snapRemaining.value = seconds
    snapProgress.value = 100
  } else {
    clearStoryTimer()
    storyRemaining.value = seconds
    storyProgress.value = 100
  }
}

function handleViewerMediaReady(kind: ViewerKind): void {
  if (
    activeViewerKind.value !== kind ||
    !mediaLoading.value ||
    mediaError.value
  ) {
    return
  }
  mediaLoading.value = false
  if (kind === 'snap' && store.openedSnap) {
    beginCountdown(
      store.openedSnap.durationSeconds,
      snapRemaining,
      snapProgress,
      closeSnapViewer,
      'snap',
    )
  } else if (kind === 'story' && store.viewedStory) {
    beginCountdown(
      store.viewedStory.durationSeconds,
      storyRemaining,
      storyProgress,
      closeStoryViewer,
      'story',
    )
  }
}

async function handleViewerVideoCanPlay(
  kind: ViewerKind,
  event: Event,
): Promise<void> {
  if (activeViewerKind.value !== kind || !mediaLoading.value) return
  const video = event.currentTarget
  if (!(video instanceof HTMLVideoElement)) {
    handleViewerMediaError(kind)
    return
  }
  const requestId = ++mediaPlayRequest
  try {
    await video.play()
    if (requestId === mediaPlayRequest) handleViewerMediaReady(kind)
  } catch {
    if (requestId === mediaPlayRequest) handleViewerMediaError(kind)
  }
}

function handleViewerMediaError(kind: ViewerKind): void {
  if (activeViewerKind.value !== kind) return
  mediaPlayRequest += 1
  mediaLoading.value = false
  mediaError.value = true
  notify(errorText('request_failed'))
  if (kind === 'snap') closeSnapViewer()
  else closeStoryViewer()
}

function finishViewerMedia(kind: ViewerKind): void {
  if (activeViewerKind.value !== kind) return
  mediaPlayRequest += 1
  activeViewerKind.value = null
  mediaLoading.value = false
}

async function openSnap(snapId: string, replay = false): Promise<void> {
  if (store.snapOpening) return
  const response = replay
    ? await store.replaySnap(snapId)
    : await store.openSnap(snapId)
  if (
    !response.success &&
    response.error !== 'snap_open_in_progress' &&
    response.error !== 'request_aborted'
  ) {
    notify(errorText(response.error))
  }
}

function closeSnapViewer(): void {
  const friendshipId = store.activeFriendshipId
  clearSnapTimer()
  finishViewerMedia('snap')
  store.clearOpenedSnap()
  void router.replace({
    path: '/apps/skypic',
    query: friendshipId
      ? { friendship: friendshipId, tab: 'chats' }
      : { tab: 'chats' },
  })
}

async function openStory(storyId: string): Promise<void> {
  if (!appMounted || store.storyViewing) return
  const requestId = ++storyNavigationRequest
  const response = await store.viewStory(storyId)
  if (!appMounted || requestId !== storyNavigationRequest) {
    if (store.viewedStory?.id === storyId) store.clearViewedStory()
    return
  }
  if (
    !response.success &&
    response.error !== 'story_view_in_progress' &&
    response.error !== 'request_aborted'
  ) {
    notify(errorText(response.error))
  }
}

function closeStoryViewer(): void {
  storyNavigationRequest += 1
  storyViewerRequest += 1
  clearStoryTimer()
  finishViewerMedia('story')
  storyViewerSheetOpen.value = false
  storyReply.value = ''
  store.clearViewedStory()
  void router.replace({ path: '/apps/skypic', query: { tab: 'stories' } })
}

async function submitStoryReply(): Promise<void> {
  const story = store.viewedStory
  const friendshipId = viewedStoryFriendshipId.value
  const body = boundedMessage(storyReply.value, 'stories.replyLimit')
  storyReply.value = body
  if (!story || !friendshipId || !body.trim()) return
  const response = await store.sendMessage(friendshipId, body, story.id)
  if (!response.success) {
    notify(errorText(response.error))
    return
  }
  storyReply.value = ''
  notify(t('stories.replySent'))
  closeStoryViewer()
}

function storyReplyKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Enter' || event.shiftKey) return
  event.preventDefault()
  void submitStoryReply()
}

async function showStoryViewers(story: SkyPicStory): Promise<void> {
  const requestId = ++storyViewerRequest
  const viewedStoryId = store.viewedStory?.id ?? null
  const openedFromViewer = viewedStoryId === story.id
  if (openedFromViewer) pauseStoryCountdown()
  const loaded = await store.loadStoryViewers(story.id)
  if (requestId !== storyViewerRequest) return
  const storyStillActive = openedFromViewer
    ? store.viewedStory?.id === story.id
    : activeTab.value === 'stories' &&
      store.stories.some((item) => item.id === story.id)
  if (!storyStillActive) return
  if (!loaded) {
    notify(errorText(store.error ?? undefined))
    if (openedFromViewer) resumeStoryCountdown()
    return
  }
  storyViewerSheetStoryId.value = story.id
  storyViewerSheetOpen.value = true
}

function closeStoryViewerSheet(): void {
  storyViewerRequest += 1
  storyViewerSheetOpen.value = false
  storyViewerSheetStoryId.value = ''
  resumeStoryCountdown()
}

async function loadMoreStoryViewers(): Promise<void> {
  const storyId = storyViewerSheetStoryId.value
  if (!storyId || (await store.loadMoreStoryViewers(storyId))) return
  notify(errorText(store.error ?? undefined))
}

async function loadMoreStories(): Promise<void> {
  if (await store.loadMoreStories()) return
  notify(errorText(store.error ?? undefined))
}

async function deleteStory(storyId: string): Promise<void> {
  if (!(await store.removeStory(storyId))) {
    notify(errorText(store.error ?? undefined))
    return
  }
  closeStoryViewer()
  notify(t('stories.deleted'))
}

function scheduleSearch(value: string): void {
  if (searchTimer !== null) window.clearTimeout(searchTimer)
  searchTimer = window.setTimeout(async () => {
    searchTimer = null
    const searched = await store.search(value)
    if (!appMounted || value !== searchQuery.value || searched) return
    notify(errorText(store.error ?? undefined))
  }, 280)
}

function updateSearchQuery(value: string): void {
  searchQuery.value = Array.from(value).slice(0, MAX_SEARCH_CHARACTERS).join('')
}

async function addFriend(profile: SkyPicProfileSummary): Promise<void> {
  const response = await store.addFriend(profile.id)
  if (!response.success) notify(errorText(response.error))
  else notify(t('friends.requestSent', { name: profile.displayName }))
}

async function respondFriend(
  friendshipId: string,
  accept: boolean,
): Promise<void> {
  const response = await store.respondFriend(friendshipId, accept)
  if (!response.success) notify(errorText(response.error))
}

async function removeFriend(friend: SkyPicFriend): Promise<void> {
  if (!(await store.removeFriend(friend.friendshipId))) {
    notify(errorText(store.error ?? undefined))
    return
  }
  notify(t('friends.removed', { name: friend.profile.displayName }))
}

async function cancelFriendRequest(
  request: SkyPicFriendRequest,
): Promise<void> {
  if (!(await store.removeFriend(request.friendshipId))) {
    notify(errorText(store.error ?? undefined))
    return
  }
  notify(t('friends.requestCanceled', { name: request.profile.displayName }))
}

async function blockProfile(profile: SkyPicProfileSummary): Promise<void> {
  if (!(await store.block(profile.id, true))) {
    notify(errorText(store.error ?? undefined))
    return
  }
  notify(t('friends.blocked', { name: profile.displayName }))
}

async function unblockProfile(profile: SkyPicProfileSummary): Promise<void> {
  if (!(await store.block(profile.id, false))) {
    notify(errorText(store.error ?? undefined))
    return
  }
  notify(t('friends.unblocked', { name: profile.displayName }))
}

function snapLabel(snap: SkyPicSnap): string {
  if (!snap.openedAt) {
    return t(snap.type === 'snap_video' ? 'snaps.newVideo' : 'snaps.newPhoto')
  }
  if (snap.replayedAt) return t('snaps.replayed')
  return t('snaps.opened')
}

function snapCanOpen(snap: SkyPicSnap): boolean {
  return (
    !store.snapOpening &&
    snap.direction === 'received' &&
    (!snap.openedAt || (snap.allowReplay && !snap.replayedAt))
  )
}

function openThreadSnap(snap: SkyPicSnap): void {
  if (!snapCanOpen(snap)) return
  void openSnap(snap.id, Boolean(snap.openedAt))
}

function profileRelationLabel(profile: SkyPicProfileSummary): string {
  if (profile.friendshipStatus === 'friends') return t('friends.friends')
  if (profile.friendshipStatus === 'outgoing') return t('friends.pending')
  if (profile.friendshipStatus === 'incoming') return t('friends.respond')
  return t('friends.add')
}

async function profileAction(profile: SkyPicProfileSummary): Promise<void> {
  if (profile.friendshipStatus === 'friends' && profile.friendshipId) {
    await openThread(profile.friendshipId)
    return
  }
  if (profile.friendshipStatus === 'incoming' && profile.friendshipId) {
    await respondFriend(profile.friendshipId, true)
    return
  }
  if (profile.friendshipStatus === 'none') await addFriend(profile)
}

function lastItemLabel(
  conversation: (typeof store.conversations)[number],
): string {
  const item = conversation.lastItem
  if (!item) return t('chats.start')
  if (item.type === 'text') return item.body || t('chats.message')
  return t(item.type === 'snap_video' ? 'snaps.video' : 'snaps.photo')
}

async function applyRouteQuery(query: LocationQuery): Promise<void> {
  if (!bootstrapped.value) return
  const navigationRequest = ++threadNavigationRequest
  const requestedTab = queryValue(query.tab)
  if (
    requestedTab === 'camera' ||
    requestedTab === 'chats' ||
    requestedTab === 'stories' ||
    requestedTab === 'friends'
  ) {
    if (activeTab.value !== requestedTab) {
      storyViewerRequest += 1
      storyViewerSheetOpen.value = false
    }
    activeTab.value = requestedTab
  }

  consumeAuthMediaDraft()
  consumeThreadMediaDraft()
  if (queryValue(query.compose)) consumeMediaDraft()
  const profileId = queryValue(query.profileId)
  highlightedProfileId.value = profileId
  const requestedFriendship =
    queryValue(query.friendship) ||
    (profileId && activeTab.value === 'chats'
      ? (conversationForProfile(profileId) ?? '')
      : '')
  if (!requestedFriendship && store.activeFriendshipId) {
    store.closeThread()
    chatBody.value = ''
    pendingThreadMedia.value = []
    threadAttachmentMenuOpen.value = false
    threadEmojiOpen.value = false
  }
  if (requestedFriendship && requestedFriendship !== store.activeFriendshipId) {
    const opened = await store.openThread(requestedFriendship)
    if (
      !opened ||
      navigationRequest !== threadNavigationRequest ||
      store.activeFriendshipId !== requestedFriendship
    ) {
      return
    }
    await store.markThread(requestedFriendship)
    if (
      navigationRequest !== threadNavigationRequest ||
      store.activeFriendshipId !== requestedFriendship
    ) {
      return
    }
  }

  const snapId = queryValue(query.snap)
  if (snapId && store.openedSnap?.id !== snapId) await openSnap(snapId)
  const storyId = queryValue(query.story)
  if (!storyId && (store.storyViewing || store.viewedStory)) {
    storyNavigationRequest += 1
    store.clearViewedStory()
  }
  if (storyId && store.viewedStory?.id !== storyId) await openStory(storyId)
}

watch(searchQuery, scheduleSearch)
watch(
  () => store.profileAbsentRevision,
  () => {
    if (store.profile) return
    if (appAuth.isSignedIn('skypic')) appAuth.signOut('skypic')
    resetAccountUiState(false)
    void router.replace({ path: '/apps/skypic', query: { tab: 'camera' } })
  },
)
watch(
  () => store.openedSnap,
  (snap) => {
    if (snap) prepareViewerMedia('snap', snap.durationSeconds)
    else {
      clearSnapTimer()
      finishViewerMedia('snap')
    }
  },
)
watch(
  () => store.viewedStory,
  (story) => {
    if (story) prepareViewerMedia('story', story.durationSeconds)
    else {
      clearStoryTimer()
      finishViewerMedia('story')
    }
  },
)
watch(
  () => route.query,
  (query) => void applyRouteQuery(query),
  { deep: true },
)

async function bootstrapApp(): Promise<void> {
  bootstrapped.value = false
  bootstrapFailed.value = false
  store.resetSession()
  if (!account.email) {
    resetAccountUiState(false)
    bootstrapped.value = true
    return
  }
  const loaded = await store.bootstrap()
  if (!appMounted) return
  if (!loaded) {
    bootstrapFailed.value = true
    return
  }
  hasSkyPicAccount.value = Boolean(store.profile)
  if (!appAuth.isSignedIn('skypic')) {
    authMode.value = hasSkyPicAccount.value ? 'login' : 'register'
    store.resetSession()
  } else if (!store.profile) {
    appAuth.signOut('skypic')
    authMode.value = 'register'
    store.resetSession()
  }
  bootstrapped.value = true
  syncProfileDraft()
  await applyRouteQuery(route.query)
}

onMounted(() => {
  appMounted = true
  void bootstrapApp()
})

onBeforeUnmount(() => {
  appMounted = false
  threadNavigationRequest += 1
  storyNavigationRequest += 1
  storyViewerRequest += 1
  mediaPlayRequest += 1
  if (feedbackTimer !== null) window.clearTimeout(feedbackTimer)
  if (searchTimer !== null) window.clearTimeout(searchTimer)
  clearSnapTimer()
  clearStoryTimer()
  store.closeThread()
  store.clearOpenedSnap()
  store.clearViewedStory()
})
</script>

<template>
  <SkyAppPage
    accent="#5a6cff"
    accent-soft="rgba(90, 108, 255, 0.2)"
    :dark="isDarkPage"
    :label="t('name')"
    class="skypic-app"
    :class="{
      'skypic-app--player-dark': phone.isDarkMode,
      'skypic-app--player-light': !phone.isDarkMode,
    }"
  >
    <div v-if="store.loading && !bootstrapped" class="sp-loading">
      <SkySpinner />
    </div>

    <div v-else-if="bootstrapFailed" class="sp-loading" role="alert">
      <p>{{ errorText(store.error ?? undefined) }}</p>
      <SkyButton @click="bootstrapApp">
        {{ phone.t('Common.retry') }}
      </SkyButton>
    </div>

    <section v-else-if="!isAuthenticated" class="sp-auth">
      <AppProfileAuth
        v-model:username="authHandle"
        :avatar-url="authPhoto?.url ?? null"
        :body="t(authMode === 'login' ? 'auth.body' : 'onboarding.body')"
        :camera-label="t('camera.capturePhoto')"
        :email="account.email"
        :email-label="t('auth.eyebrow')"
        :error="authError"
        :eyebrow="t('auth.eyebrow')"
        :gallery-label="t('camera.gallery')"
        :login-label="t('auth.login')"
        :login-mode-label="phone.t('Common.appAuth.login')"
        :max-username-length="24"
        :min-username-length="3"
        :mode="authMode"
        moving-mode-highlight
        :pending="authSubmitting"
        :register-label="t('onboarding.create')"
        :register-mode-label="phone.t('Common.appAuth.register')"
        :submit-enabled="authSubmitEnabled"
        :title="t(authMode === 'login' ? 'auth.title' : 'onboarding.title')"
        :username-label="t('onboarding.handle')"
        :username-placeholder="t('onboarding.handlePlaceholder')"
        variant="centered"
        @camera="openAuthMedia('camera')"
        @gallery="openAuthMedia('photos')"
        @submit="submitAuthentication"
        @update:mode="switchAuthMode"
      />
      <p v-if="!account.email" class="sp-auth__hint">
        {{ t('auth.noAccount') }}
      </p>
    </section>

    <template v-else-if="!store.profile">
      <SkyNavbar :title="t('onboarding.title')" />
      <SkyScrollArea padded class="sp-onboarding">
        <section class="sp-onboarding__hero">
          <span
            class="sp-avatar sp-avatar--large"
            :style="avatarStyle({ avatarSeed: onboarding.avatarSeed })"
          >
            <Camera :size="28" aria-hidden="true" />
          </span>
          <small>{{ t('onboarding.eyebrow') }}</small>
          <h2>{{ t('onboarding.heading') }}</h2>
          <p>{{ t('onboarding.body') }}</p>
        </section>
        <form class="sp-form" @submit.prevent="submitOnboarding">
          <SkyField
            v-model="onboarding.displayName"
            :label="t('onboarding.displayName')"
            :placeholder="t('onboarding.displayNamePlaceholder')"
            maxlength="40"
          />
          <SkyField
            v-model="onboarding.handle"
            :label="t('onboarding.handle')"
            :placeholder="t('onboarding.handlePlaceholder')"
            autocomplete="off"
            maxlength="24"
          />
          <p class="sp-hint">
            <Shield :size="15" aria-hidden="true" />
            {{ t('onboarding.accountBound') }}
          </p>
          <SkyButton block large :disabled="onboardingSubmitting" type="submit">
            {{
              onboardingSubmitting
                ? t('onboarding.creating')
                : t('onboarding.create')
            }}
          </SkyButton>
        </form>
      </SkyScrollArea>
    </template>

    <template v-else-if="composerMedia">
      <SkyNavbar
        :back-label="phone.t('Common.back')"
        show-back
        :title="
          t(
            composerPurpose === 'story'
              ? 'composer.storyTitle'
              : 'composer.snapTitle',
          )
        "
        @back="cancelComposer"
      >
        <template #right>
          <SkyButton
            clear
            small
            :disabled="!canPublish"
            @click="publishComposer"
          >
            {{
              publishing
                ? phone.t('Common.loading')
                : t(
                    composerPurpose === 'story'
                      ? 'composer.addStory'
                      : 'composer.send',
                  )
            }}
          </SkyButton>
        </template>
      </SkyNavbar>
      <SkyScrollArea padded class="sp-composer">
        <div class="sp-compose-preview">
          <img
            v-if="composerMedia.mediaType === 'photo'"
            :src="composerMedia.url"
            alt=""
          />
          <video
            v-else
            :src="composerMedia.url"
            autoplay
            loop
            muted
            playsinline
          />
          <strong
            v-if="textOverlay"
            class="sp-compose-preview__text"
            :style="{ color: overlayColor }"
          >
            {{ textOverlay }}
          </strong>
          <span class="sp-compose-preview__duration">
            <Timer :size="14" aria-hidden="true" />
            {{ durationSeconds }}s
          </span>
        </div>

        <SkyButton
          block
          outline
          class="sp-change-media"
          @click="
            beginCapture(
              'photos',
              composerMedia.mediaType,
              composerPurpose,
              selectedRecipientIds,
            )
          "
        >
          <Images :size="17" aria-hidden="true" />
          {{ t('composer.changeMedia') }}
        </SkyButton>

        <div class="sp-form">
          <SkyField
            v-model="caption"
            :label="t('composer.caption')"
            :placeholder="t('composer.captionPlaceholder')"
            :maxlength="MAX_CAPTION_LENGTH"
            type="textarea"
          />
          <SkyField
            v-model="textOverlay"
            :label="t('composer.textOverlay')"
            :placeholder="t('composer.textPlaceholder')"
            :maxlength="MAX_TEXT_OVERLAY_LENGTH"
          />
          <label class="sp-color-row">
            <span>
              <Palette :size="17" aria-hidden="true" />
              {{ t('composer.color') }}
            </span>
            <input
              v-model="overlayColor"
              type="color"
              :aria-label="t('composer.color')"
            />
          </label>
          <label class="sp-range-row">
            <span>
              {{ t('composer.duration') }}
              <b>
                {{
                  t('composer.seconds', {
                    count: String(durationSeconds),
                  })
                }}
              </b>
            </span>
            <SkyRange
              v-model="durationSeconds"
              :aria-label="t('composer.duration')"
              :min="1"
              :max="10"
              :step="1"
            />
          </label>
          <label v-if="composerPurpose === 'snap'" class="sp-toggle-row">
            <span>
              <b>{{ t('composer.replay') }}</b>
              <small>{{ t('composer.replayBody') }}</small>
            </span>
            <SkyToggle
              v-model="allowReplay"
              :aria-label="t('composer.replay')"
            />
          </label>
        </div>

        <section v-if="composerPurpose === 'snap'" class="sp-section">
          <header>
            <span>
              <b>{{ t('composer.recipients') }}</b>
              <small>{{ t('composer.recipientsHint') }}</small>
            </span>
            <SkyBadge v-if="selectedRecipients.length">
              {{
                t('composer.selectedCount', {
                  count: String(selectedRecipients.length),
                })
              }}
            </SkyBadge>
          </header>
          <SkyEmptyState
            v-if="!store.friends.length"
            compact
            :title="t('composer.noFriends')"
          />
          <SkyCheckbox
            v-for="friend in store.friends"
            v-else
            :key="friend.friendshipId"
            class="sp-person-row sp-recipient-row"
            :disabled="recipientSelectionDisabled(friend.profile.id)"
            :model-value="selectedRecipientIds.includes(friend.profile.id)"
            @update:model-value="toggleRecipient(friend.profile.id)"
          >
            <span class="sp-avatar" :style="avatarStyle(friend.profile)">
              <img
                v-if="friend.profile.avatarUrl"
                :src="friend.profile.avatarUrl"
                alt=""
              />
              <template v-else>{{ initials(friend.profile) }}</template>
            </span>
            <span class="sp-person-row__copy">
              <b>{{ friend.profile.displayName }}</b>
              <small>@{{ friend.profile.handle }}</small>
            </span>
          </SkyCheckbox>
        </section>
      </SkyScrollArea>
    </template>

    <template v-else>
      <template v-if="store.activeConversation">
        <SkyNavbar
          :back-label="phone.t('Common.back')"
          show-back
          :subtitle="
            store.activeConversation.streakCount
              ? `🔥 ${store.activeConversation.streakCount}`
              : ''
          "
          :title="store.activeConversation.profile.displayName"
          @back="closeThread"
        >
          <template #right>
            <button
              type="button"
              class="sp-icon-button"
              :aria-label="t('chats.sendSnap')"
              @click="
                beginCapture('camera', 'photo', 'snap', [
                  store.activeConversation.profile.id,
                ])
              "
            >
              <Camera :size="20" aria-hidden="true" />
            </button>
          </template>
        </SkyNavbar>
        <SkyScrollArea class="sp-thread">
          <div v-if="store.threadLoading" class="sp-loading sp-loading--inline">
            <SkySpinner />
          </div>
          <SkyMessages v-else>
            <template v-for="entry in threadTimeline" :key="entry.id">
              <SkyMessage
                v-if="entry.kind === 'message'"
                :type="entry.value.direction === 'sent' ? 'sent' : 'received'"
                :text="entry.value.body"
                :text-footer="relativeTime(entry.value.createdAt)"
              >
                <template #footer>
                  <button type="button" @click="toggleSaved(entry.value)">
                    <Bookmark :size="13" aria-hidden="true" />
                    {{ t(entry.value.savedAt ? 'chats.unsave' : 'chats.save') }}
                  </button>
                  <button type="button" @click="deleteMessage(entry.value)">
                    <Trash2 :size="13" aria-hidden="true" />
                    {{ t('chats.delete') }}
                  </button>
                  <small v-if="entry.value.savedAt">
                    {{ t('chats.saved') }}
                  </small>
                </template>
              </SkyMessage>
              <button
                v-else
                type="button"
                class="sp-thread-snap"
                :class="{
                  'sp-thread-snap--sent': entry.value.direction === 'sent',
                }"
                :disabled="!snapCanOpen(entry.value)"
                @click="openThreadSnap(entry.value)"
              >
                <Video
                  v-if="entry.value.type === 'snap_video'"
                  :size="18"
                  aria-hidden="true"
                />
                <ImageIcon v-else :size="18" aria-hidden="true" />
                <span>
                  <b>{{ snapLabel(entry.value) }}</b>
                  <small>{{ relativeTime(entry.value.createdAt) }}</small>
                </span>
                <RotateCcw
                  v-if="
                    entry.value.openedAt &&
                    entry.value.allowReplay &&
                    !entry.value.replayedAt
                  "
                  :size="16"
                  aria-hidden="true"
                />
              </button>
            </template>
          </SkyMessages>
          <SkyEmptyState
            v-if="!store.threadLoading && !threadTimeline.length"
            :title="t('chats.start')"
          />
        </SkyScrollArea>
        <section
          v-if="threadAttachmentMenuOpen"
          class="sp-thread-attachment-menu"
          :class="{
            'sp-thread-attachment-menu--with-preview':
              pendingThreadMedia.length > 0,
          }"
          :aria-label="t('chats.moreActions')"
        >
          <SkyGlass
            component="button"
            type="button"
            :disabled="
              threadSending ||
              pendingThreadMedia.some((media) => media.mediaType === 'video')
            "
            @click="openThreadMedia('photos', 'photo')"
          >
            <span class="sp-thread-attachment-menu__icon is-photo">
              <Images :size="20" aria-hidden="true" />
            </span>
            {{ t('chats.attachPhoto') }}
          </SkyGlass>
          <SkyGlass
            component="button"
            type="button"
            :disabled="
              threadSending ||
              pendingThreadMedia.some((media) => media.mediaType === 'video')
            "
            @click="openThreadMedia('camera', 'photo')"
          >
            <span class="sp-thread-attachment-menu__icon is-camera">
              <Camera :size="20" aria-hidden="true" />
            </span>
            {{ t('chats.takePhoto') }}
          </SkyGlass>
          <SkyGlass
            component="button"
            type="button"
            :disabled="threadSending"
            @click="openThreadEmojiPicker"
          >
            <span class="sp-thread-attachment-menu__emoji" aria-hidden="true">
              😀
            </span>
            {{ t('chats.emoji') }}
          </SkyGlass>
          <SkyGlass
            component="button"
            type="button"
            :disabled="threadSending || pendingThreadMedia.length > 0"
            @click="openThreadMedia('photos', 'video')"
          >
            <span class="sp-thread-attachment-menu__icon is-video">
              <Video :size="20" aria-hidden="true" />
            </span>
            {{ t('chats.attachVideo') }}
          </SkyGlass>
        </section>

        <FullEmojiPicker
          v-if="threadEmojiOpen"
          @close="threadEmojiOpen = false"
          @pick="appendThreadEmoji"
        />

        <div class="sp-thread-composer">
          <div
            v-if="pendingThreadMedia.length"
            class="sp-thread-media-preview"
            role="list"
            :aria-label="t('chats.attachmentPreview')"
          >
            <article
              v-for="(media, index) in pendingThreadMedia"
              :key="media.id"
              class="sp-thread-media-preview__item"
              role="listitem"
            >
              <img
                v-if="media.mediaType === 'photo' || media.thumbnailUrl"
                :src="media.thumbnailUrl ?? media.url"
                :alt="
                  phone.t(
                    media.mediaType === 'video'
                      ? 'Apps.photos.videoAlt'
                      : 'Apps.photos.photoAlt',
                  )
                "
              />
              <video
                v-else
                :src="media.url"
                :aria-label="phone.t('Apps.photos.videoAlt')"
                muted
                playsinline
                preload="metadata"
              />
              <span class="sp-thread-media-preview__order">
                <button
                  type="button"
                  :disabled="threadSending || index === 0"
                  :aria-label="
                    t('chats.moveAttachmentEarlier', {
                      number: String(index + 1),
                    })
                  "
                  @click="moveThreadMedia(index, -1)"
                >
                  <ChevronLeft :size="13" aria-hidden="true" />
                </button>
                <button
                  type="button"
                  :disabled="
                    threadSending || index === pendingThreadMedia.length - 1
                  "
                  :aria-label="
                    t('chats.moveAttachmentLater', {
                      number: String(index + 1),
                    })
                  "
                  @click="moveThreadMedia(index, 1)"
                >
                  <ChevronRight :size="13" aria-hidden="true" />
                </button>
              </span>
              <button
                type="button"
                class="sp-thread-media-preview__remove"
                :disabled="threadSending"
                :aria-label="
                  t('chats.removeAttachment', {
                    number: String(index + 1),
                  })
                "
                @click="removeThreadMedia(media.id)"
              >
                <X :size="13" aria-hidden="true" />
              </button>
            </article>
          </div>

          <SkyMessagebar
            embedded
            class="sp-thread-messagebar"
            :model-value="chatBody"
            :aria-label="t('chats.threadPlaceholder')"
            :disabled="threadSending"
            :placeholder="
              threadSending
                ? t('chats.sendingAttachments')
                : t('chats.threadPlaceholder')
            "
            @keydown="messageKeydown"
            @update:model-value="updateChatBody"
          >
            <template #left>
              <SkyGlass
                component="button"
                type="button"
                class="sp-thread-plus"
                :class="{
                  'is-active': threadAttachmentMenuOpen || threadEmojiOpen,
                }"
                :disabled="threadSending"
                :aria-label="t('chats.moreActions')"
                @click="toggleThreadAttachmentMenu"
              >
                <Plus :size="23" aria-hidden="true" />
              </SkyGlass>
            </template>
            <template #right>
              <button
                type="button"
                class="sp-send-button"
                :aria-label="phone.t('Common.send')"
                :disabled="!threadComposerHasContent || threadSending"
                @click="submitMessage"
              >
                <SkySpinner v-if="threadSending" :size="16" />
                <Send v-else :size="18" aria-hidden="true" />
              </button>
            </template>
          </SkyMessagebar>
        </div>
      </template>

      <template v-else>
        <section
          v-if="activeTab === 'camera'"
          class="sp-camera-screen"
          aria-labelledby="sp-camera-title"
        >
          <header class="sp-camera-header">
            <span>
              <small>{{ t('camera.eyebrow') }}</small>
              <h1 id="sp-camera-title">{{ t('camera.title') }}</h1>
            </span>
            <button
              type="button"
              class="sp-icon-button sp-icon-button--glass"
              :aria-label="t('profile.title')"
              @click="setTab('friends')"
            >
              <UserRound :size="20" aria-hidden="true" />
            </button>
          </header>

          <div class="sp-camera-preview">
            <div class="sp-camera-preview__glow" aria-hidden="true" />
            <Camera :size="54" aria-hidden="true" />
            <p>{{ t('camera.body') }}</p>
            <small>
              {{
                t(
                  capturePurpose === 'story'
                    ? 'camera.storyHint'
                    : 'camera.snapHint',
                )
              }}
            </small>
          </div>

          <SkySegmented
            strong
            rounded
            :active-index="capturePurpose === 'snap' ? 0 : 1"
            :aria-label="t('camera.title')"
            :item-count="2"
          >
            <SkySegmentedButton
              :active="capturePurpose === 'snap'"
              @click="capturePurpose = 'snap'"
            >
              {{ t('camera.snap') }}
            </SkySegmentedButton>
            <SkySegmentedButton
              :active="capturePurpose === 'story'"
              @click="capturePurpose = 'story'"
            >
              {{ t('camera.story') }}
            </SkySegmentedButton>
          </SkySegmented>

          <SkySegmented
            compact
            strong
            :active-index="captureMediaType === 'photo' ? 0 : 1"
            :aria-label="t('camera.title')"
            :item-count="2"
          >
            <SkySegmentedButton
              :active="captureMediaType === 'photo'"
              @click="captureMediaType = 'photo'"
            >
              <ImageIcon :size="15" aria-hidden="true" />
              {{ t('camera.photo') }}
            </SkySegmentedButton>
            <SkySegmentedButton
              :active="captureMediaType === 'video'"
              @click="captureMediaType = 'video'"
            >
              <Video :size="15" aria-hidden="true" />
              {{ t('camera.video') }}
            </SkySegmentedButton>
          </SkySegmented>

          <div class="sp-camera-actions">
            <button
              type="button"
              class="sp-camera-secondary"
              :aria-label="t('camera.gallery')"
              @click="beginCapture('photos', captureMediaType, capturePurpose)"
            >
              <Images :size="22" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="sp-shutter"
              :aria-label="
                t(
                  captureMediaType === 'photo'
                    ? 'camera.capturePhoto'
                    : 'camera.captureVideo',
                )
              "
              @click="beginCapture('camera', captureMediaType, capturePurpose)"
            >
              <span>
                <Camera
                  v-if="captureMediaType === 'photo'"
                  :size="28"
                  aria-hidden="true"
                />
                <CirclePlay v-else :size="29" aria-hidden="true" />
              </span>
            </button>
            <button
              type="button"
              class="sp-camera-secondary"
              :aria-label="t('friends.title')"
              @click="setTab('friends')"
            >
              <UsersRound :size="22" aria-hidden="true" />
            </button>
          </div>
        </section>

        <template v-else-if="activeTab === 'chats'">
          <SkyNavbar :title="t('chats.title')">
            <template #right>
              <button
                type="button"
                class="sp-icon-button"
                :aria-label="t('chats.sendSnap')"
                @click="beginCapture('camera', 'photo', 'snap', [])"
              >
                <Camera :size="20" aria-hidden="true" />
              </button>
            </template>
          </SkyNavbar>
          <SkyScrollArea with-tabbar class="sp-screen">
            <section class="sp-section">
              <header>
                <span>
                  <b>{{ t('chats.incoming') }}</b>
                  <small v-if="incomingSnaps.length">
                    {{ incomingSnaps.length }}
                  </small>
                </span>
              </header>
              <div v-if="incomingSnaps.length" class="sp-snap-strip">
                <button
                  v-for="snap in incomingSnaps"
                  :key="snap.id"
                  type="button"
                  class="sp-snap-card"
                  :disabled="!snapCanOpen(snap)"
                  @click="openThreadSnap(snap)"
                >
                  <span class="sp-avatar" :style="avatarStyle(snap.sender)">
                    <img
                      v-if="snap.sender.avatarUrl"
                      :src="snap.sender.avatarUrl"
                      alt=""
                    />
                    <template v-else>{{ initials(snap.sender) }}</template>
                  </span>
                  <span>
                    <b>{{ snap.sender.displayName }}</b>
                    <small>{{ snapLabel(snap) }}</small>
                  </span>
                  <RotateCcw
                    v-if="snap.openedAt && snap.allowReplay && !snap.replayedAt"
                    :size="17"
                    aria-hidden="true"
                  />
                  <Video
                    v-else-if="snap.type === 'snap_video'"
                    :size="17"
                    aria-hidden="true"
                  />
                  <ImageIcon v-else :size="17" aria-hidden="true" />
                </button>
              </div>
              <SkyEmptyState v-else compact :title="t('chats.noSnaps')" />
            </section>

            <section class="sp-section">
              <header>
                <b>{{ t('chats.conversations') }}</b>
              </header>
              <button
                v-for="conversation in store.conversations"
                :key="conversation.friendshipId"
                type="button"
                class="sp-person-row sp-conversation-row"
                @click="openThread(conversation.friendshipId)"
              >
                <span
                  class="sp-avatar"
                  :style="avatarStyle(conversation.profile)"
                >
                  <img
                    v-if="conversation.profile.avatarUrl"
                    :src="conversation.profile.avatarUrl"
                    alt=""
                  />
                  <template v-else>
                    {{ initials(conversation.profile) }}
                  </template>
                </span>
                <span class="sp-person-row__copy">
                  <b>
                    {{ conversation.profile.displayName }}
                    <span v-if="conversation.streakCount" class="sp-streak">
                      🔥 {{ conversation.streakCount }}
                    </span>
                  </b>
                  <small>{{ lastItemLabel(conversation) }}</small>
                </span>
                <span class="sp-row-after">
                  <time v-if="conversation.lastItem">
                    {{ relativeTime(conversation.lastItem.createdAt) }}
                  </time>
                  <SkyBadge v-if="conversation.unreadCount" small tone="danger">
                    {{ conversation.unreadCount }}
                  </SkyBadge>
                </span>
              </button>
              <SkyEmptyState
                v-if="!store.conversations.length"
                :title="t('chats.noConversations')"
              />
            </section>
          </SkyScrollArea>
        </template>
        <template v-else-if="activeTab === 'stories'">
          <SkyNavbar :title="t('stories.title')">
            <template #right>
              <button
                type="button"
                class="sp-icon-button"
                :aria-label="t('stories.add')"
                @click="beginCapture('camera', 'photo', 'story', [])"
              >
                <Plus :size="21" aria-hidden="true" />
              </button>
            </template>
          </SkyNavbar>
          <SkyScrollArea with-tabbar class="sp-screen">
            <section class="sp-story-hero">
              <span class="sp-story-hero__icon">
                <CirclePlay :size="24" aria-hidden="true" />
              </span>
              <span>
                <b>{{ t('stories.add') }}</b>
                <small>{{ t('camera.storyHint') }}</small>
              </span>
              <SkyButton
                rounded
                small
                @click="beginCapture('camera', 'photo', 'story', [])"
              >
                <Camera :size="16" aria-hidden="true" />
                {{ t('stories.add') }}
              </SkyButton>
            </section>

            <section v-if="ownStories.length" class="sp-section">
              <header>
                <b>{{ t('stories.yours') }}</b>
              </header>
              <article
                v-for="story in ownStories"
                :key="story.id"
                class="sp-story-row sp-story-row--own"
              >
                <button
                  type="button"
                  :disabled="store.storyViewing"
                  @click="openStory(story.id)"
                >
                  <span
                    class="sp-avatar sp-avatar--story"
                    :style="avatarStyle(story.author)"
                  >
                    <img
                      v-if="story.author.avatarUrl"
                      :src="story.author.avatarUrl"
                      alt=""
                    />
                    <template v-else>{{ initials(story.author) }}</template>
                  </span>
                  <span>
                    <b>{{ t('stories.yours') }}</b>
                    <small>
                      {{
                        t('stories.views', {
                          count: String(story.viewCount),
                        })
                      }}
                      · {{ relativeTime(story.createdAt) }}
                    </small>
                  </span>
                </button>
                <div class="sp-story-row__actions">
                  <button
                    type="button"
                    :aria-label="t('stories.viewers')"
                    @click="showStoryViewers(story)"
                  >
                    <Eye :size="17" aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    :aria-label="t('stories.delete')"
                    @click="deleteStory(story.id)"
                  >
                    <Trash2 :size="17" aria-hidden="true" />
                  </button>
                </div>
              </article>
            </section>

            <section class="sp-section">
              <header>
                <b>{{ t('stories.friends') }}</b>
              </header>
              <button
                v-for="story in communityStories"
                :key="story.id"
                type="button"
                class="sp-story-row"
                :disabled="store.storyViewing"
                @click="openStory(story.id)"
              >
                <span
                  class="sp-avatar sp-avatar--story"
                  :class="{ 'sp-avatar--seen': story.seen }"
                  :style="avatarStyle(story.author)"
                >
                  <img
                    v-if="story.author.avatarUrl"
                    :src="story.author.avatarUrl"
                    alt=""
                  />
                  <template v-else>{{ initials(story.author) }}</template>
                </span>
                <span>
                  <b>{{ story.author.displayName }}</b>
                  <small>
                    {{ t(story.seen ? 'stories.seen' : 'stories.unseen') }}
                    · {{ relativeTime(story.createdAt) }}
                  </small>
                </span>
                <ChevronLeft class="sp-chevron" :size="18" aria-hidden="true" />
              </button>
              <SkyEmptyState
                v-if="!communityStories.length"
                :body="t('stories.emptyBody')"
                :title="t('stories.emptyTitle')"
              >
                <template #icon>
                  <CirclePlay :size="30" aria-hidden="true" />
                </template>
              </SkyEmptyState>
              <SkyButton
                v-if="store.stories.length && store.storiesHasMore"
                block
                clear
                :disabled="store.storiesLoadingMore"
                @click="loadMoreStories"
              >
                {{
                  store.storiesLoadingMore
                    ? phone.t('Common.loading')
                    : phone.t('Common.loadMore')
                }}
              </SkyButton>
            </section>
          </SkyScrollArea>
        </template>
        <template v-else>
          <SkyNavbar :title="t('friends.title')">
            <template #right>
              <button
                type="button"
                class="sp-icon-button"
                :aria-label="t('profile.edit')"
                @click="toggleProfileEditor"
              >
                <Settings :size="20" aria-hidden="true" />
              </button>
            </template>
          </SkyNavbar>
          <SkyScrollArea with-tabbar class="sp-screen">
            <section class="sp-profile-card">
              <span
                class="sp-avatar sp-avatar--profile"
                :style="avatarStyle(store.profile)"
              >
                <img
                  v-if="store.profile.avatarUrl"
                  :src="store.profile.avatarUrl"
                  alt=""
                />
                <template v-else>{{ initials(store.profile) }}</template>
              </span>
              <span class="sp-profile-card__identity">
                <b>{{ store.profile.displayName }}</b>
                <small>@{{ store.profile.handle }}</small>
              </span>
              <button
                type="button"
                class="sp-profile-card__edit"
                @click="toggleProfileEditor"
              >
                {{ t('profile.edit') }}
              </button>
              <div class="sp-profile-stats">
                <span>
                  <b>{{ store.profile.snapScore }}</b>
                  <small>{{ t('profile.score') }}</small>
                </span>
                <span>
                  <b>{{ store.profile.friendCount }}</b>
                  <small>{{ t('profile.friends') }}</small>
                </span>
                <span>
                  <b>
                    {{
                      store.friends.reduce(
                        (best, friend) => Math.max(best, friend.bestStreak),
                        0,
                      )
                    }}
                  </b>
                  <small>{{ t('profile.streaks') }}</small>
                </span>
              </div>
              <p v-if="store.profile.bio">{{ store.profile.bio }}</p>
            </section>

            <form
              v-if="profileEditing"
              class="sp-profile-editor sp-form"
              @submit.prevent="saveProfile"
            >
              <SkyField
                v-model="profileDraft.displayName"
                :label="t('onboarding.displayName')"
                maxlength="40"
              />
              <SkyField
                v-model="profileDraft.handle"
                :label="t('onboarding.handle')"
                maxlength="24"
              />
              <SkyField
                v-model="profileDraft.bio"
                :label="t('profile.bio')"
                :placeholder="t('profile.bioPlaceholder')"
                maxlength="160"
                type="textarea"
              />
              <label class="sp-settings-label">
                <b>{{ t('profile.storyPrivacy') }}</b>
                <SkySegmented
                  strong
                  :active-index="
                    profileDraft.storyPrivacy === 'friends' ? 0 : 1
                  "
                  :aria-label="t('profile.storyPrivacy')"
                  :item-count="2"
                >
                  <SkySegmentedButton
                    :active="profileDraft.storyPrivacy === 'friends'"
                    @click="profileDraft.storyPrivacy = 'friends'"
                  >
                    {{ t('profile.privacyFriends') }}
                  </SkySegmentedButton>
                  <SkySegmentedButton
                    :active="profileDraft.storyPrivacy === 'everyone'"
                    @click="profileDraft.storyPrivacy = 'everyone'"
                  >
                    {{ t('profile.privacyEveryone') }}
                  </SkySegmentedButton>
                </SkySegmented>
              </label>
              <label class="sp-toggle-row">
                <span>
                  <b>{{ t('profile.allowStoryReplies') }}</b>
                  <small>{{ t('profile.allowStoryRepliesBody') }}</small>
                </span>
                <SkyToggle
                  v-model="profileDraft.allowStoryReplies"
                  :aria-label="t('profile.allowStoryReplies')"
                />
              </label>
              <label class="sp-toggle-row">
                <span>
                  <b>{{ t('profile.showInQuickAdd') }}</b>
                  <small>{{ t('profile.showInQuickAddBody') }}</small>
                </span>
                <SkyToggle
                  v-model="profileDraft.showInQuickAdd"
                  :aria-label="t('profile.showInQuickAdd')"
                />
              </label>
              <fieldset class="sp-account-settings">
                <legend>{{ t('profile.account') }}</legend>
                <button type="button" @click="logoutDialogOpen = true">
                  <LogOut :size="18" aria-hidden="true" />
                  <span>{{ t('profile.logout') }}</span>
                </button>
                <button
                  type="button"
                  class="sp-account-settings__danger"
                  @click="deleteAccountDialogOpen = true"
                >
                  <Trash2 :size="18" aria-hidden="true" />
                  <span>{{ t('profile.deleteAccount') }}</span>
                </button>
              </fieldset>
              <div class="sp-editor-actions">
                <SkyButton
                  outline
                  type="button"
                  @click="profileEditing = false"
                >
                  {{ t('profile.cancel') }}
                </SkyButton>
                <SkyButton :disabled="profileSaving" type="submit">
                  {{ t('profile.save') }}
                </SkyButton>
              </div>
            </form>

            <section v-if="store.incomingRequests.length" class="sp-section">
              <header>
                <b>{{ t('friends.requests') }}</b>
                <SkyBadge tone="danger">
                  {{ store.incomingRequests.length }}
                </SkyBadge>
              </header>
              <article
                v-for="request in store.incomingRequests"
                :key="request.friendshipId"
                class="sp-person-row"
                :class="{
                  'sp-person-row--highlighted':
                    highlightedProfileId === request.profile.id,
                }"
              >
                <span class="sp-avatar" :style="avatarStyle(request.profile)">
                  <img
                    v-if="request.profile.avatarUrl"
                    :src="request.profile.avatarUrl"
                    alt=""
                  />
                  <template v-else>{{ initials(request.profile) }}</template>
                </span>
                <span class="sp-person-row__copy">
                  <b>{{ request.profile.displayName }}</b>
                  <small>@{{ request.profile.handle }}</small>
                </span>
                <span class="sp-request-actions">
                  <button
                    type="button"
                    :aria-label="t('friends.decline')"
                    @click="respondFriend(request.friendshipId, false)"
                  >
                    <X :size="17" aria-hidden="true" />
                  </button>
                  <button
                    type="button"
                    class="sp-request-actions__accept"
                    :aria-label="t('friends.accept')"
                    @click="respondFriend(request.friendshipId, true)"
                  >
                    <Check :size="17" aria-hidden="true" />
                  </button>
                </span>
              </article>
            </section>

            <section v-if="store.outgoingRequests.length" class="sp-section">
              <header>
                <b>{{ t('friends.sentRequests') }}</b>
                <small>{{ store.outgoingRequests.length }}</small>
              </header>
              <article
                v-for="request in store.outgoingRequests"
                :key="request.friendshipId"
                class="sp-person-row"
              >
                <span class="sp-avatar" :style="avatarStyle(request.profile)">
                  <img
                    v-if="request.profile.avatarUrl"
                    :src="request.profile.avatarUrl"
                    alt=""
                  />
                  <template v-else>{{ initials(request.profile) }}</template>
                </span>
                <span class="sp-person-row__copy">
                  <b>{{ request.profile.displayName }}</b>
                  <small>@{{ request.profile.handle }}</small>
                </span>
                <span class="sp-request-actions">
                  <button
                    type="button"
                    :aria-label="t('friends.cancelRequest')"
                    @click="cancelFriendRequest(request)"
                  >
                    <X :size="17" aria-hidden="true" />
                  </button>
                </span>
              </article>
            </section>

            <section v-if="store.blockedProfiles.length" class="sp-section">
              <header>
                <b>{{ t('friends.blockedProfiles') }}</b>
                <small>{{ store.blockedProfiles.length }}</small>
              </header>
              <article
                v-for="person in store.blockedProfiles"
                :key="person.id"
                class="sp-person-row"
              >
                <span class="sp-avatar" :style="avatarStyle(person)">
                  <img v-if="person.avatarUrl" :src="person.avatarUrl" alt="" />
                  <template v-else>{{ initials(person) }}</template>
                </span>
                <span class="sp-person-row__copy">
                  <b>{{ person.displayName }}</b>
                  <small>@{{ person.handle }}</small>
                </span>
                <SkyButton rounded small @click="unblockProfile(person)">
                  {{ t('friends.unblock') }}
                </SkyButton>
              </article>
            </section>

            <section class="sp-section sp-discovery">
              <header>
                <b>
                  {{
                    searchQuery
                      ? t('friends.searchResults')
                      : t('friends.quickAdd')
                  }}
                </b>
              </header>
              <SkySearchbar
                :model-value="searchQuery"
                :clear-label="phone.t('Common.clear')"
                :placeholder="t('friends.searchPlaceholder')"
                @update:model-value="updateSearchQuery"
              >
                <template #icon>
                  <Search :size="17" aria-hidden="true" />
                </template>
              </SkySearchbar>
              <div
                v-if="store.searchLoading"
                class="sp-loading sp-loading--inline"
              >
                <SkySpinner />
              </div>
              <template
                v-for="person in searchQuery
                  ? store.searchResults
                  : store.suggestions"
                v-else
                :key="person.id"
              >
                <article
                  class="sp-person-row"
                  :class="{
                    'sp-person-row--highlighted':
                      highlightedProfileId === person.id,
                  }"
                >
                  <span class="sp-avatar" :style="avatarStyle(person)">
                    <img
                      v-if="person.avatarUrl"
                      :src="person.avatarUrl"
                      alt=""
                    />
                    <template v-else>{{ initials(person) }}</template>
                  </span>
                  <span class="sp-person-row__copy">
                    <b>{{ person.displayName }}</b>
                    <small>
                      @{{ person.handle }} ·
                      {{
                        t('friends.score', {
                          count: String(person.snapScore),
                        })
                      }}
                    </small>
                  </span>
                  <SkyButton
                    rounded
                    small
                    :disabled="person.friendshipStatus === 'outgoing'"
                    @click="profileAction(person)"
                  >
                    {{ profileRelationLabel(person) }}
                  </SkyButton>
                </article>
              </template>
            </section>

            <section class="sp-section">
              <header>
                <b>{{ t('friends.all') }}</b>
                <small>{{ store.friends.length }}</small>
              </header>
              <article
                v-for="friend in store.friends"
                :key="friend.friendshipId"
                class="sp-friend-card"
                :class="{
                  'sp-person-row--highlighted':
                    highlightedProfileId === friend.profile.id,
                }"
              >
                <div class="sp-person-row">
                  <span class="sp-avatar" :style="avatarStyle(friend.profile)">
                    <img
                      v-if="friend.profile.avatarUrl"
                      :src="friend.profile.avatarUrl"
                      alt=""
                    />
                    <template v-else>{{ initials(friend.profile) }}</template>
                  </span>
                  <span class="sp-person-row__copy">
                    <b>{{ friend.profile.displayName }}</b>
                    <small>
                      @{{ friend.profile.handle }}
                      <template v-if="friend.streakCount">
                        · 🔥 {{ friend.streakCount }}
                      </template>
                    </small>
                  </span>
                </div>
                <div class="sp-friend-actions">
                  <button
                    type="button"
                    @click="openThread(friend.friendshipId)"
                  >
                    <MessageCircle :size="17" aria-hidden="true" />
                    {{ t('friends.chat') }}
                  </button>
                  <button
                    type="button"
                    @click="
                      beginCapture('camera', 'photo', 'snap', [
                        friend.profile.id,
                      ])
                    "
                  >
                    <Camera :size="17" aria-hidden="true" />
                    {{ t('friends.sendSnap') }}
                  </button>
                  <button type="button" @click="removeFriend(friend)">
                    <X :size="17" aria-hidden="true" />
                    {{ t('friends.remove') }}
                  </button>
                  <button type="button" @click="blockProfile(friend.profile)">
                    <Shield :size="17" aria-hidden="true" />
                    {{ t('friends.block') }}
                  </button>
                </div>
              </article>
              <SkyEmptyState
                v-if="!store.friends.length"
                :title="t('friends.empty')"
              >
                <template #icon>
                  <UsersRound :size="30" aria-hidden="true" />
                </template>
              </SkyEmptyState>
            </section>
          </SkyScrollArea>
        </template>
        <SkyTabBar :aria-label="t('navigation')">
          <SkyTabButton
            class="sp-tab sp-tab--camera"
            :active="activeTab === 'camera'"
            :aria-label="t('tabs.camera')"
            :label="t('tabs.camera')"
            @click="setTab('camera')"
          >
            <template #icon>
              <Camera aria-hidden="true" />
            </template>
          </SkyTabButton>
          <SkyTabButton
            class="sp-tab sp-tab--monochrome"
            :active="activeTab === 'chats'"
            :aria-label="t('tabs.chats')"
            :label="t('tabs.chats')"
            @click="setTab('chats')"
          >
            <template #icon>
              <span class="sp-tab-icon">
                <MessageCircle aria-hidden="true" />
                <SkyBadge
                  v-if="store.unreadCount"
                  small
                  tone="danger"
                  class="sp-tab-badge"
                >
                  {{ store.unreadCount > 99 ? '99+' : store.unreadCount }}
                </SkyBadge>
              </span>
            </template>
          </SkyTabButton>
          <SkyTabButton
            class="sp-tab sp-tab--monochrome"
            :active="activeTab === 'stories'"
            :aria-label="t('tabs.stories')"
            :label="t('tabs.stories')"
            @click="setTab('stories')"
          >
            <template #icon>
              <CirclePlay aria-hidden="true" />
            </template>
          </SkyTabButton>
          <SkyTabButton
            class="sp-tab sp-tab--monochrome"
            :active="activeTab === 'friends'"
            :aria-label="t('tabs.friends')"
            :label="t('tabs.friends')"
            @click="setTab('friends')"
          >
            <template #icon>
              <span class="sp-tab-icon">
                <UsersRound aria-hidden="true" />
                <SkyBadge
                  v-if="store.incomingRequests.length"
                  small
                  tone="danger"
                  class="sp-tab-badge"
                >
                  {{ store.incomingRequests.length }}
                </SkyBadge>
              </span>
            </template>
          </SkyTabButton>
        </SkyTabBar>
      </template>
    </template>

    <div
      v-if="store.openedSnap"
      class="sp-media-viewer"
      role="dialog"
      aria-modal="true"
      :aria-label="t('viewer.snap')"
    >
      <div class="sp-viewer-progress" aria-hidden="true">
        <span :style="{ width: `${snapProgress}%` }" />
      </div>
      <div
        v-if="mediaLoading && activeViewerKind === 'snap'"
        class="sp-viewer-loading"
        aria-live="polite"
      >
        <SkySpinner />
      </div>
      <header>
        <small>
          {{
            t('viewer.timeLeft', {
              count: String(Math.ceil(snapRemaining)),
            })
          }}
        </small>
        <button
          type="button"
          class="sp-icon-button sp-icon-button--glass"
          :aria-label="t('viewer.close')"
          @click="closeSnapViewer"
        >
          <X :size="20" aria-hidden="true" />
        </button>
      </header>
      <img
        v-if="store.openedSnap.mediaType === 'photo'"
        :src="store.openedSnap.url"
        alt=""
        @error="handleViewerMediaError('snap')"
        @load="handleViewerMediaReady('snap')"
      />
      <video
        v-else
        :src="store.openedSnap.url"
        autoplay
        playsinline
        @canplay="handleViewerVideoCanPlay('snap', $event)"
        @error="handleViewerMediaError('snap')"
        @playing="handleViewerMediaReady('snap')"
      />
      <strong
        v-if="store.openedSnap.textOverlay"
        class="sp-media-viewer__overlay"
        :style="{ color: store.openedSnap.overlayColor }"
      >
        {{ store.openedSnap.textOverlay }}
      </strong>
      <p v-if="store.openedSnap.caption" class="sp-media-viewer__caption">
        {{ store.openedSnap.caption }}
      </p>
    </div>

    <div
      v-if="store.viewedStory"
      class="sp-media-viewer"
      role="dialog"
      aria-modal="true"
      :aria-label="t('viewer.story')"
    >
      <div class="sp-viewer-progress" aria-hidden="true">
        <span :style="{ width: `${storyProgress}%` }" />
      </div>
      <div
        v-if="mediaLoading && activeViewerKind === 'story'"
        class="sp-viewer-loading"
        aria-live="polite"
      >
        <SkySpinner />
      </div>
      <header>
        <span class="sp-viewer-author">
          <span
            class="sp-avatar sp-avatar--small"
            :style="avatarStyle(store.viewedStory.author)"
          >
            <img
              v-if="store.viewedStory.author.avatarUrl"
              :src="store.viewedStory.author.avatarUrl"
              alt=""
            />
            <template v-else>
              {{ initials(store.viewedStory.author) }}
            </template>
          </span>
          <span>
            <b>{{ store.viewedStory.author.displayName }}</b>
            <small>
              {{
                t('viewer.timeLeft', {
                  count: String(Math.ceil(storyRemaining)),
                })
              }}
            </small>
          </span>
        </span>
        <button
          type="button"
          class="sp-icon-button sp-icon-button--glass"
          :aria-label="t('viewer.close')"
          @click="closeStoryViewer"
        >
          <X :size="20" aria-hidden="true" />
        </button>
      </header>
      <img
        v-if="store.viewedStory.mediaType === 'photo'"
        :src="store.viewedStory.url"
        alt=""
        @error="handleViewerMediaError('story')"
        @load="handleViewerMediaReady('story')"
      />
      <video
        v-else
        :src="store.viewedStory.url"
        autoplay
        playsinline
        @canplay="handleViewerVideoCanPlay('story', $event)"
        @error="handleViewerMediaError('story')"
        @playing="handleViewerMediaReady('story')"
      />
      <strong
        v-if="store.viewedStory.textOverlay"
        class="sp-media-viewer__overlay"
        :style="{ color: store.viewedStory.overlayColor }"
      >
        {{ store.viewedStory.textOverlay }}
      </strong>
      <p
        v-if="store.viewedStory.caption"
        class="sp-media-viewer__caption"
        :class="{
          'sp-media-viewer__caption--with-reply':
            store.viewedStory.canReply && viewedStoryFriendshipId,
        }"
      >
        {{ store.viewedStory.caption }}
      </p>
      <SkyMessagebar
        v-if="
          store.viewedStory.canReply &&
          viewedStoryFriendshipId &&
          !viewedStorySummary?.isOwner
        "
        :model-value="storyReply"
        embedded
        class="sp-story-reply"
        :aria-label="t('stories.replyPlaceholder')"
        :placeholder="t('stories.replyPlaceholder')"
        @blur="resumeStoryCountdown"
        @focus="pauseStoryCountdown"
        @keydown="storyReplyKeydown"
        @update:model-value="updateStoryReply"
      >
        <template #right>
          <button
            type="button"
            class="sp-send-button"
            :aria-label="phone.t('Common.send')"
            :disabled="!storyReply.trim()"
            @click="submitStoryReply"
          >
            <Send :size="18" aria-hidden="true" />
          </button>
        </template>
      </SkyMessagebar>
      <footer
        v-if="viewedStorySummary?.isOwner"
        class="sp-media-viewer__owner-actions"
      >
        <button type="button" @click="showStoryViewers(viewedStorySummary)">
          <Eye :size="18" aria-hidden="true" />
          {{ t('stories.viewers') }}
        </button>
        <button type="button" @click="deleteStory(viewedStorySummary.id)">
          <Trash2 :size="18" aria-hidden="true" />
          {{ t('stories.delete') }}
        </button>
      </footer>
    </div>
    <SkySheet
      :opened="storyViewerSheetOpen"
      :aria-label="t('stories.viewers')"
      swipe-to-close
      @backdropclick="closeStoryViewerSheet"
      @escape="closeStoryViewerSheet"
      @swipeclose="closeStoryViewerSheet"
    >
      <section class="sp-viewers-sheet">
        <header>
          <b>{{ t('stories.viewers') }}</b>
          <button
            type="button"
            class="sp-icon-button"
            :aria-label="phone.t('Common.close')"
            @click="closeStoryViewerSheet"
          >
            <X :size="19" aria-hidden="true" />
          </button>
        </header>
        <div class="sp-viewers-sheet__scroll">
          <article
            v-for="viewer in store.storyViewers"
            :key="viewer.id"
            class="sp-person-row"
          >
            <span class="sp-avatar" :style="avatarStyle(viewer)">
              <img v-if="viewer.avatarUrl" :src="viewer.avatarUrl" alt="" />
              <template v-else>{{ initials(viewer) }}</template>
            </span>
            <span class="sp-person-row__copy">
              <b>{{ viewer.displayName }}</b>
              <small>
                @{{ viewer.handle }} · {{ relativeTime(viewer.viewedAt) }}
              </small>
            </span>
          </article>
          <SkyEmptyState
            v-if="!store.storyViewers.length"
            :title="t('stories.noViewers')"
          />
          <SkyButton
            v-if="store.storyViewers.length && store.storyViewersHasMore"
            block
            clear
            :disabled="store.storyViewersLoadingMore"
            @click="loadMoreStoryViewers"
          >
            {{
              store.storyViewersLoadingMore
                ? phone.t('Common.loading')
                : phone.t('Common.loadMore')
            }}
          </SkyButton>
        </div>
      </section>
    </SkySheet>

    <AccountLogoutDialog
      v-model:opened="logoutDialogOpen"
      app-id="skypic"
      :app-name="t('name')"
      @logged-out="handleLoggedOut"
    />

    <SkyDialog
      :opened="deleteAccountDialogOpen"
      @backdropclick="
        !accountActionPending && (deleteAccountDialogOpen = false)
      "
    >
      <template #title>{{ t('profile.deleteAccountTitle') }}</template>
      <p>{{ t('profile.deleteAccountBody') }}</p>
      <template #buttons>
        <SkyDialogButton
          :disabled="accountActionPending"
          @click="deleteAccountDialogOpen = false"
        >
          {{ phone.t('Common.cancel') }}
        </SkyDialogButton>
        <SkyDialogButton
          strong
          class="sp-delete-account-confirm"
          :disabled="accountActionPending"
          @click="deleteSkyPicAccount"
        >
          {{
            t(
              accountActionPending
                ? 'profile.deletingAccount'
                : 'profile.deleteAccount',
            )
          }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <SkyNotification
      :opened="Boolean(feedback)"
      :text="feedback"
      :title="t('name')"
      @close="feedback = ''"
    />
  </SkyAppPage>
</template>

<style scoped>
.skypic-app {
  --sp-accent: #5a6cff;
  --sp-accent-strong: #4254f2;
  --sp-camera-blue: #0a84ff;
  --sp-camera-blue-strong: #0067d8;
  --sp-pink: #ff5bbd;
  position: relative;
  display: flex;
  overflow: hidden;
  flex-direction: column;
}

.skypic-app--player-light {
  --sp-tab-monochrome: #000000;
}

.skypic-app--player-dark {
  --sp-tab-monochrome: #ffffff;
}

.sp-auth {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: calc(var(--sky-safe-area-top) + var(--sky-space-3))
    var(--sky-page-gutter)
    calc(var(--sky-safe-area-bottom) + var(--sky-space-5));
}

.sp-auth__hint {
  max-width: 290px;
  margin: 0 auto;
  color: var(--sky-muted);
  font-size: 12px;
  line-height: 1.45;
  text-align: center;
}

.sp-auth :deep(.app-profile-auth) {
  --auth-accent: #0a84ff;
}

.sp-loading {
  display: grid;
  flex: 1;
  place-items: center;
}

.sp-loading--inline {
  min-height: 104px;
}

.sp-screen,
.sp-composer,
.sp-onboarding {
  flex: 1;
  min-height: 0;
}

.sp-screen {
  padding: var(--sky-space-3) var(--sky-page-gutter);
}

.sp-form {
  display: grid;
  gap: var(--sky-space-4);
}

.sp-onboarding {
  padding-top: var(--sky-space-5);
}

.sp-onboarding__hero {
  display: grid;
  justify-items: center;
  margin-bottom: var(--sky-space-6);
  text-align: center;
}

.sp-onboarding__hero small {
  margin-top: var(--sky-space-3);
  color: var(--sky-app-accent);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.sp-onboarding__hero h2 {
  margin: var(--sky-space-2) 0 0;
  font-size: 25px;
  line-height: 1.08;
}

.sp-onboarding__hero p {
  max-width: 290px;
  margin: var(--sky-space-3) 0 0;
  color: var(--sky-muted);
  font-size: 13px;
  line-height: 1.5;
}

.sp-hint {
  display: flex;
  align-items: flex-start;
  gap: var(--sky-space-2);
  margin: 0;
  color: var(--sky-muted);
  font-size: 12px;
  line-height: 1.45;
}

.sp-hint svg {
  flex: 0 0 auto;
  margin-top: 1px;
  color: var(--sky-app-accent);
}

.sp-avatar {
  display: inline-grid;
  overflow: hidden;
  width: 46px;
  height: 46px;
  flex: 0 0 auto;
  place-items: center;
  border: 2px solid rgba(255, 255, 255, 0.72);
  border-radius: 50%;
  color: white;
  font-size: 13px;
  font-weight: 800;
  letter-spacing: 0.03em;
  box-shadow: 0 4px 14px rgba(30, 42, 92, 0.16);
}

.sp-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.sp-avatar--large {
  width: 78px;
  height: 78px;
}

.sp-avatar--profile {
  width: 68px;
  height: 68px;
  font-size: 19px;
}

.sp-avatar--story {
  width: 52px;
  height: 52px;
  border: 3px solid var(--sp-pink);
  outline: 2px solid var(--sky-surface);
}

.sp-avatar--seen {
  border-color: var(--sky-subtle);
}

.sp-avatar--small {
  width: 36px;
  height: 36px;
  font-size: 10px;
}

.sp-icon-button,
.sp-send-button,
.sp-request-actions button,
.sp-story-row__actions button {
  display: inline-grid;
  width: var(--sky-touch-target);
  min-width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  padding: 0;
  place-items: center;
  border: 0;
  border-radius: 50%;
  background: var(--sky-surface-variant);
  color: var(--sky-text);
}

.sp-icon-button--glass {
  border: 1px solid rgba(255, 255, 255, 0.22);
  background: rgba(20, 24, 42, 0.52);
  color: white;
  backdrop-filter: blur(14px);
}

.sp-section {
  overflow: hidden;
  margin-bottom: var(--sky-space-4);
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}

.sp-section > header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 48px;
  padding: 0 var(--sky-space-4);
  border-bottom: 1px solid var(--sky-hairline);
}

.sp-section > header > span {
  display: grid;
  gap: 1px;
}

.sp-section > header small {
  color: var(--sky-muted);
  font-size: 11px;
}

.sp-person-row {
  display: flex;
  align-items: center;
  gap: var(--sky-space-3);
  width: 100%;
  min-height: 66px;
  padding: 9px var(--sky-space-4);
  border: 0;
  border-bottom: 1px solid var(--sky-hairline);
  background: transparent;
  color: var(--sky-text);
  text-align: left;
}

.sp-person-row:last-child {
  border-bottom: 0;
}

.sp-recipient-row {
  cursor: pointer;
}

.sp-recipient-row :deep(.sky-checkbox__label) {
  display: contents;
}

.sp-recipient-row :deep(.sky-checkbox__mark) {
  order: 3;
  margin-left: auto;
}

.sp-person-row--highlighted {
  background: var(--sky-app-accent-soft);
}

.sp-person-row__copy {
  display: grid;
  flex: 1;
  min-width: 0;
  gap: 2px;
}

.sp-person-row__copy b,
.sp-person-row__copy small {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sp-person-row__copy small {
  color: var(--sky-muted);
  font-size: 11px;
}

button:focus-visible,
input:focus-visible {
  outline: 3px solid var(--sky-app-accent);
  outline-offset: 2px;
}

.sp-composer {
  padding-top: var(--sky-space-3);
}

.sp-compose-preview {
  position: relative;
  overflow: hidden;
  aspect-ratio: 3 / 4;
  border-radius: var(--sky-radius-card);
  background: #111526;
  box-shadow: 0 18px 44px rgba(9, 14, 38, 0.24);
}

.sp-compose-preview > img,
.sp-compose-preview > video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.sp-compose-preview__text {
  position: absolute;
  top: 50%;
  right: var(--sky-space-4);
  left: var(--sky-space-4);
  padding: 8px 10px;
  transform: translateY(-50%);
  border-radius: var(--sky-radius-control);
  background: rgba(0, 0, 0, 0.32);
  font-size: 20px;
  line-height: 1.2;
  text-align: center;
  overflow-wrap: anywhere;
  text-shadow: 0 2px 6px rgba(0, 0, 0, 0.72);
}

.sp-compose-preview__duration {
  position: absolute;
  right: 10px;
  bottom: 10px;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 6px 9px;
  border-radius: var(--sky-radius-pill);
  background: rgba(0, 0, 0, 0.62);
  color: white;
  font-size: 11px;
  font-weight: 750;
}

.sp-change-media {
  margin: var(--sky-space-3) 0 var(--sky-space-5);
}

.sp-change-media :deep(svg),
.sp-story-hero :deep(svg) {
  margin-right: 5px;
}

.sp-color-row,
.sp-range-row,
.sp-toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sky-space-4);
  min-height: 58px;
  padding: 10px 13px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface);
}

.sp-color-row > span {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  font-weight: 700;
}

.sp-color-row input {
  width: 44px;
  height: 44px;
  padding: 4px;
  border: 0;
  border-radius: 50%;
  background: transparent;
}

.sp-range-row {
  display: grid;
}

.sp-range-row > span {
  display: flex;
  justify-content: space-between;
}

.sp-range-row b {
  color: var(--sky-app-accent);
}

.sp-toggle-row > span {
  display: grid;
  gap: 2px;
}

.sp-toggle-row small {
  color: var(--sky-muted);
  font-size: 11px;
  line-height: 1.35;
}

.sp-composer > .sp-section {
  margin-top: var(--sky-space-5);
}

.sp-camera-screen {
  --sky-app-accent: var(--sp-camera-blue);
  --sky-app-accent-soft: rgba(10, 132, 255, 0.2);
  display: flex;
  flex: 1;
  min-height: 0;
  padding: calc(var(--sky-safe-area-top) + 8px) var(--sky-page-gutter)
    calc(var(--sky-safe-area-bottom) + 82px);
  flex-direction: column;
  gap: var(--sky-space-3);
  background:
    radial-gradient(
      circle at 12% 14%,
      rgba(37, 149, 255, 0.44),
      transparent 38%
    ),
    radial-gradient(
      circle at 88% 58%,
      rgba(10, 132, 255, 0.24),
      transparent 36%
    ),
    linear-gradient(165deg, #07172d 0%, #0b2444 50%, #061326 100%);
  color: white;
}

.sp-camera-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 48px;
}

.sp-camera-header > span {
  display: grid;
}

.sp-camera-header small {
  color: rgba(255, 255, 255, 0.62);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.sp-camera-header h1 {
  margin: 2px 0 0;
  font-size: 24px;
  line-height: 1;
}

.sp-camera-preview {
  position: relative;
  display: grid;
  overflow: hidden;
  min-height: 0;
  flex: 1;
  place-content: center;
  justify-items: center;
  padding: var(--sky-space-5);
  border: 1px solid rgba(255, 255, 255, 0.16);
  border-radius: 28px;
  background: rgba(255, 255, 255, 0.07);
  text-align: center;
  backdrop-filter: blur(18px);
}

.sp-camera-preview__glow {
  position: absolute;
  width: 180px;
  height: 180px;
  border-radius: 50%;
  background: rgba(10, 132, 255, 0.38);
  filter: blur(40px);
}

.sp-camera-preview > svg,
.sp-camera-preview > p,
.sp-camera-preview > small {
  position: relative;
}

.sp-camera-preview > svg {
  margin-bottom: var(--sky-space-4);
  color: #55b4ff;
  filter: drop-shadow(0 7px 18px rgba(10, 132, 255, 0.42));
}

.sp-camera-preview p {
  max-width: 250px;
  margin: 0;
  font-size: 15px;
  font-weight: 700;
  line-height: 1.4;
}

.sp-camera-preview small {
  max-width: 250px;
  margin-top: var(--sky-space-2);
  color: rgba(255, 255, 255, 0.64);
  font-size: 11px;
  line-height: 1.4;
}

.sp-camera-screen :deep(.sky-segmented) {
  flex: 0 0 auto;
}

.sp-camera-actions {
  display: grid;
  align-items: center;
  grid-template-columns: 1fr auto 1fr;
  gap: var(--sky-space-4);
}

.sp-camera-secondary,
.sp-shutter {
  display: grid;
  padding: 0;
  place-items: center;
  border: 0;
  border-radius: 50%;
  color: white;
}

.sp-camera-secondary {
  width: 48px;
  height: 48px;
  justify-self: center;
  border: 1px solid rgba(255, 255, 255, 0.16);
  background: rgba(255, 255, 255, 0.1);
}

.sp-shutter {
  width: 72px;
  height: 72px;
  border: 3px solid white;
  background: rgba(255, 255, 255, 0.18);
}

.sp-shutter > span {
  display: grid;
  width: 58px;
  height: 58px;
  place-items: center;
  border-radius: 50%;
  background: linear-gradient(
    145deg,
    var(--sp-camera-blue),
    var(--sp-camera-blue-strong)
  );
}

.sp-snap-strip {
  display: grid;
  gap: var(--sky-space-2);
  padding: var(--sky-space-3);
}

.sp-snap-card {
  display: grid;
  align-items: center;
  min-height: 66px;
  padding: 8px 10px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-control);
  background: linear-gradient(
    135deg,
    var(--sky-surface),
    var(--sky-surface-muted)
  );
  color: var(--sky-text);
  grid-template-columns: auto 1fr auto;
  gap: var(--sky-space-3);
  text-align: left;
}

.sp-snap-card > span:nth-child(2) {
  display: grid;
  min-width: 0;
}

.sp-snap-card small {
  color: var(--sky-muted);
  font-size: 11px;
}

.sp-snap-card:not(:disabled) > svg {
  color: var(--sp-pink);
}

.sp-snap-card:disabled {
  opacity: 0.58;
}

.sp-conversation-row {
  padding-block: 10px;
}

.sp-streak {
  color: #f36f32;
  font-size: 11px;
}

.sp-row-after {
  display: grid;
  justify-items: end;
  gap: 5px;
}

.sp-row-after time {
  color: var(--sky-subtle);
  font-size: 9px;
}

.sp-thread {
  flex: 1;
  min-height: 0;
  padding: var(--sky-space-4) var(--sky-page-gutter) 12px;
}

.sp-thread :deep(.sky-messages) {
  display: grid;
  gap: 8px;
}

.sp-thread :deep(.sky-message__footer) {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-top: 3px;
}

.sp-thread :deep(.sky-message__footer button) {
  display: inline-flex;
  align-items: center;
  min-height: 30px;
  padding: 2px 5px;
  gap: 3px;
  border: 0;
  background: transparent;
  color: inherit;
  font-size: 10px;
  opacity: 0.72;
}

.sp-thread-snap {
  display: flex;
  align-items: center;
  gap: 8px;
  width: min(78%, 260px);
  min-height: 58px;
  padding: 8px 11px;
  border: 1px solid rgba(255, 91, 189, 0.34);
  border-radius: 18px 18px 18px 6px;
  background: rgba(255, 91, 189, 0.12);
  color: var(--sky-text);
  text-align: left;
}

.sp-thread-snap--sent {
  justify-self: end;
  border-color: rgba(90, 108, 255, 0.34);
  border-radius: 18px 18px 6px 18px;
  background: var(--sky-app-accent-soft);
}

.sp-thread-snap > span {
  display: grid;
  flex: 1;
  gap: 1px;
}

.sp-thread-snap small {
  color: var(--sky-muted);
  font-size: 10px;
}

.sp-thread-snap:disabled {
  opacity: 0.58;
}

.sp-thread-attachment-menu {
  position: absolute;
  z-index: 46;
  bottom: calc(var(--sky-safe-area-bottom) + 68px);
  left: var(--sky-page-gutter);
  display: grid;
  justify-items: start;
  gap: 8px;
}

.sp-thread-attachment-menu--with-preview {
  bottom: calc(var(--sky-safe-area-bottom) + 188px);
}

.sp-thread-attachment-menu :deep(.sky-glass) {
  width: auto;
  min-width: 154px;
  min-height: 48px;
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 9px;
  padding: 5px 14px 5px 7px;
  border-radius: var(--sky-radius-pill);
  background: color-mix(in srgb, var(--sky-glass-solid) 88%, transparent);
  color: var(--sky-text);
  font-size: 13px;
  font-weight: 750;
  backdrop-filter: blur(22px) saturate(1.25);
}

.sp-thread-attachment-menu__icon,
.sp-thread-attachment-menu__emoji {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  border-radius: 50%;
  background: var(--sky-surface);
}

.sp-thread-attachment-menu__icon.is-photo {
  color: #0a84ff;
}

.sp-thread-attachment-menu__icon.is-camera {
  color: #30c76c;
}

.sp-thread-attachment-menu__icon.is-video {
  color: #0a84ff;
}

.sp-thread-attachment-menu__emoji {
  font-size: 21px;
}

.sp-thread-composer {
  position: relative;
  z-index: 42;
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  gap: var(--sky-space-2);
  padding: 6px var(--sky-page-gutter) calc(var(--sky-safe-area-bottom) + 6px);
  border-top: 1px solid var(--sky-hairline);
  background: var(--sky-bg);
}

.sp-thread-media-preview {
  display: flex;
  gap: var(--sky-space-2);
  overflow-x: auto;
  padding: 4px 3px 2px;
  scrollbar-width: none;
}

.sp-thread-media-preview::-webkit-scrollbar {
  display: none;
}

.sp-thread-media-preview__item {
  position: relative;
  width: 104px;
  height: 104px;
  flex: 0 0 104px;
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface-muted);
}

.sp-thread-media-preview__item > img,
.sp-thread-media-preview__item > video {
  width: 100%;
  height: 100%;
  display: block;
  overflow: hidden;
  border-radius: inherit;
  object-fit: cover;
}

.sp-thread-media-preview__remove,
.sp-thread-media-preview__order button {
  display: grid;
  place-items: center;
  border: 1px solid var(--sky-bg);
  border-radius: 50%;
  background: var(--sky-text);
  color: var(--sky-bg);
}

.sp-thread-media-preview__remove {
  position: absolute;
  top: -4px;
  right: -4px;
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
}

.sp-thread-media-preview__order {
  position: absolute;
  right: 4px;
  bottom: 4px;
  left: 4px;
  display: flex;
  justify-content: space-between;
}

.sp-thread-media-preview__order button {
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  border-color: rgba(255, 255, 255, 0.52);
  background: rgba(0, 0, 0, 0.64);
  color: #fff;
  backdrop-filter: blur(8px);
}

.sp-thread-media-preview__order button:disabled {
  visibility: hidden;
}

.sp-thread-messagebar {
  min-width: 0;
  padding: 0;
  background: transparent;
}

.sp-thread-messagebar :deep(.sky-toolbar__inner) {
  gap: var(--sky-space-2);
}

.sp-thread-messagebar :deep(.sky-messagebar__area) {
  min-height: 48px;
  border-radius: var(--sky-radius-pill);
}

.sp-thread-plus {
  width: 46px;
  height: 46px;
  display: grid;
  padding: 0;
  place-items: center;
  border-radius: 50%;
  color: var(--sky-text);
  transition: transform var(--sky-transition-normal) ease;
}

.sp-thread-plus.is-active {
  color: #0a84ff;
  transform: rotate(45deg);
}

.sp-send-button {
  background: var(--sky-app-accent);
  color: white;
}

.sp-send-button:disabled {
  opacity: 0.42;
}

.sp-story-hero {
  display: grid;
  align-items: center;
  margin-bottom: var(--sky-space-4);
  padding: var(--sky-space-4);
  border-radius: var(--sky-radius-card);
  background:
    radial-gradient(
      circle at 80% 0%,
      rgba(66, 232, 255, 0.27),
      transparent 44%
    ),
    linear-gradient(135deg, rgba(90, 108, 255, 0.18), rgba(255, 91, 189, 0.14));
  grid-template-columns: auto 1fr auto;
  gap: var(--sky-space-3);
}

.sp-story-hero__icon {
  display: grid;
  width: 46px;
  height: 46px;
  place-items: center;
  border-radius: 16px;
  background: var(--sky-app-accent);
  color: white;
}

.sp-story-hero > span:nth-child(2) {
  display: grid;
  gap: 2px;
}

.sp-story-hero small {
  color: var(--sky-muted);
  font-size: 10px;
  line-height: 1.35;
}

.sp-story-row {
  display: flex;
  align-items: center;
  width: 100%;
  min-height: 72px;
  padding: 9px var(--sky-space-4);
  border: 0;
  border-bottom: 1px solid var(--sky-hairline);
  background: transparent;
  color: var(--sky-text);
  gap: var(--sky-space-3);
  text-align: left;
}

.sp-story-row > span:nth-child(2),
.sp-story-row > button > span:nth-child(2) {
  display: grid;
  flex: 1;
  gap: 2px;
}

.sp-story-row small {
  color: var(--sky-muted);
  font-size: 11px;
}

.sp-story-row--own {
  display: grid;
  grid-template-columns: 1fr auto;
}

.sp-story-row--own > button:first-child {
  display: flex;
  align-items: center;
  min-height: 54px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--sky-text);
  gap: var(--sky-space-3);
  text-align: left;
}

.sp-story-row__actions {
  display: flex;
  gap: 3px;
}

.sp-story-row__actions button {
  width: 40px;
  min-width: 40px;
  height: 40px;
}

.sp-chevron {
  transform: rotate(180deg);
  color: var(--sky-subtle);
}

.sp-profile-card {
  display: grid;
  align-items: center;
  margin-bottom: var(--sky-space-4);
  padding: var(--sky-space-4);
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background:
    radial-gradient(
      circle at 100% 0%,
      var(--sky-app-accent-soft),
      transparent 46%
    ),
    var(--sky-surface);
  grid-template-columns: auto 1fr auto;
  gap: var(--sky-space-3);
}

.sp-profile-card__identity {
  display: grid;
  min-width: 0;
  gap: 2px;
}

.sp-profile-card__identity b {
  overflow: hidden;
  font-size: 17px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sp-profile-card__identity small,
.sp-profile-card p {
  color: var(--sky-muted);
}

.sp-profile-card__edit {
  min-height: 44px;
  padding: 0 10px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-pill);
  background: var(--sky-surface-variant);
  color: var(--sky-text);
  font-size: 11px;
  font-weight: 700;
}

.sp-profile-stats {
  display: grid;
  grid-column: 1 / -1;
  padding-top: var(--sky-space-2);
  grid-template-columns: repeat(3, 1fr);
}

.sp-profile-stats span {
  display: grid;
  justify-items: center;
  gap: 2px;
}

.sp-profile-stats b {
  font-size: 16px;
}

.sp-profile-stats small {
  color: var(--sky-muted);
  font-size: 10px;
}

.sp-profile-card p {
  margin: 0;
  grid-column: 1 / -1;
  font-size: 12px;
  line-height: 1.45;
}

.sp-profile-editor {
  margin-bottom: var(--sky-space-4);
  padding: var(--sky-space-4);
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}

.sp-account-settings {
  display: grid;
  gap: var(--sky-space-2);
  min-width: 0;
  margin: 0;
  padding: var(--sky-space-3);
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-control);
}

.sp-account-settings legend {
  padding: 0 5px;
  color: var(--sky-muted);
  font-size: 11px;
  font-weight: 750;
}

.sp-account-settings button {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
  min-height: var(--sky-touch-target);
  padding: 0 12px;
  border: 0;
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface-variant);
  color: var(--sky-text);
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  text-align: left;
}

.sp-account-settings__danger,
.sp-delete-account-confirm {
  color: var(--sky-danger, #ff3b30) !important;
}

.sp-settings-label {
  display: grid;
  gap: var(--sky-space-2);
}

.sp-editor-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sky-space-2);
}

.sp-discovery :deep(.sky-searchbar) {
  margin: var(--sky-space-3);
}

.sp-request-actions {
  display: flex;
  gap: 4px;
}

.sp-request-actions button {
  width: var(--sky-touch-target);
  min-width: var(--sky-touch-target);
  height: var(--sky-touch-target);
}

.sp-request-actions__accept {
  background: var(--sky-app-accent) !important;
  color: white !important;
}

.sp-friend-card {
  border-bottom: 1px solid var(--sky-hairline);
}

.sp-friend-card:last-child {
  border-bottom: 0;
}

.sp-friend-card > .sp-person-row {
  border-bottom: 0;
}

.sp-friend-actions {
  display: grid;
  padding: 0 var(--sky-space-3) var(--sky-space-3);
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 5px;
}

.sp-friend-actions button {
  display: grid;
  min-width: 0;
  min-height: 52px;
  padding: 5px 2px;
  place-items: center;
  border: 0;
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface-variant);
  color: var(--sky-text);
  font-size: 9px;
  gap: 2px;
}

:deep(.sp-tab) {
  transition:
    color var(--sky-transition-normal) ease,
    opacity var(--sky-transition-normal) ease;
}

:deep(.sp-tab:not(.sky-tab-button--active)) {
  opacity: 0.58;
}

:deep(.sp-tab--camera),
:deep(.sp-tab--camera.sky-tab-button--active) {
  color: var(--sp-camera-blue) !important;
}

:deep(.sp-tab--monochrome),
:deep(.sp-tab--monochrome.sky-tab-button--active) {
  color: var(--sp-tab-monochrome) !important;
}

.sp-tab-icon {
  position: relative;
  display: inline-grid;
  place-items: center;
}

.sp-tab-badge {
  position: absolute;
  top: -8px;
  right: -13px;
  min-width: 17px;
  padding-inline: 4px;
  font-size: 8px;
}

.sp-media-viewer {
  position: absolute;
  z-index: 80;
  inset: 0;
  overflow: hidden;
  background: #05060a;
  color: white;
}

.sp-media-viewer > img,
.sp-media-viewer > video {
  width: 100%;
  height: 100%;
  object-fit: contain;
  background: #05060a;
}

.sp-media-viewer > header {
  position: absolute;
  z-index: 3;
  top: calc(var(--sky-safe-area-top) + 13px);
  right: var(--sky-page-gutter);
  left: var(--sky-page-gutter);
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 44px;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.8);
}

.sp-viewer-progress {
  position: absolute;
  z-index: 4;
  top: calc(var(--sky-safe-area-top) + 7px);
  right: var(--sky-page-gutter);
  left: var(--sky-page-gutter);
  overflow: hidden;
  height: 3px;
  border-radius: var(--sky-radius-pill);
  background: rgba(255, 255, 255, 0.24);
}

.sp-viewer-progress span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: white;
  transition: width 100ms linear;
}

.sp-viewer-loading {
  position: absolute;
  z-index: 3;
  inset: 50% auto auto 50%;
  transform: translate(-50%, -50%);
}

.sp-viewer-author {
  display: flex;
  align-items: center;
  gap: var(--sky-space-2);
}

.sp-viewer-author > span:last-child {
  display: grid;
  gap: 1px;
}

.sp-viewer-author small,
.sp-media-viewer > header > small {
  color: rgba(255, 255, 255, 0.74);
  font-size: 10px;
}

.sp-media-viewer__overlay {
  position: absolute;
  z-index: 2;
  top: 47%;
  right: var(--sky-space-4);
  left: var(--sky-space-4);
  padding: 9px 12px;
  transform: translateY(-50%);
  border-radius: var(--sky-radius-control);
  background: rgba(0, 0, 0, 0.32);
  font-size: 21px;
  line-height: 1.2;
  text-align: center;
  overflow-wrap: anywhere;
  text-shadow: 0 2px 6px rgba(0, 0, 0, 0.8);
}

.sp-media-viewer__caption {
  position: absolute;
  z-index: 2;
  right: var(--sky-page-gutter);
  bottom: calc(var(--sky-safe-area-bottom) + 28px);
  left: var(--sky-page-gutter);
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--sky-radius-control);
  background: rgba(0, 0, 0, 0.5);
  font-size: 13px;
  line-height: 1.4;
  text-align: center;
  backdrop-filter: blur(10px);
}

.sp-media-viewer__owner-actions {
  position: absolute;
  z-index: 3;
  right: var(--sky-page-gutter);
  bottom: calc(var(--sky-safe-area-bottom) + 14px);
  left: var(--sky-page-gutter);
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--sky-space-2);
}

.sp-media-viewer__caption + .sp-media-viewer__owner-actions {
  bottom: calc(var(--sky-safe-area-bottom) + 82px);
}

.sp-media-viewer__caption--with-reply {
  bottom: calc(var(--sky-safe-area-bottom) + 82px);
}

.sp-story-reply {
  position: absolute;
  z-index: 3;
  right: var(--sky-page-gutter);
  bottom: calc(var(--sky-safe-area-bottom) + 8px);
  left: var(--sky-page-gutter);
}

.sp-media-viewer__owner-actions button {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid rgba(255, 255, 255, 0.22);
  border-radius: var(--sky-radius-pill);
  background: rgba(0, 0, 0, 0.52);
  color: white;
  font-size: 11px;
  font-weight: 750;
  gap: 6px;
  backdrop-filter: blur(12px);
}

.sp-viewers-sheet {
  display: flex;
  max-height: calc(100vh - var(--sky-safe-area-top) - 48px);
  flex-direction: column;
}

.sp-viewers-sheet > header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 54px;
  padding: 0 var(--sky-page-gutter);
  border-bottom: 1px solid var(--sky-hairline);
}

.sp-viewers-sheet__scroll {
  overflow-y: auto;
  min-height: 220px;
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-3));
}

@media (prefers-reduced-motion: reduce) {
  .sp-viewer-progress span {
    transition: none;
  }

  .sp-thread-plus,
  :deep(.sp-tab) {
    transition: none;
  }

  .sp-camera-preview__glow {
    filter: none;
  }
}
</style>
