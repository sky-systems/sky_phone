<script setup lang="ts">
import {
  SkyBadge,
  SkyBlock,
  SkyBlockTitle,
  SkyButton,
  SkyCard,
  SkyDialog,
  SkyDialogButton,
  SkyDropdown,
  SkyIcon,
  SkyLink,
  SkyList,
  SkyField,
  SkyListItem,
  SkyMessage,
  SkyMessagebar,
  SkyMessages,
  SkyNavbar,
  SkyNavbarBackLink,
  SkyAppPage,
  SkySettingsGroup,
  SkySettingsRow,
  SkySpinner,
  SkySheet,
  SkyTabBar,
  SkyTabButton,
  SkyToolbarPane,
  SkyNotification,
  SkyToggle,
} from '@/ui'
import {
  ArrowUpCircle,
  Camera,
  Check,
  ChevronRight,
  Ellipsis,
  EyeOff,
  Grid2X2,
  Flame,
  Heart,
  ImagePlay,
  Images,
  LogOut,
  MapPin,
  MessageCircle,
  Pencil,
  Plus,
  RotateCcw,
  Search,
  Settings2,
  Share2,
  Star,
  SlidersHorizontal,
  Trash2,
  UserRound,
  Video,
  X,
} from 'lucide-vue-next'
import type { CSSProperties } from 'vue'
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  reactive,
  ref,
  watch,
} from 'vue'
import { useRoute, useRouter } from 'vue-router'

import FullEmojiPicker from '@/components/FullEmojiPicker.vue'
import MessageAttachmentBubble from '@/components/MessageAttachmentBubble.vue'
import SharedContentCard from '@/components/SharedContentCard.vue'
import { useAccountStore } from '@/stores/account'
import { useAppAuthStore } from '@/stores/app-auth'
import { useEasyShareStore } from '@/stores/easyshare'
import { useFlareStore } from '@/stores/flare'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { useMessagesStore } from '@/stores/messages'
import { usePhoneStore } from '@/stores/phone'
import type {
  FlareGender,
  FlareInterest,
  FlareMatch,
  FlareMessage,
  FlareProfile,
  FlareProfileDraft,
} from '@/types/flare'
import type { PhoneMedia } from '@/types/media'
import type { EasySharePayload } from '@/types/easyshare'
import type { GifSearchResult, SmsAttachmentType } from '@/types/messages'
import { parseDatabaseDate, type DatabaseDateValue } from '@/utils/date'
import { handleEnterAction } from '@/utils/keyboard'

type FlareTab = 'discover' | 'explore' | 'likes' | 'matches' | 'profile'
type ExploreMode = 'all' | 'dates' | 'friends' | 'longTerm'
type FlareChoiceField = 'gender' | 'interestedIn' | 'lookingFor'
type FlareChoiceOption = {
  label: string
  value: string
}
type FlareDraftPhoto = Pick<PhoneMedia, 'id' | 'url'>
type FlareMediaContext = {
  draft: FlareProfileDraft
  editing: boolean
  photos: FlareDraftPhoto[]
}
type FlareChatMediaContext = { matchId: string }

const phone = usePhoneStore()
const account = useAccountStore()
const appAuth = useAppAuthStore()
const easyShare = useEasyShareStore()
const flare = useFlareStore()
const messageMedia = useMessageMediaStore()
const messages = useMessagesStore()
const route = useRoute()
const router = useRouter()
const activeTab = ref<FlareTab>('discover')
const activeMatch = ref<FlareMatch | null>(null)
const draft = ref('')
const shareDraft = ref<EasySharePayload | null>(null)
const matchReveal = ref<FlareMatch | null>(null)
const cardOffset = ref(0)
const currentPhotoIndex = ref(0)
const dragging = ref(false)
const pointerStart = ref(0)
const outgoing = ref<'like' | 'pass' | 'superlike' | null>(null)
const swipingProfile = ref<FlareProfile | null>(null)
const messageScroll = ref<HTMLElement | null>(null)
const profileEditing = ref(false)
const profileSettings = ref(false)
const profileSaving = ref(false)
const photoSourceOpened = ref(false)
const photoSourceTarget = ref<HTMLElement | null>(null)
const discoverySaving = ref(false)
const signOutDialogOpened = ref(false)
const deleteAccountDialogOpened = ref(false)
const accountActionPending = ref(false)
const unmatchDialog = ref(false)
const activeExploreMode = ref<ExploreMode>('all')
const actionToast = ref('')
const emojiOpen = ref(false)
const attachmentMenuOpen = ref(false)
const attachmentPicker = ref<'gifs' | null>(null)
const gifQuery = ref('')
const gifResults = ref<GifSearchResult[]>([])
const gifLoading = ref(false)
const gifError = ref<string | null>(null)
const gifHasMore = ref(true)
const photoSourceItems = computed(() => [
  { id: 'photos', label: phone.t('Apps.flare.choosePhotos') },
  { id: 'camera', label: phone.t('Apps.flare.takePhoto') },
])

function shareProfile(): void {
  const profile = flare.profile
  if (!profile) return
  easyShare.open({
    appId: 'flare',
    copyText: `${profile.name}, ${profile.age}\n${profile.bio}`,
    id: profile.id,
    imageUrl: profile.photoUrls[0],
    kind: 'profile',
    link: `skyphone://flare/profile/${profile.id}`,
    subtitle: phone.t(`Apps.flare.lookingFor.${profile.lookingFor}`),
    title: `${profile.name}, ${profile.age}`,
  })
}
const gifNextOffset = ref(0)
const draftPhotos = ref<FlareDraftPhoto[]>([])
const ownPhotoIndex = ref(0)
const activeChoiceField = ref<FlareChoiceField>('gender')
const choiceOpened = ref(false)
const choiceSheetContent = ref<HTMLElement | null>(null)
let activeChoiceTrigger: HTMLElement | null = null
let gifSearchTimer: ReturnType<typeof setTimeout> | undefined

function createDefaultProfileDraft(): FlareProfileDraft {
  return {
    age: 25,
    avatar: 0,
    bio: '',
    gender: 'woman',
    interestedIn: 'everyone',
    interests: [],
    lookingFor: 'longTerm',
    maxAge: 45,
    minAge: 21,
    name: '',
    photoMediaIds: [],
  }
}

const profileDraft = reactive<FlareProfileDraft>(createDefaultProfileDraft())
const bioInputStyle: CSSProperties = {
  height: '116px',
  lineHeight: '1.4',
  minHeight: '116px',
  resize: 'none',
}

const activeChoiceOptions = computed<FlareChoiceOption[]>(() =>
  choiceOptions(activeChoiceField.value),
)
const activeChoiceTitle = computed(() =>
  choiceFieldLabel(activeChoiceField.value),
)
const activeChoiceValue = computed(() => profileDraft[activeChoiceField.value])
const hasRequiredProfilePhoto = computed(() => draftPhotos.value.length >= 1)

const filteredSuggestions = computed(() =>
  activeExploreMode.value === 'all'
    ? flare.suggestions
    : flare.suggestions.filter(
        (profile) => profile.lookingFor === activeExploreMode.value,
      ),
)
const currentProfile = computed(
  () => swipingProfile.value ?? filteredSuggestions.value[0] ?? null,
)
const nextProfile = computed(() => {
  const swipingId = swipingProfile.value?.id
  if (swipingId) {
    return (
      filteredSuggestions.value.find((profile) => profile.id !== swipingId) ??
      null
    )
  }
  return filteredSuggestions.value[1] ?? null
})
const currentPhotoCount = computed(() =>
  Math.max(1, currentProfile.value?.photoUrls.length ?? 0),
)
const normalizedPhotoIndex = computed(
  () => currentPhotoIndex.value % currentPhotoCount.value,
)
const normalizedOwnPhotoIndex = computed(
  () => ownPhotoIndex.value % Math.max(1, draftPhotos.value.length),
)
const newMatches = computed(() =>
  flare.matches.filter((match) => !match.lastMessage && !match.lastMessageType),
)
const unreadMatches = computed(() =>
  flare.matches.reduce((total, match) => total + match.unread, 0),
)
const attachmentPanelOpen = computed(
  () => emojiOpen.value || attachmentPicker.value !== null,
)
const cardStyle = computed(() => ({
  transform: `translateX(${cardOffset.value}px) rotate(${cardOffset.value / 22}deg)`,
  transition: dragging.value ? 'none' : undefined,
}))
const exploreTileDefinitions = [
  { key: 'forYou', mode: 'all', tone: 'coral' },
  { key: 'longTerm', mode: 'longTerm', tone: 'violet' },
  { key: 'newFriends', mode: 'friends', tone: 'blue' },
  { key: 'dateNight', mode: 'dates', tone: 'amber' },
] as const
const exploreTiles = computed(() => {
  const profiles = flare.suggestions.filter(
    (profile) => profile.photoUrls.length > 0,
  )
  return exploreTileDefinitions.map((tile) => {
    const profile =
      tile.mode === 'all'
        ? profiles[0]
        : (profiles.find((candidate) => candidate.lookingFor === tile.mode) ??
          profiles[0])
    return {
      ...tile,
      coverUrl: profile?.photoUrls[0] ?? '',
    }
  })
})

function avatarStyle(avatar: number): Record<string, string> {
  const safeAvatar = Math.max(0, Math.min(5, Math.floor(avatar)))
  return {
    backgroundImage: `linear-gradient(${135 + safeAvatar * 12}deg, var(--flare), var(--flare-warm) 52%, var(--flare-ink))`,
    backgroundPosition: 'center',
    backgroundSize: 'cover',
  }
}

function photoStyle(url: string): Record<string, string> {
  return {
    backgroundImage: `url(${JSON.stringify(url)})`,
    backgroundPosition: 'center',
    backgroundSize: 'cover',
  }
}

function profilePhotoStyle(
  profile: Pick<FlareProfile, 'avatar' | 'photoUrls'>,
  photoIndex = 0,
): Record<string, string> {
  const selectedPhoto = profile.photoUrls.length
    ? profile.photoUrls[photoIndex % profile.photoUrls.length]
    : undefined
  return selectedPhoto ? photoStyle(selectedPhoto) : avatarStyle(profile.avatar)
}

function ownPhotoStyle(
  photoIndex = normalizedOwnPhotoIndex.value,
): Record<string, string> {
  const selectedPhoto = draftPhotos.value[photoIndex]
  return selectedPhoto
    ? photoStyle(selectedPhoto.url)
    : avatarStyle(profileDraft.avatar)
}

function ownPhotoLabel(photoIndex = normalizedOwnPhotoIndex.value): string {
  if (!draftPhotos.value.length) {
    return phone.t('Apps.flare.profilePhotoFallback')
  }
  return phone.t('Apps.flare.profilePhotoNumber', {
    count: String(draftPhotos.value.length),
    number: String(photoIndex + 1),
  })
}

function selectOwnPhoto(photoIndex: number): void {
  ownPhotoIndex.value = photoIndex
}

function syncDraft(): void {
  if (!flare.profile) return
  Object.assign(profileDraft, {
    age: flare.profile.age,
    avatar: flare.profile.avatar,
    bio: flare.profile.bio,
    gender: flare.profile.gender,
    interestedIn: flare.profile.interestedIn,
    interests: [...flare.profile.interests],
    lookingFor: flare.profile.lookingFor,
    maxAge: flare.profile.maxAge,
    minAge: flare.profile.minAge,
    name: flare.profile.name,
    photoMediaIds: [...flare.profile.photoMediaIds],
  })
  draftPhotos.value = flare.profile.photoMediaIds.flatMap((id, index) => {
    const url = flare.profile?.photoUrls[index]
    return url ? [{ id, url }] : []
  })
  if (ownPhotoIndex.value >= draftPhotos.value.length) {
    ownPhotoIndex.value = 0
  }
}

function cloneDraft(): FlareProfileDraft {
  return {
    ...profileDraft,
    interests: [...profileDraft.interests],
    photoMediaIds: [...profileDraft.photoMediaIds],
  }
}

function resetProfileDraft(): void {
  Object.assign(profileDraft, createDefaultProfileDraft())
  draftPhotos.value = []
  ownPhotoIndex.value = 0
}

function openPhotoSourcePicker(event: MouseEvent): void {
  if (draftPhotos.value.length >= 6) return
  if (!(event.currentTarget instanceof HTMLElement)) return
  photoSourceTarget.value = event.currentTarget
  photoSourceOpened.value = true
}

