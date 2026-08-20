<script setup lang="ts">
import {
  AlignLeft,
  AtSign,
  Ban,
  Bell,
  Bookmark,
  Camera,
  CalendarDays,
  Check,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Feather,
  Flag,
  Heart,
  Home,
  ImagePlus,
  Images,
  LogOut,
  MessageCircle,
  MoreHorizontal,
  PencilLine,
  Plus,
  Search,
  Send,
  Share2,
  Trash2,
  UserPlus,
  UserMinus,
  UserRound,
  UsersRound,
  X,
} from 'lucide-vue-next'
import {
  SkyBlock,
  SkyButton,
  SkyFab,
  SkyGlass,
  SkyIcon,
  SkyLink,
  SkyList,
  SkyField,
  SkyListItem,
  SkyNavbar,
  SkyNavbarBackLink,
  SkyPillNavigation,
  SkyAppPage,
  SkyScrollArea,
  SkyScrollRail,
  SkySpinner,
  SkySearchbar,
  SkySegmented,
  SkySegmentedButton,
  SkySheet,
  SkyNotification,
  SkyToggle,
  SkyMessagebar,
} from '@/ui'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import FeatherPostCard from '@/components/feather/FeatherPostCard.vue'
import AccountLogoutDialog from '@/components/account/AccountLogoutDialog.vue'
import AppProfileAuth from '@/components/account/AppProfileAuth.vue'
import { useAccountStore } from '@/stores/account'
import { useAppAuthStore } from '@/stores/app-auth'
import { useFeatherStore } from '@/stores/feather'
import { useEasyShareStore } from '@/stores/easyshare'
import type { FeatherConnectionMode } from '@/stores/feather'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import type { FeatherMedia, FeatherPost, FeatherProfile } from '@/types/feather'

type Tab = 'home' | 'explore' | 'network' | 'activity' | 'profile'
type Screen =
  | 'main'
  | 'composer'
  | 'thread'
  | 'profile'
  | 'edit'
  | 'connections'
type ExploreView = 'explore' | 'trending' | 'news'
type ActivityView = 'all' | 'mentions'
type ProfileView = 'posts' | 'replies' | 'bookmarks'
type SelectedPhoto = { id: number; url: string }
type ComposerContext = {
  body: string
  photos: SelectedPhoto[]
  replyTo?: FeatherPost
}
type ProfileMediaContext = {
  editing: { bio: string; displayName: string }
  selectedPhoto: SelectedPhoto | null
}
type AuthMediaContext = {
  mode: 'login' | 'register'
  selectedPhoto: SelectedPhoto | null
  username: string
}

const phone = usePhoneStore()
const account = useAccountStore()
const appAuth = useAppAuthStore()
const feather = useFeatherStore()
const messageMedia = useMessageMediaStore()
const route = useRoute()
const router = useRouter()
const tab = ref<Tab>('home')
const screen = ref<Screen>('main')
const exploreView = ref<ExploreView>('explore')
const activityView = ref<ActivityView>('all')
const profileView = ref<ProfileView>('posts')
const connectionMode = ref<FeatherConnectionMode>('followers')
const connectionReturnScreen = ref<'main' | 'profile'>('profile')
const settingsOpen = ref(false)
const logoutDialogOpen = ref(false)
const compactMode = ref(false)
const showSuggestions = ref(true)
const search = ref('')
const networkSearch = ref('')
const feedback = ref('')
const busy = ref(false)
const replyTo = ref<FeatherPost | null>(null)
const composerBody = ref('')
const threadReplyBody = ref('')
const threadReplyTarget = ref<FeatherPost | null>(null)
const threadReplyInput = ref<HTMLElement | null>(null)
const photos = ref<SelectedPhoto[]>([])
const menuPost = ref<FeatherPost | null>(null)
const commentLikePulseId = ref<string | null>(null)
const reportOpen = ref(false)
const reportReason = ref('spam')
const reportDetails = ref('')
const mediaPreview = ref<{ index: number; items: FeatherMedia[] } | null>(null)
const onboarding = ref({ bio: '', displayName: '', handle: '' })
const editing = ref({ bio: '', displayName: '' })
const selectedProfilePhoto = ref<SelectedPhoto | null>(null)
const authMode = ref<'login' | 'register'>('login')
const authUsername = ref('')
const authProfilePhoto = ref<SelectedPhoto | null>(null)
const authBusy = ref(false)
const authError = ref('')
let exploreSearchTimer: number | undefined
let networkSearchTimer: number | undefined
let commentLikePulseTimer: number | undefined

const displayedPosts = computed(() => {
  if (tab.value === 'explore' && search.value.trim())
    return feather.explorePosts
  if (tab.value === 'profile' || screen.value === 'profile')
    return feather.profilePosts
  return feather.feed
})
const displayedActivities = computed(() =>
  activityView.value === 'mentions'
    ? feather.activities.filter(
        (item) => item.kind === 'reply' || item.kind === 'quote',
      )
    : feather.activities,
)
const displayedProfilePosts = computed(() => {
  if (profileView.value === 'bookmarks') return feather.bookmarkedPosts
  if (profileView.value === 'replies')
    return feather.profilePosts.filter((post) => Boolean(post.reply_to_id))
  return feather.profilePosts.filter((post) => !post.reply_to_id)
})
const previewMedia = computed(() => {
  if (!mediaPreview.value) return null
  return mediaPreview.value.items[mediaPreview.value.index] ?? null
})
const networkSections = computed(() => {
  const sections: Array<{
    key: 'results' | 'suggestions'
    profiles: FeatherProfile[]
    title: string
  }> = []
  if (networkSearch.value.trim()) {
    sections.push({
      key: 'results',
      profiles: feather.networkResults,
      title: t('searchResults'),
    })
  }
  sections.push({
    key: 'suggestions',
    profiles: feather.networkSuggestions,
    title: t('suggestedPeople'),
  })
  return sections
})
const exploreCategories: ExploreView[] = ['explore', 'trending', 'news']
const tabOrder: Tab[] = ['home', 'explore', 'network', 'activity', 'profile']
const exploreViewIndex = computed(() =>
  Math.max(0, exploreCategories.indexOf(exploreView.value)),
)
const tabIndex = computed(() => Math.max(0, tabOrder.indexOf(tab.value)))
const canPost = computed(
  () =>
    !busy.value &&
    composerBody.value.length <= 360 &&
    (composerBody.value.trim().length > 0 || photos.value.length > 0),
)
const canReply = computed(() => {
  const mention =
    threadReplyTarget.value &&
    threadReplyTarget.value.id !== feather.thread?.post.id
      ? `@${threadReplyTarget.value.handle}`
      : ''
  return (
    !busy.value &&
    threadReplyBody.value.trim().length > 0 &&
    threadReplyBody.value.trim() !== mention &&
    threadReplyBody.value.length <= 360
  )
})
const hasProfileChanges = computed(() => {
  const profile = feather.profile
  if (!profile) return false
  return (
    selectedProfilePhoto.value !== null ||
    editing.value.displayName !== profile.display_name ||
    editing.value.bio !== profile.bio
  )
})
const canSaveProfile = computed(
  () =>
    !busy.value &&
    hasProfileChanges.value &&
    editing.value.displayName.trim().length > 0 &&
    editing.value.displayName.length <= 50 &&
    editing.value.bio.length <= 160,
)
const editProfileAvatarUrl = computed(
  () => selectedProfilePhoto.value?.url ?? feather.profile?.avatar_url,
)
const canCreateProfile = computed(
  () =>
    !busy.value &&
    onboarding.value.displayName.trim().length > 0 &&
    /^[a-z0-9][a-z0-9_]{1,28}[a-z0-9]$/i.test(onboarding.value.handle.trim()),
)
const activeProfile = computed(() => feather.viewedProfile ?? feather.profile)
const navbarTitle = computed(() => {
  if (screen.value === 'composer')
    return replyTo.value ? t('reply') : t('newPost')
  if (screen.value === 'thread') return t('posts')
  if (screen.value === 'edit') return t('editProfile')
  if (screen.value === 'connections')
    return connectionMode.value === 'followers'
      ? t('followers')
      : t('followingCount')
  if (screen.value === 'profile') return `@${activeProfile.value?.handle ?? ''}`
  if (tab.value === 'activity') return t('activity')
  if (tab.value === 'network') return t('network')
  if (tab.value === 'profile')
    return activeProfile.value?.display_name ?? t('profile')
  if (tab.value === 'explore') return t('explore')
  return t('name')
})
const unreadActivities = computed(
  () => feather.activities.filter((item) => !item.read).length,
)
const isAuthenticated = computed(() => appAuth.isSignedIn('feather'))
const authUsernameValid = computed(() =>
  /^[a-z0-9][a-z0-9_]{1,28}[a-z0-9]$/i.test(authUsername.value.trim()),
)

function t(path: string, params?: Record<string, string>): string {
  return phone.t(`Apps.feather.${path}`, params)
}

function relativeCommentTime(timestamp: number): string {
  const elapsed = Math.max(0, Date.now() - timestamp)
  const minutes = Math.floor(elapsed / 60_000)
  if (minutes < 1) return t('now')
  if (minutes < 60) return t('minutesShort', { count: String(minutes) })
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return t('hoursShort', { count: String(hours) })
  const days = Math.floor(hours / 24)
  return t('daysShort', { count: String(days) })
}

function leadingCommentMention(post: FeatherPost): string {
  return post.body.match(/^@[a-z0-9_]+/i)?.[0] ?? ''
}

function visibleCommentBody(post: FeatherPost): string {
  const mention = leadingCommentMention(post)
  return mention ? post.body.slice(mention.length).trimStart() : post.body
}

function focusThreadInput(): void {
  threadReplyInput.value?.querySelector('textarea')?.focus()
}

function openMediaPreview(post: FeatherPost, index: number): void {
  mediaPreview.value = { index, items: post.media }
}

function closeMediaPreview(): void {
  mediaPreview.value = null
}

function moveMediaPreview(direction: number): void {
  if (!mediaPreview.value || mediaPreview.value.items.length < 2) return
  mediaPreview.value.index =
    (mediaPreview.value.index + direction + mediaPreview.value.items.length) %
    mediaPreview.value.items.length
}

function handleMediaPreviewKeydown(event: KeyboardEvent): void {
  if (!mediaPreview.value) return
  if (event.key === 'Escape') {
    event.preventDefault()
    event.stopImmediatePropagation()
    closeMediaPreview()
  } else if (event.key === 'ArrowLeft') {
    event.preventDefault()
    moveMediaPreview(-1)
  } else if (event.key === 'ArrowRight') {
    event.preventDefault()
    moveMediaPreview(1)
  }
}

function toast(path: string): void {
  feedback.value = t(path)
  window.setTimeout(() => {
    feedback.value = ''
  }, 2200)
}

function errorToast(error?: string): void {
  const key =
    error === 'invalid_handle'
      ? 'errors.invalidHandle'
      : error === 'handle_taken'
        ? 'errors.handleTaken'
        : error === 'invalid_post'
          ? 'errors.invalidPost'
          : 'errors.generic'
  toast(key)
}

function inputValue(event: Event): string {
  const target = event.target
  if (
    !(target instanceof HTMLInputElement) &&
    !(target instanceof HTMLTextAreaElement)
  ) {
    console.error('[Feather] Text input event has no supported target.')
    return ''
  }
  return target.value
}

function switchAuthMode(mode: 'login' | 'register'): void {
  authMode.value = mode
  authProfilePhoto.value = null
  if (mode === 'register') {
    authUsername.value = (account.email.split('@')[0] ?? '')
      .replace(/[^a-z0-9_]/gi, '_')
      .slice(0, 30)
  } else {
    authUsername.value = ''
  }
  authError.value = ''
}

function authErrorMessage(error?: string): string {
  const known = [
    'already_registered',
    'handle_taken',
    'invalid_handle',
    'invalid_media',
    'invalid_username',
    'no_ifruit_account',
    'profile_not_found',
    'rate_limited',
  ]
  return t(`authErrors.${error && known.includes(error) ? error : 'default'}`)
}

async function submitAuth(): Promise<void> {
  authError.value = ''
  if (!account.email) {
    authError.value = t('authErrors.no_ifruit_account')
    return
  }
  if (!authUsernameValid.value) {
    authError.value = t('authErrors.invalid_handle')
    return
  }

  const username = authUsername.value.trim().toLowerCase()
  authBusy.value = true
  const bootstrapped = await feather.bootstrap()
  if (!bootstrapped) {
    authBusy.value = false
    authError.value = authErrorMessage()
    return
  }
  if (authMode.value === 'login') {
    authBusy.value = false
    if (!feather.onboarded || !feather.profile) {
      authError.value = t('authErrors.profile_not_found')
      return
    }
    if (feather.profile.handle.toLowerCase() !== username) {
      authError.value = t('authErrors.invalid_username')
      return
    }
  } else {
    if (feather.onboarded || feather.profile) {
      authBusy.value = false
      authError.value = t('authErrors.already_registered')
      return
    }
    const response = await feather.createProfile({
      avatarId: authProfilePhoto.value?.id,
      bio: '',
      displayName: authUsername.value.trim(),
      handle: username,
    })
    authBusy.value = false
    if (!response.success) {
      authError.value = authErrorMessage(response.error)
      return
    }
  }

  appAuth.signIn('feather', account.email)
  authUsername.value = ''
  authProfilePhoto.value = null
  if (authMode.value === 'login') await feather.bootstrap()
}

