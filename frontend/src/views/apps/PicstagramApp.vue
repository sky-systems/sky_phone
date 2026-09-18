<script setup lang="ts">
import {
  Bell,
  Bookmark,
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  Compass,
  Eye,
  Grid3X3,
  Heart,
  Home,
  ImagePlus,
  Images,
  LockKeyhole,
  MapPin,
  MessageCircle,
  MoreHorizontal,
  Plus,
  Reply,
  Search,
  Send,
  Share2,
  ShieldAlert,
  Trash2,
  UserRound,
  UsersRound,
  Video,
  X,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import picstagramIcon from '@/assets/img/app-icons/picstagram.webp'
import { useEasyShareStore } from '@/stores/easyshare'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import { usePicstagramStore } from '@/stores/picstagram'
import type { PhoneMedia } from '@/types/media'
import type {
  PicstagramActivity,
  PicstagramComment,
  PicstagramPost,
  PicstagramProfile,
  PicstagramReportReason,
  PicstagramReportTarget,
  PicstagramStory,
} from '@/types/picstagram'
import {
  SkyActionButton,
  SkyActionGroup,
  SkyActionSheet,
  SkyAppPage,
  SkyButton,
  SkyCard,
  SkyChip,
  SkyDialog,
  SkyDialogButton,
  SkyDropdown,
  SkyField,
  SkyGlass,
  SkyLink,
  SkyList,
  SkyListItem,
  SkyMessagebar,
  SkyNavbar,
  SkyPillNavigation,
  SkyScrollArea,
  SkySearchbar,
  SkySegmented,
  SkySegmentedButton,
  SkySheet,
  SkySpinner,
  SkyNotification,
  SkyToggle,
} from '@/ui'

type Tab = 'home' | 'explore' | 'create' | 'activity' | 'profile'
type AuthMode = 'login' | 'register'
type ComposeKind = 'post' | 'story'
type ConnectionMode = 'followers' | 'following'
type ProfileSection = 'all' | 'videos' | 'tagged'
type MediaSource = 'camera' | 'photos'

const phone = usePhoneStore()
const store = usePicstagramStore()
const mediaPicker = useMessageMediaStore()
const route = useRoute()
const router = useRouter()

const tab = ref<Tab>('home')
const authMode = ref<AuthMode>('login')
const authHandle = ref('')
const authDisplayName = ref('')
const authPassword = ref('')
const authConfirmPassword = ref('')
const authSubmitting = ref(false)
const composeKind = ref<ComposeKind>('post')
const selectedMedia = ref<PhoneMedia[]>([])
const composePreviewIndex = ref(0)
const caption = ref('')
const location = ref('')
const storyText = ref('')
const commentsEnabled = ref(true)
const publishing = ref(false)
const search = ref('')
const profileSection = ref<ProfileSection>('all')
const selectedPost = ref<PicstagramPost | null>(null)
const commentPost = ref<PicstagramPost | null>(null)
const actionPost = ref<PicstagramPost | null>(null)
const selectedStory = ref<PicstagramStory | null>(null)
const commentsOpen = ref(false)
const commentBody = ref('')
const replyingTo = ref<PicstagramComment | null>(null)
const actionsOpen = ref(false)
const postMenuOpened = ref(false)
const postMenuTarget = ref<HTMLElement | null>(null)
const reportOpen = ref(false)
const reportTarget = ref<{
  id: string
  label: string
  type: PicstagramReportTarget
} | null>(null)
const reportReason = ref<PicstagramReportReason>('spam')
const reportDetails = ref('')
const profileEditOpen = ref(false)
const selectedAvatar = ref<PhoneMedia | null>(null)
const removeAvatar = ref(false)
const profileDraft = ref({
  bio: '',
  displayName: '',
  handle: '',
  private: false,
})
const connectionsOpen = ref(false)
const connectionsMode = ref<ConnectionMode>('followers')
const logoutDialogOpen = ref(false)
const logoutSubmitting = ref(false)
const deleteDialogOpen = ref(false)
const blockDialogOpen = ref(false)
const storyViewersOpen = ref(false)
const moderationOpen = ref(false)
const feedback = ref('')
const carouselIndexes = ref<Record<string, number>>({})
const commentLikePulseId = ref<string | null>(null)
const expandedCommentThreads = ref<Set<string>>(new Set())
const reactionPulse = ref<{ id: string; kind: 'like' | 'save' } | null>(null)
let feedbackTimer: number | null = null
let searchTimer: number | null = null
let commentLikePulseTimer: number | null = null
let reactionPulseTimer: number | null = null

const currentProfile = computed(() => store.viewedProfile ?? store.profile)
const unreadCount = computed(
  () => store.activities.filter((activity) => !activity.read_at).length,
)
const tabIndex = computed(() =>
  ['home', 'explore', 'activity', 'profile'].indexOf(tab.value),
)
const currentComposeMedia = computed(
  () => selectedMedia.value[composePreviewIndex.value] ?? null,
)
const postMenuItems = computed(() => {
  const post = actionPost.value
  if (!post) return []
  if (post.is_owner) {
    return [
      { id: 'share', label: t('share') },
      { id: 'archive', label: t('archive') },
      {
        destructive: true,
        id: 'delete',
        label: t('deletePost'),
        separatorBefore: true,
      },
    ]
  }
  return [
    { id: 'share', label: t('share') },
    { id: 'report', label: t('report'), separatorBefore: true },
    { destructive: true, id: 'block', label: t('block') },
  ]
})
const taggedProfilePosts = computed(() => {
  const handle = currentProfile.value?.handle.trim().toLowerCase()
  if (!handle) return []
  const mention = `@${handle}`
  const matches = store
    .allPostCollections()
    .flat()
    .filter((post) => post.caption.toLowerCase().includes(mention))
  return [...new Map(matches.map((post) => [post.id, post])).values()]
})
const profileGrid = computed(() => {
  if (profileSection.value === 'videos') {
    return store.profilePosts.filter((post) =>
      post.media.some((media) => media.media_type === 'video'),
    )
  }
  if (profileSection.value === 'tagged') return taggedProfilePosts.value
  return store.profilePosts
})
const commentThreads = computed(() => {
  const roots = store.comments.filter((comment) => !comment.parent_id)
  return roots.map((comment) => ({
    comment,
    replies: store.comments
      .filter((reply) => reply.parent_id === comment.id)
      .map((reply) => {
        const mention = reply.body.match(/^@([a-z0-9._-]+)\s+/i)
        return {
          ...reply,
          display_body: mention
            ? reply.body.slice(mention[0].length)
            : reply.body,
          display_reply_to_handle: mention?.[1] ?? reply.reply_to_handle,
        }
      }),
  }))
})
const selectedStoryPosition = computed(() =>
  selectedStory.value
    ? store.stories.findIndex((story) => story.id === selectedStory.value?.id)
    : -1,
)
const selectedStoryGroup = computed(() =>
  selectedStory.value
    ? store.stories.filter(
        (story) => story.profile_id === selectedStory.value?.profile_id,
      )
    : [],
)
const selectedStoryGroupPosition = computed(() =>
  selectedStory.value
    ? selectedStoryGroup.value.findIndex(
        (story) => story.id === selectedStory.value?.id,
      )
    : -1,
)
const storyGroups = computed(() => {
  const groups = new Map<
    string,
    { avatar: string | null; handle: string; stories: PicstagramStory[] }
  >()
  store.stories.forEach((story) => {
    const existing = groups.get(story.profile_id)
    if (existing) existing.stories.push(story)
    else
      groups.set(story.profile_id, {
        avatar: story.avatar_url,
        handle: story.is_owner ? t('yourStory') : story.handle,
        stories: [story],
      })
  })
  return [...groups.values()]
})

const reportReasons: PicstagramReportReason[] = [
  'spam',
  'harassment',
  'dangerous',
  'illegal',
  'other',
]

function t(key: string, replacements?: Record<string, string>): string {
  return phone.t(`Apps.picstagram.${key}`, replacements)
}

function initials(value: string): string {
  return value.trim().slice(0, 2).toUpperCase() || 'PS'
}

function count(value: number): string {
  return new Intl.NumberFormat(phone.lang, {
    maximumFractionDigits: 1,
    notation: value > 999 ? 'compact' : 'standard',
  }).format(value)
}

function relativeTime(value: number): string {
  const seconds = Math.max(1, Math.floor((Date.now() - value) / 1000))
  if (seconds < 60) return `${seconds}s`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

function notify(message: string): void {
  if (feedbackTimer !== null) window.clearTimeout(feedbackTimer)
  feedback.value = message
  feedbackTimer = window.setTimeout(() => {
    feedback.value = ''
    feedbackTimer = null
  }, 2600)
}

function errorMessage(error?: string): string {
  return t(`errors.${error ?? 'default'}`)
}

async function submitAuth(): Promise<void> {
  if (
    authMode.value === 'register' &&
    authPassword.value !== authConfirmPassword.value
  ) {
    notify(t('passwordsMismatch'))
    return
  }
  authSubmitting.value = true
  const response =
    authMode.value === 'login'
      ? await store.login(authHandle.value, authPassword.value)
      : await store.register(
          authDisplayName.value,
          authHandle.value,
          authPassword.value,
        )
  authSubmitting.value = false
  if (!response.success) notify(errorMessage(response.error))
}

async function signOut(): Promise<void> {
  logoutSubmitting.value = true
  const response = await store.logout()
  logoutSubmitting.value = false
  logoutDialogOpen.value = false
  if (!response.success) notify(errorMessage(response.error))
}

async function showTab(next: Tab): Promise<void> {
  tab.value = next
  selectedPost.value = null
  if (next === 'explore' && !store.explore.length) await store.loadExplore()
  if (next === 'activity') await store.loadActivities()
  if (next === 'profile' && store.profile) {
    await store.loadProfile({ profileId: store.profile.id })
    store.viewedProfile = null
    profileSection.value = 'all'
  }
}

async function openProfile(profile: PicstagramProfile | string): Promise<void> {
  const profileId = typeof profile === 'string' ? profile : profile.id
  if (!(await store.loadProfile({ profileId }))) {
    notify(errorMessage('profile_not_found'))
    return
  }
  closeComments()
  connectionsOpen.value = false
  selectedPost.value = null
  tab.value = 'profile'
  profileSection.value = 'all'
}

async function openConnectionProfile(
  profile: PicstagramProfile,
): Promise<void> {
  connectionsOpen.value = false
  await openProfile(profile)
}

function goBackFromProfile(): void {
  store.viewedProfile = null
  tab.value = 'explore'
}

function openPost(post: PicstagramPost): void {
  selectedPost.value = post
}

function closePost(): void {
  selectedPost.value = null
}

async function openComments(post: PicstagramPost): Promise<void> {
  commentPost.value = post
  selectedPost.value = null
  await store.loadComments(post.id)
  replyingTo.value = null
  expandedCommentThreads.value = new Set()
  commentsOpen.value = true
}

function closeComments(): void {
  commentsOpen.value = false
  commentPost.value = null
  replyingTo.value = null
}

function toggleCommentThread(id: string): void {
  const next = new Set(expandedCommentThreads.value)
  if (next.has(id)) next.delete(id)
  else next.add(id)
  expandedCommentThreads.value = next
}

function shareCommentPost(): void {
  if (commentPost.value) sharePost(commentPost.value)
}

function startReply(comment: PicstagramComment): void {
  replyingTo.value = comment
  commentBody.value = ''
}

async function submitComment(): Promise<void> {
  if (!commentPost.value || !commentBody.value.trim()) return
  const body = replyingTo.value
    ? `@${replyingTo.value.handle} ${commentBody.value.trim()}`
    : commentBody.value.trim()
  const response = await store.comment(
    commentPost.value.id,
    body,
    replyingTo.value?.parent_id ?? replyingTo.value?.id,
    replyingTo.value?.id,
  )
  if (!response.success) {
    notify(errorMessage(response.error))
    return
  }
  commentPost.value.comment_count += 1
  commentBody.value = ''
  replyingTo.value = null
  await store.loadComments(commentPost.value.id)
}

async function reactComment(comment: PicstagramComment): Promise<void> {
  if (commentLikePulseTimer !== null) window.clearTimeout(commentLikePulseTimer)
  commentLikePulseId.value = comment.id
  await store.reactComment(comment)
  commentLikePulseTimer = window.setTimeout(() => {
    commentLikePulseId.value = null
    commentLikePulseTimer = null
  }, 360)
}

function openComposeMedia(
  source: MediaSource,
  mediaType: 'photo' | 'video',
): void {
  mediaPicker.begin(
    'picstagram:compose',
    mediaType,
    '/apps/picstagram?tab=create',
    composeKind.value === 'post' && mediaType === 'photo' ? 5 : 1,
    {
      caption: caption.value,
      commentsEnabled: commentsEnabled.value,
      kind: composeKind.value,
      location: location.value,
      storyText: storyText.value,
    },
  )
  void router.push({
    path: `/apps/${source}`,
    query: { mediaAttachment: mediaType },
  })
}

function openAvatarMedia(source: MediaSource): void {
  mediaPicker.begin(
    'picstagram:avatar',
    'photo',
    '/apps/picstagram?editProfile=1',
    1,
    { ...profileDraft.value },
  )
  void router.push({
    path: `/apps/${source}`,
    query: { mediaAttachment: 'photo' },
  })
}

function resetComposer(): void {
  selectedMedia.value = []
  composePreviewIndex.value = 0
  caption.value = ''
  location.value = ''
  storyText.value = ''
  commentsEnabled.value = true
}

function removeComposeMedia(id: number): void {
  selectedMedia.value = selectedMedia.value.filter((media) => media.id !== id)
  composePreviewIndex.value = Math.min(
    composePreviewIndex.value,
    Math.max(0, selectedMedia.value.length - 1),
  )
}

function moveComposePreview(direction: 1 | -1): void {
  composePreviewIndex.value = Math.max(
    0,
    Math.min(
      selectedMedia.value.length - 1,
      composePreviewIndex.value + direction,
    ),
  )
}

function changeComposeSelection(): void {
  openComposeMedia('photos', selectedMedia.value[0]?.mediaType ?? 'photo')
}

function beginStoryCompose(): void {
  void showTab('create')
  setComposeKind('story')
}

function beginPostCompose(): void {
  void showTab('create')
  setComposeKind('post')
}

function setComposeKind(kind: ComposeKind): void {
  composeKind.value = kind
  resetComposer()
}

function clearAvatarSelection(): void {
  removeAvatar.value = true
  selectedAvatar.value = null
}

async function publish(): Promise<void> {
  const media = selectedMedia.value[0]
  if (!media || publishing.value) return
  publishing.value = true
  const response =
    composeKind.value === 'post'
      ? await store.publishPost({
          caption: caption.value,
          commentsEnabled: commentsEnabled.value,
          location: location.value,
          mediaIds: selectedMedia.value.map((entry) => entry.id),
          mediaType: media.mediaType,
        })
      : await store.publishStory(media.id, storyText.value, media.mediaType)
  publishing.value = false
  if (!response.success) {
    notify(errorMessage(response.error))
    return
  }
  const kind = composeKind.value
  resetComposer()
  await showTab('home')
  notify(t(kind === 'post' ? 'published' : 'storyPublished'))
}

function updateCarousel(post: PicstagramPost, event: Event): void {
  const element = event.currentTarget as HTMLElement
  carouselIndexes.value[post.id] = Math.round(
    element.scrollLeft / Math.max(1, element.clientWidth),
  )
}

function moveCarousel(post: PicstagramPost, direction: 1 | -1): void {
  const current = carouselIndexes.value[post.id] ?? 0
  const next = Math.max(0, Math.min(post.media.length - 1, current + direction))
  const element = document.querySelector<HTMLElement>(
    `[data-picstagram-carousel="${post.id}"]`,
  )
  element?.scrollTo({ behavior: 'smooth', left: next * element.clientWidth })
  carouselIndexes.value[post.id] = next
}

async function react(
  post: PicstagramPost,
  kind: 'like' | 'save',
): Promise<void> {
  if (!(await store.react(post, kind))) notify(errorMessage())
}

async function reactWithPulse(
  post: PicstagramPost,
  kind: 'like' | 'save',
): Promise<void> {
  if (reactionPulseTimer !== null) window.clearTimeout(reactionPulseTimer)
  reactionPulse.value = { id: post.id, kind }
  await react(post, kind)
  reactionPulseTimer = window.setTimeout(() => {
    reactionPulse.value = null
    reactionPulseTimer = null
  }, 440)
}

function likeFromMedia(post: PicstagramPost): void {
  if (!post.is_liked) void reactWithPulse(post, 'like')
}

async function follow(profile: PicstagramProfile): Promise<void> {
  if (!(await store.followProfile(profile))) notify(errorMessage())
}

async function openConnections(mode: ConnectionMode): Promise<void> {
  if (!currentProfile.value) return
  connectionsMode.value = mode
  if (!(await store.loadConnections(currentProfile.value.id, mode))) {
    notify(errorMessage())
    return
  }
  connectionsOpen.value = true
}

function editProfile(): void {
  if (!store.profile) return
  profileDraft.value = {
    bio: store.profile.bio,
    displayName: store.profile.display_name,
    handle: store.profile.handle,
    private: store.profile.private,
  }
  selectedAvatar.value = null
  removeAvatar.value = false
  profileEditOpen.value = true
}

async function saveProfile(): Promise<void> {
  if (!store.profile) return
  const response = await store.updateProfile({
    avatarMediaId: removeAvatar.value
      ? 0
      : (selectedAvatar.value?.id ?? store.profile.avatar_media_id ?? 0),
    bio: profileDraft.value.bio,
    displayName: profileDraft.value.displayName,
    handle: profileDraft.value.handle,
    private: profileDraft.value.private,
  })
  if (!response.success) {
    notify(errorMessage(response.error))
    return
  }
  profileEditOpen.value = false
  notify(t('profileSaved'))
}

function showPostActions(event: MouseEvent, post: PicstagramPost): void {
  event.stopPropagation()
  actionPost.value = post
  postMenuTarget.value = event.currentTarget as HTMLElement
  postMenuOpened.value = true
}

function dismissPostMenu(): void {
  postMenuOpened.value = false
  postMenuTarget.value = null
}

function selectPostMenuItem(id: string): void {
  const post = actionPost.value
  if (!post) return
  dismissPostMenu()
  switch (id) {
    case 'share':
      sharePost(post)
      break
    case 'archive':
      archiveSelectedPost()
      break
    case 'delete':
      deleteDialogOpen.value = true
      break
    case 'report':
      startReport('post', post.id, t('post'))
      break
    case 'block':
      blockDialogOpen.value = true
      break
  }
}

function showProfileActions(): void {
  actionPost.value = null
  actionsOpen.value = true
}

function sharePost(post: PicstagramPost): void {
  useEasyShareStore().open({
    appId: 'picstagram',
    copyText: `@${post.handle}: ${post.caption}`,
    id: post.id,
    imageUrl: post.media[0]?.url,
    kind: 'post',
    link: `skyphone://picstagram/post/${post.id}`,
    subtitle: `@${post.handle}`,
    title: post.caption || post.display_name,
  })
}

function shareCurrentProfile(): void {
  const profile = currentProfile.value
  if (!profile) return
  actionsOpen.value = false
  useEasyShareStore().open({
    appId: 'picstagram',
    copyText: `@${profile.handle}`,
    id: profile.id,
    imageUrl: profile.avatar_url,
    kind: 'profile',
    link: `skyphone://picstagram/profile/${profile.id}`,
    subtitle: `@${profile.handle}`,
    title: profile.display_name,
  })
}

function startReport(
  type: PicstagramReportTarget,
  id: string,
  label: string,
): void {
  actionsOpen.value = false
  reportTarget.value = { id, label, type }
  reportReason.value = 'spam'
  reportDetails.value = ''
  reportOpen.value = true
}

function reportSelectedStory(): void {
  if (!selectedStory.value) return
  startReport('story', selectedStory.value.id, t('story'))
  selectedStory.value = null
}

function reportCurrentProfile(): void {
  if (!currentProfile.value || currentProfile.value.is_owner) return
  startReport(
    'profile',
    currentProfile.value.id,
    `@${currentProfile.value.handle}`,
  )
}

function reportComment(comment: PicstagramComment): void {
  closeComments()
  startReport('comment', comment.id, `@${comment.handle}`)
}

function archiveSelectedPost(): void {
  if (!actionPost.value) return
  void store.setPostStatus(actionPost.value, 'archived')
  actionsOpen.value = false
}

async function submitReport(): Promise<void> {
  if (!reportTarget.value) return
  const response = await store.report(
    reportTarget.value.type,
    reportTarget.value.id,
    reportReason.value,
    reportDetails.value,
  )
  if (!response.success) {
    notify(errorMessage(response.error))
    return
  }
  reportOpen.value = false
  notify(t('reported'))
}

async function confirmBlock(): Promise<void> {
  const profileId = actionPost.value?.profile_id ?? currentProfile.value?.id
  if (!profileId) return
  blockDialogOpen.value = false
  actionsOpen.value = false
  if (await store.blockProfile(profileId)) notify(t('blocked'))
  else notify(errorMessage())
}

async function deleteSelectedPost(): Promise<void> {
  if (!actionPost.value) return
  const post = actionPost.value
  deleteDialogOpen.value = false
  actionsOpen.value = false
  if (await store.setPostStatus(post, 'removed')) {
    if (selectedPost.value?.id === post.id) selectedPost.value = null
    actionPost.value = null
    notify(t('deletePost'))
  } else notify(errorMessage())
}

async function openStory(story: PicstagramStory): Promise<void> {
  selectedStory.value = story
  await store.viewStory(story)
}

async function openStoryGroup(stories: PicstagramStory[]): Promise<void> {
  await openStory(stories.find((item) => !item.seen) ?? stories[0])
}

async function nextStory(direction: 1 | -1): Promise<void> {
  const current = selectedStoryPosition.value
  if (current < 0) return
  const next = store.stories[current + direction]
  if (!next) {
    selectedStory.value = null
    return
  }
  selectedStory.value = next
  await store.viewStory(next)
}

async function showStoryViewers(story: PicstagramStory): Promise<void> {
  if (!story.is_owner) return
  await store.loadStoryViewers(story.id)
  storyViewersOpen.value = true
}

async function removeSelectedStory(): Promise<void> {
  if (!selectedStory.value?.is_owner) return
  if (await store.removeStory(selectedStory.value.id)) {
    selectedStory.value = null
    notify(t('storyRemoved'))
  } else notify(errorMessage())
}

async function openModeration(): Promise<void> {
  if (!(await store.loadReports())) {
    notify(errorMessage('not_authorized'))
    return
  }
  moderationOpen.value = true
  actionsOpen.value = false
}

async function resolveReport(
  id: string,
  action: 'dismiss' | 'hide' | 'remove' | 'restore',
): Promise<void> {
  if (!(await store.resolveReport(id, action))) notify(errorMessage())
}

function activityProfile(activity: PicstagramActivity): void {
  void openProfile(activity.profile_id)
}

async function respondToFollowRequest(
  profileId: string,
  accept: boolean,
): Promise<void> {
  if (!(await store.respondFollow(profileId, accept))) {
    notify(errorMessage())
    return
  }
  notify(t(accept ? 'requestAccepted' : 'requestDeclined'))
}

watch(search, (value) => {
  if (searchTimer !== null) window.clearTimeout(searchTimer)
  searchTimer = window.setTimeout(() => {
    if (value.trim()) void store.search(value)
    else {
      store.searchPosts = []
      store.searchProfiles = []
    }
  }, 300)
})

onMounted(async () => {
  await store.bootstrap()
  const easyShareId = String(route.query.easyShareId ?? '')
  if (easyShareId && route.query.easyShareKind === 'profile') {
    await openProfile(easyShareId)
  } else if (easyShareId && route.query.easyShareKind === 'post') {
    const post = await store.loadPost(easyShareId)
    if (post) selectedPost.value = post
  }
  const composeSelection = mediaPicker.consumeMany<{
    caption?: string
    commentsEnabled?: boolean
    kind?: ComposeKind
    location?: string
    storyText?: string
  }>('picstagram:compose')
  if (composeSelection?.media.length) {
    selectedMedia.value = composeSelection.media
    composePreviewIndex.value = 0
    composeKind.value = composeSelection.context?.kind ?? 'post'
    caption.value = composeSelection.context?.caption ?? ''
    location.value = composeSelection.context?.location ?? ''
    storyText.value = composeSelection.context?.storyText ?? ''
    commentsEnabled.value = composeSelection.context?.commentsEnabled ?? true
    tab.value = 'create'
  }
  const avatarSelection = mediaPicker.consumeMany<{
    bio?: string
    displayName?: string
    handle?: string
    private?: boolean
  }>('picstagram:avatar')
  if (avatarSelection?.media[0] && store.profile) {
    selectedAvatar.value = avatarSelection.media[0]
    removeAvatar.value = false
    profileDraft.value = {
      bio: avatarSelection.context?.bio ?? store.profile.bio,
      displayName:
        avatarSelection.context?.displayName ?? store.profile.display_name,
      handle: avatarSelection.context?.handle ?? store.profile.handle,
      private: avatarSelection.context?.private ?? store.profile.private,
    }
    profileEditOpen.value = true
  }
})

onBeforeUnmount(() => {
  if (feedbackTimer !== null) window.clearTimeout(feedbackTimer)
  if (searchTimer !== null) window.clearTimeout(searchTimer)
  if (commentLikePulseTimer !== null) window.clearTimeout(commentLikePulseTimer)
  if (reactionPulseTimer !== null) window.clearTimeout(reactionPulseTimer)
})
</script>

<template>
  <SkyAppPage
    class="picstagram-page"
    :label="t('name')"
    :dark="phone.isDarkMode"
    accent="#ff2d55"
    accent-soft="rgba(255, 45, 85, 0.16)"
  >
    <div v-if="store.loading" class="ps-loading">
      <SkySpinner />
      <span>{{ t('loading') }}</span>
    </div>

    <template v-else-if="!store.authenticated">
      <SkyNavbar :title="t('name')" variant="medium" />
      <SkyScrollArea class="ps-auth">
        <SkyGlass class="ps-auth-card">
          <img :src="picstagramIcon" alt="" />
          <div>
            <h1>{{ t('authTitle') }}</h1>
            <p>{{ t(authMode === 'login' ? 'loginBody' : 'registerBody') }}</p>
          </div>
          <SkySegmented strong>
            <SkySegmentedButton
              :active="authMode === 'login'"
              @click="authMode = 'login'"
              >{{ t('login') }}</SkySegmentedButton
            >
            <SkySegmentedButton
              :active="authMode === 'register'"
              @click="authMode = 'register'"
              >{{ t('register') }}</SkySegmentedButton
            >
          </SkySegmented>
          <div class="ps-fields">
            <SkyField
              v-if="authMode === 'register'"
              v-model="authDisplayName"
              :label="t('displayName')"
              :placeholder="t('displayNamePlaceholder')"
              outline
            />
            <SkyField
              v-model="authHandle"
              :label="t('username')"
              :placeholder="t('usernamePlaceholder')"
              autocomplete="username"
              outline
            />
            <SkyField
              v-model="authPassword"
              :label="t('password')"
              :placeholder="t('passwordPlaceholder')"
              type="password"
              autocomplete="current-password"
              outline
            />
            <SkyField
              v-if="authMode === 'register'"
              v-model="authConfirmPassword"
              :label="t('confirmPassword')"
              :placeholder="t('confirmPasswordPlaceholder')"
              type="password"
              outline
            />
          </div>
          <SkyButton
            large
            rounded
            :disabled="authSubmitting"
            @click="submitAuth"
          >
            <SkySpinner v-if="authSubmitting" />
            {{ t(authMode === 'login' ? 'login' : 'createAccount') }}
          </SkyButton>
        </SkyGlass>
      </SkyScrollArea>
    </template>

    <template v-else>
      <template v-if="selectedPost">
        <SkyNavbar
          :title="t('post')"
          show-back
          :back-label="phone.t('Common.back')"
          back-appearance="surface"
          variant="medium"
          @back="closePost"
        />
        <SkyScrollArea with-tabbar class="ps-screen ps-post-detail">
          <article class="ps-post-card">
            <header class="ps-post-header">
              <button
                class="ps-author"
                @click="openProfile(selectedPost.profile_id)"
              >
                <span class="ps-avatar ps-avatar--small">
                  <img
                    v-if="selectedPost.avatar_url"
                    :src="selectedPost.avatar_url"
                    alt=""
                  />
                  <template v-else>{{
                    initials(selectedPost.display_name)
                  }}</template>
                </span>
                <span
                  ><strong
                    >{{ selectedPost.display_name }}
                    <Check
                      v-if="selectedPost.verified"
                      class="ps-verified" /></strong
                  ><small v-if="selectedPost.location">{{
                    selectedPost.location
                  }}</small></span
                >
              </button>
              <SkyLink
                component="button"
                icon-only
                class="ps-post-more"
                :aria-label="t('more')"
                @click="showPostActions($event, selectedPost)"
              >
                <MoreHorizontal />
              </SkyLink>
            </header>
            <div class="ps-carousel-shell">
              <div
                :data-picstagram-carousel="selectedPost.id"
                class="ps-carousel"
                @scroll.passive="updateCarousel(selectedPost, $event)"
                @dblclick="likeFromMedia(selectedPost)"
              >
                <template v-for="media in selectedPost.media" :key="media.id">
                  <video
                    v-if="media.media_type === 'video'"
                    :src="media.url"
                    controls
                    playsinline
                    preload="metadata"
                  />
                  <img v-else :src="media.url" alt="" />
                </template>
              </div>
              <template v-if="selectedPost.media.length > 1">
                <span class="ps-counter"
                  >{{ (carouselIndexes[selectedPost.id] ?? 0) + 1 }}/{{
                    selectedPost.media.length
                  }}</span
                >
                <SkyButton
                  glass
                  icon-only
                  rounded
                  class="ps-carousel-button ps-carousel-button--left"
                  :disabled="(carouselIndexes[selectedPost.id] ?? 0) === 0"
                  @click="moveCarousel(selectedPost, -1)"
                >
                  <ChevronLeft />
                </SkyButton>
                <SkyButton
                  glass
                  icon-only
                  rounded
                  class="ps-carousel-button ps-carousel-button--right"
                  :disabled="
                    (carouselIndexes[selectedPost.id] ?? 0) ===
                    selectedPost.media.length - 1
                  "
                  @click="moveCarousel(selectedPost, 1)"
                >
                  <ChevronRight />
                </SkyButton>
                <div class="ps-dots">
                  <span
                    v-for="(_, index) in selectedPost.media"
                    :key="index"
                    :class="{
                      active: (carouselIndexes[selectedPost.id] ?? 0) === index,
                    }"
                  />
                </div>
              </template>
            </div>
            <div class="ps-post-actions">
              <div>
                <button
                  :class="{
                    active: selectedPost.is_liked,
                    'reaction-pop':
                      reactionPulse?.id === selectedPost.id &&
                      reactionPulse.kind === 'like',
                    'reaction-pop--like':
                      reactionPulse?.id === selectedPost.id &&
                      reactionPulse.kind === 'like',
                  }"
                  @click="reactWithPulse(selectedPost, 'like')"
                >
                  <Heart
                    :fill="selectedPost.is_liked ? 'currentColor' : 'none'"
                  />
                  <span>{{ count(selectedPost.like_count) }}</span>
                </button>
                <button @click="openComments(selectedPost)">
                  <MessageCircle />
                  <span>{{ count(selectedPost.comment_count) }}</span>
                </button>
                <button @click="sharePost(selectedPost)"><Share2 /></button>
              </div>
              <button
                :class="{
                  active: selectedPost.is_saved,
                  'reaction-pop':
                    reactionPulse?.id === selectedPost.id &&
                    reactionPulse.kind === 'save',
                  'reaction-pop--save':
                    reactionPulse?.id === selectedPost.id &&
                    reactionPulse.kind === 'save',
                }"
                @click="reactWithPulse(selectedPost, 'save')"
              >
                <Bookmark
                  :fill="selectedPost.is_saved ? 'currentColor' : 'none'"
                />
              </button>
            </div>
            <div class="ps-post-copy">
              <p v-if="selectedPost.caption">
                <b>@{{ selectedPost.handle }}</b> {{ selectedPost.caption }}
              </p>
              <button
                v-if="selectedPost.comments_enabled"
                @click="openComments(selectedPost)"
              >
                {{
                  t('viewComments', {
                    count: count(selectedPost.comment_count),
                  })
                }}
              </button>
              <time>{{ relativeTime(selectedPost.created_at) }}</time>
            </div>
          </article>
        </SkyScrollArea>
      </template>

      <template v-else-if="tab === 'home'">
        <SkyNavbar class="ps-home-navbar" :title="t('name')" variant="compact">
          <template #left>
            <SkyLink
              component="button"
              icon-only
              :aria-label="t('newPost')"
              @click="beginPostCompose"
              ><Plus
            /></SkyLink>
          </template>
          <template #right>
            <SkyLink
              component="button"
              icon-only
              :aria-label="t('activity')"
              @click="showTab('activity')"
              ><span class="ps-badge-anchor"
                ><Bell /><b v-if="unreadCount">{{ unreadCount }}</b></span
              ></SkyLink
            >
          </template>
        </SkyNavbar>
        <SkyScrollArea with-tabbar class="ps-screen ps-feed">
          <div class="ps-stories" :aria-label="t('stories')">
            <button class="ps-story-add" @click="beginStoryCompose">
              <span class="ps-story-ring ps-story-ring--add"
                ><span class="ps-avatar"
                  ><img
                    v-if="store.profile?.avatar_url"
                    :src="store.profile.avatar_url"
                    alt=""
                  /><template v-else>{{
                    initials(store.profile?.display_name ?? '')
                  }}</template></span
                ><Plus /></span
              ><small>{{ t('yourStory') }}</small>
            </button>
            <button
              v-for="group in storyGroups"
              :key="group.stories[0].profile_id"
              @click="openStoryGroup(group.stories)"
            >
              <span
                class="ps-story-ring"
                :class="{ seen: group.stories.every((story) => story.seen) }"
                ><span class="ps-avatar"
                  ><img
                    v-if="group.avatar"
                    :src="group.avatar"
                    alt=""
                  /><template v-else>{{
                    initials(group.handle)
                  }}</template></span
                ></span
              ><small>{{ group.handle }}</small>
            </button>
          </div>
          <div v-if="!store.feed.length" class="ps-empty">
            <Images /><strong>{{ t('emptyFeed') }}</strong
            ><span>{{ t('emptyFeedBody') }}</span
            ><SkyButton rounded @click="showTab('explore')">{{
              t('discoverPeople')
            }}</SkyButton>
          </div>
          <article
            v-for="post in store.feed"
            :key="post.id"
            class="ps-post-card"
          >
            <header class="ps-post-header">
              <button class="ps-author" @click="openProfile(post.profile_id)">
                <span class="ps-avatar ps-avatar--small"
                  ><img
                    v-if="post.avatar_url"
                    :src="post.avatar_url"
                    alt=""
                  /><template v-else>{{
                    initials(post.display_name)
                  }}</template></span
                ><span
                  ><strong
                    >{{ post.display_name }}
                    <Check v-if="post.verified" class="ps-verified" /></strong
                  ><small v-if="post.location">{{ post.location }}</small></span
                >
              </button>
              <SkyLink
                component="button"
                icon-only
                class="ps-post-more"
                :aria-label="t('more')"
                @click="showPostActions($event, post)"
              >
                <MoreHorizontal />
              </SkyLink>
            </header>
            <div class="ps-carousel-shell">
              <div
                :data-picstagram-carousel="post.id"
                class="ps-carousel"
                @scroll.passive="updateCarousel(post, $event)"
                @dblclick="likeFromMedia(post)"
              >
                <template v-for="media in post.media" :key="media.id"
                  ><video
                    v-if="media.media_type === 'video'"
                    :src="media.url"
                    controls
                    playsinline
                    preload="metadata" /><img v-else :src="media.url" alt=""
                /></template>
              </div>
              <template v-if="post.media.length > 1">
                <span class="ps-counter"
                  >{{ (carouselIndexes[post.id] ?? 0) + 1 }}/{{
                    post.media.length
                  }}</span
                >
                <SkyButton
                  glass
                  icon-only
                  rounded
                  class="ps-carousel-button ps-carousel-button--left"
                  :disabled="(carouselIndexes[post.id] ?? 0) === 0"
                  @click="moveCarousel(post, -1)"
                >
                  <ChevronLeft />
                </SkyButton>
                <SkyButton
                  glass
                  icon-only
                  rounded
                  class="ps-carousel-button ps-carousel-button--right"
                  :disabled="
                    (carouselIndexes[post.id] ?? 0) === post.media.length - 1
                  "
                  @click="moveCarousel(post, 1)"
                >
                  <ChevronRight />
                </SkyButton>
                <div class="ps-dots">
                  <span
                    v-for="(_, index) in post.media"
                    :key="index"
                    :class="{
                      active: (carouselIndexes[post.id] ?? 0) === index,
                    }"
                  />
                </div>
              </template>
            </div>
            <div class="ps-post-actions">
              <div>
                <button
                  :class="{
                    active: post.is_liked,
                    'reaction-pop':
                      reactionPulse?.id === post.id &&
                      reactionPulse.kind === 'like',
                    'reaction-pop--like':
                      reactionPulse?.id === post.id &&
                      reactionPulse.kind === 'like',
                  }"
                  @click="reactWithPulse(post, 'like')"
                >
                  <Heart :fill="post.is_liked ? 'currentColor' : 'none'" />
                  <span>{{ count(post.like_count) }}</span></button
                ><button @click="openComments(post)">
                  <MessageCircle />
                  <span>{{ count(post.comment_count) }}</span></button
                ><button @click="sharePost(post)"><Share2 /></button>
              </div>
              <button
                :class="{
                  active: post.is_saved,
                  'reaction-pop':
                    reactionPulse?.id === post.id &&
                    reactionPulse.kind === 'save',
                  'reaction-pop--save':
                    reactionPulse?.id === post.id &&
                    reactionPulse.kind === 'save',
                }"
                @click="reactWithPulse(post, 'save')"
              >
                <Bookmark :fill="post.is_saved ? 'currentColor' : 'none'" />
              </button>
            </div>
            <div class="ps-post-copy">
              <p v-if="post.caption">
                <b>@{{ post.handle }}</b> {{ post.caption }}
              </p>
              <button v-if="post.comments_enabled" @click="openComments(post)">
                {{
                  t('viewComments', { count: count(post.comment_count) })
                }}</button
              ><time>{{ relativeTime(post.created_at) }}</time>
            </div>
          </article>
          <SkyButton
            v-if="store.feedCursor"
            rounded
            tonal
            class="ps-load-more"
            @click="store.loadFeed(true)"
            >{{ phone.t('Common.continue') }}</SkyButton
          >
        </SkyScrollArea>
      </template>

      <template v-else-if="tab === 'explore'">
        <SkyNavbar :title="t('explore')" variant="compact">
          <template #subnavbar
            ><SkySearchbar
              v-model="search"
              :label="t('searchPlaceholder')"
              :clear-label="phone.t('Common.clear')"
              :placeholder="t('searchPlaceholder')"
          /></template>
        </SkyNavbar>
        <SkyScrollArea with-tabbar class="ps-screen ps-explore">
          <div
            v-if="search && store.searchProfiles.length"
            class="ps-profile-results"
          >
            <button
              v-for="profile in store.searchProfiles"
              :key="profile.id"
              @click="openProfile(profile)"
            >
              <span class="ps-avatar"
                ><img
                  v-if="profile.avatar_url"
                  :src="profile.avatar_url"
                  alt=""
                /><template v-else>{{
                  initials(profile.display_name)
                }}</template></span
              ><span
                ><strong
                  >{{ profile.display_name }}
                  <Check v-if="profile.verified" class="ps-verified" /></strong
                ><small>@{{ profile.handle }}</small></span
              ><ChevronRight />
            </button>
          </div>
          <div class="ps-grid">
            <button
              v-for="post in search ? store.searchPosts : store.explore"
              :key="post.id"
              @click="openPost(post)"
            >
              <video
                v-if="post.media[0]?.media_type === 'video'"
                :src="post.media[0].url"
                muted
                preload="metadata"
              /><img
                v-else-if="post.media[0]"
                :src="post.media[0].url"
                alt=""
              /><span v-if="post.media.length > 1"
                ><Images />{{ post.media.length }}</span
              ><Video
                v-else-if="post.media[0]?.media_type === 'video'"
                class="ps-grid-video"
              />
            </button>
          </div>
          <div
            v-if="
              search &&
              !store.searchProfiles.length &&
              !store.searchPosts.length
            "
            class="ps-empty"
          >
            <Search /><strong>{{ t('noResults') }}</strong
            ><span>{{ t('noResultsBody') }}</span>
          </div>
        </SkyScrollArea>
      </template>

      <template v-else-if="tab === 'create'">
        <SkyNavbar
          :title="t(composeKind === 'post' ? 'newPost' : 'newStory')"
          show-back
          :back-label="phone.t('Common.back')"
          back-appearance="surface"
          variant="compact"
          @back="showTab('home')"
        >
          <template #right>
            <SkyLink
              component="button"
              class="ps-publish-link"
              :disabled="!selectedMedia.length || publishing"
              @click="publish"
            >
              <SkySpinner v-if="publishing" />
              {{ t(publishing ? 'publishing' : 'share') }}
            </SkyLink>
          </template>
        </SkyNavbar>
        <SkyScrollArea with-tabbar class="ps-screen ps-create">
          <SkySegmented strong>
            <SkySegmentedButton
              :active="composeKind === 'post'"
              @click="setComposeKind('post')"
              >{{ t('newPost') }}</SkySegmentedButton
            >
            <SkySegmentedButton
              :active="composeKind === 'story'"
              @click="setComposeKind('story')"
              >{{ t('newStory') }}</SkySegmentedButton
            >
          </SkySegmented>
          <SkyCard class="ps-create-card">
            <div
              v-if="selectedMedia.length && currentComposeMedia"
              class="ps-selection-preview"
            >
              <div :key="currentComposeMedia.id" class="ps-selection-slide">
                <video
                  v-if="currentComposeMedia.mediaType === 'video'"
                  :src="currentComposeMedia.url"
                  autoplay
                  loop
                  muted
                  playsinline
                />
                <img v-else :src="currentComposeMedia.url" alt="" />
                <button
                  class="ps-selection-remove"
                  :aria-label="t('remove')"
                  @click="removeComposeMedia(currentComposeMedia.id)"
                >
                  <X />
                </button>
              </div>
              <template v-if="selectedMedia.length > 1">
                <SkyButton
                  glass
                  icon-only
                  rounded
                  class="ps-selection-arrow ps-selection-arrow--left"
                  :aria-label="t('previousPhoto')"
                  :disabled="composePreviewIndex === 0"
                  @click="moveComposePreview(-1)"
                >
                  <ChevronLeft />
                </SkyButton>
                <SkyButton
                  glass
                  icon-only
                  rounded
                  class="ps-selection-arrow ps-selection-arrow--right"
                  :aria-label="t('nextPhoto')"
                  :disabled="composePreviewIndex === selectedMedia.length - 1"
                  @click="moveComposePreview(1)"
                >
                  <ChevronRight />
                </SkyButton>
                <span class="ps-selection-counter">
                  {{ composePreviewIndex + 1 }}/{{ selectedMedia.length }}
                </span>
                <div class="ps-selection-dots" aria-hidden="true">
                  <span
                    v-for="(_, index) in selectedMedia"
                    :key="index"
                    :class="{ active: composePreviewIndex === index }"
                  />
                </div>
              </template>
              <SkyChip>{{
                t('selectedPhotos', { count: String(selectedMedia.length) })
              }}</SkyChip>
              <span
                v-if="currentComposeMedia.mediaType === 'video'"
                class="ps-video-preview-badge"
                ><Video />{{ t('video') }}</span
              >
            </div>
            <template v-else>
              <div class="ps-create-intro">
                <span><ImagePlus /></span
                ><strong>{{
                  t(composeKind === 'post' ? 'newPost' : 'newStory')
                }}</strong>
                <p>
                  {{
                    t(
                      composeKind === 'post'
                        ? 'choosePhotosHint'
                        : 'chooseStoryHint',
                    )
                  }}
                </p>
              </div>
              <div class="ps-source-grid">
                <button @click="openComposeMedia('photos', 'photo')">
                  <Images /><span
                    ><strong>{{ t('photo') }}</strong
                    ><small>{{ t('gallery') }}</small></span
                  >
                </button>
                <button @click="openComposeMedia('camera', 'photo')">
                  <Camera /><span
                    ><strong>{{ t('photo') }}</strong
                    ><small>{{ t('camera') }}</small></span
                  >
                </button>
                <button @click="openComposeMedia('photos', 'video')">
                  <Video /><span
                    ><strong>{{ t('video') }}</strong
                    ><small>{{ t('gallery') }}</small></span
                  >
                </button>
                <button @click="openComposeMedia('camera', 'video')">
                  <Camera /><span
                    ><strong>{{ t('video') }}</strong
                    ><small>{{ t('camera') }}</small></span
                  >
                </button>
              </div>
            </template>
            <SkyButton
              v-if="selectedMedia.length"
              block
              rounded
              tonal
              class="ps-change-selection"
              @click="changeComposeSelection"
            >
              <Images />{{ t('changePhotos') }}
            </SkyButton>
          </SkyCard>
          <div class="ps-compose-fields">
            <SkyField
              v-if="composeKind === 'post'"
              v-model="caption"
              :label="t('caption')"
              :placeholder="t('captionPlaceholder')"
              type="textarea"
              :rows="4"
            />
            <SkyField
              v-else
              v-model="storyText"
              :label="t('story')"
              :placeholder="t('storyTextPlaceholder')"
              type="textarea"
              :rows="4"
            />
            <SkyField
              v-if="composeKind === 'post'"
              v-model="location"
              :label="t('location')"
              :placeholder="t('locationPlaceholder')"
              ><template #media><MapPin /></template
            ></SkyField>
            <label v-if="composeKind === 'post'" class="ps-toggle-row"
              ><span
                ><strong>{{ t('allowComments') }}</strong
                ><small>{{ t('comments') }}</small></span
              ><SkyToggle v-model="commentsEnabled"
            /></label>
          </div>
        </SkyScrollArea>
      </template>

      <template v-else-if="tab === 'activity'">
        <SkyNavbar :title="t('activity')" variant="large"
          ><template v-if="store.isAdmin" #right
            ><SkyLink
              component="button"
              icon-only
              :aria-label="t('moderation')"
              @click="openModeration"
              ><ShieldAlert /></SkyLink></template
        ></SkyNavbar>
        <SkyScrollArea with-tabbar class="ps-screen ps-activity">
          <button
            v-for="activity in store.activities"
            :key="activity.id"
            class="ps-activity-row"
            :class="{
              'ps-activity-row--request': activity.kind === 'follow_request',
            }"
            @click="activityProfile(activity)"
          >
            <span class="ps-avatar"
              ><img
                v-if="activity.avatar_url"
                :src="activity.avatar_url"
                alt=""
              /><template v-else>{{
                initials(activity.display_name)
              }}</template></span
            ><span
              ><strong
                >{{ activity.display_name }}
                <Check v-if="activity.verified" class="ps-verified" /></strong
              ><small
                >{{ t(`activityKinds.${activity.kind}`) }} ·
                {{ relativeTime(activity.created_at) }}</small
              ></span
            >
            <div
              v-if="activity.kind === 'follow_request'"
              class="ps-request-actions"
              @click.stop
            >
              <SkyButton
                small
                rounded
                @click="respondToFollowRequest(activity.profile_id, true)"
                >{{ t('accept') }}</SkyButton
              ><SkyButton
                small
                rounded
                tonal
                @click="respondToFollowRequest(activity.profile_id, false)"
                >{{ t('decline') }}</SkyButton
              >
            </div>
          </button>
          <div v-if="!store.activities.length" class="ps-empty">
            <Bell /><strong>{{ t('noActivity') }}</strong>
          </div>
        </SkyScrollArea>
      </template>

      <template v-else-if="tab === 'profile'">
        <SkyNavbar
          :title="currentProfile?.display_name ?? t('profile')"
          variant="compact"
        >
          <template #left>
            <SkyLink
              v-if="currentProfile?.is_owner"
              component="button"
              icon-only
              :aria-label="t('newPost')"
              @click="beginPostCompose"
            >
              <Plus />
            </SkyLink>
            <SkyLink
              v-else
              component="button"
              icon-only
              :aria-label="phone.t('Common.back')"
              @click="goBackFromProfile"
            >
              <ChevronLeft />
            </SkyLink>
          </template>
          <template #title>
            <span class="ps-profile-navbar-title">
              <LockKeyhole
                v-if="currentProfile?.private"
                :aria-label="t('privateProfileSetting')"
              />
              {{ currentProfile ? currentProfile.handle : t('profile') }}
            </span>
          </template>
          <template #right
            ><SkyLink
              component="button"
              icon-only
              :aria-label="t('more')"
              @click="showProfileActions"
              ><MoreHorizontal /></SkyLink></template
        ></SkyNavbar>
        <SkyScrollArea
          v-if="currentProfile"
          with-tabbar
          class="ps-screen ps-profile"
        >
          <section class="ps-profile-header">
            <span class="ps-avatar ps-avatar--profile"
              ><img
                v-if="currentProfile.avatar_url"
                :src="currentProfile.avatar_url"
                alt=""
              /><template v-else>{{
                initials(currentProfile.display_name)
              }}</template></span
            >
            <div class="ps-profile-stats">
              <button>
                <strong>{{ count(currentProfile.post_count) }}</strong
                ><small>{{ t('posts') }}</small></button
              ><button @click="openConnections('followers')">
                <strong>{{ count(currentProfile.followers) }}</strong
                ><small>{{ t('followers') }}</small></button
              ><button @click="openConnections('following')">
                <strong>{{ count(currentProfile.following) }}</strong
                ><small>{{ t('following') }}</small>
              </button>
            </div>
            <div class="ps-profile-copy">
              <strong
                >{{ currentProfile.display_name }}
                <Check v-if="currentProfile.verified" class="ps-verified"
              /></strong>
              <p>{{ currentProfile.bio || t('emptyBio') }}</p>
            </div>
            <div
              v-if="currentProfile.is_owner"
              class="ps-profile-owner-actions"
            >
              <SkyButton block rounded @click="editProfile">
                {{ t('editProfile') }}
              </SkyButton>
              <SkyButton block rounded tonal @click="shareCurrentProfile">
                {{ t('shareProfile') }}
              </SkyButton>
            </div>
            <div v-else class="ps-profile-buttons">
              <SkyButton
                rounded
                :tonal="
                  currentProfile.is_following || currentProfile.is_requested
                "
                @click="follow(currentProfile)"
                >{{
                  t(
                    currentProfile.is_requested
                      ? 'requested'
                      : currentProfile.is_following
                        ? 'unfollow'
                        : 'follow',
                  )
                }}</SkyButton
              >
            </div>
          </section>
          <div v-if="currentProfile.locked" class="ps-empty ps-private">
            <LockKeyhole /><strong>{{ t('privateProfile') }}</strong
            ><span>{{ t('privateProfileBody') }}</span>
          </div>
          <template v-else>
            <div
              class="ps-profile-filters"
              role="tablist"
              :aria-label="t('posts')"
            >
              <button
                role="tab"
                :aria-selected="profileSection === 'all'"
                :class="{ active: profileSection === 'all' }"
                :aria-label="t('allPosts')"
                :title="t('allPosts')"
                @click="profileSection = 'all'"
              >
                <Grid3X3 />
              </button>
              <button
                role="tab"
                :aria-selected="profileSection === 'videos'"
                :class="{ active: profileSection === 'videos' }"
                :aria-label="t('videos')"
                :title="t('videos')"
                @click="profileSection = 'videos'"
              >
                <Video />
              </button>
              <button
                role="tab"
                :aria-selected="profileSection === 'tagged'"
                :class="{ active: profileSection === 'tagged' }"
                :aria-label="t('taggedPosts')"
                :title="t('taggedPosts')"
                @click="profileSection = 'tagged'"
              >
                <UserRound />
              </button>
            </div>
            <div class="ps-grid">
              <button
                v-for="post in profileGrid"
                :key="post.id"
                @click="openPost(post)"
              >
                <video
                  v-if="post.media[0]?.media_type === 'video'"
                  :src="post.media[0].url"
                  muted
                  preload="metadata"
                /><img
                  v-else-if="post.media[0]"
                  :src="post.media[0].url"
                  alt=""
                /><span v-if="post.media.length > 1"
                  ><Images />{{ post.media.length }}</span
                ><Video
                  v-else-if="post.media[0]?.media_type === 'video'"
                  class="ps-grid-video"
                />
              </button>
            </div>
          </template>
        </SkyScrollArea>
      </template>

      <SkyPillNavigation class="ps-navigation" :label="t('name')" layout="full">
        <SkySegmented
          class="ps-navigation-segments"
          :active-index="tabIndex"
          :item-count="4"
          :aria-label="t('name')"
          navigation
        >
          <SkySegmentedButton
            :active="tab === 'home'"
            class="ps-nav-button"
            @click="showTab('home')"
          >
            <Home /><small>{{ t('home') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="tab === 'explore'"
            class="ps-nav-button"
            @click="showTab('explore')"
          >
            <Compass /><small>{{ t('explore') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="tab === 'activity'"
            class="ps-nav-button"
            @click="showTab('activity')"
          >
            <span class="ps-badge-anchor"
              ><Bell /><b v-if="unreadCount">{{ unreadCount }}</b></span
            ><small>{{ t('activity') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="tab === 'profile'"
            class="ps-nav-button"
            @click="showTab('profile')"
          >
            <UserRound /><small>{{ t('profile') }}</small>
          </SkySegmentedButton>
        </SkySegmented>
      </SkyPillNavigation>
    </template>

    <SkySheet
      :opened="commentsOpen"
      class="ps-sheet"
      :aria-label="t('comments')"
      swipe-to-close
      @backdropclick="closeComments"
      @escape="closeComments"
      @swipeclose="closeComments"
    >
      <section class="ps-comments-sheet">
        <header>
          <strong>{{ t('comments') }}</strong
          ><button :aria-label="t('share')" @click="shareCommentPost">
            <Share2 />
          </button>
        </header>
        <div class="ps-comments-list">
          <div v-if="!store.comments.length" class="ps-empty">
            <MessageCircle /><strong>{{ t('noComments') }}</strong>
          </div>
          <div
            v-for="thread in commentThreads"
            :key="thread.comment.id"
            class="ps-comment-thread"
          >
            <article class="ps-comment-row">
              <button
                class="ps-avatar ps-avatar--comment"
                @click="openProfile(thread.comment.profile_id)"
              >
                <img
                  v-if="thread.comment.avatar_url"
                  :src="thread.comment.avatar_url"
                  alt=""
                /><template v-else>{{
                  initials(thread.comment.display_name)
                }}</template>
              </button>
              <div class="ps-comment-copy">
                <header>
                  <button @click="openProfile(thread.comment.profile_id)">
                    {{ thread.comment.display_name }}
                    <Check
                      v-if="thread.comment.verified"
                      class="ps-verified"
                    /></button
                  ><time>{{ relativeTime(thread.comment.created_at) }}</time>
                </header>
                <p>{{ thread.comment.body }}</p>
                <footer>
                  <button @click="startReply(thread.comment)">
                    <Reply />{{ t('reply') }}</button
                  ><button
                    v-if="thread.comment.is_owner"
                    @click="store.removeComment(thread.comment.id)"
                  >
                    <Trash2 />{{ t('remove') }}</button
                  ><button v-else @click="reportComment(thread.comment)">
                    {{ t('report') }}
                  </button>
                </footer>
              </div>
              <button
                class="ps-comment-like"
                :class="{
                  active: thread.comment.is_liked,
                  pulse: commentLikePulseId === thread.comment.id,
                }"
                @click="reactComment(thread.comment)"
              >
                <Heart
                  :fill="thread.comment.is_liked ? 'currentColor' : 'none'"
                /><small>{{ thread.comment.like_count || '' }}</small>
              </button>
            </article>
            <button
              v-if="thread.replies.length"
              class="ps-comment-replies-toggle"
              @click="toggleCommentThread(thread.comment.id)"
            >
              <span />
              {{
                t(
                  expandedCommentThreads.has(thread.comment.id)
                    ? 'hideReplies'
                    : 'showReplies',
                  { count: count(thread.replies.length) },
                )
              }}
            </button>
            <template v-if="expandedCommentThreads.has(thread.comment.id)">
              <article
                v-for="reply in thread.replies"
                :key="reply.id"
                class="ps-comment-row ps-comment-row--reply"
              >
                <button
                  class="ps-avatar ps-avatar--reply"
                  @click="openProfile(reply.profile_id)"
                >
                  <img
                    v-if="reply.avatar_url"
                    :src="reply.avatar_url"
                    alt=""
                  /><template v-else>{{
                    initials(reply.display_name)
                  }}</template>
                </button>
                <div class="ps-comment-copy">
                  <header>
                    <button @click="openProfile(reply.profile_id)">
                      {{ reply.display_name }}
                      <Check
                        v-if="reply.verified"
                        class="ps-verified"
                      /></button
                    ><time>{{ relativeTime(reply.created_at) }}</time>
                  </header>
                  <p>
                    <b v-if="reply.display_reply_to_handle"
                      >@{{ reply.display_reply_to_handle }}</b
                    >
                    {{ reply.display_body }}
                  </p>
                  <footer>
                    <button @click="startReply(reply)">
                      <Reply />{{ t('reply') }}</button
                    ><button
                      v-if="reply.is_owner"
                      @click="store.removeComment(reply.id)"
                    >
                      <Trash2 />{{ t('remove') }}</button
                    ><button v-else @click="reportComment(reply)">
                      {{ t('report') }}
                    </button>
                  </footer>
                </div>
                <button
                  class="ps-comment-like"
                  :class="{
                    active: reply.is_liked,
                    pulse: commentLikePulseId === reply.id,
                  }"
                  @click="reactComment(reply)"
                >
                  <Heart
                    :fill="reply.is_liked ? 'currentColor' : 'none'"
                  /><small>{{ reply.like_count || '' }}</small>
                </button>
              </article>
            </template>
          </div>
        </div>
        <div
          class="ps-comment-composer"
          :class="{ 'ps-comment-composer--replying': replyingTo }"
        >
          <div v-if="replyingTo" class="ps-replying">
            <span>{{
              t('replyingTo', { handle: `@${replyingTo.handle}` })
            }}</span
            ><button :aria-label="t('cancel')" @click="replyingTo = null">
              <X />
            </button>
          </div>
          <SkyMessagebar
            v-model="commentBody"
            embedded
            :placeholder="t(replyingTo ? 'replyPlaceholder' : 'addComment')"
            @keydown.enter.prevent="submitComment"
            ><template #right
              ><button :disabled="!commentBody.trim()" @click="submitComment">
                <Send /></button></template
          ></SkyMessagebar>
        </div>
      </section>
    </SkySheet>

    <SkySheet
      :opened="profileEditOpen"
      class="ps-sheet"
      :aria-label="t('editProfile')"
      @backdropclick="profileEditOpen = false"
      @escape="profileEditOpen = false"
    >
      <div class="ps-sheet-handle" />
      <section class="ps-edit-sheet">
        <header>
          <button @click="profileEditOpen = false">{{ t('cancel') }}</button
          ><strong>{{ t('editProfile') }}</strong
          ><button class="ps-save-link" @click="saveProfile">
            {{ t('done') }}
          </button>
        </header>
        <div class="ps-edit-avatar">
          <span class="ps-avatar ps-avatar--edit"
            ><img
              v-if="
                selectedAvatar?.url ||
                (!removeAvatar && store.profile?.avatar_url)
              "
              :src="selectedAvatar?.url ?? store.profile?.avatar_url ?? ''"
              alt=""
            /><template v-else>{{
              initials(profileDraft.displayName)
            }}</template></span
          ><strong>{{ t('avatar') }}</strong>
          <div>
            <SkyButton small rounded tonal @click="openAvatarMedia('photos')"
              ><Images />{{ t('gallery') }}</SkyButton
            ><SkyButton small rounded tonal @click="openAvatarMedia('camera')"
              ><Camera />{{ t('camera') }}</SkyButton
            >
          </div>
          <button class="ps-danger-link" @click="clearAvatarSelection">
            {{ t('removeAvatar') }}
          </button>
        </div>
        <div class="ps-edit-fields">
          <SkyList inset strong class="ps-edit-field-list">
            <SkyField
              v-model="profileDraft.displayName"
              :label="t('displayName')"
              maxlength="40"
            />
            <SkyField
              v-model="profileDraft.handle"
              :label="t('username')"
              maxlength="24"
            />
            <SkyField
              v-model="profileDraft.bio"
              :label="t('bio')"
              type="textarea"
              :rows="4"
              maxlength="160"
            />
          </SkyList>
          <section class="ps-privacy-control">
            <span class="ps-privacy-control__icon">
              <LockKeyhole v-if="profileDraft.private" />
              <UserRound v-else />
            </span>
            <div>
              <strong>{{
                t(
                  profileDraft.private
                    ? 'privateProfileSetting'
                    : 'publicProfile',
                )
              }}</strong>
              <small>{{ t('privacyHint') }}</small>
            </div>
            <SkyToggle
              v-model="profileDraft.private"
              :aria-label="t('privateProfileSetting')"
            />
          </section>
        </div>
      </section>
    </SkySheet>

    <SkySheet
      :opened="connectionsOpen"
      class="ps-sheet"
      :aria-label="t(connectionsMode)"
      @backdropclick="connectionsOpen = false"
      @escape="connectionsOpen = false"
    >
      <div class="ps-sheet-handle" />
      <section class="ps-connections-sheet">
        <header>
          <span
            ><UsersRound /><strong>{{ t(connectionsMode) }}</strong></span
          ><button @click="connectionsOpen = false"><X /></button>
        </header>
        <div>
          <article v-for="profile in store.connections" :key="profile.id">
            <button
              class="ps-connection-profile"
              @click="openConnectionProfile(profile)"
            >
              <span class="ps-avatar"
                ><img
                  v-if="profile.avatar_url"
                  :src="profile.avatar_url"
                  alt=""
                /><template v-else>{{
                  initials(profile.display_name)
                }}</template></span
              ><span
                ><strong
                  >{{ profile.display_name }}
                  <Check v-if="profile.verified" class="ps-verified" /></strong
                ><small>@{{ profile.handle }}</small></span
              ></button
            ><SkyButton
              v-if="!profile.is_owner"
              small
              rounded
              :tonal="profile.is_following || profile.is_requested"
              @click="follow(profile)"
              >{{
                t(
                  profile.is_requested
                    ? 'requested'
                    : profile.is_following
                      ? 'unfollow'
                      : 'follow',
                )
              }}</SkyButton
            >
          </article>
          <div v-if="!store.connections.length" class="ps-empty">
            <UsersRound /><strong>{{ t('noConnections') }}</strong>
          </div>
        </div>
      </section>
    </SkySheet>

    <SkySheet
      :opened="Boolean(selectedStory)"
      class="ps-story-sheet"
      :aria-label="t('story')"
      @backdropclick="selectedStory = null"
      @escape="selectedStory = null"
    >
      <section v-if="selectedStory" class="ps-story-viewer">
        <div class="ps-story-progress">
          <span
            v-for="(_, index) in selectedStoryGroup"
            :key="index"
            :class="{ active: index <= selectedStoryGroupPosition }"
          />
        </div>
        <SkyGlass class="ps-story-header"
          ><span class="ps-avatar ps-avatar--small"
            ><img
              v-if="selectedStory.avatar_url"
              :src="selectedStory.avatar_url"
              alt=""
            /><template v-else>{{
              initials(selectedStory.display_name)
            }}</template></span
          ><span
            ><strong>@{{ selectedStory.handle }}</strong
            ><small>{{ relativeTime(selectedStory.created_at) }}</small></span
          ><button @click="selectedStory = null"><X /></button
        ></SkyGlass>
        <video
          v-if="selectedStory.media_type === 'video'"
          :src="selectedStory.url"
          autoplay
          controls
          playsinline
        /><img v-else :src="selectedStory.url" alt="" />
        <p v-if="selectedStory.body">{{ selectedStory.body }}</p>
        <button class="ps-story-nav ps-story-nav--left" @click="nextStory(-1)">
          <ChevronLeft /></button
        ><button class="ps-story-nav ps-story-nav--right" @click="nextStory(1)">
          <ChevronRight />
        </button>
        <div class="ps-story-actions">
          <SkyButton
            v-if="selectedStory.is_owner"
            rounded
            tonal
            @click="showStoryViewers(selectedStory)"
            ><Eye />{{
              t('seenBy', { count: count(selectedStory.view_count) })
            }}</SkyButton
          ><SkyButton
            v-if="selectedStory.is_owner"
            rounded
            tonal
            @click="removeSelectedStory"
            ><Trash2 />{{ t('removeStory') }}</SkyButton
          ><SkyButton v-else rounded tonal @click="reportSelectedStory">{{
            t('report')
          }}</SkyButton>
        </div>
      </section>
    </SkySheet>

    <SkySheet
      :opened="storyViewersOpen"
      class="ps-sheet"
      :aria-label="t('storyViewers')"
      @backdropclick="storyViewersOpen = false"
      @escape="storyViewersOpen = false"
      ><div class="ps-sheet-handle" />
      <section class="ps-connections-sheet">
        <header>
          <span
            ><Eye /><strong>{{ t('storyViewers') }}</strong></span
          ><button @click="storyViewersOpen = false"><X /></button>
        </header>
        <div>
          <article v-for="viewer in store.storyViewers" :key="viewer.id">
            <button class="ps-connection-profile">
              <span class="ps-avatar"
                ><img
                  v-if="viewer.avatar_url"
                  :src="viewer.avatar_url"
                  alt=""
                /><template v-else>{{
                  initials(viewer.display_name)
                }}</template></span
              ><span
                ><strong>{{ viewer.display_name }}</strong
                ><small>@{{ viewer.handle }}</small></span
              >
            </button>
          </article>
        </div>
      </section></SkySheet
    >

    <SkySheet
      :opened="reportOpen"
      class="ps-sheet"
      :aria-label="t('report')"
      @backdropclick="reportOpen = false"
      @escape="reportOpen = false"
      ><div class="ps-sheet-handle" />
      <section class="ps-report-sheet">
        <header>
          <strong>{{
            t('reportTarget', { target: reportTarget?.label ?? '' })
          }}</strong
          ><button @click="reportOpen = false"><X /></button>
        </header>
        <SkyList inset strong
          ><SkyListItem
            v-for="reason in reportReasons"
            :key="reason"
            link
            link-component="button"
            :chevron="false"
            :title="t(`reportReasons.${reason}`)"
            @click="reportReason = reason"
            ><template #after
              ><Check
                v-if="reportReason === reason"
                class="ps-selection-check" /></template></SkyListItem></SkyList
        ><SkyField
          v-model="reportDetails"
          :label="t('reportDetails')"
          type="textarea"
          :rows="5"
          outline
        /><SkyButton large rounded @click="submitReport">{{
          t('submitReport')
        }}</SkyButton>
      </section></SkySheet
    >

    <SkySheet
      :opened="moderationOpen"
      class="ps-sheet"
      :aria-label="t('moderation')"
      @backdropclick="moderationOpen = false"
      @escape="moderationOpen = false"
      ><div class="ps-sheet-handle" />
      <section class="ps-moderation-sheet">
        <header>
          <strong>{{ t('moderation') }}</strong
          ><button @click="moderationOpen = false"><X /></button>
        </header>
        <div v-if="!store.reports.length" class="ps-empty">
          <ShieldAlert /><strong>{{ t('noReports') }}</strong>
        </div>
        <SkyCard
          v-for="report in store.reports"
          :key="report.id"
          class="ps-report-card"
          ><strong
            >{{ t(`reportTargets.${report.target_type}`) }} ·
            {{ t(`reportReasons.${report.reason}`) }}</strong
          >
          <p>
            @{{ report.reporter_handle }} ·
            {{ report.details || t('noDetails') }}
          </p>
          <div>
            <SkyButton
              small
              rounded
              tonal
              @click="resolveReport(report.id, 'dismiss')"
              >{{ t('dismiss') }}</SkyButton
            ><SkyButton
              small
              rounded
              tonal
              @click="resolveReport(report.id, 'hide')"
              >{{ t('hide') }}</SkyButton
            ><SkyButton
              small
              rounded
              tonal
              @click="resolveReport(report.id, 'remove')"
              >{{ t('remove') }}</SkyButton
            >
          </div></SkyCard
        >
      </section></SkySheet
    >

    <SkyDropdown
      :items="postMenuItems"
      :label="t('more')"
      :opened="postMenuOpened"
      placement="auto"
      :target="postMenuTarget"
      @backdropclick="dismissPostMenu"
      @escape="dismissPostMenu"
      @positionerror="dismissPostMenu"
      @select="selectPostMenuItem"
    />

    <SkyActionSheet
      :opened="actionsOpen"
      :label="t('more')"
      @backdropclick="actionsOpen = false"
      @escape="actionsOpen = false"
    >
      <SkyActionGroup v-if="currentProfile"
        ><SkyActionButton @click="shareCurrentProfile">{{
          t('shareProfile')
        }}</SkyActionButton
        ><SkyActionButton v-if="currentProfile.is_owner" @click="editProfile">{{
          t('editProfile')
        }}</SkyActionButton
        ><SkyActionButton
          v-if="currentProfile.is_owner && store.isAdmin"
          @click="openModeration"
          >{{ t('moderation') }}</SkyActionButton
        ><SkyActionButton
          v-if="currentProfile.is_owner"
          @click="logoutDialogOpen = true"
          >{{ t('logout') }}</SkyActionButton
        ><SkyActionButton
          v-if="!currentProfile.is_owner"
          @click="reportCurrentProfile"
          >{{ t('report') }}</SkyActionButton
        ><SkyActionButton
          v-if="!currentProfile.is_owner"
          @click="blockDialogOpen = true"
          >{{ t('block') }}</SkyActionButton
        ></SkyActionGroup
      >
      <SkyActionGroup
        ><SkyActionButton bold @click="actionsOpen = false">{{
          t('cancel')
        }}</SkyActionButton></SkyActionGroup
      >
    </SkyActionSheet>

    <SkyDialog
      :opened="logoutDialogOpen"
      @backdropclick="!logoutSubmitting && (logoutDialogOpen = false)"
      ><template #title>{{ t('signOutTitle') }}</template>
      <p>{{ t('signOutBody') }}</p>
      <template #buttons
        ><SkyDialogButton
          :disabled="logoutSubmitting"
          @click="logoutDialogOpen = false"
          >{{ t('cancel') }}</SkyDialogButton
        ><SkyDialogButton
          strong
          :disabled="logoutSubmitting"
          @click="signOut"
          >{{ t(logoutSubmitting ? 'signingOut' : 'logout') }}</SkyDialogButton
        ></template
      ></SkyDialog
    >
    <SkyDialog
      :opened="deleteDialogOpen"
      @backdropclick="deleteDialogOpen = false"
      ><template #title>{{ t('deletePostTitle') }}</template>
      <p>{{ t('deletePostBody') }}</p>
      <template #buttons
        ><SkyDialogButton @click="deleteDialogOpen = false">{{
          t('cancel')
        }}</SkyDialogButton
        ><SkyDialogButton strong @click="deleteSelectedPost">{{
          t('deletePost')
        }}</SkyDialogButton></template
      ></SkyDialog
    >
    <SkyDialog
      :opened="blockDialogOpen"
      @backdropclick="blockDialogOpen = false"
      ><template #title>{{
        t('blockTitle', {
          handle: actionPost?.handle ?? currentProfile?.handle ?? '',
        })
      }}</template>
      <p>{{ t('blockBody') }}</p>
      <template #buttons
        ><SkyDialogButton @click="blockDialogOpen = false">{{
          t('cancel')
        }}</SkyDialogButton
        ><SkyDialogButton strong @click="confirmBlock">{{
          t('block')
        }}</SkyDialogButton></template
      ></SkyDialog
    >
    <SkyNotification :opened="Boolean(feedback)" :text="feedback" />
  </SkyAppPage>
</template>

<style scoped>
.picstagram-page {
  --ps-accent: var(--sky-app-accent);
  --ps-accent-soft: var(--sky-app-accent-soft);
  background: var(--sky-bg);
  color: var(--sky-text);
}

button {
  color: inherit;
  font: inherit;
}
.ps-loading,
.ps-empty {
  display: grid;
  place-items: center;
  gap: var(--sky-space-2);
  text-align: center;
  color: var(--sky-muted);
}
.ps-loading {
  min-height: 100%;
  align-content: center;
}
.ps-loading svg,
.ps-empty > svg {
  width: 34px;
  height: 34px;
}
.ps-empty strong {
  color: var(--sky-text);
  font-size: 17px;
}
.ps-empty span {
  max-width: 270px;
  font-size: 13px;
  line-height: 1.4;
}
.ps-screen {
  padding: var(--sky-space-3) 0
    calc(
      var(--sky-safe-area-bottom) + var(--sky-tabbar-height) +
        var(--sky-space-5)
    );
}

.ps-auth {
  padding: var(--sky-space-5) var(--sky-page-gutter);
}
.ps-auth-card {
  display: grid;
  gap: var(--sky-space-4);
  padding: var(--sky-space-5);
  border-radius: var(--sky-radius-sheet);
}
.ps-auth-card > img {
  width: 74px;
  height: 74px;
  margin: 0 auto;
  border-radius: 22px;
}
.ps-auth-card h1 {
  margin: 0;
  text-align: center;
  font-size: 25px;
}
.ps-auth-card p {
  margin: 6px 0 0;
  text-align: center;
  color: var(--sky-muted);
  font-size: 13px;
  line-height: 1.4;
}
.ps-fields,
.ps-compose-fields,
.ps-edit-fields {
  display: grid;
  gap: var(--sky-space-3);
}

.ps-navigation {
  position: absolute !important;
  z-index: 30;
  right: calc(var(--sky-safe-area-right) + var(--sky-page-gutter));
  bottom: calc(var(--sky-safe-area-bottom) + 10px);
  left: calc(var(--sky-safe-area-left) + var(--sky-page-gutter));
  min-height: 56px;
  padding: 0 !important;
  background: transparent !important;
  color: var(--sky-text) !important;
}
.ps-navigation-segments {
  width: 100%;
}
.ps-nav-button {
  min-width: 0;
  padding-inline: var(--sky-space-1) !important;
}
.ps-nav-button svg {
  width: 19px;
  height: 19px;
}
.ps-nav-button small {
  overflow: hidden;
  max-width: 100%;
  font-size: 9px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ps-badge-anchor {
  position: relative;
  display: inline-flex;
}
.ps-badge-anchor b {
  position: absolute;
  top: -7px;
  right: -9px;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  color: white;
  border-radius: var(--sky-radius-pill);
  background: var(--ps-accent);
  font-size: 9px;
  line-height: 16px;
}

.ps-home-navbar :deep(.sky-navbar__inner) {
  margin-bottom: 2px;
  transform: translateY(-3px);
}

.ps-stories {
  display: flex;
  gap: 14px;
  overflow-x: auto;
  padding: 4px var(--sky-page-gutter) var(--sky-space-4);
  scrollbar-width: none;
}
.ps-stories::-webkit-scrollbar,
.ps-carousel::-webkit-scrollbar {
  display: none;
}
.ps-stories button,
.ps-story-add {
  display: grid;
  flex: 0 0 66px;
  justify-items: center;
  gap: 5px;
  padding: 0;
  border: 0;
  background: transparent;
}
.ps-stories small {
  overflow: hidden;
  width: 66px;
  font-size: 10px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ps-story-ring {
  display: grid;
  place-items: center;
  width: 62px;
  height: 62px;
  padding: 3px;
  border-radius: 50%;
  background: linear-gradient(140deg, #ffcc00, #ff2d55 50%, #af52de);
}
.ps-story-ring.seen {
  background: var(--sky-hairline);
}
.ps-story-ring--add {
  position: relative;
  background: var(--sky-surface-variant);
}
.ps-story-ring--add > svg {
  position: absolute;
  right: 0;
  bottom: 0;
  width: 19px;
  height: 19px;
  padding: 3px;
  color: white;
  border: 2px solid var(--sky-bg);
  border-radius: 50%;
  background: var(--ps-accent);
}
.ps-avatar {
  display: grid;
  place-items: center;
  overflow: hidden;
  width: 50px;
  height: 50px;
  flex: 0 0 auto;
  border-radius: 50%;
  background: var(--sky-surface-variant);
  color: var(--sky-text);
  font-size: 14px;
  font-weight: 750;
}
.ps-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.ps-story-ring .ps-avatar {
  width: 56px;
  height: 56px;
  border: 2px solid var(--sky-bg);
}
.ps-avatar--small {
  width: 36px;
  height: 36px;
  font-size: 11px;
}
.ps-avatar--comment {
  width: 38px;
  height: 38px;
  border: 0;
}
.ps-avatar--reply {
  width: 30px;
  height: 30px;
  border: 0;
  font-size: 9px;
}
.ps-avatar--profile {
  width: 88px;
  height: 88px;
  font-size: 24px;
}
.ps-avatar--edit {
  width: 96px;
  height: 96px;
  font-size: 26px;
}

.ps-feed {
  display: grid;
  grid-auto-rows: max-content;
  align-content: start;
  gap: var(--sky-space-3);
  padding-top: 0;
}
.ps-feed > .ps-empty {
  min-height: 320px;
  padding: var(--sky-space-6);
}
.ps-post-card {
  overflow: hidden;
  background: var(--sky-surface);
  border-block: 1px solid var(--sky-hairline);
}
.ps-feed > .ps-post-card {
  margin-inline: 8px;
  border: 1px solid var(--sky-hairline);
  border-radius: 14px;
}
.ps-post-detail {
  padding-inline: var(--sky-page-gutter);
}
.ps-post-detail .ps-post-card {
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
}
.ps-post-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 58px;
  padding: 9px var(--sky-page-gutter);
}
.ps-author {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
  padding: 0;
  border: 0;
  background: transparent;
  text-align: left;
}
.ps-author > span:last-child {
  display: grid;
  min-width: 0;
}
.ps-author strong {
  display: flex;
  align-items: center;
  gap: 3px;
  overflow: hidden;
  font-size: 13px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ps-author small {
  color: var(--sky-muted);
  font-size: 11px;
}
.ps-verified {
  display: inline;
  width: 14px;
  height: 14px;
  padding: 2px;
  color: white;
  border-radius: 50%;
  background: var(--ps-accent);
  stroke-width: 3;
}
.ps-icon-button {
  display: grid;
  place-items: center;
  width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  padding: 0;
  border: 0;
  background: transparent;
}
.ps-icon-button svg {
  width: 22px;
}
.ps-carousel-shell {
  position: relative;
}
.ps-carousel {
  display: flex;
  overflow-x: auto;
  aspect-ratio: 1 / 1;
  scroll-snap-type: x mandatory;
  background: #060606;
}
.ps-carousel img,
.ps-carousel video {
  width: 100%;
  height: 100%;
  flex: 0 0 100%;
  object-fit: cover;
  scroll-snap-align: start;
}
.ps-counter {
  position: absolute;
  top: 10px;
  right: 10px;
  padding: 5px 9px;
  color: white;
  border-radius: var(--sky-radius-pill);
  background: rgba(0, 0, 0, 0.62);
  font-size: 11px;
  font-weight: 700;
}
.ps-carousel-button {
  position: absolute;
  top: 50%;
  display: grid;
  place-items: center;
  width: 44px;
  min-width: 44px;
  height: 44px;
  min-height: 44px;
  padding: 0;
  color: white;
  transform: translateY(-50%);
}
.ps-carousel-button:disabled {
  opacity: 0;
  pointer-events: none;
}
.ps-carousel-button--left {
  left: 8px;
}
.ps-carousel-button--right {
  right: 8px;
}
.ps-carousel-button svg {
  width: 20px;
}
.ps-dots {
  position: absolute;
  bottom: 8px;
  left: 50%;
  display: flex;
  gap: 4px;
  padding: 5px 7px;
  border-radius: var(--sky-radius-pill);
  background: rgba(0, 0, 0, 0.45);
  transform: translateX(-50%);
}
.ps-dots span {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.48);
}
.ps-dots span.active {
  background: white;
  transform: scale(1.25);
}
.ps-post-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 7px 9px 2px;
}
.ps-post-actions > div {
  display: flex;
}
.ps-post-actions button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  place-items: center;
  width: auto;
  min-width: 42px;
  height: 42px;
  padding: 0 7px;
  border: 0;
  background: transparent;
}
.ps-post-actions button.active {
  color: var(--ps-accent);
}
.ps-post-actions svg {
  width: 25px;
  height: 25px;
  stroke-width: 1.8;
}
.ps-post-actions button > span {
  min-width: 0;
  font-size: 11px;
  font-weight: 750;
  line-height: 1;
}
.ps-post-more :deep(svg) {
  width: 21px;
  height: 21px;
}
.ps-post-actions button.reaction-pop svg {
  animation: ps-reaction-pop 0.44s var(--sky-ease-out);
}
.ps-post-actions button.reaction-pop--like {
  color: var(--ps-accent);
}
.ps-post-actions button.reaction-pop--save svg {
  filter: drop-shadow(0 0 7px var(--ps-accent));
}
@keyframes ps-reaction-pop {
  0% {
    transform: scale(0.82);
  }
  45% {
    transform: scale(1.38) rotate(-7deg);
  }
  72% {
    transform: scale(0.94);
  }
  100% {
    transform: scale(1);
  }
}
.ps-post-copy {
  display: grid;
  gap: 6px;
  padding: 0 var(--sky-page-gutter) 14px;
  font-size: 13px;
}
.ps-post-copy p {
  margin: 0;
  line-height: 1.4;
}
.ps-post-copy > button,
.ps-post-copy time {
  justify-self: start;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--sky-muted);
  font-size: 12px;
}
.ps-load-more {
  margin: var(--sky-space-3) var(--sky-page-gutter);
}
.ps-publish-link {
  min-width: 52px;
  justify-content: flex-end;
  color: var(--ps-accent) !important;
  font-size: 13px;
  font-weight: 750;
}
.ps-publish-link:disabled {
  cursor: default;
  opacity: 0.42;
}
.ps-publish-link :deep(.sky-spinner) {
  width: 16px;
  height: 16px;
}

.ps-explore {
  padding-top: 2px;
  padding-inline: 2px;
}
.ps-profile-results {
  margin: var(--sky-space-2) var(--sky-page-gutter) var(--sky-space-3);
  overflow: hidden;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}
.ps-profile-results > button {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  padding: 10px 12px;
  border: 0;
  border-bottom: 1px solid var(--sky-hairline);
  background: transparent;
  text-align: left;
}
.ps-profile-results > button:last-child {
  border-bottom: 0;
}
.ps-profile-results > button > span:nth-child(2),
.ps-connection-profile > span:last-child {
  display: grid;
  flex: 1;
  min-width: 0;
}
.ps-profile-results small,
.ps-connection-profile small {
  color: var(--sky-muted);
}
.ps-profile-results > button > svg {
  width: 17px;
  color: var(--sky-muted);
}
.ps-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 2px;
}
.ps-grid button {
  position: relative;
  overflow: hidden;
  aspect-ratio: 1 / 1;
  padding: 0;
  border: 0;
  background: var(--sky-surface-variant);
}
.ps-grid img,
.ps-grid video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.ps-grid button > span {
  position: absolute;
  top: 6px;
  right: 6px;
  display: flex;
  align-items: center;
  gap: 2px;
  padding: 3px 6px;
  color: white;
  border-radius: var(--sky-radius-pill);
  background: rgba(0, 0, 0, 0.52);
  font-size: 9px;
}
.ps-grid button > span svg,
.ps-grid-video {
  width: 13px;
  height: 13px;
}
.ps-grid-video {
  position: absolute;
  top: 7px;
  right: 7px;
  color: white;
  filter: drop-shadow(0 1px 2px #000);
}

.ps-create {
  display: grid;
  grid-auto-rows: max-content;
  align-content: start;
  gap: var(--sky-space-4);
  padding-inline: var(--sky-page-gutter);
}
.ps-create-card {
  margin: 0;
  padding: 0;
  border: 1px solid var(--sky-hairline);
  border-radius: calc(var(--sky-radius-card) + var(--sky-space-1));
  background: var(--sky-surface);
}
.ps-create-card :deep(.sky-card__content) {
  padding: 12px;
}
.ps-create-intro {
  display: grid;
  place-items: center;
  padding: 8px 4px 12px;
  text-align: center;
}
.ps-create-intro > span {
  display: grid;
  place-items: center;
  width: 50px;
  height: 50px;
  margin-bottom: 8px;
  color: var(--ps-accent);
  border-radius: 17px;
  background: var(--ps-accent-soft);
}
.ps-create-intro svg {
  width: 29px;
}
.ps-create-intro p {
  margin: 5px 0 0;
  color: var(--sky-muted);
  font-size: 12px;
}
.ps-source-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 9px;
}
.ps-source-grid button {
  display: flex;
  align-items: center;
  gap: 9px;
  min-height: 50px;
  padding: 8px 10px;
  border: 1px solid var(--sky-hairline);
  border-radius: calc(var(--sky-radius-control) + 10px);
  background: var(--sky-surface-muted);
  text-align: left;
}
.ps-source-grid button > svg {
  width: 23px;
  color: var(--ps-accent);
}
.ps-source-grid button > span {
  display: grid;
}
.ps-source-grid small {
  color: var(--sky-muted);
  font-size: 10px;
}
.ps-selection-preview {
  position: relative;
  overflow: hidden;
  height: 240px;
  border-radius: calc(var(--sky-radius-control) + 10px);
  background: #050505;
}
.ps-selection-preview img,
.ps-selection-preview video {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.ps-selection-slide {
  position: relative;
  width: 100%;
  height: 100%;
}
.ps-selection-remove {
  position: absolute;
  top: 9px;
  right: 9px;
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border: 0;
  border-radius: 50%;
  background: rgba(0, 0, 0, 0.65);
  color: white;
}
.ps-selection-arrow {
  position: absolute;
  z-index: 2;
  top: 50%;
  display: grid;
  place-items: center;
  width: 44px;
  min-width: 44px;
  height: 44px;
  min-height: 44px;
  padding: 0;
  color: white;
  transform: translateY(-50%);
}
.ps-selection-arrow:disabled {
  opacity: 0.22;
}
.ps-selection-arrow--left {
  left: 9px;
}
.ps-selection-arrow--right {
  right: 9px;
}
.ps-selection-arrow svg {
  width: 19px;
  height: 19px;
}
.ps-selection-counter {
  position: absolute;
  z-index: 2;
  top: 10px;
  left: 50%;
  padding: 5px 8px;
  border-radius: var(--sky-radius-pill);
  background: rgba(0, 0, 0, 0.62);
  color: white;
  font-size: 10px;
  font-weight: 750;
  transform: translateX(-50%);
}
.ps-selection-dots {
  position: absolute;
  z-index: 2;
  bottom: 12px;
  left: 50%;
  display: flex;
  gap: 4px;
  transform: translateX(-50%);
}
.ps-selection-dots span {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.45);
}
.ps-selection-dots span.active {
  background: white;
  transform: scale(1.25);
}
.ps-selection-preview > :deep(.sky-chip) {
  position: absolute;
  bottom: 9px;
  left: 9px;
}
.ps-video-preview-badge {
  position: absolute;
  top: 10px;
  left: 10px;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 6px 9px;
  border-radius: var(--sky-radius-pill);
  background: rgba(0, 0, 0, 0.65);
  color: white;
  font-size: 11px;
  font-weight: 700;
}
.ps-video-preview-badge svg {
  width: 14px;
  height: 14px;
}
.ps-change-selection {
  margin-top: 10px;
}
.ps-change-selection :deep(svg) {
  width: 17px;
  height: 17px;
}
.ps-toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sky-space-4);
  padding: 13px 14px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface);
}
.ps-toggle-row > span {
  display: grid;
}
.ps-toggle-row small {
  margin-top: 2px;
  color: var(--sky-muted);
  font-size: 11px;
}