function closePhotoSourcePicker(): void {
  photoSourceOpened.value = false
}

function selectPhotoSource(id: string): void {
  if (id !== 'photos' && id !== 'camera') return
  openProfileMediaApp(id)
}

function openProfileMediaApp(app: 'camera' | 'photos'): void {
  const remaining = 6 - draftPhotos.value.length
  if (remaining < 1) return
  closePhotoSourcePicker()
  messageMedia.begin(
    'flare:profile-photos',
    'photo',
    flare.profile ? '/apps/flare?profileEdit=1' : '/apps/flare',
    app === 'photos' ? remaining : 1,
    {
      draft: cloneDraft(),
      editing: Boolean(flare.profile),
      photos: draftPhotos.value.map((photo) => ({ ...photo })),
    } satisfies FlareMediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

function removeDraftPhoto(id: number): void {
  if (draftPhotos.value.length <= 1) return
  draftPhotos.value = draftPhotos.value.filter((photo) => photo.id !== id)
  profileDraft.photoMediaIds = draftPhotos.value.map((photo) => photo.id)
}

function eventValue(event: Event): string {
  return (event.target as HTMLInputElement).value
}

function choiceFieldLabel(field: FlareChoiceField): string {
  if (field === 'gender') return phone.t('Apps.flare.gender')
  if (field === 'interestedIn') return phone.t('Apps.flare.showMe')
  return phone.t('Apps.flare.relationshipGoal')
}

function choiceOptions(field: FlareChoiceField): FlareChoiceOption[] {
  if (field === 'gender') {
    return [
      { label: phone.t('Apps.flare.woman'), value: 'woman' },
      { label: phone.t('Apps.flare.man'), value: 'man' },
      { label: phone.t('Apps.flare.nonbinary'), value: 'nonbinary' },
    ]
  }
  if (field === 'interestedIn') {
    return [
      { label: phone.t('Apps.flare.everyone'), value: 'everyone' },
      { label: phone.t('Apps.flare.women'), value: 'woman' },
      { label: phone.t('Apps.flare.men'), value: 'man' },
      {
        label: phone.t('Apps.flare.nonbinaryPeople'),
        value: 'nonbinary',
      },
    ]
  }
  return [
    {
      label: phone.t('Apps.flare.lookingFor.longTerm'),
      value: 'longTerm',
    },
    { label: phone.t('Apps.flare.lookingFor.dates'), value: 'dates' },
    { label: phone.t('Apps.flare.lookingFor.friends'), value: 'friends' },
  ]
}

function choiceLabel(field: FlareChoiceField): string {
  const value = profileDraft[field]
  return (
    choiceOptions(field).find((option) => option.value === value)?.label ?? ''
  )
}

function choiceLinkProps(field: FlareChoiceField): Record<string, unknown> {
  return {
    'aria-controls': 'flare-choice-sheet',
    'aria-expanded': choiceOpened.value && activeChoiceField.value === field,
    'aria-haspopup': 'dialog',
    class: 'flare-choice-trigger',
    onClick: (event: MouseEvent) =>
      openChoice(field, event.currentTarget as HTMLElement),
    type: 'button',
  }
}

async function openChoice(
  field: FlareChoiceField,
  trigger: HTMLElement | null,
): Promise<void> {
  activeChoiceTrigger = trigger
  activeChoiceField.value = field
  await nextTick()
  await new Promise<void>((resolve) => {
    globalThis.requestAnimationFrame(() => resolve())
  })
  choiceOpened.value = true
  await nextTick()
  choiceSheetContent.value
    ?.querySelector<HTMLElement>('[aria-selected="true"]')
    ?.focus({ preventScroll: true })
}

async function openProfileGoalEditor(): Promise<void> {
  profileEditing.value = true
  await openChoice('lookingFor', null)
}

function closeChoice(): void {
  const trigger = activeChoiceTrigger
  choiceOpened.value = false
  activeChoiceTrigger = null
  void nextTick(() => trigger?.focus({ preventScroll: true }))
}

function selectChoice(value: string): void {
  if (activeChoiceField.value === 'gender') {
    profileDraft.gender = value as FlareGender
  } else if (activeChoiceField.value === 'interestedIn') {
    profileDraft.interestedIn = value as FlareInterest
  } else if (activeChoiceField.value === 'lookingFor') {
    profileDraft.lookingFor = value
  }
  closeChoice()
}

function updateNumber(key: 'age' | 'minAge' | 'maxAge', event: Event): void {
  profileDraft[key] = Number(eventValue(event))
}

function updateInterests(event: Event): void {
  profileDraft.interests = eventValue(event)
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean)
    .slice(0, 5)
}

function beginDrag(event: PointerEvent): void {
  if (outgoing.value) return
  dragging.value = true
  pointerStart.value = event.clientX - cardOffset.value
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function moveDrag(event: PointerEvent): void {
  if (!dragging.value) return
  cardOffset.value = event.clientX - pointerStart.value
}

function endDrag(event: PointerEvent): void {
  if (!dragging.value) return
  dragging.value = false
  if (Math.abs(cardOffset.value) >= 76) {
    void swipe(cardOffset.value > 0 ? 'like' : 'pass')
  } else {
    const tapped = Math.abs(cardOffset.value) < 5
    cardOffset.value = 0
    const photoCount = currentProfile.value?.photoUrls.length ?? 0
    if (tapped && photoCount > 1) {
      const bounds = (
        event.currentTarget as HTMLElement
      ).getBoundingClientRect()
      const direction = event.clientX < bounds.left + bounds.width / 2 ? -1 : 1
      currentPhotoIndex.value =
        (normalizedPhotoIndex.value + direction + photoCount) % photoCount
    }
  }
}

function cancelDrag(): void {
  dragging.value = false
  cardOffset.value = 0
}

async function swipe(choice: 'like' | 'pass' | 'superlike'): Promise<void> {
  const profile = currentProfile.value
  if (!profile || outgoing.value) return
  outgoing.value = choice
  swipingProfile.value = profile
  cardOffset.value = choice === 'pass' ? -430 : 430
  const match = await flare.swipe(profile.id, choice)
  const errorKey = flare.error
  globalThis.setTimeout(() => {
    cardOffset.value = 0
    currentPhotoIndex.value = 0
    swipingProfile.value = null
    outgoing.value = null
    if (match) matchReveal.value = match
    if (errorKey) {
      showActionError(errorKey)
      if (errorKey === 'invalid_target' || errorKey === 'discovery_disabled') {
        void refreshFlareState()
      }
    }
  }, 260)
}

async function reactToLike(
  targetId: number,
  choice: 'like' | 'pass' | 'superlike',
): Promise<void> {
  const match = await flare.swipe(targetId, choice)
  if (match) matchReveal.value = match
  else if (flare.error) {
    const errorKey = flare.error
    showActionError(errorKey)
    if (errorKey === 'invalid_target' || errorKey === 'discovery_disabled') {
      await refreshFlareState()
    }
  }
}

async function rewind(): Promise<void> {
  if (await flare.rewind()) activeExploreMode.value = 'all'
  else showActionError()
}

function showActionError(errorKey = flare.error || 'default'): void {
  actionToast.value = phone.t(`Apps.flare.errors.${errorKey}`)
  globalThis.setTimeout(() => {
    actionToast.value = ''
  }, 2400)
}

async function refreshFlareState(): Promise<void> {
  await flare.bootstrap()
  syncDraft()
}

async function saveProfile(): Promise<void> {
  if (profileSaving.value || !hasRequiredProfilePhoto.value) return
  profileSaving.value = true
  const creatingProfile = !flare.profile
  try {
    if (await flare.saveProfile({ ...profileDraft })) {
      syncDraft()
      profileEditing.value = false
      profileSettings.value = false
      activeTab.value = creatingProfile ? 'discover' : 'profile'
    }
  } finally {
    profileSaving.value = false
  }
}

function selectTab(tab: FlareTab): void {
  activeTab.value = tab
  if (tab !== 'profile') profileEditing.value = false
  if (tab !== 'profile') profileSettings.value = false
}

function openSettings(): void {
  activeTab.value = 'profile'
  profileEditing.value = false
  profileSettings.value = true
}

function closeProfileScreen(): void {
  syncDraft()
  profileEditing.value = false
  profileSettings.value = false
}

function openExplore(mode: ExploreMode): void {
  activeExploreMode.value = mode
  currentPhotoIndex.value = 0
  selectTab('discover')
}

function clearExplore(): void {
  activeExploreMode.value = 'all'
  currentPhotoIndex.value = 0
}

async function setDiscovery(enabled: boolean): Promise<void> {
  if (discoverySaving.value) return
  discoverySaving.value = true
  if (!(await flare.setDiscovery(enabled))) showActionError()
  discoverySaving.value = false
}

function closeSignOutDialog(): void {
  if (!accountActionPending.value) signOutDialogOpened.value = false
}

function closeDeleteAccountDialog(): void {
  if (!accountActionPending.value) deleteAccountDialogOpened.value = false
}

async function signOut(): Promise<void> {
  if (accountActionPending.value) return
  accountActionPending.value = true
  const success = await account.logout()
  accountActionPending.value = false
  if (!success) {
    showActionError('request_failed')
    return
  }
  appAuth.clear()
  signOutDialogOpened.value = false
  profileSettings.value = false
  profileEditing.value = false
  resetProfileDraft()
  flare.reset('not_authenticated')
}

async function deleteFlareAccount(): Promise<void> {
  if (accountActionPending.value) return
  accountActionPending.value = true
  const success = await flare.deleteProfile()
  accountActionPending.value = false
  if (!success) {
    showActionError()
    return
  }
  deleteAccountDialogOpened.value = false
  profileSettings.value = false
  profileEditing.value = false
  resetProfileDraft()
}

async function confirmUnmatch(): Promise<void> {
  const matchId = activeMatch.value?.id
  if (!matchId) return
  if (await flare.unmatch(matchId)) {
    unmatchDialog.value = false
    activeMatch.value = null
  } else showActionError()
}

async function openMatch(match: FlareMatch): Promise<void> {
  activeMatch.value = match
  if (!(await flare.loadThread(match.id))) {
    activeMatch.value = null
    showActionError()
    await refreshFlareState()
    return
  }
  await nextTick()
  messageScroll.value?.scrollTo({ top: messageScroll.value.scrollHeight })
}

async function openEasyShareDraft(): Promise<boolean> {
  const shared = easyShare.consumeChatDraft('flare')
  if (!shared?.targetId) return false
  const match = flare.matches.find((item) => item.id === shared.targetId)
  if (!match) {
    showActionError()
    return true
  }
  await openMatch(match)
  if (activeMatch.value?.id === match.id) {
    draft.value = ''
    shareDraft.value = shared.payload
  }
  return true
}

function closeMatch(): void {
  activeMatch.value = null
  draft.value = ''
  shareDraft.value = null
  emojiOpen.value = false
  attachmentMenuOpen.value = false
  attachmentPicker.value = null
}

async function openRevealedMatch(): Promise<void> {
  const match = matchReveal.value
  if (!match) return
  matchReveal.value = null
  await openMatch(match)
}

async function sendMessage(): Promise<void> {
  const body = draft.value.trim()
  if ((!body && !shareDraft.value) || !activeMatch.value || flare.sending)
    return
  const shared = shareDraft.value
  draft.value = ''
  shareDraft.value = null
  emojiOpen.value = false
  attachmentMenuOpen.value = false
  attachmentPicker.value = null
  if (
    !(await flare.send(
      activeMatch.value.id,
      shared
        ? { body, messageType: 'share', sharePayload: shared }
        : { body, messageType: 'text' },
    ))
  ) {
    draft.value = body
    shareDraft.value = shared
    showActionError()
  }
  await nextTick()
  messageScroll.value?.scrollTo({
    behavior: 'smooth',
    top: messageScroll.value.scrollHeight,
  })
}

function appendEmoji(emoji: string): void {
  draft.value += emoji
}

function toggleAttachmentMenu(): void {
  attachmentMenuOpen.value = !attachmentMenuOpen.value
  emojiOpen.value = false
  attachmentPicker.value = null
}

function openEmojiPicker(): void {
  attachmentMenuOpen.value = false
  attachmentPicker.value = null
  emojiOpen.value = true
}

function openGifPicker(): void {
  attachmentMenuOpen.value = false
  emojiOpen.value = false
  attachmentPicker.value = 'gifs'
  if (!gifResults.value.length) void loadGifs(true)
}

function openChatMediaApp(
  app: 'camera' | 'photos',
  mediaType: 'photo' | 'video',
): void {
  if (!activeMatch.value) return
  const matchId = activeMatch.value.id
  attachmentMenuOpen.value = false
  messageMedia.begin(
    'flare:chat-media',
    mediaType,
    `/apps/flare?match=${encodeURIComponent(matchId)}`,
    1,
    { matchId } satisfies FlareChatMediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { messageAttachment: mediaType },
  })
}

async function sendAttachment(
  messageType: SmsAttachmentType,
  mediaAssetId: string,
  mediaDurationMs?: number,
): Promise<void> {
  if (!activeMatch.value || flare.sending) return
  attachmentMenuOpen.value = false
  attachmentPicker.value = null
  if (
    !(await flare.send(activeMatch.value.id, {
      mediaAssetId,
      mediaDurationMs,
      messageType,
    }))
  ) {
    showActionError()
  }
  await nextTick()
  messageScroll.value?.scrollTo({
    behavior: 'smooth',
    top: messageScroll.value.scrollHeight,
  })
}

async function loadGifs(reset = false): Promise<void> {
  if (gifLoading.value || (!reset && !gifHasMore.value)) return
  gifError.value = null
  gifLoading.value = true
  const response = await messages.searchGifs(
    gifQuery.value,
    reset ? 0 : gifNextOffset.value,
  )
  gifLoading.value = false
  if (!response.success || !response.data) {
    if (reset) gifResults.value = []
    gifError.value = response.error ?? 'gif_provider_failed'
    return
  }
  const existingIds = new Set(
    reset ? [] : gifResults.value.map((result) => result.id),
  )
  const uniqueResults = response.data.results.filter((result) => {
    if (existingIds.has(result.id)) return false
    existingIds.add(result.id)
    return true
  })
  gifResults.value = reset
    ? uniqueResults
    : [...gifResults.value, ...uniqueResults]
  gifHasMore.value = response.data.hasMore
  gifNextOffset.value = response.data.nextOffset
}

function queueGifSearch(): void {
  if (gifSearchTimer) clearTimeout(gifSearchTimer)
  gifSearchTimer = setTimeout(() => void loadGifs(true), 320)
}

function attachmentMessage(message: FlareMessage): {
  media_asset_id: string | null
  media_duration_ms: number | null
  message_type: SmsAttachmentType
} {
  return {
    media_asset_id: message.mediaUrl,
    media_duration_ms: message.mediaDurationMs,
    message_type: message.messageType as SmsAttachmentType,
  }
}

function matchPreview(match: FlareMatch): string {
  if (match.lastMessageType === 'image') {
    return phone.t('Apps.flare.messagePhoto')
  }
  if (match.lastMessageType === 'gif') return phone.t('Apps.flare.gif')
  if (match.lastMessageType === 'video') return phone.t('Apps.flare.video')
  return match.lastMessage || phone.t('Apps.flare.newMatch')
}

function messageTime(value: DatabaseDateValue): string {
  const parsed = parseDatabaseDate(value)
  if (Number.isNaN(parsed.getTime())) return ''
  return new Intl.DateTimeFormat(phone.lang, {
    hour: '2-digit',
    minute: '2-digit',
  }).format(parsed)
}

onMounted(async () => {
  await flare.bootstrap()
  await openEasyShareDraft()
  const selection = messageMedia.consumeMany<FlareMediaContext>(
    'flare:profile-photos',
  )
  if (selection?.context) {
    Object.assign(profileDraft, {
      ...selection.context.draft,
      interests: [...selection.context.draft.interests],
      photoMediaIds: [...selection.context.draft.photoMediaIds],
    })
    draftPhotos.value = selection.context.photos.map((photo) => ({ ...photo }))
    const existingIds = new Set(profileDraft.photoMediaIds)
    for (const media of selection.media) {
      if (existingIds.has(media.id) || draftPhotos.value.length >= 6) continue
      existingIds.add(media.id)
      draftPhotos.value.push({ id: media.id, url: media.url })
    }
    profileDraft.photoMediaIds = draftPhotos.value.map((photo) => photo.id)
    activeTab.value = 'profile'
    profileEditing.value = selection.context.editing
  } else {
    syncDraft()
    if (flare.profile && draftPhotos.value.length === 0) {
      activeTab.value = 'profile'
      profileEditing.value = true
    }
    if (route.query.profileEdit === '1' && flare.profile) {
      activeTab.value = 'profile'
      profileEditing.value = true
    }
  }
  if (route.query.profileEdit === '1') {
    void router.replace('/apps/flare')
  }

  const chatSelection =
    messageMedia.consumeMany<FlareChatMediaContext>('flare:chat-media')
  const requestedMatchId =
    chatSelection?.context?.matchId ??
    (typeof route.query.match === 'string' ? route.query.match : '')
  if (requestedMatchId) {
    const match = flare.matches.find((item) => item.id === requestedMatchId)
    if (match) {
      await openMatch(match)
      const media = chatSelection?.media[0]
      if (media) {
        await sendAttachment(
          media.mediaType === 'photo' ? 'image' : 'video',
          import.meta.env.DEV ? media.url : String(media.id),
        )
      }
    }
    if (route.query.match) void router.replace('/apps/flare')
  }
})

watch(
  () => easyShare.chatDraft,
  (shared) => {
    if (shared?.appId === 'flare') void openEasyShareDraft()
  },
)

onBeforeUnmount(() => {
  if (gifSearchTimer) clearTimeout(gifSearchTimer)
})
</script>

<template>
  <sky-app-page
    component="main"
    class="native-app flare-page"
    :class="{
      'flare-page--chat': Boolean(activeMatch),
      'flare-page--attachment-panel': attachmentPanelOpen,
      'flare-page--without-tabs':
        !flare.profile || profileEditing || profileSettings,
    }"
  >
    <div v-if="flare.loading" class="flare-loading">
      <span class="flare-mark"><Flame fill="currentColor" /></span>
      <sky-spinner />
    </div>

    <section
      v-else-if="flare.error === 'not_authenticated'"
      class="flare-state"
    >
      <span class="flare-mark"><Flame fill="currentColor" /></span>
      <h1>{{ phone.t('Apps.flare.signInTitle') }}</h1>
      <p>{{ phone.t('Apps.flare.signInBody') }}</p>
    </section>

    <template v-else-if="!flare.profile">
      <sky-navbar
        :title="phone.t('Apps.flare.createProfile')"
        class="flare-navbar top-0 sticky"
      />
      <section class="flare-profile-form flare-profile-form--onboarding">
        <div class="flare-brand-lockup">
          <span class="flare-mark"><Flame fill="currentColor" /></span>
          <div>
            <h1>{{ phone.t('Apps.flare.welcome') }}</h1>
            <p>{{ phone.t('Apps.flare.welcomeBody') }}</p>
          </div>
        </div>
        <sky-card :content-wrap="false" class="flare-photo-editor">
          <header>
            <div>
              <strong>{{ phone.t('Apps.flare.profilePhotos') }}</strong>
              <small>{{ phone.t('Apps.flare.profilePhotosBody') }}</small>
            </div>
            <span>{{ draftPhotos.length }}/6</span>
          </header>
          <div class="flare-photo-grid">
            <div
              v-for="(photo, index) in draftPhotos"
              :key="photo.id"
              class="flare-photo-slot"
            >
              <i :style="photoStyle(photo.url)" />
              <span v-if="index === 0" class="flare-photo-primary">
                {{ phone.t('Apps.flare.primaryPhoto') }}
              </span>
              <sky-link
                v-if="draftPhotos.length > 1"
                component="button"
                icon-only
                class="flare-photo-remove"
                :aria-label="
                  phone.t('Apps.flare.removePhoto', {
                    number: String(index + 1),
                  })
                "
                @click="removeDraftPhoto(photo.id)"
              >
                <X />
              </sky-link>
            </div>
          </div>
          <div
            v-if="draftPhotos.length < 6"
            class="flare-onboarding-photo-actions"
          >
            <sky-button outline rounded @click="openProfileMediaApp('photos')">
              <Images :size="19" />
              <span>{{ phone.t('Apps.flare.choosePhotos') }}</span>
            </sky-button>
            <sky-button outline rounded @click="openProfileMediaApp('camera')">
              <Camera :size="19" />
              <span>{{ phone.t('Apps.flare.takePhoto') }}</span>
            </sky-button>
          </div>
          <p
            v-if="!hasRequiredProfilePhoto"
            class="flare-photo-required"
            role="status"
          >
            {{ phone.t('Apps.flare.profilePhotoRequired') }}
          </p>
        </sky-card>
        <sky-list inset strong>
          <sky-field
            :label="phone.t('Apps.flare.yourName')"
            :value="profileDraft.name"
            :placeholder="phone.t('Apps.flare.namePlaceholder')"
            @input="profileDraft.name = eventValue($event)"
          />
          <sky-field
            :label="phone.t('Apps.flare.age')"
            type="number"
            min="18"
            max="99"
            :value="profileDraft.age"
            @input="updateNumber('age', $event)"
          />
          <sky-field
            :label="phone.t('Apps.flare.bio')"
            type="textarea"
            :value="profileDraft.bio"
            :placeholder="phone.t('Apps.flare.bioPlaceholder')"
            :input-style="bioInputStyle"
            :maxlength="300"
            @input="profileDraft.bio = eventValue($event)"
          />
          <sky-list-item
            class="flare-choice-row"
            :header="phone.t('Apps.flare.gender')"
            :title="choiceLabel('gender')"
            link
            link-component="button"
            :link-props="choiceLinkProps('gender')"
          />
          <sky-list-item
            class="flare-choice-row"
            :header="phone.t('Apps.flare.showMe')"
            :title="choiceLabel('interestedIn')"
            link
            link-component="button"
            :link-props="choiceLinkProps('interestedIn')"
          />
          <sky-list-item
            class="flare-choice-row"
            :header="phone.t('Apps.flare.relationshipGoal')"
            :title="choiceLabel('lookingFor')"
            link
            link-component="button"
            :link-props="choiceLinkProps('lookingFor')"
          />
          <sky-field
            :label="phone.t('Apps.flare.interests')"
            :value="profileDraft.interests.join(', ')"
            :placeholder="phone.t('Apps.flare.interestsPlaceholder')"
            @input="updateInterests"
          />
        </sky-list>
        <p class="flare-form-hint">
          {{ phone.t('Apps.flare.interestsHint') }}
        </p>
        <p v-if="flare.error" class="flare-error">
          {{ phone.t(`Apps.flare.errors.${flare.error}`) }}
        </p>
        <sky-block class="flare-profile-form__actions">
          <sky-button
            large
            rounded
            :disabled="profileSaving || !hasRequiredProfilePhoto"
            :aria-busy="profileSaving"
            @click="saveProfile"
          >
            {{ phone.t('Apps.flare.start') }}
          </sky-button>
        </sky-block>
      </section>
    </template>

    <template v-else-if="activeMatch">
      <sky-navbar class="flare-navbar top-0 sticky">
        <template #left>
          <sky-navbar-back-link
            :text="phone.t('Common.back')"
            @click="closeMatch"
          />
        </template>
        <template #title>
          <span class="flare-chat-title">
            <i :style="profilePhotoStyle(activeMatch.profile)" />
            {{ activeMatch.profile.name }}
          </span>
        </template>
        <template #right>
          <sky-link
            component="button"
            icon-only
            :aria-label="phone.t('Apps.flare.matchActions')"
            @click="unmatchDialog = true"
          >
            <Ellipsis />
          </sky-link>
        </template>
      </sky-navbar>
      <div ref="messageScroll" class="flare-chat-scroll">
        <sky-messages>
          <sky-message
            v-for="message in flare.messages"
            :key="message.id"
            :type="message.direction"
            :text="message.messageType === 'text' ? message.body : undefined"
            :text-footer="messageTime(message.createdAt)"
          >
            <template v-if="message.messageType !== 'text'" #text>
              <SharedContentCard
                v-if="message.messageType === 'share' && message.sharePayload"
                :payload="message.sharePayload"
                variant="flare"
              />
              <MessageAttachmentBubble
                v-else
                :message="attachmentMessage(message)"
              />
            </template>
          </sky-message>
        </sky-messages>
      </div>

      <section v-if="attachmentMenuOpen" class="messages-attachment-menu">
        <button type="button" @click="openChatMediaApp('photos', 'photo')">
          <span><Images :size="20" /></span>
          {{ phone.t('Apps.flare.attachPhoto') }}
        </button>
        <button type="button" @click="openChatMediaApp('camera', 'photo')">
          <span><Camera :size="20" /></span>
          {{ phone.t('Apps.flare.takePhoto') }}
        </button>
        <button type="button" @click="openEmojiPicker">
          <span class="messages-action-emoji">😀</span>
          {{ phone.t('Apps.flare.emoji') }}
        </button>
        <button type="button" @click="openGifPicker">
          <span><ImagePlay :size="20" /></span>
          {{ phone.t('Apps.flare.attachGif') }}
        </button>
        <button type="button" @click="openChatMediaApp('photos', 'video')">
          <span><Video :size="20" /></span>
          {{ phone.t('Apps.flare.attachVideo') }}
        </button>
      </section>

      <section
        v-if="attachmentPicker"
        class="messages-media-picker flare-media-picker"
      >
        <header>
          <strong>{{ phone.t('Apps.flare.gifs') }}</strong>
          <button type="button" @click="attachmentPicker = null">
            {{ phone.t('Common.done') }}
          </button>
        </header>
        <div class="messages-media-picker__gifs">
          <label class="messages-gif-search">
            <Search :size="15" />
            <input
              v-model="gifQuery"
              type="search"
              :placeholder="phone.t('Apps.flare.searchGifs')"
              @input="queueGifSearch"
            />
          </label>
          <button
            v-for="gif in gifResults"
            :key="gif.id"
            type="button"
            :aria-label="gif.title"
            @click="sendAttachment('gif', gif.url)"
          >
            <img
              :src="gif.previewUrl"
              :alt="gif.title"
              loading="lazy"
              referrerpolicy="no-referrer"
            />
          </button>
          <button
            v-if="gifResults.length && gifHasMore && !gifLoading"
            type="button"
            class="messages-gif-more"
            @click="loadGifs()"
          >
            {{ phone.t('Apps.flare.loadMore') }}
          </button>
          <div v-if="gifError && !gifLoading" class="messages-gif-error">
            <ImagePlay :size="24" />
            <strong>{{ phone.t(`Apps.flare.errors.${gifError}`) }}</strong>
            <button type="button" @click="loadGifs(true)">
              {{ phone.t('Apps.flare.retryGifs') }}
            </button>
          </div>
          <sky-spinner v-if="gifLoading" class="messages-gif-loading" />
        </div>
      </section>

      <FullEmojiPicker
        v-if="emojiOpen"
        @close="emojiOpen = false"
        @pick="appendEmoji"
      />

      <div v-if="shareDraft" class="shared-composer-preview">
        <SharedContentCard compact :payload="shareDraft" variant="flare" />
        <button
          type="button"
          :aria-label="phone.t('Common.close')"
          @click="shareDraft = null"
        >
          <X :size="15" />
        </button>
      </div>

      <sky-messagebar
        class="flare-messagebar messages-messagebar"
        :placeholder="phone.t('Apps.flare.messagePlaceholder')"
        :value="draft"
        :disabled="flare.sending"
        @input="draft = eventValue($event)"
        @keydown.enter.exact="handleEnterAction($event, sendMessage)"
      >
        <template #left>
          <sky-toolbar-pane class="ios:h-10 messages-messagebar__tools">
            <sky-link
              component="button"
              icon-only
              :aria-label="phone.t('Apps.flare.moreActions')"
              :class="{
                active: attachmentMenuOpen || attachmentPanelOpen,
              }"
              @click="toggleAttachmentMenu"
            >
              <Plus :size="25" />
            </sky-link>
          </sky-toolbar-pane>
        </template>
        <template #right>
          <sky-toolbar-pane>
            <sky-link
              component="button"
              icon-only
              :disabled="(!draft.trim() && !shareDraft) || flare.sending"
              @click="sendMessage"
            >
              <ArrowUpCircle :size="29" />
            </sky-link>
          </sky-toolbar-pane>
        </template>
      </sky-messagebar>
    </template>

    <template v-else>
      <sky-navbar
        :key="
          profileEditing
            ? 'profile-edit'
            : profileSettings
              ? 'profile-settings'
              : activeTab
        "
        class="flare-navbar"
        :show-back="
          activeTab === 'profile' && (profileEditing || profileSettings)
        "
        back-appearance="surface"
        :back-label="phone.t('Common.back')"
        @back="closeProfileScreen"
      >
        <template #title>
          <span v-if="activeTab === 'discover'" class="flare-title">
            <Flame fill="currentColor" /> Flare
          </span>
          <strong v-else-if="profileEditing" class="flare-section-title">
            {{ phone.t('Apps.flare.editProfile') }}
          </strong>
          <strong v-else-if="profileSettings" class="flare-section-title">
            {{ phone.t('Apps.flare.settings') }}
          </strong>
          <strong v-else class="flare-section-title">
            {{ phone.t(`Apps.flare.tabs.${activeTab}`) }}
          </strong>
        </template>
        <template #right>
          <sky-link
            v-if="
              activeTab === 'profile' && (profileEditing || profileSettings)
            "
            component="button"
            class="flare-navbar-done"
            :disabled="profileSaving || !hasRequiredProfilePhoto"
            :aria-busy="profileSaving"
            @click="saveProfile"
          >
            {{ phone.t('Common.done') }}
          </sky-link>
          <sky-link
            v-else-if="activeTab === 'discover'"
            component="button"
            icon-only
            :aria-label="phone.t('Apps.flare.filters')"
            @click="openSettings"
          >
            <SlidersHorizontal />
          </sky-link>
        </template>
      </sky-navbar>

      <section v-if="activeTab === 'discover'" class="flare-discover">
        <div
          v-if="!flare.profile.discoverable"
          class="flare-state flare-state--discovery-off"
        >
          <span class="flare-state__icon"><EyeOff /></span>
          <h2>{{ phone.t('Apps.flare.discoveryOffTitle') }}</h2>
          <p>{{ phone.t('Apps.flare.discoveryOffBody') }}</p>
          <sky-button rounded @click="setDiscovery(true)">
            {{ phone.t('Apps.flare.enableDiscovery') }}
          </sky-button>
        </div>
        <div v-else-if="currentProfile" class="flare-deck">
          <article
            v-if="nextProfile"
            :key="nextProfile.id"
            class="flare-card flare-card--next"
            :aria-hidden="true"
          >
            <div
              class="flare-card__photo"
              :style="profilePhotoStyle(nextProfile)"
            />
          </article>
          <article
            :key="currentProfile.id"
            class="flare-card"
            :class="{
              'is-liking': cardOffset > 28,
              'is-passing': cardOffset < -28,
            }"
            :style="cardStyle"
            @pointerdown="beginDrag"
            @pointermove="moveDrag"
            @pointerup="endDrag"
            @pointercancel="cancelDrag"
          >
            <div
              class="flare-card__photo"
              :style="profilePhotoStyle(currentProfile, normalizedPhotoIndex)"
              role="img"
              :aria-label="currentProfile.name"
            />
            <div class="flare-card__progress" aria-hidden="true">
              <i
                v-for="photoNumber in currentPhotoCount"
                :key="photoNumber"
                :class="{ active: photoNumber - 1 === normalizedPhotoIndex }"
              />
            </div>
            <button
              v-if="activeExploreMode !== 'all'"
              type="button"
              class="flare-card__mode"
              :aria-label="phone.t('Apps.flare.clearExploreFilter')"
              @pointerdown.stop
              @click.stop="clearExplore"
            >
              {{ phone.t(`Apps.flare.lookingFor.${activeExploreMode}`) }}
              <X :size="12" />
            </button>
            <span class="flare-card__stamp flare-card__stamp--like">
              {{ phone.t('Apps.flare.like') }}
            </span>
            <span class="flare-card__stamp flare-card__stamp--pass">
              {{ phone.t('Apps.flare.pass') }}
            </span>
            <div class="flare-card__scrim" />
            <div class="flare-card__content">
              <div class="flare-card__headline">
                <h2>{{ currentProfile.name }}</h2>
                <b>{{ currentProfile.age }}</b>
              </div>
              <p class="flare-card__location">
                <MapPin :size="14" /> {{ phone.t('Apps.flare.nearby') }}
              </p>
              <p class="flare-card__bio">{{ currentProfile.bio }}</p>
              <div class="flare-tags">
                <span class="flare-intent">
                  <Heart :size="12" fill="currentColor" />
                  {{
                    phone.t(
                      `Apps.flare.lookingFor.${currentProfile.lookingFor}`,
                    )
                  }}
                </span>
                <span
                  v-for="interest in currentProfile.interests.slice(0, 2)"
                  :key="interest"
                >
                  {{ interest }}
                </span>
              </div>
            </div>
          </article>
        </div>
        <div
          v-else-if="flare.profile.discoverable"
          class="flare-state flare-state--compact"
        >
          <span class="flare-state__icon"><RotateCcw /></span>
          <h2>{{ phone.t('Apps.flare.noProfiles') }}</h2>
          <p>{{ phone.t('Apps.flare.noProfilesBody') }}</p>
          <sky-button
            v-if="activeExploreMode !== 'all'"
            clear
            rounded
            @click="clearExplore"
          >
            {{ phone.t('Apps.flare.clearExploreFilter') }}
          </sky-button>
        </div>
        <div
          v-if="flare.profile.discoverable && currentProfile"
          class="flare-actions"
        >
          <sky-button
            rounded
            class="flare-action flare-action--small flare-action--rewind"
            :aria-label="phone.t('Apps.flare.rewind')"
            @click="rewind"
          >
            <RotateCcw />
          </sky-button>
          <sky-button
            rounded
            class="flare-action flare-action--pass"
            :aria-label="phone.t('Apps.flare.pass')"
            @click="swipe('pass')"
          >
            <X />
          </sky-button>
          <sky-button
            rounded
            class="flare-action flare-action--small flare-action--super"
            :aria-label="phone.t('Apps.flare.superLike')"
            @click="swipe('superlike')"
          >
            <Star fill="currentColor" />
          </sky-button>
          <sky-button
            rounded
            class="flare-action flare-action--like"
            :aria-label="phone.t('Apps.flare.like')"
            @click="swipe('like')"
          >
            <Heart fill="currentColor" />
          </sky-button>
        </div>
      </section>

      <section
        v-else-if="activeTab === 'explore'"
        class="flare-scroll-view flare-explore"
      >
        <div class="flare-page-heading">
          <p>{{ phone.t('Apps.flare.exploreBody') }}</p>
        </div>
        <div class="flare-explore-grid">
          <sky-card
            v-for="tile in exploreTiles"
            :key="tile.key"
            component="button"
            type="button"
            :content-wrap="false"
            class="flare-explore-card"
            :class="`flare-explore-card--${tile.tone}`"
            @click="openExplore(tile.mode)"
          >
            <div
              class="flare-explore-card__photo"
              :class="{ 'is-fallback': !tile.coverUrl }"
              :style="tile.coverUrl ? photoStyle(tile.coverUrl) : undefined"
            />
            <div class="flare-explore-card__shade" />
            <strong>{{
              phone.t(`Apps.flare.exploreModes.${tile.key}`)
            }}</strong>
            <ChevronRight />
          </sky-card>
        </div>
      </section>

      <section
        v-else-if="activeTab === 'likes'"
        class="flare-scroll-view flare-likes"
      >
        <div class="flare-page-heading">
          <p>{{ phone.t('Apps.flare.likesBody') }}</p>
        </div>
        <div v-if="flare.likes.length" class="flare-likes-grid">
          <article v-for="profile in flare.likes" :key="profile.id">
            <i :style="profilePhotoStyle(profile)" />
            <span>
              <strong>{{ profile.name }}, {{ profile.age }}</strong>
              <small v-if="profile.superLiked" class="is-super-like">
                <Star :size="11" fill="currentColor" />
                {{ phone.t('Apps.flare.superLikedYou') }}
              </small>
              <small v-else>{{ phone.t('Apps.flare.likedYou') }}</small>
            </span>
            <div class="flare-like-actions">
              <sky-button
                rounded
                :aria-label="phone.t('Apps.flare.pass')"
                @click="reactToLike(profile.id, 'pass')"
              >
                <X />
              </sky-button>
              <sky-button
                rounded
                :aria-label="phone.t('Apps.flare.like')"
                @click="reactToLike(profile.id, 'like')"
              >
                <Heart fill="currentColor" />
              </sky-button>
            </div>
          </article>
        </div>
        <div v-else class="flare-state flare-state--compact">
          <span class="flare-state__icon"><Heart /></span>
          <h2>{{ phone.t('Apps.flare.noLikes') }}</h2>
          <p>{{ phone.t('Apps.flare.noLikesBody') }}</p>
        </div>
      </section>

      <section
        v-else-if="activeTab === 'matches'"
        class="flare-scroll-view flare-inbox"
      >
        <template v-if="flare.matches.length">
          <h2 v-if="newMatches.length">
            {{ phone.t('Apps.flare.newMatches') }}
          </h2>
          <div v-if="newMatches.length" class="flare-new-matches">
            <button
              v-for="match in newMatches"
              :key="match.id"
              type="button"
              @click="openMatch(match)"
            >
              <i :style="profilePhotoStyle(match.profile)">
                <b v-if="match.unread" />
              </i>
              <span>{{ match.profile.name }}</span>
            </button>
          </div>
          <h2>{{ phone.t('Apps.flare.messages') }}</h2>
          <sky-list strong class="flare-conversation-list">
            <sky-list-item
              v-for="match in flare.matches"
              :key="match.id"
              link
              :title="match.profile.name"
              :subtitle="matchPreview(match)"
              @click="openMatch(match)"
            >
              <template #media>
                <i
                  class="flare-match-avatar"
                  :style="profilePhotoStyle(match.profile)"
                />
              </template>
              <template #after>
                <span v-if="match.unread" class="flare-unread">{{
                  match.unread
                }}</span>
              </template>
            </sky-list-item>
          </sky-list>
        </template>
        <div v-else class="flare-state flare-state--compact">
          <span class="flare-state__icon"><MessageCircle /></span>
          <h2>{{ phone.t('Apps.flare.noMatches') }}</h2>
          <p>{{ phone.t('Apps.flare.noMatchesBody') }}</p>
        </div>
      </section>

      <section
        v-else-if="profileSettings"
        class="flare-scroll-view flare-settings"
      >
        <sky-block-title>{{
          phone.t('Apps.flare.discoverySettings')
        }}</sky-block-title>
        <sky-list inset strong>
          <sky-list-item
            :title="phone.t('Apps.flare.showProfile')"
            :subtitle="phone.t('Apps.flare.showProfileBody')"
          >
            <template #after>
              <sky-toggle
                :checked="flare.profile.discoverable"
                :disabled="discoverySaving"
                :aria-label="phone.t('Apps.flare.showProfile')"
                @change="setDiscovery(!flare.profile.discoverable)"
              />
            </template>
          </sky-list-item>
        </sky-list>
        <sky-block class="flare-settings-note">
          {{ phone.t('Apps.flare.discoveryPrivacyNote') }}
        </sky-block>

        <sky-block-title>{{
          phone.t('Apps.flare.discoveryPreferences')
        }}</sky-block-title>
        <sky-list inset strong>
          <sky-list-item
            class="flare-choice-row"
            :header="phone.t('Apps.flare.showMe')"
            :title="choiceLabel('interestedIn')"
            link
            link-component="button"
            :link-props="choiceLinkProps('interestedIn')"
          />
          <sky-field
            :label="phone.t('Apps.flare.minimumAge')"
            type="number"
            min="18"
            max="99"
            :value="profileDraft.minAge"
            @input="updateNumber('minAge', $event)"
          />
          <sky-field
            :label="phone.t('Apps.flare.maximumAge')"
            type="number"
            min="18"
            max="99"
            :value="profileDraft.maxAge"
            @input="updateNumber('maxAge', $event)"
          />
        </sky-list>

        <sky-settings-group
          class="flare-account-actions"
          :title="phone.t('Apps.flare.accountActions')"
          :footer="phone.t('Apps.flare.signOutHint')"
        >
          <sky-settings-row
            kind="action"
            :pending="accountActionPending"
            :title="phone.t('Apps.flare.signOut')"
            @activate="signOutDialogOpened = true"
          >
            <template #leading>
              <LogOut :size="20" aria-hidden="true" />
            </template>
          </sky-settings-row>
          <sky-settings-row
            kind="action"
            tone="danger"
            :pending="accountActionPending"
            :title="phone.t('Apps.flare.deleteAccount')"
            @activate="deleteAccountDialogOpened = true"
          >
            <template #leading>
              <Trash2 :size="20" aria-hidden="true" />
            </template>
          </sky-settings-row>
        </sky-settings-group>

        <p v-if="flare.error" class="flare-error">
          {{ phone.t(`Apps.flare.errors.${flare.error}`) }}
        </p>
      </section>

      <section
        v-else-if="!profileEditing"
        class="flare-scroll-view flare-profile-overview"
      >
        <div class="flare-profile-portrait">
          <i
            :style="ownPhotoStyle()"
            role="img"
            :aria-label="ownPhotoLabel()"
          />
          <span><Flame :size="16" fill="currentColor" /></span>
        </div>
        <div
          v-if="draftPhotos.length > 1"
          class="flare-profile-photo-strip"
          role="group"
          :aria-label="phone.t('Apps.flare.profilePhotos')"
        >
          <button
            v-for="(photo, index) in draftPhotos"
            :key="photo.id"
            type="button"
            :class="{ active: index === normalizedOwnPhotoIndex }"
            :aria-label="
              phone.t('Apps.flare.viewProfilePhoto', {
                count: String(draftPhotos.length),
                number: String(index + 1),
              })
            "
            :aria-pressed="index === normalizedOwnPhotoIndex"
            @click="selectOwnPhoto(index)"
          >
            <i :style="photoStyle(photo.url)" aria-hidden="true" />
          </button>
        </div>
        <h1>{{ profileDraft.name }}, {{ profileDraft.age }}</h1>
        <p>{{ profileDraft.bio }}</p>
        <button
          v-if="!flare.profile.discoverable"
          type="button"
          class="flare-hidden-banner"
          @click="profileSettings = true"
        >
          <EyeOff />
          <span>
            <strong>{{ phone.t('Apps.flare.discoveryOffTitle') }}</strong>
            <small>{{ phone.t('Apps.flare.discoveryOffShort') }}</small>
          </span>
          <ChevronRight />
        </button>
        <div class="flare-profile-controls">
          <button type="button" @click="profileSettings = true">
            <span><Settings2 /></span>
            {{ phone.t('Apps.flare.settings') }}
          </button>
          <button type="button" class="primary" @click="profileEditing = true">
            <span><Pencil /></span>
            {{ phone.t('Apps.flare.editProfile') }}
          </button>
          <button type="button" @click="shareProfile">
            <span><Share2 /></span>
            {{ phone.t('Apps.easyShare.shareProfile') }}
          </button>
        </div>
        <sky-card
          component="button"
          type="button"
          :content-wrap="false"
          class="flare-profile-card"
          aria-controls="flare-choice-sheet"
          aria-haspopup="dialog"
          :aria-label="phone.t('Apps.flare.editRelationshipGoal')"
          @click="openProfileGoalEditor"
        >
          <span><Heart fill="currentColor" /></span>
          <div>
            <strong>{{
              phone.t(`Apps.flare.lookingFor.${profileDraft.lookingFor}`)
            }}</strong>
            <small>{{ phone.t('Apps.flare.profileGoalBody') }}</small>
          </div>
          <ChevronRight />
        </sky-card>
      </section>

      <section v-else class="flare-profile-form flare-profile-form--editing">
        <sky-card :content-wrap="false" class="flare-photo-editor">
          <header>
            <div>
              <strong>{{ phone.t('Apps.flare.profilePhotos') }}</strong>
              <small>{{ phone.t('Apps.flare.profilePhotosBody') }}</small>
            </div>
            <span>{{ draftPhotos.length }}/6</span>
          </header>
          <div class="flare-photo-grid">
            <div
              v-for="(photo, index) in draftPhotos"
              :key="photo.id"
              class="flare-photo-slot"
            >
              <i :style="photoStyle(photo.url)" />
              <span v-if="index === 0" class="flare-photo-primary">
                {{ phone.t('Apps.flare.primaryPhoto') }}
              </span>
              <sky-link
                v-if="draftPhotos.length > 1"
                component="button"
                icon-only
                class="flare-photo-remove"
                :aria-label="
                  phone.t('Apps.flare.removePhoto', {
                    number: String(index + 1),
                  })
                "
                @click="removeDraftPhoto(photo.id)"
              >
                <X />
              </sky-link>
            </div>
            <sky-button
              v-if="draftPhotos.length < 6"
              clear
              class="flare-photo-add"
              :class="{ 'is-empty': !draftPhotos.length }"
              aria-controls="flare-photo-source-menu"
              aria-haspopup="menu"
              :aria-expanded="photoSourceOpened"
              @click="openPhotoSourcePicker"
            >
              <Plus />
              <span>{{ phone.t('Apps.flare.addPhotos') }}</span>
            </sky-button>
          </div>
          <p
            v-if="!hasRequiredProfilePhoto"
            class="flare-photo-required"
            role="status"
          >
            {{ phone.t('Apps.flare.profilePhotoRequired') }}
          </p>
        </sky-card>
        <sky-list inset strong>
          <sky-field
            :label="phone.t('Apps.flare.yourName')"
            :value="profileDraft.name"
            @input="profileDraft.name = eventValue($event)"
          />
          <sky-field
            :label="phone.t('Apps.flare.age')"
            type="number"
            min="18"
            max="99"
            :value="profileDraft.age"
            @input="updateNumber('age', $event)"
          />
          <sky-field
            :label="phone.t('Apps.flare.bio')"
            type="textarea"
            :value="profileDraft.bio"
            :placeholder="phone.t('Apps.flare.bioPlaceholder')"
            :input-style="bioInputStyle"
            :maxlength="300"
            @input="profileDraft.bio = eventValue($event)"
          />
          <sky-list-item
            class="flare-choice-row"
            :header="phone.t('Apps.flare.gender')"
            :title="choiceLabel('gender')"
            link
            link-component="button"
            :link-props="choiceLinkProps('gender')"
          />
          <sky-list-item
            class="flare-choice-row"
            :header="phone.t('Apps.flare.relationshipGoal')"
            :title="choiceLabel('lookingFor')"
            link
            link-component="button"
            :link-props="choiceLinkProps('lookingFor')"
          />
          <sky-field
            :label="phone.t('Apps.flare.interests')"
            :value="profileDraft.interests.join(', ')"
            :placeholder="phone.t('Apps.flare.interestsPlaceholder')"
            @input="updateInterests"
          />
        </sky-list>
        <p class="flare-form-hint">
          {{ phone.t('Apps.flare.interestsHint') }}
        </p>
        <p v-if="flare.error" class="flare-error">
          {{ phone.t(`Apps.flare.errors.${flare.error}`) }}
        </p>
      </section>

      <sky-tab-bar
        v-if="!profileEditing && !profileSettings"
        component="nav"
        icons
        labels
        bg-class="flare-tabbar__background"
        inner-class="flare-tabbar__inner"
        class="flare-tabbar bottom-0 left-0 fixed"
        :aria-label="phone.t('Apps.flare.navigation')"
      >
        <sky-toolbar-pane class="flare-tab-pane">
          <sky-tab-button
            component="button"
            :active="activeTab === 'discover'"
            :link-props="{ type: 'button', class: 'flare-tab-link' }"
            @click="selectTab('discover')"
          >
            <template #label>{{
              phone.t('Apps.flare.tabs.discover')
            }}</template>
            <template #icon
              ><sky-icon><Flame fill="currentColor" /></sky-icon
            ></template>
          </sky-tab-button>
          <sky-tab-button
            component="button"
            :active="activeTab === 'explore'"
            :link-props="{ type: 'button', class: 'flare-tab-link' }"
            @click="selectTab('explore')"
          >
            <template #label>{{ phone.t('Apps.flare.tabs.explore') }}</template>
            <template #icon
              ><sky-icon><Grid2X2 /></sky-icon
            ></template>
          </sky-tab-button>
          <sky-tab-button
            component="button"
            :active="activeTab === 'likes'"
            :link-props="{ type: 'button', class: 'flare-tab-link' }"
            @click="selectTab('likes')"
          >
            <template #label>{{ phone.t('Apps.flare.tabs.likes') }}</template>
            <template #icon>
              <sky-icon class="flare-tab-icon">
                <Heart fill="currentColor" />
                <sky-badge v-if="flare.likes.length" small>{{
                  flare.likes.length
                }}</sky-badge>
              </sky-icon>
            </template>
          </sky-tab-button>
          <sky-tab-button
            component="button"
            :active="activeTab === 'matches'"
            :link-props="{ type: 'button', class: 'flare-tab-link' }"
            @click="selectTab('matches')"
          >
            <template #label>{{ phone.t('Apps.flare.tabs.matches') }}</template>
            <template #icon>
              <sky-icon class="flare-tab-icon">
                <MessageCircle />
                <sky-badge v-if="unreadMatches" small>{{
                  unreadMatches
                }}</sky-badge>
              </sky-icon>
            </template>
          </sky-tab-button>
          <sky-tab-button
            component="button"
            :active="activeTab === 'profile'"
            :link-props="{ type: 'button', class: 'flare-tab-link' }"
            @click="selectTab('profile')"
          >
            <template #label>{{ phone.t('Apps.flare.tabs.profile') }}</template>
            <template #icon
              ><sky-icon><UserRound /></sky-icon
            ></template>
          </sky-tab-button>
        </sky-toolbar-pane>
      </sky-tab-bar>
    </template>

    <div
      v-if="matchReveal"
      class="flare-match-reveal"
      role="dialog"
      aria-modal="true"
    >
      <SkyButton
        glass
        icon-only
        rounded
        type="button"
        class="flare-match-reveal__close"
        :aria-label="phone.t('Common.close')"
        @click="matchReveal = null"
      >
        <X />
      </SkyButton>
      <Flame class="flare-match-reveal__flame" fill="currentColor" />
      <h2>{{ phone.t('Apps.flare.itsAMatch') }}</h2>
      <p>
        {{
          phone.t('Apps.flare.matchBody', { name: matchReveal.profile.name })
        }}
      </p>
      <div class="flare-match-pair">
        <i :style="ownPhotoStyle()" />
        <span><Heart fill="currentColor" /></span>
        <i :style="profilePhotoStyle(matchReveal.profile)" />
      </div>
      <div class="flare-match-actions">
        <sky-button
          large
          rounded
          class="flare-match-primary"
          @click="openRevealedMatch"
        >
          {{ phone.t('Apps.flare.sayHello') }}
        </sky-button>
        <sky-button
          clear
          inline
          class="flare-match-secondary"
          @click="matchReveal = null"
        >
          {{ phone.t('Apps.flare.keepSwiping') }}
        </sky-button>
      </div>
    </div>

    <SkyDropdown
      id="flare-photo-source-menu"
      :items="photoSourceItems"
      :label="phone.t('Apps.flare.addPhotos')"
      :opened="photoSourceOpened"
      :target="photoSourceTarget"
      @backdropclick="closePhotoSourcePicker"
      @escape="closePhotoSourcePicker"
      @positionerror="closePhotoSourcePicker"
      @select="selectPhotoSource"
    />

    <div class="flare-choice-sheet">
      <sky-sheet
        :opened="choiceOpened"
        @backdropclick="closeChoice"
        @escape="closeChoice"
      >
        <section
          id="flare-choice-sheet"
          ref="choiceSheetContent"
          class="flare-choice-sheet__content"
          role="dialog"
          :aria-hidden="!choiceOpened"
          :aria-modal="choiceOpened ? 'true' : undefined"
          aria-labelledby="flare-choice-sheet-title"
          :inert="!choiceOpened"
          @keydown.esc.stop.prevent="closeChoice"
        >
          <span class="flare-choice-sheet__grabber" aria-hidden="true" />
          <header class="flare-choice-sheet__header">
            <h2 id="flare-choice-sheet-title">{{ activeChoiceTitle }}</h2>
            <sky-link
              component="button"
              icon-only
              class="flare-choice-sheet__close"
              :aria-label="phone.t('Common.close')"
              :link-props="{ type: 'button' }"
              @click="closeChoice"
            >
              <X />
            </sky-link>
          </header>
          <sky-list
            component="ul"
            role="listbox"
            inset
            strong
            class="flare-choice-sheet__list"
          >
            <sky-list-item
              v-for="option in activeChoiceOptions"
              :key="option.value"
              class="flare-choice-option"
              :title="option.label"
              link
              :chevron="false"
              link-component="button"
              :link-props="{
                type: 'button',
                role: 'option',
                class: 'flare-choice-option__button',
                'aria-selected': activeChoiceValue === option.value,
              }"
              @click="selectChoice(option.value)"
            >
              <template #after>
                <Check
                  v-if="activeChoiceValue === option.value"
                  class="flare-choice-check"
                  aria-hidden="true"
                />
              </template>
            </sky-list-item>
          </sky-list>
        </section>
      </sky-sheet>
    </div>

    <sky-dialog
      :opened="signOutDialogOpened"
      :title="phone.t('Apps.flare.signOutTitle')"
      :content="phone.t('Apps.flare.signOutBody')"
      @backdropclick="closeSignOutDialog"
      @escape="closeSignOutDialog"
    >
      <template #buttons>
        <sky-dialog-button
          :disabled="accountActionPending"
          @click="closeSignOutDialog"
        >
          {{ phone.t('Common.cancel') }}
        </sky-dialog-button>
        <sky-dialog-button
          strong
          :disabled="accountActionPending"
          @click="signOut"
        >
          {{
            accountActionPending
              ? phone.t('Apps.flare.signingOut')
              : phone.t('Apps.flare.signOut')
          }}
        </sky-dialog-button>
      </template>
    </sky-dialog>

    <sky-dialog
      :opened="deleteAccountDialogOpened"
      role="alertdialog"
      :title="phone.t('Apps.flare.deleteAccountTitle')"
      :content="phone.t('Apps.flare.deleteAccountBody')"
      @backdropclick="closeDeleteAccountDialog"
      @escape="closeDeleteAccountDialog"
    >
      <template #buttons>
        <sky-dialog-button
          :disabled="accountActionPending"
          @click="closeDeleteAccountDialog"
        >
          {{ phone.t('Common.cancel') }}
        </sky-dialog-button>
        <sky-dialog-button
          strong
          class="flare-dialog-button--danger"
          :disabled="accountActionPending"
          @click="deleteFlareAccount"
        >
          {{
            accountActionPending
              ? phone.t('Apps.flare.deletingAccount')
              : phone.t('Common.delete')
          }}
        </sky-dialog-button>
      </template>
    </sky-dialog>

    <sky-dialog
      :opened="unmatchDialog"
      @backdropclick="unmatchDialog = false"
      @escape="unmatchDialog = false"
    >
      <template #title>{{ phone.t('Apps.flare.unmatchTitle') }}</template>
      <p>
        {{
          phone.t('Apps.flare.unmatchBody', {
            name: activeMatch?.profile.name ?? '',
          })
        }}
      </p>
      <template #buttons>
        <sky-dialog-button @click="unmatchDialog = false">
          {{ phone.t('Common.cancel') }}
        </sky-dialog-button>
        <sky-dialog-button strong @click="confirmUnmatch">
          {{ phone.t('Apps.flare.unmatch') }}
        </sky-dialog-button>
      </template>
    </sky-dialog>

    <sky-notification :opened="Boolean(actionToast)" :text="actionToast" />
  </sky-app-page>