function openAuthMedia(app: 'camera' | 'photos'): void {
  messageMedia.begin(
    'feather:auth-avatar',
    'photo',
    '/apps/feather?auth=register',
    1,
    {
      mode: authMode.value,
      selectedPhoto: authProfilePhoto.value,
      username: authUsername.value,
    } satisfies AuthMediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

async function createProfile(): Promise<void> {
  if (!canCreateProfile.value) return
  busy.value = true
  const response = await feather.createProfile({
    bio: onboarding.value.bio,
    displayName: onboarding.value.displayName,
    handle: onboarding.value.handle,
  })
  busy.value = false
  if (!response.success) errorToast(response.error)
}

async function selectTab(next: Tab): Promise<void> {
  tab.value = next
  screen.value = 'main'
  feather.viewedProfile = null
  if (next === 'home') await feather.loadFeed()
  if (next === 'explore') await feather.explore(search.value)
  if (next === 'network') await feather.loadNetwork(networkSearch.value)
  if (next === 'activity') {
    await feather.loadActivities()
    await feather.markActivities()
  }
  if (next === 'profile' && feather.profile) {
    profileView.value = 'posts'
    await feather.loadProfile(feather.profile.id)
  }
}

async function selectProfileView(next: ProfileView): Promise<void> {
  profileView.value = next
  if (next === 'bookmarks') await feather.loadBookmarks()
}

async function setFeedMode(mode: 'for-you' | 'following'): Promise<void> {
  await feather.loadFeed(mode)
}

async function runSearch(): Promise<void> {
  if (exploreSearchTimer !== undefined) {
    window.clearTimeout(exploreSearchTimer)
    exploreSearchTimer = undefined
  }
  await feather.explore(search.value)
}

async function runNetworkSearch(): Promise<void> {
  await feather.loadNetwork(networkSearch.value)
}

async function selectTopic(topic: string): Promise<void> {
  search.value = topic
  exploreView.value = 'explore'
  await runSearch()
}

function shareProfile(): void {
  const profile = activeProfile.value
  if (!profile) return
  useEasyShareStore().open({
    appId: 'feather',
    copyText: `@${profile.handle}`,
    id: profile.id,
    imageUrl: profile.avatar_url,
    kind: 'profile',
    link: `skyphone://feather/profile/${profile.id}`,
    subtitle: `@${profile.handle}`,
    title: profile.display_name,
  })
}

function sharePost(post: FeatherPost): void {
  useEasyShareStore().open({
    appId: 'feather',
    copyText: `@${post.handle}: ${post.body}`,
    id: post.id,
    imageUrl: post.media[0]?.url,
    kind: 'post',
    link: `skyphone://feather/post/${post.id}`,
    subtitle: `@${post.handle}`,
    title: post.body,
  })
}

function openComposer(post?: FeatherPost): void {
  replyTo.value = post ?? null
  composerBody.value = ''
  photos.value = []
  screen.value = 'composer'
}

function openComposerMedia(app: 'camera' | 'photos'): void {
  const remaining = 4 - photos.value.length
  if (remaining < 1) {
    toast('photoLimit')
    return
  }
  messageMedia.begin(
    'feather:composer',
    'photo',
    '/apps/feather?compose=1',
    app === 'photos' ? remaining : 1,
    {
      body: composerBody.value,
      photos: [...photos.value],
      replyTo: replyTo.value ?? undefined,
    } satisfies ComposerContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

async function publish(): Promise<void> {
  if (!canPost.value) return
  busy.value = true
  const response = await feather.createPost({
    body: composerBody.value,
    mediaIds: photos.value.map((photo) => photo.id),
    replyToId: replyTo.value?.id,
  })
  busy.value = false
  if (!response.success) {
    errorToast(response.error)
    return
  }
  if (replyTo.value) await feather.loadThread(replyTo.value.id)
  screen.value = replyTo.value ? 'thread' : 'main'
  replyTo.value = null
  composerBody.value = ''
  photos.value = []
}

async function openThread(
  post: FeatherPost,
  focusReply = false,
): Promise<void> {
  if (!(await feather.loadThread(post.id))) return
  threadReplyBody.value = ''
  threadReplyTarget.value = feather.thread?.post ?? null
  screen.value = 'thread'
  if (focusReply) {
    await nextTick()
    focusThreadInput()
  }
}

async function focusThreadReply(post: FeatherPost): Promise<void> {
  const previousTarget = threadReplyTarget.value
  const previousMention =
    previousTarget && previousTarget.id !== feather.thread?.post.id
      ? `@${previousTarget.handle} `
      : ''
  const nextMention =
    post.id !== feather.thread?.post.id ? `@${post.handle} ` : ''
  const bodyWithoutPreviousMention = previousMention
    ? threadReplyBody.value.replace(new RegExp(`^${previousMention}`), '')
    : threadReplyBody.value
  threadReplyTarget.value = post
  if (!threadReplyBody.value.trim() || previousMention || nextMention) {
    threadReplyBody.value = `${nextMention}${bodyWithoutPreviousMention}`
  }
  await nextTick()
  focusThreadInput()
}

async function reactComment(post: FeatherPost): Promise<void> {
  const isActivating = !post.is_liked
  await feather.react(post, 'like')
  if (!isActivating || !post.is_liked) return
  if (commentLikePulseTimer !== undefined)
    window.clearTimeout(commentLikePulseTimer)
  commentLikePulseId.value = post.id
  commentLikePulseTimer = window.setTimeout(() => {
    commentLikePulseId.value = null
    commentLikePulseTimer = undefined
  }, 480)
}

function handleCommentKeydown(event: KeyboardEvent): void {
  if (event.key !== 'Enter' || event.shiftKey || event.isComposing) return
  event.preventDefault()
  void publishThreadReply()
}

async function clearThreadReplyTarget(): Promise<void> {
  if (!feather.thread) return
  const mention = threadReplyTarget.value
    ? `@${threadReplyTarget.value.handle} `
    : ''
  if (threadReplyBody.value.startsWith(mention))
    threadReplyBody.value = threadReplyBody.value.slice(mention.length)
  threadReplyTarget.value = feather.thread.post
  await nextTick()
  focusThreadInput()
}

async function publishThreadReply(): Promise<void> {
  if (!canReply.value || !feather.thread) return
  const postId = feather.thread.post.id
  busy.value = true
  const response = await feather.createPost({
    body: threadReplyBody.value,
    mediaIds: [],
    replyToId: postId,
  })
  busy.value = false
  if (!response.success) {
    errorToast(response.error)
    return
  }
  threadReplyBody.value = ''
  await feather.loadThread(postId)
  threadReplyTarget.value = feather.thread?.post ?? null
  await nextTick()
  focusThreadInput()
}

async function openProfile(profileId: number): Promise<void> {
  if (await feather.loadProfile(profileId)) {
    profileView.value = 'posts'
    screen.value = 'profile'
  }
}

async function followProfile(profile: FeatherProfile): Promise<void> {
  await feather.follow(profile)
}

async function openConnections(mode: FeatherConnectionMode): Promise<void> {
  if (!activeProfile.value) return
  if (screen.value !== 'connections') {
    connectionReturnScreen.value = screen.value === 'main' ? 'main' : 'profile'
  }
  connectionMode.value = mode
  screen.value = 'connections'
  await feather.loadConnections(activeProfile.value.id, mode)
}

async function removeConnection(profile: FeatherProfile): Promise<void> {
  if (await feather.removeConnection(profile, connectionMode.value))
    toast(
      connectionMode.value === 'followers'
        ? 'followerRemoved'
        : 'followingRemoved',
    )
}

function openEdit(): void {
  if (!feather.profile) return
  editing.value = {
    bio: feather.profile.bio,
    displayName: feather.profile.display_name,
  }
  selectedProfilePhoto.value = null
  screen.value = 'edit'
}

function openProfileMedia(app: 'camera' | 'photos'): void {
  messageMedia.begin(
    'feather:profile-avatar',
    'photo',
    '/apps/feather?profileEdit=1',
    1,
    {
      editing: { ...editing.value },
      selectedPhoto: selectedProfilePhoto.value,
    } satisfies ProfileMediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

function closeProfileEdit(): void {
  tab.value = 'profile'
  screen.value = 'main'
  feather.viewedProfile = null
  selectedProfilePhoto.value = null
  if (route.query.profileEdit === '1')
    void router.replace({ path: '/apps/feather' })
}

async function saveProfile(): Promise<void> {
  busy.value = true
  const response = await feather.updateProfile({
    ...editing.value,
    avatarId: selectedProfilePhoto.value?.id,
  })
  busy.value = false
  if (!response.success) {
    errorToast(response.error)
    return
  }
  if (feather.profile) await feather.loadProfile(feather.profile.id)
  closeProfileEdit()
}

function openPostMenu(post: FeatherPost): void {
  reportOpen.value = false
  menuPost.value = post
}

function closePostMenu(): void {
  menuPost.value = null
}

async function deletePost(): Promise<void> {
  if (!menuPost.value) return
  const success = await feather.deletePost(menuPost.value.id)
  menuPost.value = null
  if (success) toast('deleted')
}

async function blockPostAuthor(): Promise<void> {
  if (!menuPost.value) return
  const success = await feather.blockProfile(menuPost.value.profile_id)
  menuPost.value = null
  if (success) {
    screen.value = 'main'
    toast('blocked')
  }
}

function openPostReport(): void {
  reportOpen.value = true
}

function closePostReport(): void {
  reportOpen.value = false
  menuPost.value = null
  reportDetails.value = ''
}

async function submitReport(): Promise<void> {
  if (!menuPost.value) return
  const success = await feather.reportPost(
    menuPost.value.id,
    reportReason.value,
    reportDetails.value,
  )
  reportOpen.value = false
  menuPost.value = null
  reportDetails.value = ''
  if (success) toast('reported')
}

function goBack(): void {
  if (screen.value === 'connections') {
    screen.value = connectionReturnScreen.value
    if (screen.value === 'main' && tab.value === 'profile')
      feather.viewedProfile = null
    return
  }
  if (screen.value === 'edit') {
    closeProfileEdit()
    return
  }
  if (screen.value === 'thread' || screen.value === 'profile') {
    screen.value = 'main'
    feather.viewedProfile = null
    return
  }
  if (screen.value === 'composer') {
    screen.value = replyTo.value ? 'thread' : 'main'
    return
  }
  void router.back()
}

watch(networkSearch, () => {
  if (networkSearchTimer !== undefined) window.clearTimeout(networkSearchTimer)
  networkSearchTimer = window.setTimeout(() => {
    if (tab.value === 'network') void runNetworkSearch()
  }, 250)
})

watch(
  search,
  (value) => {
    if (exploreSearchTimer !== undefined)
      window.clearTimeout(exploreSearchTimer)
    if (!value.trim()) {
      exploreSearchTimer = undefined
      return
    }
    exploreSearchTimer = window.setTimeout(() => {
      exploreSearchTimer = undefined
      if (tab.value === 'explore') void runSearch()
    }, 300)
  },
  { flush: 'sync' },
)

onBeforeUnmount(() => {
  if (exploreSearchTimer !== undefined) window.clearTimeout(exploreSearchTimer)
  if (networkSearchTimer !== undefined) window.clearTimeout(networkSearchTimer)
  if (commentLikePulseTimer !== undefined)
    window.clearTimeout(commentLikePulseTimer)
  window.removeEventListener('keydown', handleMediaPreviewKeydown, true)
})

onMounted(async () => {
  window.addEventListener('keydown', handleMediaPreviewKeydown, true)
  const selection =
    messageMedia.consumeMany<ComposerContext>('feather:composer')
  const profileSelection = messageMedia.consumeMany<ProfileMediaContext>(
    'feather:profile-avatar',
  )
  const authSelection = messageMedia.consumeMany<AuthMediaContext>(
    'feather:auth-avatar',
  )
  if (selection) {
    if (selection.context) {
      composerBody.value = selection.context.body
      photos.value = selection.context.photos
      replyTo.value = selection.context.replyTo ?? null
    }
    for (const media of selection.media) {
      if (photos.value.some((photo) => photo.id === media.id)) continue
      photos.value.push({ id: media.id, url: media.url })
    }
  }
  if (profileSelection) {
    if (profileSelection.context) {
      editing.value = profileSelection.context.editing
      selectedProfilePhoto.value = profileSelection.context.selectedPhoto
    }
    if (profileSelection.media[0]) {
      selectedProfilePhoto.value = {
        id: profileSelection.media[0].id,
        url: profileSelection.media[0].url,
      }
    }
  }
  if (authSelection) {
    if (authSelection.context) {
      authMode.value = authSelection.context.mode
      authUsername.value = authSelection.context.username
      authProfilePhoto.value = authSelection.context.selectedPhoto
    }
    if (authSelection.media[0]) {
      authProfilePhoto.value = {
        id: authSelection.media[0].id,
        url: authSelection.media[0].url,
      }
    }
  }
  if (route.query.compose === '1') screen.value = 'composer'
  await feather.bootstrap()
  if (route.query.profileEdit === '1' && feather.profile) screen.value = 'edit'
  if (feather.onboarded) {
    const easyShareId = String(route.query.easyShareId ?? '')
    if (easyShareId && route.query.easyShareKind === 'profile') {
      const profileId = Number(easyShareId)
      if (Number.isInteger(profileId) && profileId > 0)
        await openProfile(profileId)
    } else if (easyShareId && route.query.easyShareKind === 'post') {
      if (await feather.loadThread(easyShareId)) {
        threadReplyTarget.value = feather.thread?.post ?? null
        screen.value = 'thread'
      }
    }
    await feather.loadActivities()
    if (tab.value === 'profile' && feather.profile)
      await feather.loadProfile(feather.profile.id)
  }
})
</script>

<template>
  <SkyAppPage
    component="main"
    class="feather-app"
    :class="{
      'feather-app--active': feather.onboarded && isAuthenticated,
      'feather-app--home':
        feather.onboarded &&
        isAuthenticated &&
        screen === 'main' &&
        tab === 'home',
      'feather-app--light': !phone.isDarkMode,
      'feather-app--composer':
        feather.onboarded && isAuthenticated && screen === 'composer',
      'feather-app--section':
        feather.onboarded &&
        isAuthenticated &&
        screen === 'main' &&
        tab !== 'home',
      'native-app': feather.onboarded && isAuthenticated,
      'feather-app--compact': compactMode,
    }"
  >
    <SkyNavbar
      v-if="feather.onboarded && isAuthenticated"
      class="feather-navbar"
      :subtitle="screen === 'main' && tab === 'home' ? undefined : t('name')"
      :title="screen === 'main' && tab === 'home' ? undefined : navbarTitle"
    >
      <template v-if="screen === 'main' && tab === 'home'" #title>
        <Feather
          class="feather-navbar__brand-mark"
          :size="30"
          :stroke-width="1.8"
        />
      </template>
      <template v-if="screen !== 'main'" #left>
        <SkyNavbarBackLink
          v-if="screen === 'profile'"
          :text="t('back')"
          :show-text="false"
          @click="goBack"
        />
        <SkyLink
          v-else-if="screen === 'composer'"
          component="button"
          class="feather-composer-close"
          :link-props="{ type: 'button' }"
          :aria-label="t('cancel')"
          @click="goBack"
        >
          <X :size="16" />
        </SkyLink>
        <SkyNavbarBackLink
          v-else
          :class="{ 'feather-edit__navbar-back': screen === 'edit' }"
          :text="t('back')"
          :show-text="false"
          @click="goBack"
        />
      </template>
      <template #right>
        <SkyButton
          v-if="screen === 'composer'"
          rounded
          small
          variant="secondary"
          :disabled="!canPost"
          class="feather-composer-publish"
          @click="publish"
        >
          {{ busy ? t('posting') : t('post') }}
        </SkyButton>
        <SkyButton
          v-else-if="screen === 'edit'"
          icon-only
          rounded
          variant="plain"
          :disabled="!canSaveProfile"
          class="feather-edit__navbar-save"
          :aria-label="busy ? t('loading') : t('saveProfile')"
          @click="saveProfile"
        >
          <SkySpinner v-if="busy" :size="15" />
          <Check v-else :size="16" :stroke-width="2.8" />
        </SkyButton>
        <SkyButton
          v-else-if="
            ((screen === 'main' && tab === 'profile') ||
              screen === 'profile') &&
            activeProfile?.is_owner
          "
          icon-only
          rounded
          tonal
          class="feather-profile__logout"
          :aria-label="phone.t('Common.signOut')"
          @click="logoutDialogOpen = true"
        >
          <LogOut :size="16" />
        </SkyButton>
      </template>
    </SkyNavbar>

    <div v-if="feather.loading && !feather.onboarded" class="feather-loading">
      <SkySpinner class="text-[#438cf5]" />
      <span>{{ t('loading') }}</span>
    </div>

    <section v-else-if="!isAuthenticated" class="feather-auth">
      <AppProfileAuth
        :mode="authMode"
        v-model:username="authUsername"
        :avatar-url="authProfilePhoto?.url ?? null"
        :body="t('authBody')"
        :camera-label="t('takePhoto')"
        :email="account.email"
        :email-label="t('email')"
        :error="authError"
        :eyebrow="t('authEyebrow')"
        :gallery-label="t('chooseGallery')"
        :login-label="t('login')"
        :max-username-length="30"
        :min-username-length="3"
        :pending="authBusy"
        :register-label="t('register')"
        :title="t('authWelcome')"
        :username-label="t('handle')"
        :username-placeholder="t('handlePlaceholder')"
        @camera="openAuthMedia('camera')"
        @gallery="openAuthMedia('photos')"
        @submit="submitAuth"
        @update:mode="switchAuthMode"
      />
    </section>

    <section v-else-if="!feather.onboarded" class="feather-onboarding">
      <div class="feather-welcome__mark"><Feather :size="45" /></div>
      <span class="feather-onboarding__step">{{ t('profileStep') }}</span>
      <h1>{{ t('welcome') }}</h1>
      <p>{{ t('welcomeBody') }}</p>
      <div class="feather-onboarding__account">
        <CheckCircle2 :size="15" />
        <span>{{ t('accountConnected') }}</span>
        <strong>{{ account.email }}</strong>
      </div>
      <div class="feather-onboarding__form">
        <div class="feather-onboarding__form-head">
          <span><UserRound :size="20" /></span>
          <div>
            <h2>{{ t('createProfile') }}</h2>
            <p>{{ t('profileDetailsHint') }}</p>
          </div>
        </div>
        <SkyList strong inset class="feather-onboarding__fields">
          <SkyField
            :value="onboarding.displayName"
            :label="t('displayName')"
            :placeholder="t('displayNamePlaceholder')"
            :maxlength="50"
            @input="onboarding.displayName = inputValue($event)"
          >
            <template #media><UserRound :size="18" /></template>
          </SkyField>
          <SkyField
            :value="onboarding.handle"
            :label="t('handle')"
            :placeholder="t('handlePlaceholder')"
            :maxlength="30"
            :info="t('handleHint')"
            @input="onboarding.handle = inputValue($event)"
          >
            <template #media><AtSign :size="18" /></template>
          </SkyField>
          <SkyField
            :value="onboarding.bio"
            type="textarea"
            :label="t('bio')"
            :placeholder="t('bioPlaceholder')"
            :maxlength="160"
            :info="`${onboarding.bio.length}/160`"
            @input="onboarding.bio = inputValue($event)"
          >
            <template #media><AlignLeft :size="18" /></template>
          </SkyField>
        </SkyList>
      </div>
      <SkyButton
        large
        rounded
        :disabled="!canCreateProfile"
        class="feather-primary feather-onboarding__button"
        @click="createProfile"
      >
        {{ t('start') }}
      </SkyButton>
      <SkyButton
        large
        rounded
        outline
        class="feather-onboarding__logout"
        @click="logoutDialogOpen = true"
      >
        <LogOut :size="16" />
        {{ phone.t('Common.signOut') }}
      </SkyButton>
    </section>

    <template v-else>
      <section v-if="screen === 'composer'" class="feather-composer">
        <p v-if="replyTo" class="feather-replying">
          {{ t('replyingTo', { handle: replyTo.handle }) }}
        </p>
        <SkyGlass :highlight="false" class="feather-composer-card">
          <div class="feather-composer-card__inner">
            <div class="feather-composer__identity">
              <div class="feather-compose-avatar">
                <img
                  v-if="feather.profile?.avatar_url"
                  :src="feather.profile.avatar_url"
                  alt=""
                />
                <UserRound v-else :size="20" />
              </div>
              <div>
                <strong>{{ feather.profile?.display_name }}</strong>
                <span>@{{ feather.profile?.handle }}</span>
              </div>
            </div>
            <textarea
              v-model="composerBody"
              autofocus
              :maxlength="360"
              :placeholder="
                replyTo ? t('replyPlaceholder') : t('composerPlaceholder')
              "
            ></textarea>
            <div class="feather-composer-card__footer">
              <span><UsersRound :size="14" /> {{ t('composerAudience') }}</span>
              <b>{{
                t('charactersLeft', {
                  count: String(360 - composerBody.length),
                })
              }}</b>
            </div>
          </div>
        </SkyGlass>

        <section class="feather-composer-media">
          <header>
            <span><ImagePlus :size="21" /></span>
            <div>
              <strong>{{ t('mediaTitle') }}</strong>
              <small>{{ t('mediaBody') }}</small>
            </div>
            <b>{{ photos.length }} / 4</b>
          </header>
          <div class="feather-composer-media__actions">
            <SkyGlass :highlight="false">
              <button
                type="button"
                :disabled="photos.length >= 4"
                @click="openComposerMedia('photos')"
              >
                <span><Images :size="20" /></span>
                <strong>{{ t('chooseGallery') }}</strong>
                <small>{{ t('chooseGalleryBody') }}</small>
              </button>
            </SkyGlass>
            <SkyGlass :highlight="false">
              <button
                type="button"
                :disabled="photos.length >= 4"
                @click="openComposerMedia('camera')"
              >
                <span><Camera :size="20" /></span>
                <strong>{{ t('takePhoto') }}</strong>
                <small>{{ t('takePhotoBody') }}</small>
              </button>
            </SkyGlass>
          </div>
          <div v-if="photos.length" class="feather-composer-media__selected">
            <div class="feather-composer-media__selected-head">
              <strong>{{ t('selectedPhotos') }}</strong>
              <span>{{ photos.length }} / 4</span>
            </div>
            <div
              class="feather-compose-media"
              :class="`feather-compose-media--${photos.length}`"
            >
              <div v-for="(photo, index) in photos" :key="photo.id">
                <img :src="photo.url" alt="" />
                <button
                  type="button"
                  :aria-label="t('removePhoto', { number: String(index + 1) })"
                  @click="photos.splice(index, 1)"
                >
                  <X :size="14" />
                </button>
                <i>{{ index + 1 }}</i>
              </div>
            </div>
          </div>
        </section>
      </section>

      <section v-else-if="screen === 'edit'" class="feather-edit">
        <div class="feather-edit__identity">
          <div class="feather-edit__avatar">
            <img
              v-if="editProfileAvatarUrl"
              :src="editProfileAvatarUrl"
              alt=""
            />
            <UserRound v-else :size="28" />
          </div>
          <div class="feather-edit__account">
            <strong>{{ feather.profile?.display_name }}</strong>
            <span>@{{ feather.profile?.handle }}</span>
          </div>
          <span class="feather-edit__badge"><PencilLine :size="14" /></span>
        </div>

        <div class="feather-edit__photo">
          <strong>{{ t('chooseAvatar') }}</strong>
          <div class="feather-edit__photo-actions">
            <SkyButton tonal rounded @click="openProfileMedia('photos')">
              <Images :size="16" />
              <span>{{ t('chooseGallery') }}</span>
            </SkyButton>
            <SkyButton tonal rounded @click="openProfileMedia('camera')">
              <Camera :size="16" />
              <span>{{ t('takePhoto') }}</span>
            </SkyButton>
          </div>
        </div>

        <SkyList strong inset class="feather-edit__fields">
          <SkyField
            :value="editing.displayName"
            :label="t('displayName')"
            :placeholder="t('displayNamePlaceholder')"
            :maxlength="50"
            :info="`${editing.displayName.length}/50`"
            @input="editing.displayName = inputValue($event)"
          >
            <template #media><UserRound :size="18" /></template>
          </SkyField>
          <SkyField
            :value="editing.bio"
            type="textarea"
            :label="t('bio')"
            :placeholder="t('bioPlaceholder')"
            :maxlength="160"
            :info="`${editing.bio.length}/160`"
            @input="editing.bio = inputValue($event)"
          >
            <template #media><AlignLeft :size="18" /></template>
          </SkyField>
        </SkyList>
      </section>

      <SkyScrollArea
        v-else-if="screen === 'connections' && activeProfile"
        class="feather-scroll feather-connections"
      >
        <SkySegmented class="feather-connections__tabs">
          <SkySegmentedButton
            type="button"
            :active="connectionMode === 'followers'"
            :class="{ 'is-active': connectionMode === 'followers' }"
            @click="openConnections('followers')"
          >
            {{ t('followers') }}
          </SkySegmentedButton>
          <SkySegmentedButton
            type="button"
            :active="connectionMode === 'following'"
            :class="{ 'is-active': connectionMode === 'following' }"
            @click="openConnections('following')"
          >
            {{ t('followingCount') }}
          </SkySegmentedButton>
        </SkySegmented>

        <div
          v-if="feather.connectionLoading"
          class="feather-connections__loading"
        >
          <SkySpinner />
        </div>
        <SkyBlock
          v-else-if="!feather.connections.length"
          strong
          inset
          class="feather-connections__empty"
        >
          <UsersRound :size="30" />
          <strong>{{ t('noConnections') }}</strong>
          <p>{{ t('noConnectionsBody') }}</p>
        </SkyBlock>
        <SkyList v-else strong inset class="feather-connections__list">
          <SkyListItem
            v-for="person in feather.connections"
            :key="person.id"
            :title="person.display_name"
            :text="`@${person.handle}`"
          >
            <template #media>
              <button
                type="button"
                class="feather-connections__profile"
                :aria-label="person.display_name"
                @click="openProfile(person.id)"
              >
                <span class="feather-avatar feather-connections__avatar">
                  <img
                    v-if="person.avatar_url"
                    :src="person.avatar_url"
                    alt=""
                  />
                  <UserRound v-else :size="19" />
                </span>
              </button>
            </template>
            <template #after>
              <SkyButton
                v-if="activeProfile.is_owner"
                outline
                rounded
                small
                class="feather-connections__remove"
                @click="removeConnection(person)"
              >
                <UserMinus :size="13" />
                <span>{{ t('removeConnection') }}</span>
              </SkyButton>
              <SkyButton
                v-else-if="!person.is_owner"
                rounded
                small
                :tonal="person.is_following"
                class="feather-follow-button"
                :class="{
                  'feather-follow-button--pending': !person.is_following,
                  'feather-follow-button--following': person.is_following,
                }"
                @click="followProfile(person)"
              >
                {{ person.is_following ? t('following') : t('follow') }}
              </SkyButton>
            </template>
          </SkyListItem>
        </SkyList>
      </SkyScrollArea>

      <SkyScrollArea
        v-else-if="screen === 'thread' && feather.thread"
        class="feather-scroll feather-thread"
      >
        <FeatherPostCard
          :post="feather.thread.post"
          @follow="feather.followPost"
          @media="openMediaPreview"
          @menu="openPostMenu"
          @open="() => undefined"
          @profile="openProfile"
          @react="feather.react"
          @reply="focusThreadReply"
          @share="sharePost"
        />
        <section class="feather-comments">
          <header class="feather-comments__header">
            <strong>{{ t('comments') }}</strong>
            <span>{{ feather.thread.replies.length }}</span>
          </header>

          <div
            v-if="!feather.thread.replies.length"
            class="feather-thread-empty"
          >
            <MessageCircle :size="22" />
            <strong>{{ t('noComments') }}</strong>
            <span>{{ t('noReplies') }}</span>
          </div>

          <article
            v-for="post in feather.thread.replies"
            v-else
            :key="post.id"
            class="feather-comment"
            :class="{
              'feather-comment--reply': Boolean(leadingCommentMention(post)),
            }"
          >
            <button
              type="button"
              class="feather-avatar feather-comment__avatar"
              :aria-label="post.display_name"
              @click="openProfile(post.profile_id)"
            >
              <img v-if="post.avatar_url" :src="post.avatar_url" alt="" />
              <UserRound v-else :size="18" />
            </button>
            <div class="feather-comment__copy">
              <header>
                <button type="button" @click="openProfile(post.profile_id)">
                  <strong>{{ post.display_name }}</strong>
                  <CheckCircle2
                    v-if="post.verified"
                    :size="13"
                    :aria-label="t('verified')"
                  />
                </button>
                <time>{{ relativeCommentTime(post.created_at) }}</time>
              </header>
              <p>
                <span v-if="leadingCommentMention(post)">{{
                  leadingCommentMention(post)
                }}</span>
                {{ visibleCommentBody(post) }}
              </p>
              <footer>
                <button type="button" @click="focusThreadReply(post)">
                  {{ t('reply') }}
                </button>
                <span v-if="post.like_count">{{
                  t('likesCount', { count: String(post.like_count) })
                }}</span>
                <button
                  type="button"
                  class="feather-comment__more"
                  :aria-label="t('moreActions')"
                  @click="openPostMenu(post)"
                >
                  <MoreHorizontal :size="16" />
                </button>
              </footer>
            </div>
            <button
              type="button"
              class="feather-comment__like"
              :class="{
                'is-liked': post.is_liked,
                'is-pulsing': commentLikePulseId === post.id,
              }"
              :aria-label="t('likeComment', { name: post.display_name })"
              @click="reactComment(post)"
            >
              <Heart
                :size="17"
                :fill="post.is_liked ? 'currentColor' : 'none'"
              />
            </button>
          </article>
        </section>

        <div class="feather-comment-composer">
          <div
            v-if="
              threadReplyTarget &&
              threadReplyTarget.id !== feather.thread.post.id
            "
            class="feather-comment-composer__target"
          >
            <span>{{
              t('replyingTo', { handle: threadReplyTarget.handle })
            }}</span>
            <SkyButton
              icon-only
              rounded
              tonal
              type="button"
              :aria-label="t('cancel')"
              @click="clearThreadReplyTarget"
            >
              <X :size="13" />
            </SkyButton>
          </div>
          <form ref="threadReplyInput" @submit.prevent="publishThreadReply">
            <SkyMessagebar
              v-model="threadReplyBody"
              :aria-label="t('addComment')"
              embedded
              :placeholder="t('addComment')"
              @keydown="handleCommentKeydown"
            >
              <template #left>
                <span class="feather-avatar feather-comment-composer__avatar">
                  <img
                    v-if="feather.profile?.avatar_url"
                    :src="feather.profile.avatar_url"
                    alt=""
                  />
                  <UserRound v-else :size="17" />
                </span>
              </template>
              <template #right>
                <SkyButton
                  icon-only
                  rounded
                  type="submit"
                  :disabled="!canReply"
                  class="feather-comment-composer__send"
                  :aria-label="t('postComment')"
                >
                  <Send :size="16" />
                </SkyButton>
              </template>
            </SkyMessagebar>
          </form>
          <span
            v-if="threadReplyBody.length > 320"
            class="feather-comment-composer__count"
            >{{ 360 - threadReplyBody.length }}</span
          >
        </div>
      </SkyScrollArea>

      <SkyScrollArea
        v-else-if="
          (screen === 'profile' || (screen === 'main' && tab === 'profile')) &&
          activeProfile
        "
        class="feather-scroll feather-profile-screen"
        :with-tabbar="screen === 'main'"
      >
        <SkyGlass :highlight="false" class="feather-profile-glass">
          <div class="feather-profile">
            <div class="feather-profile__cover">
              <span class="feather-profile__cover-title">
                <Feather :size="17" :stroke-width="2" />
                {{ activeProfile.display_name }}
              </span>
            </div>
            <div class="feather-profile__top">
              <div class="feather-profile__avatar">
                <img
                  v-if="activeProfile.avatar_url"
                  :src="activeProfile.avatar_url"
                  alt=""
                />
                <UserRound v-else :size="29" />
              </div>
              <SkyButton
                v-if="!activeProfile.is_owner"
                rounded
                small
                :tonal="activeProfile.is_following"
                class="feather-follow-button"
                :class="{
                  'feather-follow-button--pending': !activeProfile.is_following,
                  'feather-follow-button--following':
                    activeProfile.is_following,
                }"
                @click="followProfile(activeProfile)"
              >
                <SkyIcon v-if="!activeProfile.is_following"
                  ><UserPlus :size="14"
                /></SkyIcon>
                {{ activeProfile.is_following ? t('following') : t('follow') }}
              </SkyButton>
            </div>
            <div class="feather-profile__identity">
              <h1>
                {{ activeProfile.display_name }}
                <CheckCircle2 v-if="activeProfile.verified" :size="15" />
              </h1>
              <span class="feather-profile__handle"
                >@{{ activeProfile.handle }}</span
              >
              <p class="feather-profile__bio">
                {{ activeProfile.bio || t('noBio') }}
              </p>
              <div class="feather-profile__joined">
                <CalendarDays :size="14" />
                {{ t('joinedDate') }}
              </div>
            </div>
            <div class="feather-profile__stats">
              <span>
                <strong>{{ activeProfile.post_count }}</strong>
                <small>{{ t('posts') }}</small>
              </span>
              <button type="button" @click="openConnections('following')">
                <strong>{{ activeProfile.following }}</strong>
                <small>{{ t('followingCount') }}</small>
              </button>
              <button type="button" @click="openConnections('followers')">
                <strong>{{ activeProfile.followers }}</strong>
                <small>{{ t('followers') }}</small>
              </button>
            </div>
            <div v-if="activeProfile.is_owner" class="feather-profile__actions">
              <SkyButton
                outline
                rounded
                class="feather-profile-action"
                @click="shareProfile"
              >
                <Share2 :size="15" />
                <span>{{ t('shareProfile') }}</span>
              </SkyButton>
              <SkyButton
                rounded
                class="feather-primary feather-profile-action"
                @click="openEdit"
              >
                <PencilLine :size="15" />
                <span>{{ t('editProfile') }}</span>
              </SkyButton>
            </div>
          </div>
        </SkyGlass>
        <SkySegmented class="feather-profile-tabs" rounded strong>
          <SkySegmentedButton
            type="button"
            :active="profileView === 'posts'"
            :class="{ 'is-active': profileView === 'posts' }"
            @click="selectProfileView('posts')"
          >
            <AlignLeft :size="16" /> {{ t('posts') }}
          </SkySegmentedButton>
          <SkySegmentedButton
            type="button"
            :active="profileView === 'replies'"
            :class="{ 'is-active': profileView === 'replies' }"
            @click="selectProfileView('replies')"
          >
            <AtSign :size="17" />
          </SkySegmentedButton>
          <SkySegmentedButton
            v-if="activeProfile.is_owner"
            type="button"
            :active="profileView === 'bookmarks'"
            :class="{ 'is-active': profileView === 'bookmarks' }"
            :aria-label="t('bookmarks')"
            :title="t('bookmarks')"
            @click="selectProfileView('bookmarks')"
          >
            <Bookmark :size="17" />
          </SkySegmentedButton>
        </SkySegmented>
        <div
          v-if="profileView === 'bookmarks' && feather.bookmarksLoading"
          class="feather-network-loading"
        >
          <SkySpinner />
        </div>
        <div
          v-else-if="
            profileView === 'bookmarks' && !displayedProfilePosts.length
          "
          class="feather-empty"
        >
          <Bookmark :size="34" />
          <h2>{{ t('noBookmarks') }}</h2>
          <p>{{ t('noBookmarksBody') }}</p>
        </div>
        <FeatherPostCard
          v-for="post in displayedProfilePosts"
          v-show="profileView !== 'bookmarks' || !feather.bookmarksLoading"
          :key="post.id"
          :post="post"
          @follow="feather.followPost"
          @media="openMediaPreview"
          @menu="openPostMenu"
          @open="openThread"
          @profile="openProfile"
          @react="feather.react"
          @reply="openThread($event, true)"
          @share="sharePost"
        />
        <section
          v-if="
            activeProfile.is_owner &&
            profileView === 'posts' &&
            showSuggestions &&
            feather.suggestions.length
          "
          class="feather-profile-suggestions"
        >
          <h2>{{ t('people') }}</h2>
          <SkyScrollRail
            class="feather-profile-suggestions__rail"
            :label="t('people')"
          >
            <article
              v-for="person in feather.suggestions"
              :key="person.id"
              class="feather-profile-suggestion"
            >
              <button
                type="button"
                class="feather-profile-suggestion__profile"
                @click="openProfile(person.id)"
              >
                <span class="feather-avatar feather-profile-suggestion__avatar">
                  <img
                    v-if="person.avatar_url"
                    :src="person.avatar_url"
                    alt=""
                  />
                  <UserRound v-else :size="20" />
                </span>
                <span class="feather-profile-suggestion__identity">
                  <strong>{{ person.display_name }}</strong>
                  <small>@{{ person.handle }}</small>
                  <p>{{ person.bio || t('noBio') }}</p>
                </span>
              </button>
              <SkyButton
                rounded
                small
                :tonal="person.is_following"
                class="feather-follow-button"
                :class="{
                  'feather-follow-button--pending': !person.is_following,
                  'feather-follow-button--following': person.is_following,
                }"
                @click="followProfile(person)"
              >
                {{ person.is_following ? t('following') : t('follow') }}
              </SkyButton>
            </article>
          </SkyScrollRail>
        </section>
      </SkyScrollArea>

      <section v-else-if="screen === 'main'" class="feather-main">
        <div v-if="tab === 'home'" class="feather-feed-tabs">
          <SkySegmented class="feather-context-tabs">
            <SkySegmentedButton
              type="button"
              :active="feather.mode === 'for-you'"
              :class="{ 'is-active': feather.mode === 'for-you' }"
              @click="setFeedMode('for-you')"
              >{{ t('forYou') }}</SkySegmentedButton
            >
            <SkySegmentedButton
              type="button"
              :active="feather.mode === 'following'"
              :class="{ 'is-active': feather.mode === 'following' }"
              @click="setFeedMode('following')"
              >{{ t('following') }}</SkySegmentedButton
            >
          </SkySegmented>
        </div>

        <div v-if="tab === 'explore'" class="feather-explore-head">
          <SkySearchbar
            :value="search"
            class="feather-explore-search"
            :placeholder="t('postSearchPlaceholder')"
            @clear="search = ''"
            @input="search = inputValue($event)"
            @keyup.enter="runSearch"
          />
          <SkySegmented
            class="feather-explore-tabs"
            :active-index="exploreViewIndex"
            :aria-label="t('explore')"
            :item-count="exploreCategories.length"
            rounded
            strong
          >
            <SkySegmentedButton
              v-for="category in exploreCategories"
              :key="category"
              type="button"
              :active="exploreView === category"
              :class="{ 'is-active': exploreView === category }"
              @click="exploreView = category"
            >
              {{ t(`exploreTabs.${category}`) }}
            </SkySegmentedButton>
          </SkySegmented>
        </div>

        <div v-if="tab === 'activity'" class="feather-activity-head">
          <SkySegmented class="feather-context-tabs">
            <SkySegmentedButton
              type="button"
              :active="activityView === 'all'"
              :class="{ 'is-active': activityView === 'all' }"
              @click="activityView = 'all'"
            >
              {{ t('all') }}
            </SkySegmentedButton>
            <SkySegmentedButton
              type="button"
              :active="activityView === 'mentions'"
              :class="{ 'is-active': activityView === 'mentions' }"
              @click="activityView = 'mentions'"
            >
              {{ t('mentions') }}
            </SkySegmentedButton>
          </SkySegmented>
        </div>

        <SkyScrollArea
          v-if="tab === 'network'"
          class="feather-scroll feather-network"
          with-tabbar
        >
          <SkyGlass :highlight="false" class="feather-network-glass">
            <header class="feather-network__hero">
              <div>
                <small>{{ t('network') }}</small>
                <h1>{{ t('networkTitle') }}</h1>
                <p>{{ t('networkBody') }}</p>
              </div>
              <UsersRound :size="35" />
            </header>
          </SkyGlass>
          <SkySearchbar
            :value="networkSearch"
            class="feather-network-search"
            :placeholder="t('networkSearchPlaceholder')"
            @clear="networkSearch = ''"
            @input="networkSearch = inputValue($event)"
            @keyup.enter="runNetworkSearch"
          />
          <div v-if="feather.networkLoading" class="feather-network-loading">
            <SkySpinner />
          </div>
          <template v-else>
            <section
              v-for="section in networkSections"
              :key="section.key"
              class="feather-network-section"
            >
              <h2 class="feather-section-title">{{ section.title }}</h2>
              <SkyBlock
                v-if="!section.profiles.length"
                strong
                inset
                class="feather-network-empty"
              >
                <Search :size="25" />
                <strong>{{
                  section.key === 'results'
                    ? t('noPeopleFound')
                    : t('noSuggestions')
                }}</strong>
                <p>
                  {{
                    section.key === 'results'
                      ? t('noPeopleFoundBody')
                      : t('noSuggestionsBody')
                  }}
                </p>
              </SkyBlock>
              <SkyList v-else strong inset class="feather-network-list">
                <SkyListItem
                  v-for="person in section.profiles"
                  :key="person.id"
                  class="feather-network-person"
                  content-class="feather-network-person__content"
                  inner-class="feather-network-person__inner"
                  media-class="feather-network-person__media"
                  title-wrap-class="feather-network-person__title-wrap"
                >
                  <template #media>
                    <button
                      type="button"
                      class="feather-network-person__avatar"
                      :aria-label="person.display_name"
                      @click="openProfile(person.id)"
                    >
                      <span class="feather-avatar">
                        <img
                          v-if="person.avatar_url"
                          :src="person.avatar_url"
                          alt=""
                        />
                        <UserRound v-else :size="20" />
                      </span>
                    </button>
                  </template>
                  <template #title>
                    <button
                      type="button"
                      class="feather-network-person__name"
                      @click="openProfile(person.id)"
                    >
                      <span>{{ person.display_name }}</span>
                      <CheckCircle2
                        v-if="person.verified"
                        :size="13"
                        :aria-label="t('verified')"
                      />
                    </button>
                  </template>
                  <template #subtitle
                    ><span class="feather-network-person__handle"
                      >@{{ person.handle }}</span
                    ></template
                  >
                  <template #text
                    ><span class="feather-network-person__bio">{{
                      person.bio || t('noBio')
                    }}</span></template
                  >
                  <template #footer>
                    <span class="feather-network-person__stats">
                      <span
                        ><strong>{{ person.followers }}</strong>
                        {{ t('followers') }}</span
                      >
                      <i></i>
                      <span>{{
                        t('postsCount', { count: String(person.post_count) })
                      }}</span>
                    </span>
                  </template>
                  <template #after>
                    <SkyButton
                      inline
                      rounded
                      small
                      :tonal="person.is_following"
                      class="feather-follow-button feather-network-person__follow"
                      :class="{
                        'feather-follow-button--pending': !person.is_following,
                        'feather-follow-button--following': person.is_following,
                      }"
                      @click="followProfile(person)"
                    >
                      <SkyIcon>
                        <CheckCircle2 v-if="person.is_following" :size="13" />
                        <UserPlus v-else :size="13" />
                      </SkyIcon>
                      {{ person.is_following ? t('following') : t('follow') }}
                    </SkyButton>
                  </template>
                </SkyListItem>
              </SkyList>
            </section>
          </template>
        </SkyScrollArea>

        <SkyScrollArea
          v-else-if="tab === 'explore' && !search.trim()"
          class="feather-scroll feather-trends"
          with-tabbar
        >
          <div v-if="!feather.topics.length" class="feather-empty">
            <Search :size="34" />
            <h2>{{ t('noTrendingHashtags') }}</h2>
            <p>{{ t('noTrendingHashtagsBody') }}</p>
          </div>
          <button
            v-for="topic in feather.topics"
            :key="topic.tag"
            type="button"
            class="feather-trend"
            @click="selectTopic(topic.tag)"
          >
            <span>{{ t(`trendKinds.${exploreView}`) }}</span>
            <strong>{{ topic.tag }}</strong>
            <small>{{ t('postsCount', { count: String(topic.count) }) }}</small>
            <b>•••</b>
          </button>
        </SkyScrollArea>

        <SkyScrollArea
          v-else-if="tab === 'activity'"
          class="feather-scroll"
          with-tabbar
        >
          <div v-if="!displayedActivities.length" class="feather-empty">
            <Bell :size="34" />
            <h2>{{ t('noActivity') }}</h2>
            <p>{{ t('activityBody') }}</p>
          </div>
          <button
            v-for="item in displayedActivities"
            :key="item.id"
            class="feather-activity"
            type="button"
            @click="
              item.post_id
                ? feather
                    .loadThread(item.post_id)
                    .then((ok) => ok && (screen = 'thread'))
                : openProfile(item.profile_id)
            "
          >
            <div class="feather-avatar">
              <img v-if="item.avatar_url" :src="item.avatar_url" alt="" />
              <UserRound v-else :size="20" />
            </div>
            <p>
              <strong>{{ item.display_name }}</strong>
              {{ t(`activityKinds.${item.kind}`) }}
            </p>
          </button>
        </SkyScrollArea>

        <SkyScrollArea v-else class="feather-scroll" with-tabbar>
          <div
            v-if="tab === 'explore' && feather.exploreLoading"
            class="feather-network-loading"
          >
            <SkySpinner />
          </div>
          <div
            v-else-if="!displayedPosts.length && !feather.loading"
            class="feather-empty"
          >
            <Search v-if="tab === 'explore'" :size="34" />
            <Feather v-else :size="34" />
            <h2>
              {{ tab === 'explore' ? t('emptyExplore') : t('emptyFeed') }}
            </h2>
            <p>
              {{
                tab === 'explore' ? t('emptyExploreBody') : t('emptyFeedBody')
              }}
            </p>
          </div>
          <FeatherPostCard
            v-for="post in displayedPosts"
            v-show="tab !== 'explore' || !feather.exploreLoading"
            :key="post.id"
            :post="post"
            @follow="feather.followPost"
            @media="openMediaPreview"
            @menu="openPostMenu"
            @open="openThread"
            @profile="openProfile"
            @react="feather.react"
            @reply="openThread($event, true)"
            @share="sharePost"
          />
          <template v-if="tab === 'explore' && feather.suggestions.length">
            <h2 class="feather-section-title">{{ t('people') }}</h2>
            <div
              v-for="person in feather.suggestions"
              :key="person.id"
              class="feather-person"
            >
              <div class="feather-avatar">
                <img
                  v-if="person.avatar_url"
                  :src="person.avatar_url"
                  alt=""
                /><UserRound v-else :size="20" />
              </div>
              <button type="button" @click="openProfile(person.id)">
                <strong>{{ person.display_name }}</strong
                ><span>@{{ person.handle }}</span>
              </button>
              <SkyButton
                rounded
                small
                :tonal="person.is_following"
                class="feather-follow-button"
                :class="{
                  'feather-follow-button--pending': !person.is_following,
                  'feather-follow-button--following': person.is_following,
                }"
                @click="followProfile(person)"
              >
                <SkyIcon v-if="!person.is_following"
                  ><UserPlus :size="14"
                /></SkyIcon>
                {{ person.is_following ? t('following') : t('follow') }}
              </SkyButton>
            </div>
          </template>
        </SkyScrollArea>
      </section>

      <SkyPillNavigation
        v-if="screen === 'main'"
        class="feather-navigation"
        :label="t('name')"
        layout="full"
      >
        <SkySegmented
          class="feather-navigation__segments"
          :active-index="tabIndex"
          :aria-label="t('name')"
          :item-count="tabOrder.length"
          navigation
          strong
        >
          <SkySegmentedButton
            :active="tab === 'home'"
            class="feather-navigation__button"
            @click="selectTab('home')"
          >
            <Home :size="20" :fill="tab === 'home' ? 'currentColor' : 'none'" />
            <small>{{ t('home') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="tab === 'explore'"
            class="feather-navigation__button"
            @click="selectTab('explore')"
          >
            <Search :size="20" />
            <small>{{ t('explore') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="tab === 'network'"
            class="feather-navigation__button"
            @click="selectTab('network')"
          >
            <UsersRound
              :size="20"
              :fill="tab === 'network' ? 'currentColor' : 'none'"
            />
            <small>{{ t('network') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="tab === 'activity'"
            class="feather-navigation__button"
            @click="selectTab('activity')"
          >
            <span class="feather-navigation__badge-anchor">
              <Bell
                :size="20"
                :fill="tab === 'activity' ? 'currentColor' : 'none'"
              />
              <b v-if="unreadActivities">{{ unreadActivities }}</b>
            </span>
            <small>{{ t('activityNav') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="tab === 'profile'"
            class="feather-navigation__button"
            @click="selectTab('profile')"
          >
            <UserRound
              :size="20"
              :fill="tab === 'profile' ? 'currentColor' : 'none'"
            />
            <small>{{ t('profile') }}</small>
          </SkySegmentedButton>
        </SkySegmented>
      </SkyPillNavigation>
      <SkyFab
        v-if="screen === 'main'"
        component="button"
        type="button"
        class="feather-compose-fab"
        variant="glass"
        :aria-label="t('newPost')"
        @click="openComposer()"
      >
        <template #icon><Plus :size="20" /></template>
      </SkyFab>
    </template>

    <AccountLogoutDialog
      v-model:opened="logoutDialogOpen"
      app-id="feather"
      :app-name="t('name')"
    />

    <SkySheet :opened="settingsOpen" @backdropclick="settingsOpen = false">
      <SkyBlock strong inset class="feather-settings-sheet">
        <header>
          <div>
            <span>{{ t('settingsEyebrow') }}</span>
            <h2>{{ t('settings') }}</h2>
          </div>
          <SkyButton clear rounded @click="settingsOpen = false">
            {{ t('done') }}
          </SkyButton>
        </header>
        <SkyList strong inset>
          <SkyListItem :title="t('compactMode')" :text="t('compactModeBody')">
            <template #after>
              <SkyToggle
                :checked="compactMode"
                :aria-label="t('compactMode')"
                @change="compactMode = !compactMode"
              />
            </template>
          </SkyListItem>
          <SkyListItem
            :title="t('showSuggestions')"
            :text="t('showSuggestionsBody')"
          >
            <template #after>
              <SkyToggle
                :checked="showSuggestions"
                :aria-label="t('showSuggestions')"
                @change="showSuggestions = !showSuggestions"
              />
            </template>
          </SkyListItem>
        </SkyList>
      </SkyBlock>
    </SkySheet>

    <div class="feather-post-menu">
      <SkySheet
        :opened="menuPost !== null && !reportOpen"
        :aria-label="t('moreActions')"
        swipe-to-close
        grabber-clickable
        :grabber-label="t('cancel')"
        @backdropclick="closePostMenu"
        @escape="closePostMenu"
        @grabberclick="closePostMenu"
        @swipeclose="closePostMenu"
      >
        <section v-if="menuPost" class="feather-post-menu__content">
          <header class="feather-post-menu__header" data-sky-sheet-drag-handle>
            <span>@{{ menuPost.handle }}</span>
            <h2>{{ t('moreActions') }}</h2>
          </header>
          <div class="feather-post-menu__group">
            <SkyButton
              v-if="menuPost?.is_owner"
              block
              clear
              class="feather-post-menu__action feather-post-menu__action--danger"
              @click="deletePost"
            >
              <Trash2 :size="18" />
              <span>{{ t('delete') }}</span>
            </SkyButton>
            <template v-else>
              <SkyButton
                block
                clear
                class="feather-post-menu__action"
                @click="openPostReport"
              >
                <Flag :size="18" />
                <span>{{ t('report') }}</span>
              </SkyButton>
              <SkyButton
                block
                clear
                class="feather-post-menu__action feather-post-menu__action--danger"
                @click="blockPostAuthor"
              >
                <Ban :size="18" />
                <span>{{
                  t('block', { handle: menuPost?.handle ?? '' })
                }}</span>
              </SkyButton>
            </template>
          </div>
        </section>
      </SkySheet>
    </div>

    <SkySheet :opened="reportOpen" @backdropclick="closePostReport">
      <SkyBlock strong inset class="feather-report">
        <h2>{{ t('reportTitle') }}</h2>
        <p>{{ t('reportBody') }}</p>
        <select v-model="reportReason">
          <option
            v-for="reason in [
              'spam',
              'harassment',
              'dangerous',
              'illegal',
              'other',
            ]"
            :key="reason"
            :value="reason"
          >
            {{ t(`reasons.${reason}`) }}
          </option>
        </select>
        <textarea
          v-model="reportDetails"
          maxlength="500"
          :placeholder="t('bioPlaceholder')"
        ></textarea>
        <SkyButton
          large
          rounded
          class="feather-primary"
          @click="submitReport"
          >{{ t('reportSubmit') }}</SkyButton
        >
        <SkyButton large clear @click="closePostReport">
          {{ t('cancel') }}
        </SkyButton>
      </SkyBlock>
    </SkySheet>

    <div
      v-if="mediaPreview && previewMedia"
      class="feather-media-preview"
      role="dialog"
      aria-modal="true"
      :aria-label="t('imagePreview')"
      @click="closeMediaPreview"
    >
      <img
        :src="previewMedia.url"
        :alt="t('postImage', { number: String(mediaPreview.index + 1) })"
        @click.stop
      />
      <template v-if="mediaPreview.items.length > 1">
        <SkyButton
          glass
          icon-only
          rounded
          class="feather-media-preview__arrow feather-media-preview__arrow--left"
          :aria-label="t('previousImage')"
          @click.stop="moveMediaPreview(-1)"
        >
          <ChevronLeft :size="20" :stroke-width="2.8" />
        </SkyButton>
        <SkyButton
          glass
          icon-only
          rounded
          class="feather-media-preview__arrow feather-media-preview__arrow--right"
          :aria-label="t('nextImage')"
          @click.stop="moveMediaPreview(1)"
        >
          <ChevronRight :size="20" :stroke-width="2.8" />
        </SkyButton>
        <span class="feather-media-preview__count">
          {{ mediaPreview.index + 1 }} / {{ mediaPreview.items.length }}
        </span>
      </template>
    </div>

    <SkyNotification :opened="Boolean(feedback)" :text="feedback" />
  </SkyAppPage>
</template>

<style scoped>
.feather-app {
  --feather-blue: #438cf5;
  --feather-blue-dark: #2867d8;
  --sky-app-accent: var(--feather-blue);
  --sky-app-accent-soft: rgba(67, 140, 245, 0.15);
  --color-primary: var(--feather-blue);
  background: #fff;
  color: #111923;
}
.feather-media-preview {
  position: absolute;
  z-index: 120;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 64px 12px 42px;
  background: rgb(0 0 0 / 92%);
  cursor: zoom-out;
}
.feather-media-preview > img {
  display: block;
  max-width: 100%;
  max-height: 100%;
  border-radius: 12px;
  object-fit: contain;
  box-shadow: 0 18px 50px rgb(0 0 0 / 55%);
  cursor: default;
}
.feather-media-preview__arrow {
  --sky-button-text: #fff;
  position: absolute;
  top: 50%;
  width: 44px !important;
  min-width: 44px;
  height: 44px;
  min-height: 44px;
  padding: 0;
  color: #fff !important;
  transform: translateY(-50%);
}
.feather-media-preview__arrow--left {
  left: 10px;
}
.feather-media-preview__arrow--right {
  right: 10px;
}
.feather-media-preview__count {
  position: absolute;
  bottom: 48px;
  left: 50%;
  border: 1px solid rgb(255 255 255 / 14%);
  border-radius: 999px;
  padding: 5px 10px;
  color: #fff;
  background: rgb(22 27 34 / 78%);
  backdrop-filter: blur(14px);
  font-size: 11px;
  font-weight: 700;
  transform: translateX(-50%);
}
:global(.dark) .feather-app {
  background: #090d12;
  color: #f4f7fa;
}
.feather-navbar {
  --sky-navbar-glass: color-mix(in srgb, #fff 91%, transparent);
  --sky-safe-area-top: 46px;
  flex: 0 0 auto;
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 12%, transparent);
  backdrop-filter: blur(18px);
}
:global(.dark) .feather-navbar {
  --sky-navbar-glass: color-mix(in srgb, #090d12 91%, transparent);
}
.feather-explore-search {
  width: auto;
  margin: 10px 12px 8px;
}
.feather-explore-search :deep(form) {
  min-height: 32px;
}
.feather-primary {
  --sky-app-accent: var(--feather-blue);
  --sky-button-text: #fff;
}
.feather-loading,
.feather-welcome {
  display: flex;
  min-height: 75%;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 13px;
  padding: 30px;
  text-align: center;
}
.feather-loading {
  flex-direction: row;
  font-size: 13px;
}
.feather-welcome h1,
.feather-onboarding h1 {
  margin: 4px 0 0;
  font-size: 27px;
  letter-spacing: -0.8px;
}
.feather-welcome p,
.feather-onboarding > p {
  max-width: 290px;
  margin: 0 0 12px;
  color: #738092;
  font-size: 13px;
  line-height: 1.45;
}
.feather-welcome__mark {
  display: grid;
  place-items: center;
  width: 86px;
  height: 86px;
  border-radius: 27px;
  color: #fff;
  background: linear-gradient(145deg, #76d0ff, #438cf5 55%, #2757d8);
  box-shadow: 0 15px 35px rgb(45 111 224 / 25%);
}
.feather-auth {
  --auth-accent: var(--feather-blue);
  --panel: #18212b;
  min-height: 100%;
  overflow-y: auto;
  padding: 68px 15px 34px;
  color: #f4f7fa;
  background:
    radial-gradient(circle at 85% 5%, rgb(90 183 255 / 18%), transparent 31%),
    radial-gradient(circle at 0 42%, rgb(67 140 245 / 8%), transparent 36%),
    #0f151b;
}
.feather-auth__hero {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 4px 3px 18px;
}
.feather-auth__hero .feather-welcome__mark {
  width: 64px;
  height: 64px;
  flex: 0 0 64px;
  border-radius: 21px;
  box-shadow: 0 12px 27px rgb(45 111 224 / 24%);
}
.feather-auth__hero span {
  color: var(--feather-blue);
  font-size: 9px;
  font-weight: 800;
  letter-spacing: 1.2px;
  text-transform: uppercase;
}
.feather-auth__hero h1 {
  margin: 2px 0 1px;
  font-size: 24px;
  letter-spacing: -0.7px;
}
.feather-auth__hero p {
  margin: 0;
  color: #738092;
  font-size: 10px;
  line-height: 1.35;
}
.feather-auth__card {
  padding: 13px;
  border: 0.5px solid rgb(67 140 245 / 18%);
  border-radius: 22px;
  background: rgb(255 255 255 / 86%);
  box-shadow: 0 18px 42px rgb(31 66 120 / 12%);
  backdrop-filter: blur(20px);
}
:global(.dark) .feather-auth__card {
  border-color: rgb(118 192 255 / 16%);
  background: rgb(18 25 34 / 88%);
  box-shadow: 0 18px 42px rgb(0 0 0 / 25%);
}
.feather-auth__modes {
  margin-bottom: 14px;
}
.feather-auth__modes :deep(.sky-segmented-button--active) {
  color: var(--feather-blue);
}
.feather-auth__copy {
  padding: 0 3px 8px;
}
.feather-auth__copy h2 {
  margin: 0 0 3px;
  font-size: 17px;
  letter-spacing: -0.25px;
}
.feather-auth__copy p {
  margin: 0;
  color: #788493;
  font-size: 10px;
  line-height: 1.4;
}
.feather-auth__fields {
  margin: 4px 0 10px;
}
.feather-auth__fields :deep(.sky-list-item__media) {
  color: var(--feather-blue);
}
.feather-auth__photo {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 2px 5px 10px;
  text-align: left;
}
.feather-auth__photo > span {
  display: grid;
  width: 62px;
  height: 62px;
  flex: none;
  place-items: center;
  overflow: hidden;
  border-radius: 50%;
  color: var(--feather-blue);
  background: rgb(67 140 245 / 10%);
}
.feather-auth__photo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.feather-auth__photo > div {
  display: grid;
  min-width: 0;
  flex: 1;
  gap: 6px;
}
.feather-auth__photo :deep(.sky-button) {
  min-height: 34px;
  justify-content: flex-start;
  gap: 6px;
  font-size: 11px;
}
.feather-auth__error {
  margin: 0 4px 10px;
  border-radius: 10px;
  padding: 8px 10px;
  color: #c43d52;
  background: rgb(240 79 101 / 10%);
  font-size: 10px;
  line-height: 1.35;
}
.feather-auth__submit {
  width: 100%;
  min-height: 43px;
  box-shadow: 0 9px 20px rgb(67 140 245 / 25%);
}
.feather-auth__switch {
  margin: 12px 0 1px;
  color: #7a8695;
  font-size: 10px;
  text-align: center;
}
.feather-auth__switch button {
  border: 0;
  padding: 0 2px;
  color: var(--feather-blue);
  background: transparent;
  font: inherit;
  font-weight: 750;
}
.feather-auth__trust {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 13px 15px 0;
  color: #7b8796;
  font-size: 9px;
  line-height: 1.35;
  text-align: center;
}
.feather-auth__trust svg {
  flex: 0 0 auto;
  color: #39a87b;
}
.feather-onboarding {
  min-height: 100%;
  overflow-y: auto;
  padding: 55px 14px 30px;
  text-align: center;
}
.feather-onboarding .feather-welcome__mark {
  width: 80px;
  height: 80px;
  margin: 0 auto;
  border-radius: 25px;
  box-shadow: 0 14px 34px rgb(45 111 224 / 28%);
}
.feather-onboarding h1 {
  margin-top: 7px;
  font-size: 30px;
  letter-spacing: -0.9px;
}
.feather-onboarding > p {
  max-width: 310px;
  margin-bottom: 14px;
  font-size: 14px;
  line-height: 1.5;
}
.feather-onboarding__button {
  width: calc(100% - 20px);
  min-height: 46px;
  margin: 17px 10px 0;
  font-size: 14px;
  font-weight: 750;
  box-shadow: 0 10px 24px rgb(67 140 245 / 24%);
}
.feather-onboarding__button:disabled {
  --sky-app-accent: rgb(67 140 245 / 13%);
  --sky-button-text: #71839a;
  color: #71839a !important;
  background: rgb(67 140 245 / 13%) !important;
  opacity: 1;
  box-shadow: none;
}
.feather-onboarding__step {
  display: inline-block;
  margin-top: 15px;
  color: var(--feather-blue);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.15px;
  text-transform: uppercase;
}
.feather-onboarding__account {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 2px 9px;
  margin: 3px 10px 15px;
  border: 1px solid rgb(44 155 109 / 12%);
  border-radius: 15px;
  padding: 11px 13px;
  color: #2c9b6d;
  background: rgb(44 155 109 / 9%);
  text-align: left;
}
.feather-onboarding__account svg {
  grid-row: span 2;
}
.feather-onboarding__account span {
  font-size: 11px;
  font-weight: 750;
}
.feather-onboarding__account strong {
  overflow: hidden;
  color: #6f7c8b;
  font-size: 10.5px;
  font-weight: 500;
  text-overflow: ellipsis;
}
.feather-onboarding__form {
  margin: 0 2px;
  border: 1px solid rgb(67 140 245 / 13%);
  border-radius: 23px;
  padding: 13px 10px 10px;
  background: rgb(67 140 245 / 4%);
  box-shadow: 0 14px 34px rgb(31 66 120 / 9%);
  text-align: left;
}
.feather-onboarding__form-head {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 0 8px 9px;
}
.feather-onboarding__form-head > span {
  display: grid;
  width: 38px;
  height: 38px;
  flex: 0 0 38px;
  place-items: center;
  border-radius: 13px;
  color: var(--feather-blue);
  background: rgb(67 140 245 / 12%);
}
.feather-onboarding__form-head h2 {
  margin: 0 0 2px;
  font-size: 15px;
  letter-spacing: -0.2px;
}
.feather-onboarding__form-head p {
  margin: 0;
  color: #738092;
  font-size: 11px;
  line-height: 1.35;
}
.feather-onboarding__fields {
  margin: 0;
}
.feather-onboarding__fields :deep(.sky-list-item__media) {
  color: #72b5ff;
}
.feather-onboarding__fields :deep(.sky-field .text-xs) {
  font-size: 12px;
  line-height: 1.35;
}
.feather-onboarding__fields :deep(input),
.feather-onboarding__fields :deep(textarea) {
  font-size: 15px;
  line-height: 1.4;
}
.feather-onboarding__fields :deep(textarea) {
  min-height: 54px;
  resize: none;
}
.feather-main {
  display: flex;
  height: 100%;
  min-height: 0;
  flex-direction: column;
  padding-bottom: 0;
}
.feather-scroll {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
}
.feather-feed-tabs {
  padding: 0;
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 11%, transparent);
}
.feather-explore-head {
  padding: 0;
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 11%, transparent);
}
.feather-activity-head {
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 11%, transparent);
}
.feather-context-tabs,
.feather-profile-tabs {
  background: transparent;
}
.feather-context-tabs :deep(.sky-button),
.feather-profile-tabs :deep(.sky-button) {
  min-height: 41px;
  overflow: visible;
  border-radius: 0;
  color: #6f7b89;
  background: transparent;
  font-size: 12px;
  font-weight: 650;
}
.feather-context-tabs :deep(.sky-button.is-active),
.feather-profile-tabs :deep(.sky-button.is-active) {
  color: currentColor;
  font-weight: 750;
}
.feather-context-tabs :deep(.sky-button.is-active)::after,
.feather-profile-tabs :deep(.sky-button.is-active)::after {
  position: absolute;
  right: 22%;
  bottom: 0;
  left: 22%;
  height: 3px;
  border-radius: 3px 3px 0 0;
  background: var(--feather-blue);
  content: '';
}
.feather-trends__header {
  padding: 17px 14px 9px;
}
.feather-trends__header span {
  color: #738091;
  font-size: 11px;
}
.feather-trends__header h2 {
  margin: 2px 0 0;
  font-size: 20px;
  letter-spacing: -0.5px;
}
.feather-trend {
  display: flex;
  width: 100%;
  flex-direction: column;
  border: 0;
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 11%, transparent);
  padding: 12px 14px;
  color: inherit;
  background: transparent;
  text-align: left;
}
.feather-trend span,
.feather-trend small {
  color: #778391;
  font-size: 10px;
}
.feather-trend strong {
  margin: 2px 0;
  font-size: 14px;
}
.feather-trend:active {
  background: color-mix(in srgb, currentColor 5%, transparent);
}
.feather-empty {
  display: flex;
  align-items: center;
  flex-direction: column;
  padding: 65px 35px;
  color: #8290a1;
  text-align: center;
}
.feather-empty h2 {
  margin: 13px 0 4px;
  color: inherit;
  font-size: 16px;
}
.feather-empty p {
  margin: 0;
  font-size: 12px;
  line-height: 1.4;
}
.feather-navigation__badge-anchor {
  position: relative;
}
.feather-navigation__badge-anchor b {
  position: absolute;
  top: -6px;
  right: -8px;
  min-width: 14px;
  border-radius: 8px;
  padding: 1px 3px;
  color: #fff;
  background: #f04f65;
  font-size: 8px;
}
.feather-composer {
  min-height: calc(100% - 44px);
  padding: 12px 14px;
}
.feather-replying {
  margin: 2px 0 10px 48px;
  color: var(--feather-blue);
  font-size: 11px;
}
.feather-composer__row {
  display: flex;
  gap: 10px;
}
.feather-compose-avatar {
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  overflow: hidden;
  border-radius: 50%;
  color: #fff;
  background: linear-gradient(145deg, #71c8ff, #377be7);
}
.feather-compose-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.feather-composer textarea {
  width: 100%;
  min-height: 165px;
  resize: none;
  border: 0;
  padding: 8px 0;
  outline: none;
  color: inherit;
  background: transparent;
  font: inherit;
  font-size: 17px;
  line-height: 1.4;
}
.feather-compose-media {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 4px;
  margin: 5px 0 8px 52px;
}
.feather-compose-media > div {
  position: relative;
  overflow: hidden;
  border-radius: 12px;
}
.feather-compose-media img {
  width: 100%;
  height: 115px;
  object-fit: cover;
}
.feather-compose-media button {
  position: absolute;
  top: 5px;
  right: 5px;
  display: grid;
  place-items: center;
  width: 24px;
  height: 24px;
  border: 0;
  border-radius: 50%;
  color: #fff;
  background: rgb(0 0 0 / 65%);
}
.feather-composer__tools {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-left: 52px;
  border-top: 0.5px solid color-mix(in srgb, currentColor 12%, transparent);
  color: #7e8996;
  font-size: 10px;
}
.feather-composer__tools :deep(.sky-button) {
  color: var(--feather-blue);
  font-size: 11px;
}
.feather-section-title {
  margin: 0;
  padding: 13px 14px 8px;
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 12%, transparent);
  font-size: 14px;
}
.feather-profile__cover {
  height: 104px;
  background: linear-gradient(135deg, #bceaff, #69baf8 53%, #3a78e5);
}
.feather-profile {
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 12%, transparent);
}
.feather-profile__top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  height: 50px;
  padding: 0 14px;
}
.feather-profile__top :deep(.sky-button) {
  margin-top: 9px;
}
.feather-profile__avatar {
  display: grid;
  place-items: center;
  width: 76px;
  height: 76px;
  flex: 0 0 76px;
  overflow: hidden;
  transform: translateY(-38px);
  border: 3px solid #fff;
  border-radius: 50%;
  color: #fff;
  background: linear-gradient(145deg, #71c8ff, #377be7);
}
:global(.dark) .feather-profile__avatar {
  border-color: #090d12;
}
.feather-profile__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.feather-profile__identity h1 {
  display: flex;
  align-items: center;
  gap: 4px;
  margin: 0;
  font-size: 20px;
  letter-spacing: -0.45px;
}
.feather-profile__identity h1 svg {
  color: var(--feather-blue);
}
.feather-profile__identity {
  padding: 3px 14px 0;
}
.feather-profile__handle {
  display: block;
  margin-top: 1px;
  color: #7c8795;
  font-size: 12px;
}
.feather-profile__bio {
  margin: 10px 0 8px;
  font-size: 13px;
  line-height: 1.45;
}
.feather-profile__stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 6px;
  padding: 0 14px 13px;
  color: #7c8795;
  font-size: 12px;
}
.feather-profile__stats span,
.feather-profile__stats button {
  display: flex;
  min-width: 0;
  flex-direction: column;
  align-items: center;
  border: 0;
  border-radius: 11px;
  padding: 8px 4px;
  color: inherit;
  background: color-mix(in srgb, currentColor 7%, transparent);
  font: inherit;
  text-align: center;
}
.feather-profile__stats button {
  cursor: pointer;
  transition:
    color 150ms ease,
    transform 150ms ease,
    background-color 150ms ease;
}
.feather-profile__stats button:active {
  transform: scale(0.96);
  color: var(--feather-blue);
  background: color-mix(in srgb, var(--feather-blue) 13%, transparent);
}
.feather-profile__stats strong {
  color: currentColor;
  font-size: 15px;
  line-height: 18px;
}
.feather-profile__stats small {
  max-width: 100%;
  overflow: hidden;
  font-size: 9.5px;
  line-height: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-profile-tabs {
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 11%, transparent);
}
.feather-profile__avatar--edit {
  margin: 60px auto 15px;
  transform: none;
}
.feather-activity,
.feather-person {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  border: 0;
  border-bottom: 0.5px solid color-mix(in srgb, currentColor 12%, transparent);
  padding: 12px 14px;
  color: inherit;
  background: transparent;
  text-align: left;
}
.feather-avatar {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  flex: 0 0 40px;
  overflow: hidden;
  border-radius: 50%;
  color: #fff;
  background: linear-gradient(145deg, #71c8ff, #377be7);
}
.feather-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.feather-activity p {
  margin: 0;
  font-size: 13px;
  line-height: 1.4;
}
.feather-person > button {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  border: 0;
  color: inherit;
  background: transparent;
  text-align: left;
}
.feather-person span {
  color: #7c8795;
  font-size: 11.5px;
}
.feather-person strong {
  overflow: hidden;
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-report {
  display: grid;
  gap: 8px;
  padding: 14px;
}
.feather-report h2 {
  margin: 0;
  font-size: 17px;
}
.feather-report p {
  margin: 0;
  color: #7c8795;
  font-size: 11px;
}
.feather-report select,
.feather-report textarea {
  width: 100%;
  border: 0.5px solid color-mix(in srgb, currentColor 20%, transparent);
  border-radius: 10px;
  padding: 10px;
  color: inherit;
  background: color-mix(in srgb, currentColor 5%, transparent);
  font: inherit;
  font-size: 12px;
}
.feather-report textarea {
  min-height: 70px;
  resize: none;
}

/* Feather's signed-in product surface follows the supplied X iOS references. */
.dark.feather-app {
  --feather-blue: #1d9bf0;
  --feather-border: #2f3336;
  --feather-muted: #71767b;
  display: flex;
  flex-direction: column;
  padding: 0 0 24px;
  overflow: hidden;
  background: #000;
  color: #e7e9ea;
}
.dark.feather-app .feather-navbar {
  --sky-navbar-glass: color-mix(in srgb, #000 90%, transparent);
  --sky-safe-area-top: 46px;
  border-bottom-color: var(--feather-border);
  background: color-mix(in srgb, #000 88%, transparent);
  backdrop-filter: blur(18px);
}
.dark.feather-app .feather-explore-search {
  width: auto;
}
.dark.feather-app .feather-explore-search :deep(form) {
  min-height: 36px;
  border-radius: 999px;
  color: #e7e9ea;
  background: #202327;
}
.dark.feather-app .feather-main {
  height: auto;
  flex: 1;
  padding-bottom: 0;
  background: #000;
}
.dark.feather-app .feather-scroll {
  overscroll-behavior: contain;
  scrollbar-width: none;
}
.dark.feather-app .feather-scroll::-webkit-scrollbar {
  display: none;
}
.dark.feather-app .feather-feed-tabs,
.dark.feather-app .feather-explore-head,
.dark.feather-app .feather-activity-head,
.dark.feather-app .feather-profile-tabs {
  border-bottom: 1px solid var(--feather-border);
  background: #000;
}
.dark.feather-app .feather-context-tabs,
.dark.feather-app .feather-profile-tabs {
  min-width: 100%;
  padding: 0;
}
.dark.feather-app .feather-context-tabs :deep(.sky-button),
.dark.feather-app .feather-profile-tabs :deep(.sky-button) {
  min-height: 46px;
  border-radius: 0;
  color: var(--feather-muted);
  background: transparent;
  font-size: 13px;
  font-weight: 750;
  white-space: nowrap;
}
.dark.feather-app .feather-context-tabs :deep(.sky-button.is-active),
.dark.feather-app .feather-profile-tabs :deep(.sky-button.is-active) {
  color: #e7e9ea;
}
.dark.feather-app .feather-context-tabs :deep(.sky-button.is-active)::after,
.dark.feather-app .feather-profile-tabs :deep(.sky-button.is-active)::after {
  right: 20%;
  left: 20%;
  height: 3px;
  background: #eff3f4;
}
.dark.feather-app .feather-explore-tabs {
  display: flex;
  justify-content: flex-start !important;
  overflow-x: auto !important;
  overflow-y: hidden !important;
  scrollbar-width: none;
}
.dark.feather-app .feather-explore-tabs :deep(.sky-button) {
  width: auto !important;
  min-width: 92px;
  flex: 0 0 auto !important;
}
.dark.feather-app .feather-explore-tabs::-webkit-scrollbar {
  display: none;
}
.dark.feather-app .feather-trend {
  position: relative;
  min-height: 83px;
  border-bottom: 1px solid var(--feather-border);
  padding: 14px 42px 13px 14px;
  color: #e7e9ea;
  background: #000;
}
.dark.feather-app .feather-trend span,
.dark.feather-app .feather-trend small {
  color: var(--feather-muted);
  font-size: 11px;
  font-weight: 550;
}
.dark.feather-app .feather-trend strong {
  margin: 3px 0;
  font-size: 15px;
  line-height: 1.2;
}
.dark.feather-app .feather-trend b {
  position: absolute;
  top: 20px;
  right: 14px;
  color: var(--feather-muted);
  font-size: 13px;
  letter-spacing: 1px;
}
.dark.feather-app .feather-network__hero {
  padding: 30px 22px 23px;
  border-bottom: 1px solid var(--feather-border);
}
.dark.feather-app .feather-network__hero svg {
  color: var(--feather-blue);
}
.dark.feather-app .feather-network__hero h1 {
  margin: 13px 0 5px;
  font-size: 25px;
  letter-spacing: -0.8px;
}
.dark.feather-app .feather-network__hero p {
  margin: 0;
  color: var(--feather-muted);
  font-size: 13px;
  line-height: 1.45;
}
.dark.feather-app .feather-section-title {
  border-bottom-color: var(--feather-border);
  color: #e7e9ea;
  background: #000;
  font-size: 17px;
}
.dark.feather-app .feather-person,
.dark.feather-app .feather-activity {
  align-items: flex-start;
  border-bottom-color: var(--feather-border);
  color: #e7e9ea;
  background: #000;
}
.dark.feather-app .feather-person > button p {
  display: -webkit-box;
  margin: 5px 0 0;
  overflow: hidden;
  color: #e7e9ea;
  font-size: 11px;
  line-height: 1.35;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.dark.feather-app .feather-person > :deep(.sky-button) {
  --sky-app-accent: #eff3f4;
  --sky-button-text: #0f1419;
  min-width: 66px;
  font-weight: 800;
}
.dark.feather-app .feather-empty {
  align-items: flex-start;
  padding: 72px 28px;
  color: var(--feather-muted);
  text-align: left;
}
.dark.feather-app .feather-empty svg {
  display: none;
}
.dark.feather-app .feather-empty h2 {
  max-width: 245px;
  margin: 0 0 10px;
  color: #e7e9ea;
  font-size: 28px;
  line-height: 1.05;
  letter-spacing: -1px;
}
.dark.feather-app .feather-empty p {
  max-width: 250px;
  font-size: 14px;
  line-height: 1.4;
}
.dark.feather-app .feather-navigation__badge-anchor b {
  background: var(--feather-blue);
}
.dark.feather-app .feather-composer,
.dark.feather-app .feather-edit {
  min-height: 100%;
  color: #e7e9ea;
  background: #000;
}
.dark.feather-app .feather-composer textarea {
  min-height: 190px;
  color: #e7e9ea;
  caret-color: var(--feather-blue);
  font-size: 18px;
}
.dark.feather-app .feather-composer__tools {
  border-top-color: var(--feather-border);
}
.dark.feather-app .feather-profile-screen {
  background: #000;
}
.dark.feather-app .feather-profile {
  border-bottom-color: var(--feather-border);
  background: #000;
}
.dark.feather-app .feather-profile__cover {
  height: 154px;
  background: linear-gradient(180deg, #168ad0, #1d9bf0);
}
.dark.feather-app .feather-profile__top {
  height: 58px;
  padding: 0 14px;
}
.dark.feather-app .feather-profile__avatar {
  width: 84px;
  height: 84px;
  transform: translateY(-42px);
  border: 4px solid #000;
  background: #16181c;
}
.dark.feather-app .feather-profile h1 {
  margin-top: 6px;
  color: #e7e9ea;
  font-size: 23px;
  line-height: 1.15;
}
.dark.feather-app .feather-profile > span,
.dark.feather-app .feather-profile__joined,
.dark.feather-app .feather-profile__stats {
  color: var(--feather-muted);
}
.dark.feather-app .feather-profile > span {
  font-size: 14px;
}
.dark.feather-app .feather-profile > p {
  margin-top: 13px;
  color: #e7e9ea;
  font-size: 14px;
}
.dark.feather-app .feather-profile__joined {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 10px 14px 0;
  font-size: 12px;
}
.dark.feather-app .feather-profile__stats {
  gap: 19px;
  padding-top: 11px;
  padding-bottom: 14px;
  font-size: 13px;
}
.dark.feather-app .feather-profile__stats strong {
  color: #e7e9ea;
}
.dark.feather-app .feather-profile__actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  padding: 0 14px 16px;
}
.dark.feather-app .feather-profile__actions :deep(.sky-button) {
  min-height: 39px;
  border-color: #536471;
  color: #e7e9ea;
  font-size: 13px;
  font-weight: 800;
}
.dark.feather-app .feather-profile-tabs :deep(.sky-button) {
  min-width: 62px;
  gap: 5px;
}
.dark.feather-app .feather-profile-suggestions {
  padding: 14px 0 17px;
  border-bottom: 1px solid var(--feather-border);
}
.dark.feather-app .feather-profile-suggestions h2 {
  margin: 0 14px 12px;
  font-size: 20px;
}
.dark.feather-app .feather-profile-suggestions__rail {
  display: flex;
  gap: 10px;
  overflow-x: auto;
  padding: 0 14px;
  scrollbar-width: none;
}
.dark.feather-app .feather-profile-suggestion {
  position: relative;
  width: 218px;
  min-width: 218px;
  overflow: hidden;
  border: 1px solid var(--feather-border);
  border-radius: 17px;
  background: #000;
}
.dark.feather-app .feather-profile-suggestion__cover {
  height: 76px;
  background: linear-gradient(135deg, #123d64, #1d9bf0);
}
.dark.feather-app .feather-profile-suggestion__profile {
  display: flex;
  width: 100%;
  flex-direction: column;
  border: 0;
  padding: 31px 12px 12px;
  color: #e7e9ea;
  background: transparent;
  text-align: left;
}
.dark.feather-app .feather-profile-suggestion__avatar {
  position: absolute;
  top: 46px;
  left: 11px;
  width: 58px;
  height: 58px;
  border: 3px solid #000;
}
.dark.feather-app .feather-profile-suggestion strong {
  font-size: 16px;
}
.dark.feather-app .feather-profile-suggestion small {
  color: var(--feather-muted);
  font-size: 12px;
}
.dark.feather-app .feather-profile-suggestion p {
  display: -webkit-box;
  margin: 10px 0 0;
  overflow: hidden;
  font-size: 12px;
  line-height: 1.35;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.dark.feather-app .feather-profile-suggestion > :deep(.sky-button) {
  position: absolute;
  right: 10px;
  bottom: 74px;
  z-index: 2;
  --sky-app-accent: #eff3f4;
  --sky-button-text: #0f1419;
  min-width: 67px;
  font-weight: 800;
}
.dark.feather-app .feather-settings-sheet,
.dark.feather-app .feather-report {
  color: #e7e9ea;
  background: #000;
}
.feather-settings-sheet > header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 4px 4px 10px;
}
.feather-settings-sheet > header span {
  color: var(--feather-blue);
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1px;
  text-transform: uppercase;
}
.feather-settings-sheet > header h2 {
  margin: 1px 0 0;
  font-size: 21px;
}
.dark.feather-app .feather-settings-sheet :deep(.sky-list),
.dark.feather-app .feather-settings-sheet :deep(.sky-list-item) {
  color: #e7e9ea;
  background: #16181c;
}
.feather-app--compact :deep(.feather-post) {
  padding-block: 7px;
}
.feather-app--compact :deep(.feather-post__text) {
  font-size: 12.5px;
}

/* Signed-in Feather mirrors the compact, card-led Local Pages shell. */
.feather-app--active {
  --feather-blue: #58a6ff;
  --feather-blue-dark: #2778dc;
  --color-primary: var(--feather-blue);
  --feather-panel: #20262c;
  --feather-muted: #9ba4aa;
  --feather-border: rgb(255 255 255 / 8%);
  position: relative;
  height: 100%;
  padding: 0;
  overflow: hidden;
  background: #12171b !important;
  color: #f7f8f4;
  font-family: var(--sky-font-family);
}
.feather-app--active.feather-app--light {
  --feather-panel: #f0f1ec;
  --feather-muted: #70797e;
  --feather-border: rgb(0 0 0 / 8%);
  background: #fbfbf6 !important;
  color: #171b1e;
}
.feather-app--active button,
.feather-app--active input,
.feather-app--active textarea,
.feather-app--active select {
  font: inherit;
}
.feather-app--active .feather-navbar {
  --sky-navbar-glass: color-mix(in srgb, #12171b 91%, transparent);
  --sky-safe-area-top: 46px;
  position: absolute;
  z-index: 8;
  top: 0;
  right: 0;
  left: 0;
  flex: none;
  border-bottom: 0;
  background: color-mix(in srgb, #12171b 88%, transparent);
  backdrop-filter: blur(18px);
}
.feather-app--active.feather-app--light .feather-navbar {
  --sky-navbar-glass: color-mix(in srgb, #fbfbf6 91%, transparent);
  background: color-mix(in srgb, #fbfbf6 88%, transparent);
}
.feather-app--active.feather-app--section .feather-navbar {
  border-bottom: 1px solid var(--feather-border);
}
.feather-navbar__brand-mark {
  display: block;
  color: currentColor;
  filter: drop-shadow(0 3px 8px rgb(0 0 0 / 18%));
  transform: translateY(4px);
}
.feather-app--active .feather-main {
  position: absolute;
  inset: 0;
  display: flex;
  height: auto;
  min-height: 0;
  flex-direction: column;
  gap: 9px;
  padding: 108px 13px 0;
  background: transparent;
}
.feather-app--active.feather-app--home .feather-main {
  padding-top: 106px;
}
.feather-app--active .feather-scroll {
  display: flex;
  min-height: 0;
  flex: 1;
  flex-direction: column;
  gap: 10px;
  overflow-y: auto;
  overscroll-behavior: contain;
  scrollbar-width: none;
}
.feather-app--active .feather-scroll::-webkit-scrollbar {
  display: none;
}
.feather-hero-glass,
.feather-network-glass,
.feather-profile-glass {
  display: block;
  width: 100%;
  flex: none;
  overflow: hidden;
  border-radius: 17px;
}
.feather-hero {
  display: flex;
  min-height: 105px;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 13px 15px;
  color: #e9f5ff;
  background: linear-gradient(125deg, #173f6d, #2778dc);
}
.feather-hero > div {
  min-width: 0;
  max-width: 215px;
}
.feather-hero small,
.feather-hero strong,
.feather-hero span {
  display: block;
}
.feather-hero small,
.feather-network__hero small {
  color: #a8d4ff;
  font-size: 9.5px;
  font-weight: 900;
  line-height: 1.1;
  letter-spacing: 0.09em;
  text-transform: uppercase;
}
.feather-hero strong {
  margin: 4px 0 3px;
  font-size: 18px;
  line-height: 1.12;
}
.feather-hero span {
  font-size: 11px;
  line-height: 1.3;
}
.feather-hero > svg {
  flex: none;
  color: #b9ddff;
  filter: drop-shadow(0 5px 8px rgb(0 0 0 / 24%));
}
.feather-app--active .feather-feed-tabs,
.feather-app--active .feather-activity-head,
.feather-app--active .feather-profile-tabs {
  flex: none;
  overflow: hidden;
  border: 0;
  border-radius: 13px;
  padding: 4px;
  background: var(--feather-panel);
}
.feather-app--active .feather-feed-tabs {
  display: flex;
  align-items: stretch;
  gap: 10px;
}
.feather-app--active .feather-feed-tabs .feather-context-tabs {
  min-width: 0;
  flex: 1;
}
.feather-app--active .feather-explore-head {
  display: grid;
  flex: none;
  gap: 7px;
  overflow: hidden;
  border: 0;
  border-radius: 17px;
  padding: 9px;
  background: var(--feather-panel);
}
.feather-app--active .feather-explore-search {
  width: auto;
  margin: 0;
}
.feather-app--active .feather-explore-search :deep(form) {
  min-height: 39px;
  border-radius: 12px;
  color: inherit;
  background: color-mix(in srgb, currentColor 7%, transparent);
}
.feather-app--active .feather-context-tabs,
.feather-app--active .feather-profile-tabs {
  min-width: 100%;
  padding: 0;
  background: transparent;
}
.feather-app--active .feather-context-tabs :deep(.sky-button),
.feather-app--active .feather-profile-tabs :deep(.sky-button) {
  min-height: 34px;
  overflow: hidden;
  border-radius: 9px;
  color: var(--feather-muted);
  background: transparent;
  font-size: 11.5px;
  font-weight: 750;
  white-space: nowrap;
}
.feather-app--active .feather-context-tabs :deep(.sky-button.is-active),
.feather-app--active .feather-profile-tabs :deep(.sky-button.is-active) {
  color: #fff;
  background: var(--feather-blue-dark);
}
.feather-app--active.feather-app--light
  .feather-context-tabs
  :deep(.sky-button.is-active),
.feather-app--active.feather-app--light
  .feather-profile-tabs
  :deep(.sky-button.is-active) {
  color: #fff;
}
.feather-app--active .feather-context-tabs :deep(.sky-button.is-active)::after,
.feather-app--active .feather-profile-tabs :deep(.sky-button.is-active)::after {
  display: none;
}
.feather-app--active .feather-feed-tabs {
  overflow: visible;
  border-bottom: 1px solid var(--feather-border);
  border-radius: 0;
  margin-right: -13px;
  margin-left: -13px;
  padding: 0 13px;
  background: transparent;
}
.feather-app--active .feather-feed-tabs .feather-context-tabs {
  overflow: visible;
  background: transparent;
}
.feather-app--active
  .feather-feed-tabs
  .feather-context-tabs
  :deep(.sky-button) {
  position: relative;
  min-height: 42px;
  overflow: visible;
  border-radius: 0;
  color: var(--feather-muted);
  background: transparent !important;
  box-shadow: none;
}
.feather-app--active
  .feather-feed-tabs
  .feather-context-tabs
  :deep(.sky-button.is-active) {
  color: inherit;
  background: transparent !important;
}
.feather-app--active
  .feather-feed-tabs
  .feather-context-tabs
  :deep(.sky-button.is-active)::after {
  position: absolute;
  right: 24%;
  bottom: -1px;
  left: 24%;
  display: block;
  height: 3px;
  border-radius: 999px 999px 0 0;
  background: var(--feather-blue);
  content: '';
}
.feather-app--active .feather-explore-tabs {
  --sky-segmented-strong-highlight: #f7f9fc;
  display: flex;
  width: 100%;
  min-height: 40px;
  justify-content: stretch !important;
  gap: 4px;
  overflow: hidden !important;
  border: 1px solid var(--feather-border);
  border-radius: var(--sky-radius-pill);
  padding: 3px;
  background: rgba(127, 127, 127, 0.1);
}
.feather-app--active.feather-app--light .feather-explore-tabs {
  --sky-segmented-strong-highlight: #fff;
}
.feather-app--active .feather-explore-tabs :deep(.sky-segmented-button) {
  width: 0 !important;
  min-width: 0;
  min-height: 32px;
  flex: 1 1 0 !important;
  border-radius: var(--sky-radius-pill);
  color: var(--feather-muted);
  font-size: 10.5px;
  font-weight: 800;
}
.feather-app--active
  .feather-explore-tabs
  :deep(.sky-segmented-button--active) {
  color: var(--feather-blue-dark);
}
.feather-app--active .feather-main > .feather-scroll {
  padding-top: 1px;
}
.feather-app--active :deep(.feather-post-glass) {
  flex: none;
  border: 1px solid var(--feather-border);
  background: color-mix(in srgb, var(--feather-panel) 90%, transparent);
  box-shadow: 0 5px 18px rgb(0 0 0 / 10%);
}
.feather-app--active :deep(.feather-post) {
  padding: 11px 11px 8px;
}
.feather-app--active :deep(.feather-post__header strong) {
  font-size: 13px;
}
.feather-app--active :deep(.feather-post__header span) {
  color: var(--feather-muted);
  font-size: 10.5px;
}
.feather-app--active :deep(.feather-post__text) {
  font-size: 12.5px;
  line-height: 1.42;
}
.feather-app--active :deep(.feather-actions) {
  color: var(--feather-muted);
}
.feather-app--active :deep(.feather-follow) {
  --sky-app-accent: var(--feather-blue);
  --sky-app-accent-soft: color-mix(
    in srgb,
    var(--feather-blue) 14%,
    transparent
  );
  color: var(--feather-blue);
}
.feather-app--active .feather-trend,
.feather-app--active .feather-person,
.feather-app--active .feather-activity {
  position: relative;
  width: 100%;
  flex: none;
  border: 1px solid var(--feather-border);
  border-radius: 15px;
  padding: 11px;
  color: inherit;
  background: var(--feather-panel);
  box-shadow: 0 5px 18px rgb(0 0 0 / 9%);
}
.feather-app--active .feather-trend {
  min-height: 76px;
  padding-right: 40px;
}
.feather-app--active .feather-trend span,
.feather-app--active .feather-trend small,
.feather-app--active .feather-person span {
  color: var(--feather-muted);
  font-size: 10.5px;
}
.feather-app--active .feather-trend strong {
  margin: 3px 0;
  font-size: 14px;
}
.feather-app--active .feather-trend b {
  position: absolute;
  top: 15px;
  right: 12px;
  color: var(--feather-muted);
  font-size: 11px;
  letter-spacing: 1px;
}
.feather-network-glass {
  margin-bottom: 2px;
}
.feather-app--active .feather-network-search {
  width: auto;
  flex: none;
  margin: 0;
}
.feather-app--active .feather-network-search :deep(form) {
  min-height: 40px;
  border: 1px solid var(--feather-border);
  border-radius: 13px;
  color: inherit;
  background: var(--feather-panel);
  box-shadow: 0 5px 18px rgb(0 0 0 / 9%);
}
.feather-network-loading {
  display: grid;
  min-height: 80px;
  flex: none;
  place-items: center;
}
.feather-network-section {
  display: flex;
  flex: none;
  flex-direction: column;
  gap: 8px;
}
.feather-network-list {
  overflow: hidden;
  margin: 0 !important;
  border: 1px solid var(--feather-border);
  border-radius: 18px;
  background: color-mix(in srgb, var(--feather-panel) 97%, transparent);
  box-shadow: 0 7px 22px rgb(0 0 0 / 9%);
}
.feather-network-person :deep(.feather-network-person__content) {
  min-height: 91px;
  align-items: flex-start;
  padding-block: 11px;
}
.feather-network-person :deep(.feather-network-person__media) {
  margin-right: 10px;
  padding-block: 0;
}
.feather-network-person :deep(.feather-network-person__inner) {
  min-width: 0;
  padding-block: 0 7px;
}
.feather-network-person :deep(.feather-network-person__title-wrap) {
  align-items: center;
}
.feather-network-person
  :deep(.feather-network-person__title-wrap > div:first-child) {
  min-width: 0;
  flex: 1;
}
.feather-network-person__handle {
  display: block;
  margin-top: 1px;
  color: var(--feather-muted);
  font-size: 9.5px;
  line-height: 1.2;
}
.feather-network-person__bio {
  display: -webkit-box;
  overflow: hidden;
  margin-top: 5px;
  color: color-mix(in srgb, currentColor 82%, var(--feather-muted));
  font-size: 10px;
  line-height: 1.35;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.feather-network-person__avatar {
  display: block;
  border: 0;
  border-radius: 50%;
  padding: 0;
  background: transparent;
}
.feather-network-person__avatar .feather-avatar {
  width: 44px;
  height: 44px;
  border: 2px solid color-mix(in srgb, var(--feather-blue) 25%, transparent);
  box-shadow: 0 5px 13px rgb(0 0 0 / 14%);
}
.feather-network-person__name {
  display: flex;
  width: 100%;
  min-width: 0;
  max-width: 100%;
  align-items: center;
  gap: 4px;
  overflow: hidden;
  border: 0;
  padding: 0;
  color: inherit;
  background: transparent;
  font: inherit;
  font-size: 11.5px;
  font-weight: 850;
  text-align: left;
}
.feather-network-person__name span {
  display: block;
  min-width: 0;
  max-width: 100%;
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-network-person__name svg {
  flex: none;
  color: var(--feather-blue);
}
.feather-network-person__stats {
  display: flex;
  align-items: center;
  gap: 5px;
  color: var(--feather-muted);
  font-size: 8.5px;
  font-weight: 600;
}
.feather-network-person__stats strong {
  color: inherit;
  font-size: inherit;
}
.feather-network-person__stats i {
  width: 2px;
  height: 2px;
  border-radius: 50%;
  background: currentColor;
}
.feather-network-person__follow {
  min-width: 84px !important;
  min-height: 32px !important;
  justify-content: center;
  padding-inline: 11px !important;
  font-size: 9.5px !important;
  box-shadow: 0 5px 14px rgba(29, 155, 240, 0.2);
}
.feather-app--active .feather-network-empty {
  display: flex;
  min-height: 112px;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 4px;
  margin: 0;
  border: 1px solid var(--feather-border);
  color: var(--feather-muted);
  background: var(--feather-panel);
  text-align: center;
}
.feather-app--active .feather-network-empty strong {
  color: inherit;
  font-size: 13px;
}
.feather-app--active .feather-network-empty p {
  margin: 0;
  font-size: 10.5px;
}
.feather-app--active .feather-network__hero {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  border: 0;
  padding: 15px;
  background: linear-gradient(125deg, #173f6d, #2778dc);
}
.feather-app--active .feather-network__hero > div {
  min-width: 0;
}
.feather-app--active .feather-network__hero h1 {
  margin: 4px 0 3px;
  color: #fff;
  font-size: 19px;
  letter-spacing: -0.4px;
}
.feather-app--active .feather-network__hero p {
  margin: 0;
  color: #d8ebff;
  font-size: 10.5px;
  line-height: 1.35;
}
.feather-app--active .feather-network__hero > svg {
  flex: none;
  color: #b9ddff;
}
.feather-app--active .feather-section-title {
  flex: none;
  border: 0;
  padding: 7px 3px 1px;
  color: inherit;
  background: transparent;
  font-size: 14px;
}
.feather-app--active .feather-person > button p {
  display: -webkit-box;
  margin: 4px 0 0;
  overflow: hidden;
  color: var(--feather-muted);
  font-size: 10.5px;
  line-height: 1.35;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.feather-app--active .feather-person > :deep(.sky-button) {
  min-width: 72px;
  font-size: 10.5px;
  font-weight: 800;
}
.feather-app--active .feather-follow-button {
  min-width: 72px;
  min-height: 31px;
  border-width: 1px;
  padding-inline: 10px 12px;
  font-size: 10.5px;
  font-weight: 800;
  letter-spacing: 0.1px;
  transition:
    transform 160ms ease,
    box-shadow 160ms ease,
    background-color 160ms ease;
}
.feather-app--active .feather-follow-button :deep(.sky-icon) {
  margin-right: 4px;
}
.feather-app--active .feather-follow-button--pending {
  --sky-app-accent: var(--feather-blue);
  --sky-button-text: #fff;
  border-color: color-mix(in srgb, var(--feather-blue) 76%, #fff);
  box-shadow: 0 4px 12px rgb(29 155 240 / 24%);
}
.feather-app--active .feather-follow-button--following {
  --sky-app-accent: var(--feather-blue);
  --sky-app-accent-soft: rgba(29, 155, 240, 0.14);
  border-color: color-mix(in srgb, currentColor 22%, transparent);
  color: var(--feather-blue);
  box-shadow: none;
}
@media (hover: hover) {
  .feather-app--active .feather-follow-button--pending:hover,
  .feather-app--active :deep(.feather-follow:hover) {
    transform: translateY(-1px);
    background: color-mix(in srgb, var(--feather-blue) 10%, transparent);
  }
}
.feather-app--active .feather-empty {
  min-height: 230px;
  justify-content: center;
  padding: 35px 25px;
  color: var(--feather-muted);
  text-align: center;
}
.feather-app--active .feather-empty h2 {
  margin: 10px 0 4px;
  color: inherit;
  font-size: 16px;
  letter-spacing: -0.2px;
}
.feather-comments {
  overflow: visible;
  border: 0;
  border-radius: 0;
  background: transparent;
}
.feather-comments__header {
  display: flex;
  min-height: 44px;
  align-items: center;
  justify-content: center;
  gap: 5px;
  padding: 0 4px;
  border-bottom: 1px solid var(--feather-border);
}
.feather-comments__header strong {
  font-size: 13px;
  letter-spacing: -0.2px;
}
.feather-comments__header span {
  color: var(--feather-muted);
  font-size: 10px;
  font-weight: 700;
}
.feather-comment {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr) 34px;
  align-items: flex-start;
  gap: 9px;
  padding: 10px 2px;
}
.feather-comment + .feather-comment {
  border-top: 0;
}
.feather-comment--reply {
  margin-left: 34px;
  padding-top: 5px;
}
.feather-comment--reply .feather-comment__avatar {
  width: 32px;
  height: 32px;
  flex-basis: 32px;
}
.feather-comment--reply .feather-comment__avatar::before {
  inset: -6px;
}
.feather-comment__avatar {
  width: 36px;
  height: 36px;
  position: relative;
  flex-basis: 36px;
  border: 0;
}
.feather-comment__avatar::before {
  position: absolute;
  inset: -4px;
  content: '';
}
.feather-comment__copy {
  min-width: 0;
}
.feather-comment__copy > header {
  display: flex;
  align-items: center;
  gap: 6px;
}
.feather-comment__copy > header button {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 4px;
  overflow: hidden;
  border: 0;
  padding: 0;
  color: inherit;
  background: transparent;
}
.feather-comment__copy > header strong {
  overflow: hidden;
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-comment__copy > header svg {
  flex: none;
  color: var(--feather-blue);
}
.feather-comment__copy time {
  flex: none;
  color: var(--feather-muted);
  font-size: 9px;
}
.feather-comment__copy > p {
  margin: 0;
  padding-top: 2px;
  color: inherit;
  font-size: 12px;
  line-height: 1.42;
  overflow-wrap: anywhere;
}
.feather-comment__copy > p span {
  color: var(--feather-blue);
  font-weight: 750;
}
.feather-comment__copy > footer {
  display: flex;
  min-height: 27px;
  align-items: center;
  gap: 11px;
  margin-top: 1px;
  color: var(--feather-muted);
  font-size: 9px;
  font-weight: 700;
}
.feather-comment__copy > footer button {
  position: relative;
  border: 0;
  padding: 0;
  color: inherit;
  background: transparent;
  font: inherit;
  font-weight: 750;
}
.feather-comment__copy > footer button::before {
  position: absolute;
  inset: -9px -7px;
  content: '';
}
.feather-comment__more {
  display: grid;
  place-items: center;
}
.feather-comment__like {
  display: grid;
  width: 34px;
  height: 40px;
  position: relative;
  place-items: center;
  border: 0;
  border-radius: 50%;
  color: var(--feather-muted);
  background: transparent;
}
.feather-comment__like::before {
  position: absolute;
  inset: -2px -5px;
  content: '';
}
.feather-comment__like.is-liked {
  color: #f04f65;
}
.feather-comment__like.is-pulsing svg {
  animation: feather-comment-heart 480ms cubic-bezier(0.22, 1.45, 0.36, 1);
}
@keyframes feather-comment-heart {
  0% {
    transform: scale(0.78);
  }
  55% {
    transform: scale(1.42);
  }
  100% {
    transform: scale(1);
  }
}
.feather-comment-composer {
  position: sticky;
  z-index: 5;
  bottom: 0;
  margin-top: auto;
  border: 0;
  border-top: 1px solid var(--feather-border);
  border-radius: 0;
  padding: 7px 2px 5px;
  background: var(--sky-bg, #12171b);
  box-shadow: 0 -8px 18px rgb(0 0 0 / 8%);
}
.feather-comment-composer__target {
  display: flex;
  min-height: 30px;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 0 3px 4px 10px;
  color: var(--feather-muted);
  font-size: 9.5px;
}
.feather-comment-composer__target span {
  overflow: hidden;
  color: var(--feather-blue);
  font-weight: 750;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-comment-composer__target :deep(.sky-button) {
  --sky-app-accent: var(--feather-muted);
  --sky-app-accent-soft: rgba(127, 127, 127, 0.12);
  width: 28px;
  height: 28px;
}
.feather-comment-composer :deep(.sky-messagebar) {
  margin: 0;
  border: 0;
  padding: 0;
  background: transparent;
  box-shadow: none;
}
.feather-comment-composer :deep(.sky-messagebar__area) {
  border: 1px solid var(--feather-border);
  border-radius: var(--sky-radius-pill);
  background: var(--feather-panel);
  box-shadow: none;
}
.feather-comment-composer :deep(textarea) {
  min-height: 40px;
  padding-inline: 12px;
  color: inherit;
  caret-color: var(--feather-blue);
  font-size: 12px;
}
.feather-comment-composer__avatar {
  width: 36px;
  height: 36px;
  flex-basis: 36px;
}
.feather-comment-composer__send {
  --sky-app-accent: var(--feather-blue);
  --sky-button-text: #fff;
  width: 36px;
  height: 36px;
  min-height: 36px;
}
.feather-comment-composer__count {
  display: block;
  padding: 0 11px 5px;
  color: var(--feather-muted);
  font-size: 8.5px;
  text-align: right;
}
.feather-thread-empty {
  display: flex;
  min-height: 150px;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 7px;
  padding: 22px 12px;
  color: var(--feather-muted);
  font-size: 11px;
}
.feather-thread-empty strong {
  color: inherit;
  font-size: 13px;
}
.feather-thread-empty svg {
  color: var(--feather-blue);
}
@media (prefers-reduced-motion: reduce) {
  .feather-comment__like.is-pulsing svg {
    animation: none;
  }
}
.feather-app--active .feather-empty p {
  max-width: 230px;
  font-size: 12px;
}
.feather-navigation {
  --sky-app-accent: var(--feather-blue);
}
.feather-navigation__segments {
  width: 100%;
}
.feather-navigation__button {
  min-width: 0;
  gap: 2px;
  padding-inline: 2px;
}
.feather-navigation__button small {
  display: block;
  max-width: 58px;
  overflow: hidden;
  font-size: 8.5px;
  font-weight: 700;
  line-height: 10px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-navigation__badge-anchor {
  position: relative;
  display: grid;
  place-items: center;
}
.feather-compose-fab {
  position: absolute;
  z-index: 12;
  right: 14px;
  bottom: 91px;
  width: 46px;
  height: 46px;
  min-width: 46px;
  color: var(--feather-blue);
  transition:
    transform 150ms ease,
    box-shadow 150ms ease,
    filter 150ms ease;
}
.feather-compose-fab:active {
  transform: scale(0.94);
}
.feather-navigation__badge-anchor b {
  position: absolute;
  top: -5px;
  right: -8px;
  min-width: 14px;
  border-radius: 8px;
  padding: 1px 3px;
  color: #fff;
  background: #f04f65;
  font-size: 8px;
  text-align: center;
}
.feather-app--active > .feather-scroll,
.feather-app--active > .feather-composer,
.feather-app--active > .feather-edit {
  position: absolute;
  top: 104px;
  right: 0;
  bottom: 24px;
  left: 0;
  min-height: 0;
  overflow-y: auto;
}
.feather-app--active > .feather-scroll {
  padding: 13px;
}
.feather-app--active > .feather-profile-screen {
  bottom: 96px;
}
.feather-profile-glass {
  flex: none;
}
.feather-app--active .feather-profile-glass {
  overflow: hidden;
  border: 1px solid var(--feather-border);
  border-radius: 18px;
}
.feather-app--active .feather-profile {
  overflow: hidden;
  border: 0;
  background: transparent;
}
.feather-app--active .feather-profile__cover {
  position: relative;
  height: 112px;
  overflow: hidden;
  color: #fff;
  background: linear-gradient(135deg, #173f6d, #58a6ff);
}
.feather-profile__cover-title {
  position: absolute;
  top: 15px;
  left: 15px;
  max-width: calc(100% - 72px);
  display: flex;
  align-items: center;
  gap: 7px;
  overflow: hidden;
  color: #fff;
  font-size: 13px;
  font-weight: 800;
  line-height: 20px;
  text-overflow: ellipsis;
  text-shadow: 0 2px 8px rgb(0 0 0 / 34%);
  white-space: nowrap;
}
.feather-profile__cover-title svg {
  flex: none;
}
.feather-app--active .feather-profile__logout {
  --sky-app-accent: #fff;
  --sky-app-accent-soft: rgba(255, 255, 255, 0.14);
  --sky-button-text: #fff;
  width: 34px;
  height: 34px;
  border: 1px solid rgb(255 255 255 / 24%);
  padding: 0;
  color: #fff;
  box-shadow: inset 0 1px 0 rgb(255 255 255 / 16%);
}
.feather-app--active .feather-profile__top {
  height: 50px;
  padding: 0 13px;
}
.feather-app--active .feather-profile__avatar {
  width: 76px;
  height: 76px;
  transform: translateY(-38px);
  border: 3px solid var(--feather-panel);
  background: linear-gradient(145deg, #72c9ff, #377be7);
}
.feather-app--active .feather-profile__identity {
  padding: 4px 13px 0;
}
.feather-app--active .feather-profile__identity h1 {
  color: inherit;
  font-size: 20px;
}
.feather-app--active .feather-profile__handle,
.feather-app--active .feather-profile__joined,
.feather-app--active .feather-profile__stats {
  color: var(--feather-muted);
}
.feather-app--active .feather-profile__handle {
  font-size: 11.5px;
}
.feather-app--active .feather-profile__bio {
  margin: 10px 0 8px;
  color: inherit;
  font-size: 12.5px;
  line-height: 1.45;
}
.feather-app--active .feather-profile__joined {
  display: inline-flex;
  flex-direction: row;
  align-items: center;
  gap: 5px;
  margin: 0;
  font-size: 11px;
  line-height: 1;
  white-space: nowrap;
}
.feather-app--active .feather-profile__joined svg {
  flex: none;
}
.feather-app--active .feather-profile__stats {
  padding: 12px 13px;
  font-size: 11.5px;
}
.feather-app--active .feather-profile__stats span {
  border: 1px solid var(--feather-border);
  background: color-mix(in srgb, var(--feather-blue) 8%, transparent);
}
.feather-app--active .feather-profile__stats strong {
  color: var(--feather-blue);
}
.feather-app--active .feather-profile__actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 7px;
  padding: 0 13px 13px;
}
.feather-app--active .feather-profile__actions :deep(.sky-button) {
  width: 100%;
  min-width: 0;
  min-height: 36px;
  gap: 6px;
  border-color: color-mix(in srgb, var(--feather-blue) 55%, transparent);
  color: inherit;
  padding-inline: 7px;
  font-size: 10.5px;
  font-weight: 750;
}
.feather-onboarding__logout {
  width: 100%;
  margin-top: 8px;
  border-color: color-mix(in srgb, #f04f65 62%, transparent);
  color: #f04f65;
}
.feather-app--active .feather-profile-action span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-app--active .feather-profile-action svg {
  flex: none;
}
.feather-app--active .feather-profile-tabs {
  margin-top: 1px;
}
.feather-app--active .feather-profile-suggestions {
  flex: none;
  margin-top: 7px;
  border: 0;
  border-radius: 17px;
  padding: 13px 0;
  background: var(--feather-panel);
}
.feather-app--active .feather-profile-suggestions h2 {
  margin: 0 13px 10px;
  font-size: 16px;
}
.feather-app.feather-app--active .feather-profile-suggestions__rail {
  gap: 9px;
  padding: 0 13px 7px;
  scrollbar-color: var(--feather-muted) transparent;
  scrollbar-width: thin;
}
.feather-app.feather-app--active
  .feather-profile-suggestions__rail::-webkit-scrollbar {
  display: block;
  height: 5px;
}
.feather-app.feather-app--active
  .feather-profile-suggestions__rail::-webkit-scrollbar-track {
  background: transparent;
}
.feather-app.feather-app--active
  .feather-profile-suggestions__rail::-webkit-scrollbar-thumb {
  border-radius: var(--sky-radius-pill);
  background: rgba(113, 118, 123, 0.68);
}
.feather-app.feather-app--active .feather-profile-suggestion {
  position: relative;
  width: 240px;
  min-width: 240px;
  min-height: 88px;
  overflow: hidden;
  border: 1px solid var(--feather-border);
  border-radius: 15px;
  border-color: var(--feather-border);
  background: color-mix(in srgb, var(--feather-panel) 87%, #111);
}
.feather-app--active.feather-app--light .feather-profile-suggestion {
  background: #fff;
}
.feather-app.feather-app--active .feather-profile-suggestion__profile {
  display: grid;
  width: 100%;
  grid-template-columns: 42px minmax(0, 1fr);
  align-items: start;
  gap: 9px;
  border: 0;
  padding: 11px 72px 11px 11px;
  color: inherit;
  background: transparent;
  text-align: left;
}
.feather-app.feather-app--active .feather-profile-suggestion__avatar {
  position: static;
  width: 42px;
  height: 42px;
  border: 0;
}
.feather-app--active .feather-profile-suggestion__identity {
  min-width: 0;
}
.feather-app--active .feather-profile-suggestion__identity strong,
.feather-app--active .feather-profile-suggestion__identity small {
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-app--active .feather-profile-suggestion__identity strong {
  font-size: 12.5px;
}
.feather-app--active .feather-profile-suggestion__identity small {
  color: var(--feather-muted);
  font-size: 10.5px;
}
.feather-app--active .feather-profile-suggestion__identity p {
  display: -webkit-box;
  margin: 5px 0 0;
  overflow: hidden;
  font-size: 10.5px;
  line-height: 1.3;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.feather-app.feather-app--active
  .feather-profile-suggestion
  > :deep(.sky-button) {
  position: absolute;
  top: 10px;
  right: 9px;
  bottom: auto;
  width: auto;
  min-width: 56px;
  min-height: 27px;
  padding-inline: 8px;
  font-size: 10px;
}
.feather-app--active .feather-composer,
.feather-app--active .feather-edit {
  color: inherit;
  background: transparent;
}
.feather-app--active .feather-composer {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin: 0;
  border: 0;
  border-radius: 0;
  padding: 13px 13px 34px;
  background: transparent;
}
.feather-app--active.feather-app--composer .feather-navbar {
  --sky-safe-area-top: 54px;
}
.feather-app--active.feather-app--composer > .feather-composer {
  top: 112px;
  padding-top: 18px;
}
.feather-composer-close {
  display: grid;
  width: 32px;
  height: 32px;
  place-items: center;
  border: 1px solid var(--feather-border);
  border-radius: 50%;
  color: #fff;
  color: inherit;
  background: var(--feather-panel);
}
.feather-composer-publish {
  --sky-surface-muted: color-mix(
    in srgb,
    var(--feather-panel) 86%,
    currentColor 14%
  );
  min-width: 52px;
  min-height: 28px;
  border-color: var(--feather-border);
  padding-inline: 10px;
  font-size: 10px;
  font-weight: 800;
}
.feather-edit__navbar-save {
  display: grid;
  width: 44px !important;
  min-width: 44px;
  height: 44px !important;
  min-height: 44px;
  flex: 0 0 44px;
  place-items: center;
  border-color: transparent;
  border-radius: 50% !important;
  padding: 0;
  background: transparent !important;
  color: #fff;
  box-shadow: none;
}
.feather-edit__navbar-save :deep(svg) {
  display: block;
}
.feather-edit__navbar-back :deep(.sky-navbar-back-link__icon) {
  transform: translateX(2px);
}
.feather-composer-card {
  flex: none;
  overflow: hidden;
  border-radius: 18px;
}
.feather-composer-card__inner {
  padding: 13px;
}
.feather-composer__identity {
  display: flex;
  align-items: center;
  gap: 9px;
}
.feather-composer__identity > div:last-child {
  min-width: 0;
}
.feather-composer__identity strong,
.feather-composer__identity span {
  display: block;
}
.feather-composer__identity strong {
  overflow: hidden;
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-composer__identity span {
  color: var(--feather-muted);
  font-size: 10.5px;
}
.feather-app--active .feather-composer-card textarea {
  min-height: 135px;
  margin-top: 9px;
  padding: 4px 1px 10px;
  color: inherit;
  caret-color: var(--feather-blue);
  font-size: 15px;
  line-height: 1.45;
}
.feather-composer-card__footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  border-top: 1px solid var(--feather-border);
  padding-top: 9px;
  color: var(--feather-muted);
  font-size: 10px;
}
.feather-composer-card__footer span {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 5px;
  color: var(--feather-blue);
}
.feather-composer-card__footer b {
  flex: none;
  font-weight: 750;
}
.feather-composer-media {
  flex: none;
  border: 1px solid var(--feather-border);
  border-radius: 18px;
  padding: 13px;
  background: var(--feather-panel);
}
.feather-composer-media > header {
  display: flex;
  align-items: center;
  gap: 9px;
}
.feather-composer-media > header > span {
  display: grid;
  width: 36px;
  height: 36px;
  flex: none;
  place-items: center;
  border-radius: 11px;
  color: var(--feather-blue);
  background: color-mix(in srgb, var(--feather-blue) 14%, transparent);
}
.feather-composer-media > header > div {
  min-width: 0;
  flex: 1;
}
.feather-composer-media > header strong,
.feather-composer-media > header small {
  display: block;
}
.feather-composer-media > header strong {
  font-size: 13px;
}
.feather-composer-media > header small {
  margin-top: 1px;
  color: var(--feather-muted);
  font-size: 9.5px;
  line-height: 1.3;
}
.feather-composer-media > header > b {
  flex: none;
  border-radius: 8px;
  padding: 4px 7px;
  color: var(--feather-blue);
  background: color-mix(in srgb, var(--feather-blue) 11%, transparent);
  font-size: 10px;
}
.feather-composer-media__actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-top: 11px;
}
.feather-composer-media__actions > * {
  min-width: 0;
  overflow: hidden;
  border-radius: 14px;
}
.feather-composer-media__actions button {
  width: 100%;
  min-height: 105px;
  border: 0;
  padding: 10px;
  color: inherit;
  background: transparent;
  text-align: left;
}
.feather-composer-media__actions button > span {
  display: grid;
  width: 32px;
  height: 32px;
  margin-bottom: 7px;
  place-items: center;
  border-radius: 10px;
  color: #fff;
  background: var(--feather-blue-dark);
}
.feather-composer-media__actions button strong,
.feather-composer-media__actions button small {
  display: block;
}
.feather-composer-media__actions button strong {
  font-size: 11.5px;
}
.feather-composer-media__actions button small {
  margin-top: 2px;
  color: var(--feather-muted);
  font-size: 9px;
  line-height: 1.25;
}
.feather-composer-media__actions button:disabled {
  opacity: 0.38;
}
@media (hover: hover) {
  .feather-composer-media__actions button:not(:disabled):hover {
    background: color-mix(in srgb, var(--feather-blue) 9%, transparent);
  }
}
.feather-composer-media__selected {
  margin-top: 13px;
}
.feather-composer-media__selected-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 7px;
  font-size: 11px;
}
.feather-composer-media__selected-head span {
  color: var(--feather-blue);
  font-size: 10px;
  font-weight: 800;
}
.feather-app--active .feather-compose-media {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 6px;
  margin: 0;
}
.feather-app--active .feather-compose-media--1 {
  grid-template-columns: 1fr;
}
.feather-app--active .feather-compose-media > div {
  min-height: 94px;
  border: 1px solid var(--feather-border);
  border-radius: 12px;
}
.feather-app--active .feather-compose-media--1 > div {
  min-height: 165px;
}
.feather-app--active .feather-compose-media img {
  height: 100%;
  min-height: 94px;
}
.feather-app--active .feather-compose-media i {
  position: absolute;
  bottom: 5px;
  left: 5px;
  display: grid;
  width: 18px;
  height: 18px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: rgb(0 0 0 / 68%);
  font-size: 8px;
  font-style: normal;
  font-weight: 850;
}
.feather-app--active .feather-edit {
  display: flex;
  flex-direction: column;
  gap: 13px;
  padding: 14px 13px 34px;
}
.feather-navbar :deep(.feather-navbar__plain-action) {
  background-image: none !important;
  background: transparent !important;
  box-shadow: none !important;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}
.feather-navbar :deep(.feather-navbar__plain-action > span) {
  display: none !important;
}
.feather-edit__identity {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  overflow: hidden;
  border: 1px solid var(--feather-border);
  border-radius: 18px;
  padding: 13px;
  background:
    radial-gradient(
      circle at 100% 0,
      color-mix(in srgb, var(--feather-blue) 22%, transparent),
      transparent 48%
    ),
    color-mix(in srgb, var(--feather-panel) 94%, transparent);
  box-shadow: 0 10px 28px rgb(0 0 0 / 8%);
}
.feather-edit__avatar {
  display: grid;
  width: 58px;
  height: 58px;
  flex: 0 0 58px;
  place-items: center;
  overflow: hidden;
  border: 2px solid color-mix(in srgb, var(--feather-blue) 58%, #fff);
  border-radius: 50%;
  color: #fff;
  background: linear-gradient(145deg, #71c8ff, #377be7);
  box-shadow: 0 7px 18px rgb(29 155 240 / 22%);
}
.feather-edit__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.feather-edit__account {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
}
.feather-edit__account strong {
  overflow: hidden;
  font-size: 15px;
  line-height: 1.25;
  letter-spacing: -0.2px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-edit__account span {
  overflow: hidden;
  margin-top: 3px;
  color: var(--feather-muted);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-edit__badge {
  display: grid;
  width: 30px;
  height: 30px;
  flex: 0 0 30px;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: var(--feather-blue);
  box-shadow: 0 5px 14px rgb(29 155 240 / 25%);
}
.feather-edit__photo {
  display: flex;
  flex-direction: column;
  gap: 8px;
  border: 1px solid var(--feather-border);
  border-radius: 18px;
  padding: 11px 12px 12px;
  background: color-mix(in srgb, var(--feather-panel) 96%, transparent);
  box-shadow: 0 10px 28px rgb(0 0 0 / 7%);
}
.feather-edit__photo > strong {
  font-size: 11px;
  font-weight: 800;
}
.feather-edit__photo-actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.feather-edit__photo-actions :deep(.sky-button) {
  min-width: 0;
  min-height: 35px;
  gap: 6px;
  border: 1px solid color-mix(in srgb, var(--feather-blue) 24%, transparent);
  color: var(--feather-blue);
  font-size: 10px;
  font-weight: 800;
}
.feather-edit__fields {
  overflow: hidden;
  margin: 0 !important;
  border: 1px solid var(--feather-border);
  border-radius: 18px;
  background: color-mix(in srgb, var(--feather-panel) 96%, transparent);
  box-shadow: 0 10px 28px rgb(0 0 0 / 7%);
}
.feather-edit__fields :deep(.sky-list-item__media) {
  align-self: flex-start;
  margin-top: 20px;
  color: var(--feather-blue);
}
.feather-edit__fields :deep(input),
.feather-edit__fields :deep(textarea) {
  font-size: 13px;
  line-height: 1.45;
}
.feather-edit__fields :deep(textarea) {
  min-height: 128px;
  resize: none;
}
.feather-edit__fields :deep(.sky-field__info) {
  color: var(--feather-muted);
  font-size: 9px;
}
.feather-connections {
  padding-top: 10px !important;
}
.feather-connections__tabs {
  width: 100%;
  margin-bottom: 11px;
  border: 1px solid var(--feather-border);
  border-radius: 15px;
  padding: 3px;
  background: color-mix(in srgb, var(--feather-panel) 94%, transparent);
}
.feather-connections__tabs :deep(button) {
  min-height: 31px;
  border-radius: 11px !important;
  font-size: 10px;
  font-weight: 800;
}
.feather-connections__loading {
  display: grid;
  min-height: 180px;
  place-items: center;
  color: var(--feather-blue);
}
.feather-connections__empty {
  display: flex;
  min-height: 180px;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  margin: 0 !important;
  border: 1px solid var(--feather-border);
  border-radius: 18px;
  color: var(--feather-muted);
  text-align: center;
}
.feather-connections__empty strong {
  margin-top: 9px;
  color: inherit;
  font-size: 14px;
}
.feather-connections__empty p {
  max-width: 210px;
  margin: 4px 0 0;
  font-size: 10px;
  line-height: 1.4;
}
.feather-connections__list {
  overflow: hidden;
  margin: 0 !important;
  border: 1px solid var(--feather-border);
  border-radius: 18px;
  background: color-mix(in srgb, var(--feather-panel) 96%, transparent);
}
.feather-connections__list :deep(.sky-list-item__content) {
  min-height: 62px;
}
.feather-connections__list :deep(.sky-list-item__title) {
  max-width: 108px;
  overflow: hidden;
  font-size: 12px;
  font-weight: 800;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-connections__list :deep(.sky-list-item__text) {
  max-width: 108px;
  overflow: hidden;
  color: var(--feather-muted);
  font-size: 9px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.feather-connections__profile {
  border: 0;
  padding: 0;
  background: transparent;
}
.feather-connections__avatar {
  width: 39px;
  height: 39px;
}
.feather-connections__remove {
  min-width: 70px;
  min-height: 29px;
  gap: 4px;
  border-color: color-mix(in srgb, #f04f65 62%, transparent);
  color: #f04f65;
  font-size: 9px;
  font-weight: 800;
}
.feather-app--active .feather-settings-sheet,
.feather-app--active .feather-report {
  color: inherit;
  background: var(--feather-panel);
}
.feather-post-menu__content {
  padding: 0 14px calc(var(--sky-safe-area-bottom) + 14px);
}
.feather-post-menu__header {
  padding: 0 2px 11px;
  touch-action: none;
}
.feather-post-menu__header span {
  display: block;
  color: var(--feather-muted);
  font-size: 10px;
  font-weight: 700;
}
.feather-post-menu__header h2 {
  margin: 2px 0 0;
  font-size: 17px;
  letter-spacing: -0.25px;
}
.feather-post-menu__group {
  overflow: hidden;
  border: 1px solid var(--feather-border);
  border-radius: 16px;
  background: color-mix(in srgb, currentColor 5%, transparent);
}
.feather-post-menu__action {
  min-height: 46px;
  justify-content: flex-start;
  gap: 9px;
  border-radius: 0;
  padding: 9px 13px;
  color: inherit;
  font-size: 12px;
  font-weight: 700;
  line-height: 18px;
}
.feather-post-menu__action + .feather-post-menu__action {
  border-top: 1px solid var(--feather-border);
}
.feather-post-menu__action--danger {
  color: var(--sky-danger);
}
.feather-post-menu__action svg {
  flex: none;
}
@supports not (color: color-mix(in srgb, white, black)) {
  .feather-navbar {
    --sky-navbar-glass: rgb(255 255 255 / 91%);
    border-bottom-color: rgb(127 127 127 / 18%);
  }
  :global(.dark) .feather-navbar {
    --sky-navbar-glass: rgb(9 13 18 / 91%);
  }
  .dark.feather-app .feather-navbar {
    --sky-navbar-glass: rgb(0 0 0 / 90%);
    background: rgb(0 0 0 / 88%);
  }
  .feather-app--active .feather-navbar {
    --sky-navbar-glass: rgb(18 23 27 / 91%);
    background: rgb(18 23 27 / 88%);
  }
  .feather-app--active.feather-app--light .feather-navbar {
    --sky-navbar-glass: rgb(251 251 246 / 91%);
    background: rgb(251 251 246 / 88%);
  }
  .feather-feed-tabs,
  .feather-explore-head,
  .feather-activity-head,
  .feather-trend,
  .feather-composer__tools,
  .feather-section-title,
  .feather-profile,
  .feather-profile-tabs,
  .feather-activity,
  .feather-person {
    border-color: rgb(127 127 127 / 18%);
  }
  .feather-trend:active,
  .feather-profile__stats button,
  .feather-report select,
  .feather-report textarea,
  .feather-app--active .feather-explore-search :deep(form) {
    background: rgb(127 127 127 / 7%);
  }
  .feather-profile__stats button:active,
  .feather-comments__header span,
  .feather-app--active .feather-profile__stats span,
  .feather-composer-media > header > span,
  .feather-composer-media > header > b,
  .feather-app--active .feather-follow-button--pending:hover,
  .feather-app--active :deep(.feather-follow:hover),
  .feather-composer-media__actions button:not(:disabled):hover {
    background: rgb(29 155 240 / 13%);
  }
  .feather-report select,
  .feather-report textarea,
  .feather-app--active .feather-follow-button--following {
    border-color: rgb(127 127 127 / 24%);
  }
  .feather-app--active :deep(.feather-post-glass),
  .feather-network-list,
  .feather-comments,
  .feather-comment-composer,
  .feather-profile-suggestion,
  .feather-edit__identity,
  .feather-edit__photo,
  .feather-edit__fields,
  .feather-connections__tabs,
  .feather-connections__list {
    background: var(--feather-panel);
  }
  .feather-network-person__bio {
    color: var(--feather-muted);
  }
  .feather-network-person__avatar .feather-avatar,
  .feather-app--active .feather-follow-button--pending,
  .feather-app--active .feather-profile__actions :deep(.sky-button),
  .feather-edit__photo-actions :deep(.sky-button) {
    border-color: var(--feather-blue);
  }
  .feather-edit__avatar {
    border-color: #70c5fa;
  }
  .feather-connections__remove {
    border-color: #f04f65;
  }
}
</style>