.ps-activity {
  padding-inline: var(--sky-page-gutter);
}
.ps-activity-row {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  min-height: 68px;
  padding: 10px 0;
  border: 0;
  border-bottom: 1px solid var(--sky-hairline);
  background: transparent;
  text-align: left;
}
.ps-activity-row > span:nth-child(2) {
  display: grid;
  flex: 1;
  min-width: 0;
}
.ps-activity-row small {
  color: var(--sky-muted);
  line-height: 1.35;
}
.ps-request-actions {
  display: flex;
  gap: 5px;
}
.ps-activity-row--request {
  margin: 6px 0;
  padding: 10px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}
.ps-activity > .ps-empty {
  min-height: 360px;
}

.ps-profile {
  padding-inline: var(--sky-page-gutter);
}
.ps-profile-navbar-title {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  max-width: 190px;
}
.ps-profile-navbar-title svg {
  width: 14px;
  height: 14px;
  flex: 0 0 auto;
  color: var(--sky-muted);
}
.ps-profile-header {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: var(--sky-space-4);
  padding: var(--sky-space-3) 0 var(--sky-space-5);
}
.ps-profile-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
}
.ps-profile-stats button {
  display: grid;
  justify-items: center;
  gap: 2px;
  padding: 8px 2px;
  border: 0;
  background: transparent;
}
.ps-profile-stats strong {
  font-size: 17px;
}
.ps-profile-stats small {
  color: var(--sky-muted);
  font-size: 10px;
}
.ps-profile-copy,
.ps-profile-buttons,
.ps-profile-owner-actions {
  grid-column: 1 / -1;
}
.ps-profile-copy > strong {
  display: flex;
  align-items: center;
  gap: 4px;
}
.ps-profile-copy p {
  margin: 4px 0 0;
  font-size: 13px;
  line-height: 1.45;
}
.ps-profile-buttons {
  display: grid;
  grid-template-columns: 1fr;
}
.ps-profile-owner-actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.ps-profile-buttons :deep(.sky-button) {
  min-width: 0;
}
.ps-profile-buttons svg {
  width: 17px;
}
.ps-profile-filters {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  margin: 0 calc(var(--sky-page-gutter) * -1) 2px;
  border-top: 1px solid var(--sky-hairline);
  border-bottom: 1px solid var(--sky-hairline);
}
.ps-profile-filters button {
  position: relative;
  display: grid;
  place-items: center;
  height: 48px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--sky-muted);
}
.ps-profile-filters button::after {
  position: absolute;
  right: 18%;
  bottom: -1px;
  left: 18%;
  height: 2px;
  border-radius: var(--sky-radius-pill);
  background: transparent;
  content: '';
}
.ps-profile-filters button.active {
  color: var(--sky-text);
}
.ps-profile-filters button.active::after {
  background: var(--sky-text);
}
.ps-profile-filters svg {
  width: 21px;
  height: 21px;
  stroke-width: 1.8;
}
.ps-profile > .ps-grid {
  margin-inline: calc(var(--sky-page-gutter) * -1);
}
.ps-private {
  min-height: 300px;
}