</template>

<style scoped>
.flare-page {
  --flare: #ff385c;
  --flare-warm: #ff6847;
  --flare-ink: #17171b;
  --flare-muted: #7a7a82;
  --flare-surface: #fff;
  --flare-panel: #f4f4f6;
  --color-primary: var(--flare);
  --sky-safe-area-top: 46px;
  --sky-safe-area-bottom: 25px;
  display: flex !important;
  flex-direction: column;
  padding: 0 0 105px !important;
  overflow: hidden;
  background: var(--flare-surface) !important;
  color: var(--flare-ink);
}
.flare-page--without-tabs,
.flare-page--chat {
  padding-bottom: 0 !important;
}
.flare-page button {
  font: inherit;
}
.flare-navbar {
  z-index: 12;
  flex: 0 0 auto;
  color: var(--flare-ink);
  border-bottom: 1px solid color-mix(in srgb, var(--flare-ink) 9%, transparent);
}
.flare-navbar :deep(.sky-link) {
  color: var(--flare-muted);
}
.flare-navbar :deep(.flare-navbar-done) {
  color: var(--flare);
  font-weight: 700;
}
.flare-navbar :deep(.flare-navbar-done:disabled) {
  pointer-events: none;
  opacity: 0.45;
}
.flare-title {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  color: var(--flare);
  font-size: 22px;
  font-weight: 850;
  letter-spacing: -0.9px;
}
.flare-title svg {
  width: 21px;
  height: 21px;
}
.flare-section-title {
  font-size: 18px;
  letter-spacing: -0.3px;
}
.flare-loading,
.flare-state {
  min-height: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 28px;
  text-align: center;
}
.flare-loading {
  padding-top: 72px;
  padding-bottom: 50px;
}
.flare-mark {
  width: 62px;
  height: 62px;
  display: grid;
  place-items: center;
  border-radius: 21px;
  color: #fff;
  background: linear-gradient(145deg, var(--flare-warm), var(--flare));
  box-shadow: 0 14px 34px rgb(255 56 92 / 25%);
}
.flare-mark svg {
  width: 34px;
}
.flare-state h1,
.flare-state h2 {
  margin: 1px 0 0;
  font-size: 23px;
  letter-spacing: -0.5px;
}
.flare-state p {
  max-width: 280px;
  margin: 0;
  color: var(--flare-muted);
  font-size: 13px;
  line-height: 1.45;
}
.flare-state--compact {
  min-height: 240px;
}
.flare-state__icon {
  width: 58px;
  height: 58px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--flare);
  background: rgb(255 56 92 / 10%);
}
.flare-state--discovery-off {
  grid-row: 1 / -1;
}
.flare-state--discovery-off :deep(.sky-button) {
  width: auto;
  margin-top: 7px;
  padding-right: 20px;
  padding-left: 20px;
  color: #fff;
  background: linear-gradient(100deg, var(--flare-warm), var(--flare));
}

.flare-discover {
  min-height: 0;
  flex: 1;
  display: grid;
  grid-template-rows: minmax(0, 1fr) 72px;
  gap: 2px;
  padding: 7px 10px 4px;
}
.flare-deck {
  position: relative;
  min-height: 0;
}
.flare-card {
  position: absolute;
  inset: 0;
  overflow: hidden;
  border-radius: 17px;
  background: #29292d;
  box-shadow: 0 4px 14px rgb(23 23 27 / 14%);
  cursor: grab;
  touch-action: none;
  user-select: none;
  will-change: transform;
  transition: transform 0.26s cubic-bezier(0.2, 0.75, 0.25, 1);
}
.flare-card:active {
  cursor: grabbing;
}
.flare-card--next {
  pointer-events: none;
}
.flare-card__photo {
  position: absolute;
  inset: 0;
  background-repeat: no-repeat;
}
.flare-card__progress {
  position: absolute;
  z-index: 3;
  top: 8px;
  right: 8px;
  left: 8px;
  display: flex;
  gap: 4px;
}
.flare-card__progress i {
  height: 3px;
  flex: 1;
  border-radius: 3px;
  background: rgb(255 255 255 / 45%);
  box-shadow: 0 1px 2px rgb(0 0 0 / 25%);
}
.flare-card__progress i.active {
  background: #fff;
}
.flare-card__mode {
  position: absolute;
  z-index: 5;
  top: 19px;
  left: 10px;
  padding: 5px 8px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border: 1px solid rgb(255 255 255 / 25%);
  border-radius: 999px;
  color: #fff;
  background: rgb(0 0 0 / 38%);
  font-size: 9px !important;
  font-weight: 750;
  backdrop-filter: blur(10px);
}
.flare-card__scrim {
  position: absolute;
  inset: 42% 0 0;
  background: linear-gradient(transparent, rgb(0 0 0 / 87%));
}
.flare-card__content {
  position: absolute;
  right: 16px;
  bottom: 16px;
  left: 16px;
  color: #fff;
  text-shadow: 0 1px 6px rgb(0 0 0 / 42%);
}
.flare-card__headline {
  display: flex;
  align-items: baseline;
  gap: 6px;
}
.flare-card__headline h2 {
  margin: 0;
  font-size: 28px;
  line-height: 1;
  letter-spacing: -0.8px;
}
.flare-card__headline b {
  font-size: 23px;
  font-weight: 450;
  line-height: 1;
}
.flare-card__headline svg {
  align-self: center;
  color: #43c9ff;
}
.flare-card__location {
  margin: 6px 0 9px;
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
}
.flare-card__bio {
  max-width: 330px;
  margin: 0 0 9px;
  overflow: hidden;
  display: -webkit-box;
  font-size: 12px;
  line-height: 1.35;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.flare-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
}
.flare-tags span {
  padding: 5px 8px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border: 1px solid rgb(255 255 255 / 26%);
  border-radius: 999px;
  background: rgb(0 0 0 / 32%);
  font-size: 10px;
  font-weight: 700;
  backdrop-filter: blur(9px);
}
.flare-card__stamp {
  position: absolute;
  z-index: 4;
  top: 44px;
  padding: 6px 10px;
  border: 4px solid;
  border-radius: 7px;
  opacity: 0;
  font-size: 23px;
  font-weight: 900;
  letter-spacing: 1px;
  text-transform: uppercase;
}
.flare-card__stamp--like {
  left: 20px;
  color: #54df9b;
  transform: rotate(-12deg);
}
.flare-card__stamp--pass {
  right: 20px;
  color: #ff596f;
  transform: rotate(12deg);
}
.flare-card.is-liking .flare-card__stamp--like,
.flare-card.is-passing .flare-card__stamp--pass {
  opacity: 1;
}
.flare-actions {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 17px;
}
.flare-action {
  width: 54px !important;
  height: 54px !important;
  min-width: 54px !important;
  padding: 0 !important;
  border: 1px solid rgb(23 23 27 / 8%) !important;
  border-radius: 50% !important;
  background: var(--flare-surface) !important;
  box-shadow: 0 4px 13px rgb(0 0 0 / 11%);
}
.flare-action svg {
  width: 25px;
  height: 25px;
}
.flare-action--small {
  width: 42px !important;
  height: 42px !important;
  min-width: 42px !important;
}
.flare-action--small svg {
  width: 20px;
  height: 20px;
}
.flare-action--rewind {
  color: #f2af36 !important;
}
.flare-action--pass {
  color: #ff4964 !important;
}
.flare-action--super {
  color: #1ea9ed !important;
}
.flare-action--like {
  color: #28c98b !important;
}