.ps-sheet :deep(.sky-sheet__panel) {
  max-height: calc(100% - var(--sky-safe-area-top) - 34px);
  border-radius: var(--sky-radius-sheet) var(--sky-radius-sheet) 0 0;
  background: var(--sky-bg);
}
.ps-sheet-handle {
  width: 38px;
  height: 5px;
  margin: 8px auto 6px;
  border-radius: var(--sky-radius-pill);
  background: var(--sky-hairline);
}
.ps-comments-sheet,
.ps-edit-sheet,
.ps-connections-sheet,
.ps-report-sheet,
.ps-moderation-sheet {
  display: flex;
  flex-direction: column;
  max-height: calc(100vh - var(--sky-safe-area-top) - 48px);
}
.ps-comments-sheet > header,
.ps-edit-sheet > header,
.ps-connections-sheet > header,
.ps-report-sheet > header,
.ps-moderation-sheet > header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 48px;
  padding: 0 var(--sky-page-gutter);
  border-bottom: 1px solid var(--sky-hairline);
}
.ps-comments-sheet > header > button,
.ps-connections-sheet > header > button,
.ps-report-sheet > header > button,
.ps-moderation-sheet > header > button {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: var(--sky-surface-variant);
}
.ps-comments-sheet > header svg,
.ps-connections-sheet > header svg,
.ps-report-sheet > header svg,
.ps-moderation-sheet > header svg {
  width: 18px;
}
.ps-comments-list {
  flex: 1;
  overflow-y: auto;
  min-height: 260px;
  margin: 8px var(--sky-page-gutter) 12px;
  padding: 4px 10px 12px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}