.flare-scroll-view,
.flare-profile-form,
.flare-chat-scroll {
  min-height: 0;
  flex: 1;
  overflow-y: auto;
  scrollbar-width: none;
}
.flare-scroll-view::-webkit-scrollbar,
.flare-profile-form::-webkit-scrollbar,
.flare-chat-scroll::-webkit-scrollbar {
  display: none;
}
.flare-scroll-view {
  padding: 15px 14px 24px;
}
.flare-page-heading {
  margin: 0 2px 14px;
}
.flare-page-heading p {
  margin: 0;
  color: var(--flare-muted);
  font-size: 12px;
  line-height: 1.4;
}

.flare-explore-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}
.flare-explore-card {
  position: relative;
  aspect-ratio: 1 / 1;
  margin: 0 !important;
  padding: 0 !important;
  overflow: hidden;
  border-radius: 15px !important;
  color: #fff;
  cursor: pointer;
}
.flare-explore-card__photo,
.flare-explore-card__shade {
  position: absolute;
  inset: 0;
}
.flare-explore-card__photo {
  background-repeat: no-repeat;
  filter: saturate(0.82);
}
.flare-explore-card__photo.is-fallback {
  background: linear-gradient(145deg, var(--flare), var(--flare-warm));
}
.flare-explore-card__shade {
  background: linear-gradient(15deg, rgb(0 0 0 / 72%), transparent 70%);
  mix-blend-mode: multiply;
}
.flare-explore-card--coral .flare-explore-card__shade {
  background-color: rgb(255 68 90 / 42%);
}
.flare-explore-card--violet .flare-explore-card__shade {
  background-color: rgb(126 63 218 / 42%);
}
.flare-explore-card--blue .flare-explore-card__shade {
  background-color: rgb(24 133 211 / 40%);
}
.flare-explore-card--amber .flare-explore-card__shade {
  background-color: rgb(220 137 16 / 43%);
}
.flare-explore-card strong {
  position: absolute;
  right: 30px;
  bottom: 13px;
  left: 12px;
  font-size: 15px;
  line-height: 1.15;
}
.flare-explore-card > svg {
  position: absolute;
  right: 9px;
  bottom: 12px;
  width: 18px;
}