.ps-comments-list > .ps-empty {
  min-height: 250px;
}
.ps-comment-thread {
  padding: 8px 0;
  border-bottom: 1px solid var(--sky-hairline);
}
.ps-comment-thread:last-child {
  border-bottom: 0;
}
.ps-comment-replies-toggle {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 1px 0 3px 44px;
  padding: 4px 0;
  border: 0;
  background: transparent;
  color: var(--sky-muted);
  font-size: 11px;
  font-weight: 700;
}
.ps-comment-replies-toggle > span {
  width: 22px;
  height: 1px;
  background: var(--sky-hairline);
}
.ps-comment-row {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: start;
  gap: 9px;
  padding: 6px 0;
}
.ps-comment-row--reply {
  margin: 5px 0 0 30px;
  padding: 8px 9px;
  border-radius: var(--sky-radius-control);
  background: var(--sky-surface-muted);
}
.ps-comment-copy {
  min-width: 0;
}
.ps-comment-copy > header {
  display: flex;
  align-items: center;
  gap: 6px;
}
.ps-comment-copy > header button {
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 0;
  border: 0;
  background: transparent;
  font-size: 12px;
  font-weight: 750;
}
.ps-comment-copy time {
  color: var(--sky-muted);
  font-size: 10px;
}
.ps-comment-copy p {
  margin: 3px 0 5px;
  font-size: 13px;
  line-height: 1.4;
  overflow-wrap: anywhere;
}
.ps-comment-copy p b {
  color: var(--ps-accent);
}
.ps-comment-copy footer {
  display: flex;
  gap: 12px;
}
.ps-comment-copy footer button {
  display: flex;
  align-items: center;
  gap: 3px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--sky-muted);
  font-size: 10px;
  font-weight: 700;
}
.ps-comment-copy footer svg {
  width: 12px;
  height: 12px;
}
.ps-comment-like {
  display: grid;
  justify-items: center;
  gap: 1px;
  width: 34px;
  padding: 7px 0;
  border: 0;
  background: transparent;
  color: var(--sky-muted);
}
.ps-comment-like svg {
  width: 16px;
  height: 16px;
}
.ps-comment-like small {
  font-size: 9px;
}
.ps-comment-like.active {
  color: var(--ps-accent);
}
.ps-comment-like.pulse svg {
  animation: ps-heart 0.36s var(--sky-ease-out);
}
@keyframes ps-heart {
  45% {
    transform: scale(1.45) rotate(-8deg);
  }
}
.ps-comment-composer {
  margin: 8px var(--sky-page-gutter) calc(var(--sky-safe-area-bottom) + 8px);
  padding: 5px 6px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-pill);
  background: var(--sky-surface);
  box-shadow: var(--sky-shadow-glass);
}
.ps-comment-composer--replying {
  border-radius: calc(var(--sky-radius-card) + var(--sky-space-1));
}
.ps-replying {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 3px 7px 5px 10px;
  color: var(--sky-muted);
  font-size: 11px;
}
.ps-replying button {
  display: grid;
  place-items: center;
  width: 23px;
  height: 23px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: var(--sky-surface-variant);
}
.ps-replying svg {
  width: 13px;
}
.ps-comment-composer :deep(.sky-messagebar) {
  margin: 0;
  padding: 0;
  border: 0;
  background: transparent;
  box-shadow: none;
}
.ps-comment-composer :deep(.sky-messagebar textarea) {
  background: var(--sky-surface-muted);
}
.ps-comment-composer :deep(.sky-messagebar) button {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  padding: 0;
  border: 0;
  border-radius: 50%;
  background: var(--ps-accent);
  color: white;
}
.ps-comment-composer :deep(.sky-messagebar) button:disabled {
  opacity: 0.4;
}
.ps-comment-composer :deep(.sky-messagebar) svg {
  width: 18px;
}

.ps-edit-sheet > header button {
  padding: 7px 0;
  border: 0;
  background: transparent;
  color: var(--ps-accent);
}
.ps-save-link {
  font-weight: 750;
}
.ps-edit-sheet {
  overflow-y: auto;
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-4));
}
.ps-edit-avatar {
  display: grid;
  place-items: center;
  gap: 8px;
  padding: var(--sky-space-4);
}
.ps-edit-avatar > div {
  display: flex;
  gap: 8px;
}
.ps-edit-avatar svg {
  width: 16px;
}
.ps-danger-link {
  padding: 4px;
  border: 0;
  background: transparent;
  color: var(--sky-danger);
  font-size: 12px;
}
.ps-edit-fields {
  padding: 0;
}
.ps-edit-field-list {
  margin-bottom: 0;
}
.ps-privacy-control {
  display: flex;
  align-items: center;
  gap: 11px;
  margin: 0 var(--sky-page-gutter);
  padding: 13px 14px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}
.ps-privacy-control > div {
  display: grid;
  min-width: 0;
  flex: 1;
  gap: 2px;
}
.ps-privacy-control__icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 34px;
  place-items: center;
  border-radius: 50%;
  background: var(--ps-accent-soft);
  color: var(--ps-accent);
}
.ps-privacy-control small {
  color: var(--sky-muted);
  font-size: 11px;
  line-height: 1.35;
}
.ps-privacy-control__icon svg {
  width: 15px;
  height: 15px;
}
.ps-fields :deep(.sky-field) {
  overflow: hidden;
  margin: 0;
  padding: 12px 14px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}