.flare-likes-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}
.flare-likes-grid article {
  position: relative;
  aspect-ratio: 0.76;
  padding: 0;
  overflow: hidden;
  border: 0;
  border-radius: 16px;
  color: #fff;
  text-align: left;
  background: #28282c;
}
.flare-likes-grid i {
  position: absolute;
  inset: 0;
  background-repeat: no-repeat;
}
.flare-likes-grid article::after {
  position: absolute;
  inset: 38% 0 0;
  content: '';
  background: linear-gradient(transparent, rgb(0 0 0 / 88%));
}
.flare-likes-grid span {
  position: absolute;
  z-index: 1;
  right: 11px;
  bottom: 11px;
  left: 11px;
}
.flare-likes-grid strong,
.flare-likes-grid small {
  display: block;
}
.flare-likes-grid strong {
  font-size: 14px;
}
.flare-likes-grid small {
  margin-top: 1px;
  color: rgb(255 255 255 / 78%);
  font-size: 10px;
}
.flare-likes-grid small.is-super-like {
  display: flex;
  align-items: center;
  gap: 3px;
  color: #72d6ff;
}
.flare-like-actions {
  position: absolute;
  z-index: 2;
  right: 9px;
  bottom: 47px;
  display: flex;
  gap: 7px;
}
.flare-like-actions :deep(.sky-button) {
  width: 33px !important;
  height: 33px !important;
  min-width: 33px !important;
  padding: 0 !important;
  border-radius: 50% !important;
  color: #ff526a;
  background: rgb(7 7 9 / 72%);
  backdrop-filter: blur(10px);
}
.flare-like-actions :deep(.sky-button:last-child) {
  color: #35d898;
}
.flare-like-actions svg {
  width: 17px;
  height: 17px;
}