.ps-fields :deep(.sky-field__inner) {
  padding: 0;
}
.ps-fields :deep(.sky-field__label) {
  margin-top: 0;
}
.ps-fields :deep(.sky-field__label-text) {
  top: auto;
  margin: 0;
  padding: 0;
  background: transparent;
}
.ps-fields :deep(.sky-field__control) {
  margin: 0;
  border-radius: calc(var(--sky-radius-control) + 10px);
  background: var(--sky-surface-muted);
}
.ps-fields :deep(.sky-field__border) {
  display: none;
}
.ps-compose-fields :deep(.sky-field) {
  overflow: hidden;
  margin: 0;
  padding-left: 14px;
  border: 1px solid var(--sky-hairline);
  border-radius: var(--sky-radius-card);
  background: var(--sky-surface);
}
.ps-compose-fields :deep(.sky-field__media) {
  margin-right: 10px;
  color: var(--ps-accent);
}
.ps-compose-fields :deep(.sky-field__media svg) {
  width: 19px;
  height: 19px;
}
.ps-compose-fields :deep(.sky-field__inner) {
  padding: 11px 14px 11px 0;
}
.ps-compose-fields :deep(.sky-field__label) {
  color: var(--sky-muted);
  font-size: 11px;
  font-weight: 700;
}
.ps-compose-fields :deep(.sky-field__control) {
  margin: 0;
  background: transparent;
}
.ps-compose-fields :deep(.sky-field__input) {
  height: 36px;
  min-height: 36px;
  font-size: 14px;
}
.ps-compose-fields :deep(.sky-field__textarea) {
  min-height: 88px;
  padding: 6px 0 0;
  resize: none;
}
.ps-compose-fields > .ps-toggle-row,
.ps-edit-fields > .ps-toggle-row {
  border-radius: var(--sky-radius-card);
}

.ps-connections-sheet > header > span {
  display: flex;
  align-items: center;
  gap: 8px;
}
.ps-connections-sheet > div {
  overflow-y: auto;
  min-height: 280px;
  padding: 5px var(--sky-page-gutter) calc(var(--sky-safe-area-bottom) + 12px);
}
.ps-connections-sheet article {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 66px;
  border-bottom: 1px solid var(--sky-hairline);
}
.ps-connection-profile {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
  flex: 1;
  padding: 7px 0;
  border: 0;
  background: transparent;
  text-align: left;
}
.ps-connections-sheet .ps-empty {
  min-height: 260px;
}

.ps-story-sheet :deep(.sky-sheet__panel) {
  inset: 0;
  max-height: none;
  border-radius: 0;
  background: #000;
}
.ps-story-viewer {
  position: relative;
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: #000;
  color: white;
}
.ps-story-viewer > img,
.ps-story-viewer > video {
  width: 100%;
  height: 100%;
  object-fit: contain;
}
.ps-story-progress {
  position: absolute;
  z-index: 4;
  top: calc(var(--sky-safe-area-top) + 7px);
  right: 10px;
  left: 10px;
  display: flex;
  gap: 3px;
}
.ps-story-progress span {
  height: 3px;
  flex: 1;
  border-radius: 2px;
  background: rgba(255, 255, 255, 0.35);
}
.ps-story-progress span.active {
  background: white;
}
.ps-story-header {
  position: absolute;
  z-index: 4;
  top: calc(var(--sky-safe-area-top) + 18px);
  right: 10px;
  left: 10px;
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 8px 10px;
  border-radius: var(--sky-radius-pill);
}
.ps-story-header > span:nth-child(2) {
  display: grid;
  flex: 1;
}
.ps-story-header small {
  color: rgba(255, 255, 255, 0.65);
}
.ps-story-header button {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  padding: 0;
  border: 0;
  background: transparent;
  color: white;
}
.ps-story-viewer > p {
  position: absolute;
  right: var(--sky-page-gutter);
  bottom: 95px;
  left: var(--sky-page-gutter);
  margin: 0;
  padding: 12px 14px;
  border-radius: var(--sky-radius-control);
  background: rgba(0, 0, 0, 0.58);
  text-align: center;
}
.ps-story-nav {
  position: absolute;
  z-index: 3;
  top: 25%;
  bottom: 25%;
  width: 42%;
  border: 0;
  background: transparent;
  color: transparent;
}
.ps-story-nav--left {
  left: 0;
}
.ps-story-nav--right {
  right: 0;
}
.ps-story-actions {
  position: absolute;
  z-index: 4;
  right: 12px;
  bottom: calc(var(--sky-safe-area-bottom) + 12px);
  left: 12px;
  display: flex;
  justify-content: center;
  gap: 8px;
}

.ps-report-sheet,
.ps-moderation-sheet {
  gap: var(--sky-space-3);
  overflow-y: auto;
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-4));
}
.ps-report-sheet > :deep(.sky-list),
.ps-report-sheet > :deep(.sky-field),
.ps-report-sheet > :deep(.sky-button) {
  margin-inline: var(--sky-page-gutter);
}
.ps-selection-check {
  width: 18px;
  color: var(--ps-accent);
}
.ps-moderation-sheet {
  padding-inline: var(--sky-page-gutter);
}
.ps-moderation-sheet > header {
  margin-inline: calc(var(--sky-page-gutter) * -1);
}
.ps-report-card {
  margin: 0;
  padding: 14px;
}
.ps-report-card p {
  color: var(--sky-muted);
  font-size: 12px;
}
.ps-report-card > div {
  display: flex;
  gap: 6px;
}
</style>