.flare-inbox h2 {
  margin: 4px 2px 10px;
  font-size: 16px;
  letter-spacing: -0.2px;
}
.flare-new-matches + h2 {
  margin-top: 17px;
}
.flare-new-matches {
  margin: 0 -14px;
  padding: 0 14px 4px;
  display: flex;
  gap: 12px;
  overflow-x: auto;
  scrollbar-width: none;
}
.flare-new-matches button {
  width: 65px;
  flex: none;
  padding: 0;
  border: 0;
  color: inherit;
  background: transparent;
  text-align: center;
}
.flare-new-matches i {
  position: relative;
  width: 62px;
  height: 62px;
  display: block;
  border: 2px solid var(--flare);
  border-radius: 50%;
  background-repeat: no-repeat;
}
.flare-new-matches i b {
  position: absolute;
  right: 0;
  bottom: 1px;
  width: 12px;
  height: 12px;
  border: 2px solid var(--flare-surface);
  border-radius: 50%;
  background: #20cf79;
}
.flare-new-matches span {
  margin-top: 5px;
  display: block;
  overflow: hidden;
  font-size: 10px;
  white-space: nowrap;
  text-overflow: ellipsis;
}
.flare-conversation-list {
  margin: 0 -14px !important;
}
.flare-match-avatar,
.flare-chat-title i {
  display: block;
  flex: none;
  border-radius: 50%;
  background-repeat: no-repeat;
}
.flare-match-avatar {
  width: 50px;
  height: 50px;
}
.flare-unread {
  min-width: 21px;
  height: 21px;
  display: grid;
  place-items: center;
  border-radius: 999px;
  color: #fff;
  background: var(--flare);
  font-size: 11px;
  font-weight: 800;
}

.flare-profile-overview {
  padding-top: 23px;
  text-align: center;
}
.flare-profile-portrait {
  position: relative;
  width: 112px;
  height: 112px;
  margin: 0 auto 12px;
}
.flare-profile-portrait > i {
  width: 100%;
  height: 100%;
  display: block;
  border: 4px solid var(--flare-surface);
  border-radius: 50%;
  background-repeat: no-repeat;
  box-shadow: 0 9px 25px rgb(0 0 0 / 16%);
}
.flare-profile-portrait > span {
  position: absolute;
  right: 0;
  bottom: 3px;
  width: 31px;
  height: 31px;
  display: grid;
  place-items: center;
  border: 3px solid var(--flare-surface);
  border-radius: 50%;
  color: #fff;
  background: var(--flare);
}
.flare-profile-photo-strip {
  max-width: 100%;
  margin: -2px auto 14px;
  padding: 2px;
  display: flex;
  justify-content: center;
  gap: 6px;
}
.flare-profile-photo-strip > button {
  width: 44px;
  height: 52px;
  margin: 0;
  padding: 2px;
  display: grid;
  place-items: center;
  border: 2px solid transparent;
  border-radius: 13px;
  background: transparent;
  color: inherit;
  cursor: pointer;
  transition:
    border-color 180ms ease,
    transform 180ms ease;
}
.flare-profile-photo-strip > button > i {
  width: 36px;
  height: 44px;
  display: block;
  border-radius: 9px;
  background-repeat: no-repeat;
}
.flare-profile-photo-strip > button.active {
  border-color: var(--flare);
}
.flare-profile-photo-strip > button:active {
  transform: scale(0.96);
}
.flare-profile-photo-strip > button:focus-visible {
  outline: 2px solid var(--flare);
  outline-offset: 2px;
}
.flare-profile-overview > h1 {
  margin: 0;
  font-size: 24px;
  letter-spacing: -0.6px;
}
.flare-profile-overview > p {
  max-width: 280px;
  margin: 6px auto 17px;
  color: var(--flare-muted);
  font-size: 12px;
  line-height: 1.4;
}
.flare-hidden-banner {
  width: 100%;
  margin: 0 0 18px;
  padding: 11px 12px;
  display: flex;
  align-items: center;
  gap: 10px;
  border: 0;
  border-radius: 14px;
  color: var(--flare-ink);
  text-align: left;
  background: rgb(255 56 92 / 9%);
}
.flare-hidden-banner > svg:first-child {
  width: 20px;
  color: var(--flare);
}
.flare-hidden-banner > span {
  min-width: 0;
  flex: 1;
}
.flare-hidden-banner strong,
.flare-hidden-banner small {
  display: block;
}
.flare-hidden-banner strong {
  font-size: 12px;
}
.flare-hidden-banner small {
  margin-top: 1px;
  color: var(--flare-muted);
  font-size: 10px;
}
.flare-hidden-banner > svg:last-child {
  width: 16px;
  color: var(--flare-muted);
}
.flare-profile-controls {
  display: flex;
  justify-content: center;
  gap: 24px;
}
.flare-profile-controls button {
  width: 84px;
  padding: 0;
  border: 0;
  color: var(--flare-muted);
  background: transparent;
  font-size: 10px;
  font-weight: 700;
}
.flare-profile-controls span {
  width: 48px;
  height: 48px;
  margin: 0 auto 6px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--flare-ink);
  background: var(--flare-panel);
}
.flare-profile-controls .primary span {
  color: #fff;
  background: linear-gradient(140deg, var(--flare-warm), var(--flare));
  box-shadow: 0 7px 18px rgb(255 56 92 / 25%);
}
.flare-profile-card {
  box-sizing: border-box;
  width: calc(100% - 4px);
  min-height: 65px;
  margin: 26px 2px 0 !important;
  padding: 14px !important;
  display: flex;
  align-items: center;
  gap: 11px;
  border: 0;
  color: inherit;
  font: inherit;
  text-align: left;
  border-radius: 15px !important;
  background: var(--flare-panel) !important;
  box-shadow: none !important;
  cursor: pointer;
}
.flare-profile-card:active {
  background: var(--sky-pressed) !important;
}
.flare-profile-card:focus-visible {
  outline: 2px solid var(--flare);
  outline-offset: 2px;
}
.flare-profile-card > span {
  width: 37px;
  height: 37px;
  display: grid;
  flex: none;
  place-items: center;
  border-radius: 12px;
  color: var(--flare);
  background: rgb(255 56 92 / 11%);
}
.flare-profile-card > div {
  min-width: 0;
  flex: 1;
}
.flare-profile-card strong,
.flare-profile-card small {
  display: block;
}
.flare-profile-card strong {
  font-size: 13px;
}
.flare-profile-card small {
  margin-top: 2px;
  color: var(--flare-muted);
  font-size: 10px;
}
.flare-profile-card > svg {
  width: 17px;
  color: var(--flare-muted);
}

.flare-profile-form {
  padding: 16px 0 24px;
}
.flare-profile-form--onboarding {
  padding-top: 15px;
}
.flare-profile-form__actions {
  margin: 16px 0 0 !important;
}
.flare-profile-form :deep(.sky-list),
.flare-settings :deep(.sky-list) {
  margin-top: 8px;
  margin-bottom: 8px;
}
.flare-choice-row :deep(.flare-choice-trigger),
.flare-choice-option :deep(.flare-choice-option__button) {
  width: 100%;
  border: 0;
  color: inherit;
  background: transparent;
  text-align: left;
}
.flare-choice-row :deep(.flare-choice-trigger:focus-visible),
.flare-choice-option :deep(.flare-choice-option__button:focus-visible) {
  outline: 2px solid var(--flare);
  outline-offset: -2px;
}
.flare-brand-lockup {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 2px 20px 16px;
}
.flare-brand-lockup .flare-mark {
  width: 54px;
  height: 54px;
  border-radius: 18px;
}
.flare-brand-lockup .flare-mark svg {
  width: 28px;
}
.flare-brand-lockup h1 {
  margin: 0;
  font-size: 23px;
}
.flare-brand-lockup p {
  margin: 3px 0 0;
  color: var(--flare-muted);
  font-size: 12px;
}
.flare-photo-editor {
  margin: 0 16px 14px !important;
  padding: 14px !important;
  border-radius: 18px !important;
  background: var(--flare-panel) !important;
  box-shadow: none !important;
}
.flare-photo-editor > header {
  margin-bottom: 12px;
  display: flex;
  align-items: flex-start;
  gap: 12px;
}
.flare-photo-editor > header > div {
  min-width: 0;
  flex: 1;
}
.flare-photo-editor > header strong,
.flare-photo-editor > header small {
  display: block;
}
.flare-photo-editor > header strong {
  font-size: 15px;
}
.flare-photo-editor > header small {
  margin-top: 3px;
  color: var(--flare-muted);
  font-size: 10px;
  line-height: 1.35;
}
.flare-photo-editor > header > span {
  padding: 4px 7px;
  border-radius: 999px;
  color: var(--flare);
  background: rgb(255 56 92 / 10%);
  font-size: 10px;
  font-weight: 800;
}
.flare-photo-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
}
.flare-photo-slot {
  position: relative;
  aspect-ratio: 0.78;
  overflow: hidden;
  border-radius: 13px;
  background: color-mix(in srgb, var(--flare-muted) 18%, transparent);
}
.flare-photo-slot > i {
  position: absolute;
  inset: 0;
  display: block;
  background-repeat: no-repeat;
}
.flare-photo-primary {
  position: absolute;
  right: 7px;
  bottom: 7px;
  left: 7px;
  padding: 4px 6px;
  overflow: hidden;
  border-radius: 999px;
  color: #fff;
  background: rgb(0 0 0 / 58%);
  font-size: 9px;
  font-weight: 800;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
  backdrop-filter: blur(8px);
}
.flare-photo-slot :deep(.flare-photo-remove) {
  position: absolute;
  top: 6px;
  right: 6px;
  width: 26px;
  height: 26px;
  min-width: 26px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: rgb(0 0 0 / 62%);
  backdrop-filter: blur(8px);
}
.flare-photo-slot :deep(.flare-photo-remove svg) {
  width: 15px;
  height: 15px;
}
.flare-photo-grid :deep(.flare-photo-add) {
  width: 100%;
  height: auto;
  min-height: 0;
  aspect-ratio: 0.78;
  padding: 10px 7px;
  display: flex;
  flex-direction: column;
  gap: 7px;
  border: 1px dashed color-mix(in srgb, var(--flare-muted) 44%, transparent);
  border-radius: 13px;
  color: var(--flare);
  background: color-mix(in srgb, var(--flare-surface) 68%, transparent);
  font-size: 10px;
  font-weight: 750;
  line-height: 1.2;
  white-space: normal;
}
.flare-photo-grid :deep(.flare-photo-add.is-empty) {
  min-height: 104px;
  grid-column: 1 / -1;
  aspect-ratio: auto;
}
.flare-photo-grid :deep(.flare-photo-add svg) {
  width: 25px;
  height: 25px;
}
.flare-onboarding-photo-actions {
  margin-top: var(--sky-space-3);
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--sky-space-2);
}
.flare-onboarding-photo-actions :deep(.sky-button) {
  min-width: 0;
  padding-inline: var(--sky-space-2);
}
.flare-onboarding-photo-actions :deep(.sky-button span) {
  overflow: hidden;
  text-overflow: ellipsis;
}
.flare-photo-required {
  margin: var(--sky-space-3) 0 0;
  color: var(--flare);
  font-size: var(--sky-font-caption);
  font-weight: 650;
  line-height: 1.35;
}
.flare-error {
  margin: 8px 22px 0;
  color: #ff3b30;
  font-size: 12px;
  text-align: center;
}
.flare-form-hint {
  margin: 4px 22px 0;
  color: var(--flare-muted);
  font-size: 10px;
  line-height: 1.4;
}
.flare-settings {
  padding-right: 0;
  padding-left: 0;
}
.flare-settings :deep(.sky-block-title) {
  margin-top: 15px;
  margin-bottom: 5px;
}
.flare-settings-note {
  margin: 8px 20px 15px !important;
  color: var(--flare-muted);
  font-size: 11px;
  line-height: 1.45;
}
.flare-account-actions {
  margin: 0 var(--sky-page-gutter) var(--sky-space-6);
}
.flare-account-actions :deep(.sky-settings-group__title),
.flare-account-actions :deep(.sky-settings-group__footer) {
  margin-right: 0;
  margin-left: 0;
}
.flare-account-actions
  :deep(.sky-settings-row--danger .sky-settings-row__leading) {
  color: var(--sky-danger);
}
.flare-dialog-button--danger:not(:disabled) {
  background: var(--sky-danger);
  color: #fff;
}

.flare-choice-sheet :deep(.sky-sheet__panel) {
  z-index: 70;
  max-height: min(62%, 420px);
  overflow-y: auto !important;
  color: var(--flare-ink);
  background: var(--flare-surface) !important;
  box-shadow: 0 -18px 55px rgb(0 0 0 / 18%);
}
.flare-choice-sheet__content {
  padding: 8px 0 max(18px, var(--sky-safe-area-bottom));
}
.flare-choice-sheet__grabber {
  width: 36px;
  height: 4px;
  margin: 0 auto 5px;
  display: block;
  border-radius: 999px;
  background: color-mix(in srgb, var(--flare-muted) 38%, transparent);
}
.flare-choice-sheet__header {
  position: relative;
  min-height: 48px;
  padding: 7px 58px 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
}
.flare-choice-sheet__header h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 800;
  letter-spacing: -0.35px;
}
.flare-choice-sheet__header :deep(.flare-choice-sheet__close) {
  position: absolute;
  top: 4px;
  right: 13px;
  width: 36px;
  height: 36px;
  min-width: 36px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: var(--flare-ink);
  background: var(--flare-panel);
}
.flare-choice-sheet__header :deep(.flare-choice-sheet__close svg) {
  width: 18px;
  height: 18px;
}
.flare-choice-sheet__list {
  margin: 0 12px 8px !important;
}
.flare-choice-check {
  width: 20px;
  height: 20px;
  color: var(--flare);
  stroke-width: 3;
}

.flare-chat-title {
  display: inline-flex;
  align-items: center;
  gap: 8px;
}
.flare-chat-title i {
  width: 32px;
  height: 32px;
}
.flare-chat-scroll {
  padding: 10px 12px 82px;
}
.flare-page--attachment-panel .flare-chat-scroll {
  padding-bottom: 390px;
}
.flare-chat-scroll :deep(.sky-message--sent [class*='message-bubble']) {
  background: linear-gradient(
    110deg,
    var(--flare-warm),
    var(--flare)
  ) !important;
}
.flare-messagebar {
  position: absolute;
  z-index: 14;
  right: 10px;
  bottom: 27px;
  left: 10px;
  border-radius: 22px;
  box-shadow: 0 7px 24px rgb(0 0 0 / 12%);
}
.flare-messagebar :deep(.sky-link) {
  color: var(--flare);
}
.flare-messagebar :deep(.messages-messagebar__tools .sky-link) {
  color: var(--flare-text);
}
.flare-messagebar :deep(.messages-messagebar__tools .sky-link.active) {
  background: rgb(255 56 92 / 13%);
  color: var(--flare);
}
.flare-media-picker > header button,
.flare-media-picker .messages-gif-more,
.flare-media-picker .messages-gif-error button {
  color: var(--flare) !important;
}

.flare-tabbar {
  z-index: 30;
  color: var(--flare-muted);
}
.flare-tabbar :deep(.flare-tabbar__inner) {
  width: 100% !important;
  max-width: none !important;
  gap: 0 !important;
  padding-right: 7px;
  padding-left: 7px;
}
.flare-tabbar :deep(.flare-tab-pane) {
  width: 100% !important;
  border-radius: 24px;
}
.flare-tabbar :deep(.flare-tab-link) {
  min-width: 0;
  padding-right: 2px !important;
  padding-left: 2px !important;
}
.flare-tabbar :deep(.flare-tab-link > span > span:last-child) {
  font-size: 9px;
}
.flare-tabbar :deep(.flare-tab-link svg) {
  width: 22px;
  height: 22px;
}
.flare-tabbar :deep(.sky-tab-button--active) {
  color: var(--flare) !important;
}
.flare-tab-icon {
  position: relative;
}
.flare-tab-icon :deep(.sky-badge) {
  position: absolute;
  top: -7px;
  right: -8px;
  border: 2px solid var(--flare-surface);
  background: var(--flare);
}

.flare-match-reveal {
  position: absolute;
  z-index: 80;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 30px;
  color: #fff;
  text-align: center;
  background: radial-gradient(circle at 50% 30%, #ff6a62, #ef2f78 55%, #9d1669);
}
.flare-match-reveal__close {
  position: absolute;
  top: 24px;
  right: 18px;
  width: 44px;
  min-width: 44px;
  height: 44px;
  min-height: 44px;
  display: grid;
  place-items: center;
  color: #fff;
}
.flare-match-reveal__flame {
  width: 58px;
  height: 58px;
}
.flare-match-reveal h2 {
  margin: 6px 0 3px;
  font-size: 37px;
  font-weight: 900;
  letter-spacing: -1.8px;
}
.flare-match-reveal p {
  margin: 0;
  opacity: 0.88;
}
.flare-match-pair {
  display: flex;
  align-items: center;
  margin: 28px 0;
}
.flare-match-pair i {
  width: 104px;
  height: 104px;
  border: 4px solid #fff;
  border-radius: 50%;
  background-repeat: no-repeat;
  box-shadow: 0 12px 30px rgb(70 0 30 / 28%);
}
.flare-match-pair span {
  z-index: 1;
  width: 45px;
  height: 45px;
  display: grid;
  margin: 0 -8px;
  place-items: center;
  border-radius: 50%;
  color: var(--flare);
  background: #fff;
}
.flare-match-actions {
  width: min(100%, 320px);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
}
.flare-match-actions :deep(.flare-match-primary) {
  width: 100%;
  color: var(--flare);
  background: #fff;
  box-shadow: 0 10px 24px rgb(84 0 34 / 18%);
}
.flare-match-actions :deep(.flare-match-secondary) {
  width: auto;
  padding-right: 18px;
  padding-left: 18px;
  color: #fff;
}
:global(.phone-app.dark .flare-page) {
  --flare-ink: #f5f5f7;
  --flare-muted: #98989f;
  --flare-surface: #08080a;
}
:global(.phone-app.dark .flare-page) {
  --flare-panel: #18181b;
}
:global(.phone-app.dark .flare-action) {
  box-shadow: none;
}
@supports not (color: color-mix(in srgb, white, black)) {
  .flare-navbar {
    border-bottom-color: rgb(127 127 127 / 18%);
  }
  .flare-photo-slot {
    background: rgb(127 127 127 / 18%);
  }
  .flare-photo-grid :deep(.flare-photo-add) {
    border-color: rgb(127 127 127 / 44%);
    background: var(--flare-surface);
  }
  .flare-choice-sheet__grabber {
    background: rgb(127 127 127 / 38%);
  }
}
</style>
