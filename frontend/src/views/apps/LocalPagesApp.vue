<script setup lang="ts">
import {
  ArrowLeft,
  Bookmark,
  Camera,
  ChevronLeft,
  ChevronRight,
  Compass,
  Heart,
  ImagePlus,
  Images,
  LogOut,
  Mail,
  MapPin,
  Pencil,
  Plus,
  Share2,
  Store,
  Trash2,
  UserRound,
  X,
} from 'lucide-vue-next'
import {
  SkyButton,
  SkyGlass,
  SkyNavbar,
  SkyNotification,
  SkyAppPage,
  SkyPillNavigation,
  SkySearchbar,
  SkyScrollArea,
  SkySegmented,
  SkySegmentedButton,
} from '@/ui'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import CityMarktSelect from '@/components/citymarkt/CityMarktSelect.vue'
import CityMarktGallery from '@/components/citymarkt/CityMarktGallery.vue'
import AccountLogoutDialog from '@/components/account/AccountLogoutDialog.vue'
import AppProfileAuth from '@/components/account/AppProfileAuth.vue'
import { useAccountStore } from '@/stores/account'
import { useAppAuthStore } from '@/stores/app-auth'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { useEasyShareStore } from '@/stores/easyshare'
import { useMarketplaceStore } from '@/stores/marketplace'
import { usePagesStore } from '@/stores/pages'
import { usePhoneStore } from '@/stores/phone'
import type { MarketplaceListing } from '@/types/marketplace'
import type { PagesCategory, PagesPost, PagesProfileDraft } from '@/types/pages'
import type { PhoneMedia } from '@/types/media'

type SelectedPhoto = { background: string; id: string }
type ComposeDraft = {
  body: string
  category: Exclude<PagesCategory, 'citymarkt'>
  district: string
  images: string[]
  title: string
}
type MediaContext = { draft: ComposeDraft; photos: SelectedPhoto[] }
type ProfileMediaContext = { draft: PagesProfileDraft }
type AuthMediaContext = {
  mode: 'login' | 'register'
  selectedPhoto: PhoneMedia | null
  username: string
}

type Screen = 'main' | 'detail' | 'compose'
type Tab = 'feed' | 'create' | 'profile'

const phone = usePhoneStore()
const account = useAccountStore()
const appAuth = useAppAuthStore()
const messageMedia = useMessageMediaStore()
const easyShare = useEasyShareStore()
const marketplace = useMarketplaceStore()
const pages = usePagesStore()
const route = useRoute()
const router = useRouter()
const screen = ref<Screen>('main')
const tab = ref<Tab>('feed')
const profileMode = ref<'own' | 'saved'>('own')
const selected = ref<PagesPost | null>(null)
const galleryIndex = ref(0)
const search = ref('')
const category = ref<string>('all')
const feedback = ref('')
const reactionPending = ref(false)
const reactionPulse = ref('')
const onboardingReady = ref(false)
const authMode = ref<'login' | 'register'>('login')
const authUsername = ref('')
const authProfilePhoto = ref<PhoneMedia | null>(null)
const authPending = ref(false)
const authError = ref('')
const profileEditing = ref(false)
const profilePending = ref(false)
const logoutDialogOpen = ref(false)
const profileDraft = ref<PagesProfileDraft>({
  avatarMediaId: 0,
  bio: '',
  handle: '',
})
const selectedProfilePhoto = ref<PhoneMedia | null>(null)
const pickedPhotos = ref<SelectedPhoto[]>([])
const cityMarktListing = ref<MarketplaceListing | null>(null)
const cityMarktListingId = ref<string | null>(null)
const draft = ref<ComposeDraft>({
  body: '',
  category: 'recommendation' as Exclude<PagesCategory, 'citymarkt'>,
  district: 'los_santos',
  images: [] as string[],
  title: '',
})

const categoryIds: PagesCategory[] = [
  'recommendation',
  'wanted',
  'service',
  'event',
  'place',
  'community',
  'citymarkt',
]
const composeCategoryIds = categoryIds.filter((item) => item !== 'citymarkt')
const districts = [
  'los_santos',
  'vinewood',
  'vespucci',
  'south_los_santos',
  'sandy_shores',
  'paleto_bay',
  'blaine_county',
]
const categoryOptions = computed(() => [
  { label: phone.t('Apps.localPages.allCategories'), value: 'all' },
  ...categoryIds.map((value) => ({ label: label('categories', value), value })),
])
const composeCategoryOptions = computed(() =>
  composeCategoryIds.map((value) => ({
    label: label('categories', value),
    value,
  })),
)
const districtOptions = computed(() =>
  districts.map((value) => ({
    label: phone.t(`Apps.citymarkt.districts.${value}`),
    value,
  })),
)
const displayedPosts = computed(() =>
  tab.value === 'profile'
    ? profileMode.value === 'own'
      ? pages.ownItems
      : pages.savedItems
    : pages.items,
)
const isAuthenticated = computed(() => appAuth.isSignedIn('local-pages'))
const selectedPhotos = computed(() =>
  draft.value.images
    .map((id) => pickedPhotos.value.find((photo) => photo.id === id))
    .filter((photo) => photo !== undefined),
)
const selectedImages = computed(() =>
  selectedPhotos.value.map((photo, index) => ({
    gradient: photo.background,
    media_id: photo.id,
    sort_order: index + 1,
  })),
)
const canPublish = computed(() => {
  const title = draft.value.title.trim().length
  const body = draft.value.body.trim().length
  return title >= 5 && title <= 80 && body >= 10 && body <= 1500
})
const canSaveProfile = computed(() => {
  const handle = profileDraft.value.handle.trim().toLowerCase()
  return (
    handle.length >= 3 &&
    handle.length <= 24 &&
    /^[a-z0-9][a-z0-9._]*[a-z0-9]$/.test(handle) &&
    profileDraft.value.bio.trim().length <= 160
  )
})
const tabIndex = computed(() => (tab.value === 'feed' ? 0 : 2))

let reactionPulseTimer: ReturnType<typeof setTimeout> | undefined

function triggerReactionPulse(id: string, kind: 'like' | 'save'): void {
  reactionPulse.value = ''
  void nextTick(() => {
    reactionPulse.value = `${id}:${kind}`
    if (reactionPulseTimer) clearTimeout(reactionPulseTimer)
    reactionPulseTimer = setTimeout(() => {
      reactionPulse.value = ''
      reactionPulseTimer = undefined
    }, 520)
  })
}

onBeforeUnmount(() => {
  if (reactionPulseTimer) clearTimeout(reactionPulseTimer)
})
const profileAvatarUrl = computed(
  () =>
    selectedProfilePhoto.value?.url ??
    (profileDraft.value.avatarMediaId > 0 ? pages.profile?.avatar_url : null),
)
const authUsernameValid = computed(() => {
  const username = authUsername.value.trim().toLowerCase()
  return (
    username.length >= 3 &&
    username.length <= 24 &&
    /^[a-z0-9][a-z0-9._]*[a-z0-9]$/.test(username)
  )
})

function label(group: string, value: string): string {
  return phone.t(`Apps.localPages.${group}.${value}`)
}

function relativeDate(value: number): string {
  const elapsed = Math.max(0, Date.now() - value)
  const hours = Math.max(1, Math.floor(elapsed / 3_600_000))
  return hours < 24
    ? phone.t('Apps.localPages.hoursAgo', { count: String(hours) })
    : phone.t('Apps.localPages.daysAgo', {
        count: String(Math.floor(hours / 24)),
      })
}

function showFeedback(key: string): void {
  feedback.value = phone.t(key)
  window.setTimeout(() => {
    feedback.value = ''
  }, 2600)
}

async function loadFeed(): Promise<void> {
  await pages.load({ category: category.value, search: search.value })
}

function updateSearch(event: Event): void {
  search.value = (event.target as HTMLInputElement).value
}

function clearSearch(): void {
  search.value = ''
  void loadFeed()
}

async function selectTab(next: Tab): Promise<void> {
  if (next === 'create') {
    if (!isAuthenticated.value) {
      tab.value = 'profile'
      return
    }
    if (!pages.profile) await pages.loadProfile()
    if (!pages.profile?.exists) {
      syncProfileDraft()
      profileEditing.value = true
      tab.value = 'profile'
      screen.value = 'main'
      return
    }
    screen.value = 'compose'
    return
  }
  tab.value = next
  screen.value = 'main'
  if (next === 'profile' && isAuthenticated.value) {
    await pages.loadProfile()
    ensureBrowserProfile()
    syncProfileDraft()
    profileEditing.value = !pages.profile?.exists
  }
}

function switchAuthMode(mode: 'login' | 'register'): void {
  authMode.value = mode
  authProfilePhoto.value = null
  authUsername.value =
    mode === 'register'
      ? (account.email.split('@')[0] ?? '')
          .replace(/[^a-z0-9._]/gi, '_')
          .slice(0, 24)
      : ''
  authError.value = ''
}

function authErrorMessage(error?: string): string {
  const known = [
    'invalid_profile',
    'invalid_profile_image',
    'invalid_username',
    'no_ifruit_account',
    'profile_exists',
    'profile_handle_taken',
    'profile_not_found',
    'rate_limited',
  ]
  return phone.t(
    `Apps.localPages.authErrors.${error && known.includes(error) ? error : 'default'}`,
  )
}

async function submitAuth(): Promise<void> {
  authError.value = ''
  if (!account.email) {
    authError.value = authErrorMessage('no_ifruit_account')
    return
  }
  if (!authUsernameValid.value) {
    authError.value = authErrorMessage('invalid_username')
    return
  }

  const username = authUsername.value.trim().toLowerCase()
  authPending.value = true
  const loaded = await pages.loadProfile()
  if (!loaded || !pages.profile) {
    authPending.value = false
    authError.value = authErrorMessage()
    return
  }

  if (authMode.value === 'login') {
    authPending.value = false
    if (!pages.profile.exists) {
      authError.value = authErrorMessage('profile_not_found')
      return
    }
    if (pages.profile.handle.toLowerCase() !== username) {
      authError.value = authErrorMessage('invalid_username')
      return
    }
  } else {
    if (pages.profile.exists) {
      authPending.value = false
      authError.value = authErrorMessage('profile_exists')
      return
    }
    const response = await pages.saveProfile({
      avatarMediaId: authProfilePhoto.value?.id ?? 0,
      bio: '',
      handle: username,
    })
    authPending.value = false
    if (!response.success) {
      authError.value = authErrorMessage(response.error)
      return
    }
  }

  appAuth.signIn('local-pages', account.email)
  authUsername.value = ''
  authProfilePhoto.value = null
  await pages.loadProfile()
  ensureBrowserProfile()
  syncProfileDraft()
  profileEditing.value = false
  tab.value = 'profile'
  screen.value = 'main'
  onboardingReady.value = true
}

function openAuthMedia(app: 'camera' | 'photos'): void {
  messageMedia.begin(
    'local-pages:auth-avatar',
    'photo',
    '/apps/local-pages?auth=register',
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

function syncProfileDraft(): void {
  profileDraft.value = {
    avatarMediaId: pages.profile?.avatar_media_id ?? 0,
    bio: pages.profile?.bio ?? '',
    handle: pages.profile?.handle ?? account.email.split('@')[0].toLowerCase(),
  }
  selectedProfilePhoto.value = null
}

function ensureBrowserProfile(): void {
  const onboardingScenario = new URLSearchParams(window.location.search).get(
    'testScenario',
  )
  if (
    !import.meta.env.DEV ||
    [
      'local-pages-onboarding',
      'local-pages-register',
      'citymarkt-local-pages-account-missing',
    ].includes(onboardingScenario ?? '') ||
    pages.profile
  )
    return
  const handle = account.email.split('@')[0].toLowerCase()
  pages.profile = {
    avatar_media_id: null,
    avatar_url: null,
    bio: '',
    email: account.email,
    exists: true,
    handle,
    post_count: pages.ownItems.length,
  }
}

function editProfile(): void {
  syncProfileDraft()
  profileEditing.value = true
}

function cancelProfileEdit(): void {
  if (!pages.profile?.exists) return
  syncProfileDraft()
  profileEditing.value = false
}

function openProfileMedia(app: 'camera' | 'photos'): void {
  messageMedia.begin(
    'local-pages:profile-avatar',
    'photo',
    '/apps/local-pages?profileEdit=1',
    1,
    { draft: { ...profileDraft.value } } satisfies ProfileMediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

function removeProfilePhoto(): void {
  selectedProfilePhoto.value = null
  profileDraft.value.avatarMediaId = 0
}

async function saveProfile(): Promise<void> {
  if (!canSaveProfile.value || profilePending.value) {
    showFeedback('Apps.localPages.errors.invalid_profile')
    return
  }
  profilePending.value = true
  try {
    const response = await pages.saveProfile({
      avatarMediaId:
        selectedProfilePhoto.value?.id ?? profileDraft.value.avatarMediaId,
      bio: profileDraft.value.bio.trim(),
      handle: profileDraft.value.handle.trim().toLowerCase(),
    })
    if (!response.success) {
      showFeedback(`Apps.localPages.errors.${response.error ?? 'default'}`)
      return
    }
    const loaded = await pages.loadProfile()
    ensureBrowserProfile()
    if (!pages.profile?.exists || (!loaded && !import.meta.env.DEV)) {
      showFeedback('Apps.localPages.errors.request_failed')
      return
    }
    syncProfileDraft()
    tab.value = 'profile'
    screen.value = 'main'
    profileEditing.value = false
    await loadFeed()
    showFeedback('Apps.localPages.profileSaved')
  } finally {
    profilePending.value = false
  }
}

async function openPost(post: PagesPost): Promise<void> {
  const response = await pages.get(post.id)
  if (!response.success || !response.data) return
  selected.value = response.data
  galleryIndex.value = 0
  screen.value = 'detail'
}

function togglePhoto(id: string): void {
  const index = draft.value.images.indexOf(id)
  if (index >= 0) {
    draft.value.images.splice(index, 1)
    pickedPhotos.value = pickedPhotos.value.filter((photo) => photo.id !== id)
  }
}

function openMediaApp(app: 'camera' | 'photos'): void {
  const remaining = 6 - draft.value.images.length
  if (remaining < 1) {
    showFeedback('Apps.localPages.photoLimit')
    return
  }
  messageMedia.begin(
    'local-pages:compose',
    'photo',
    '/apps/local-pages?compose=1',
    app === 'photos' ? remaining : 1,
    {
      draft: { ...draft.value, images: [...draft.value.images] },
      photos: [...pickedPhotos.value],
    } satisfies MediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

async function publish(): Promise<void> {
  if (!canPublish.value) {
    showFeedback('Apps.localPages.errors.invalid_post')
    return
  }
  const response = cityMarktListingId.value
    ? await pages.shareCityMarkt(cityMarktListingId.value)
    : await pages.create({
        body: draft.value.body.trim(),
        category: draft.value.category,
        district: draft.value.district,
        images: draft.value.images.map((id) => ({ id })),
        title: draft.value.title.trim(),
      })
  if (!response.success) {
    showFeedback(`Apps.localPages.errors.${response.error ?? 'default'}`)
    return
  }
  draft.value = {
    body: '',
    category: 'recommendation',
    district: 'los_santos',
    images: [],
    title: '',
  }
  pickedPhotos.value = []
  cityMarktListing.value = null
  cityMarktListingId.value = null
  tab.value = 'feed'
  screen.value = 'main'
  await router.replace('/apps/local-pages')
  await Promise.all([pages.load(), pages.loadProfile()])
  showFeedback('Apps.localPages.published')
}

function closeCompose(): void {
  draft.value = {
    body: '',
    category: 'recommendation',
    district: 'los_santos',
    images: [],
    title: '',
  }
  pickedPhotos.value = []
  cityMarktListing.value = null
  cityMarktListingId.value = null
  screen.value = 'main'
  void router.replace('/apps/local-pages')
}

async function react(kind: 'like' | 'save'): Promise<void> {
  if (!selected.value || !isAuthenticated.value) {
    showFeedback('Apps.localPages.errors.not_authenticated')
    return
  }
  const active =
    kind === 'like'
      ? !Boolean(selected.value.is_liked)
      : !Boolean(selected.value.is_saved)
  if (await pages.react(selected.value.id, kind, active)) {
    if (kind === 'like') {
      selected.value.like_count = Math.max(
        0,
        selected.value.like_count + (active ? 1 : -1),
      )
      selected.value.is_liked = active
    } else selected.value.is_saved = active
    if (active) triggerReactionPulse(selected.value.id, kind)
  }
}

async function reactToPost(
  post: PagesPost,
  kind: 'like' | 'save',
): Promise<void> {
  if (!isAuthenticated.value) {
    showFeedback('Apps.localPages.errors.not_authenticated')
    return
  }
  if (reactionPending.value) return
  const active =
    kind === 'like' ? !Boolean(post.is_liked) : !Boolean(post.is_saved)
  reactionPending.value = true
  try {
    const success = await pages.react(post.id, kind, active)
    if (success && active) triggerReactionPulse(post.id, kind)
  } finally {
    reactionPending.value = false
  }
}

async function removePost(): Promise<void> {
  if (!selected.value || !(await pages.remove(selected.value.id))) return
  selected.value = null
  screen.value = 'main'
  await pages.loadProfile()
  showFeedback('Apps.localPages.deleted')
}

function moveGallery(direction: number): void {
  if (!selected.value?.images.length) return
  galleryIndex.value =
    (galleryIndex.value + direction + selected.value.images.length) %
    selected.value.images.length
}

function openCityMarktListing(): void {
  if (!selected.value?.citymarkt_listing_id) return
  void router.push({
    path: '/apps/citymarkt',
    query: {
      listingId: selected.value.citymarkt_listing_id,
      transition: 'app-switch',
    },
  })
}

function sharePost(post: PagesPost): void {
  easyShare.open({
    appId: 'local-pages',
    copyText: `${post.title}\n${post.body}`,
    id: post.id,
    kind: 'post',
    link: `skyphone://local-pages/post/${post.id}`,
    subtitle: `@${post.author_name}`,
    title: post.title,
  })
}

onMounted(async () => {
  const selection = messageMedia.consumeMany<MediaContext>(
    'local-pages:compose',
  )
  const profileSelection = messageMedia.consumeMany<ProfileMediaContext>(
    'local-pages:profile-avatar',
  )
  const authSelection = messageMedia.consumeMany<AuthMediaContext>(
    'local-pages:auth-avatar',
  )
  if (selection) {
    if (selection.context) {
      draft.value = selection.context.draft
      pickedPhotos.value = selection.context.photos
    }
    for (const media of selection.media) {
      const id = String(media.id)
      if (draft.value.images.includes(id) || draft.value.images.length >= 6)
        continue
      draft.value.images.push(id)
      pickedPhotos.value.push({
        background: `url(${JSON.stringify(media.url)})`,
        id,
      })
    }
  }
  if (authSelection) {
    if (authSelection.context) {
      authMode.value = authSelection.context.mode
      authUsername.value = authSelection.context.username
      authProfilePhoto.value = authSelection.context.selectedPhoto
    }
    if (authSelection.media[0]) authProfilePhoto.value = authSelection.media[0]
  }
  if (isAuthenticated.value) {
    await pages.loadProfile()
    ensureBrowserProfile()
    if (!pages.profile?.exists) {
      syncProfileDraft()
      profileEditing.value = true
      tab.value = 'profile'
      screen.value = 'main'
    } else {
      await loadFeed()
    }
    if (profileSelection) {
      if (profileSelection.context)
        profileDraft.value = profileSelection.context.draft
      if (profileSelection.media[0]) {
        selectedProfilePhoto.value = profileSelection.media[0]
        profileDraft.value.avatarMediaId = profileSelection.media[0].id
      }
      profileEditing.value = true
      tab.value = 'profile'
      screen.value = 'main'
    }
  } else {
    tab.value = 'profile'
    screen.value = 'main'
  }
  onboardingReady.value = true
  if (route.query.compose === '1' && pages.profile?.exists) {
    const listingId = String(route.query.cityMarktListingId ?? '')
    if (listingId) {
      const response = await marketplace.get(listingId)
      if (
        response.success &&
        response.data?.is_owner &&
        ['active', 'reserved'].includes(response.data.status)
      ) {
        cityMarktListing.value = response.data
        cityMarktListingId.value = response.data.id
        draft.value = {
          body: response.data.description,
          category: 'recommendation',
          district: response.data.district ?? 'los_santos',
          images: response.data.images.map((image) => image.media_id),
          title: response.data.title,
        }
        pickedPhotos.value = response.data.images.map((image) => ({
          background: image.gradient,
          id: image.media_id,
        }))
      } else {
        showFeedback('Apps.localPages.errors.citymarkt_not_found')
      }
    }
    if (!listingId || cityMarktListingId.value) screen.value = 'compose'
  }
  const easyShareId = String(route.query.easyShareId ?? '')
  if (
    pages.profile?.exists &&
    easyShareId &&
    route.query.easyShareKind === 'post'
  ) {
    const response = await pages.get(easyShareId)
    if (response.success && response.data) {
      selected.value = response.data
      galleryIndex.value = 0
      screen.value = 'detail'
    }
  }
})
</script>

<template>
  <sky-app-page
    component="main"
    class="pages pb-safe-24"
    :class="{ 'pages--light': !phone.isDarkMode }"
  >
    <template v-if="screen === 'main'">
      <div v-if="!onboardingReady" class="pages__gate-loading">
        {{ phone.t('Common.loading') }}
      </div>
      <sky-navbar
        v-if="onboardingReady && isAuthenticated && pages.profile?.exists"
        class="pages-navbar"
        :subtitle="
          phone.t(
            tab === 'feed' ? 'Apps.localPages.eyebrow' : 'Apps.localPages.name',
          )
        "
        :title="
          phone.t(
            tab === 'feed' ? 'Apps.localPages.name' : 'Apps.localPages.profile',
          )
        "
      >
        <template v-if="tab === 'profile' && !profileEditing" #right>
          <SkyButton
            clear
            icon-only
            rounded
            small
            class="pages__navbar-logout"
            :aria-label="phone.t('Common.signOut')"
            @click="logoutDialogOpen = true"
          >
            <LogOut :size="16" />
          </SkyButton>
        </template>
      </sky-navbar>

      <SkyScrollArea
        v-if="onboardingReady"
        class="pages__content"
        :with-tabbar="isAuthenticated && Boolean(pages.profile?.exists)"
        :class="{
          'pages__content--gate': !isAuthenticated || !pages.profile?.exists,
        }"
      >
        <template v-if="tab === 'feed'">
          <sky-glass class="pages-hero-glass">
            <div class="pages__hero">
              <div>
                <small>{{ phone.t('Apps.localPages.cityPulse') }}</small
                ><strong>{{ phone.t('Apps.localPages.heroTitle') }}</strong
                ><span>{{ phone.t('Apps.localPages.heroBody') }}</span>
              </div>
              <MapPin :size="40" />
            </div>
          </sky-glass>
          <sky-searchbar
            component="form"
            class="pages-searchbar"
            :value="search"
            :placeholder="phone.t('Apps.localPages.searchPlaceholder')"
            @input="updateSearch"
            @clear="clearSearch"
            @submit.prevent="loadFeed"
          />
          <CityMarktSelect
            :model-value="category"
            :options="categoryOptions"
            @change="
              (value) => {
                category = value
                loadFeed()
              }
            "
          />
        </template>

        <template v-else>
          <section v-if="!isAuthenticated" class="pages__auth">
            <AppProfileAuth
              :mode="authMode"
              v-model:username="authUsername"
              :avatar-url="authProfilePhoto?.url ?? null"
              :body="phone.t('Apps.localPages.authBody')"
              :camera-label="phone.t('Apps.localPages.camera')"
              :email="account.email"
              :email-label="phone.t('Apps.localPages.profileEmail')"
              :error="authError"
              :eyebrow="phone.t('Apps.localPages.authEyebrow')"
              :gallery-label="phone.t('Apps.localPages.gallery')"
              :login-label="phone.t('Apps.localPages.login')"
              :max-username-length="24"
              :min-username-length="3"
              :pending="authPending"
              :register-label="phone.t('Apps.localPages.register')"
              :title="phone.t('Apps.localPages.authWelcome')"
              :username-label="phone.t('Apps.localPages.profileHandle')"
              :username-placeholder="
                phone.t('Apps.localPages.profileHandlePlaceholder')
              "
              @camera="openAuthMedia('camera')"
              @gallery="openAuthMedia('photos')"
              @submit="submitAuth"
              @update:mode="switchAuthMode"
            />
          </section>
          <template v-else>
            <section
              v-if="profileEditing || !pages.profile?.exists"
              class="pages__profile-editor"
            >
              <div class="pages__profile-editor-head">
                <span><UserRound :size="21" /></span>
                <div>
                  <strong>{{
                    phone.t(
                      pages.profile?.exists
                        ? 'Apps.localPages.editProfile'
                        : 'Apps.localPages.createProfile',
                    )
                  }}</strong>
                  <small>{{
                    phone.t('Apps.localPages.profileSetupBody')
                  }}</small>
                </div>
              </div>
              <div class="pages__profile-photo-editor">
                <span class="pages__profile-photo-preview">
                  <img
                    v-if="profileAvatarUrl"
                    :src="profileAvatarUrl"
                    :alt="phone.t('Apps.localPages.profilePhoto')"
                  />
                  <UserRound v-else :size="30" />
                </span>
                <div>
                  <strong>{{ phone.t('Apps.localPages.profilePhoto') }}</strong>
                  <small>{{
                    phone.t('Apps.localPages.profilePhotoHint')
                  }}</small>
                  <div class="pages__profile-photo-actions">
                    <sky-glass
                      ><button
                        type="button"
                        @click="openProfileMedia('camera')"
                      >
                        <Camera :size="15" />{{
                          phone.t('Apps.localPages.camera')
                        }}
                      </button></sky-glass
                    >
                    <sky-glass
                      ><button
                        type="button"
                        @click="openProfileMedia('photos')"
                      >
                        <Images :size="15" />{{
                          phone.t('Apps.localPages.gallery')
                        }}
                      </button></sky-glass
                    >
                  </div>
                  <button
                    v-if="profileAvatarUrl"
                    class="pages__profile-photo-remove"
                    type="button"
                    @click="removeProfilePhoto"
                  >
                    {{ phone.t('Apps.localPages.removeProfilePhoto') }}
                  </button>
                </div>
              </div>
              <label>
                {{ phone.t('Apps.localPages.profileEmail') }}
                <sky-glass
                  class="pages__profile-field pages__profile-field--readonly"
                >
                  <Mail :size="16" />
                  <input
                    :value="pages.profile?.email || account.email"
                    readonly
                  />
                </sky-glass>
              </label>
              <label>
                {{ phone.t('Apps.localPages.profileHandle') }}
                <span>{{ profileDraft.handle.trim().length }}/24</span>
                <sky-glass class="pages__profile-field">
                  <b>@</b>
                  <input
                    v-model="profileDraft.handle"
                    maxlength="24"
                    :placeholder="
                      phone.t('Apps.localPages.profileHandlePlaceholder')
                    "
                    autocapitalize="none"
                  />
                </sky-glass>
                <small>{{
                  phone.t('Apps.localPages.profileHandleHint')
                }}</small>
              </label>
              <label>
                {{ phone.t('Apps.localPages.profileBio') }}
                <span>{{ profileDraft.bio.trim().length }}/160</span>
                <sky-glass
                  class="pages__profile-field pages__profile-field--bio"
                >
                  <textarea
                    v-model="profileDraft.bio"
                    maxlength="160"
                    :placeholder="
                      phone.t('Apps.localPages.profileBioPlaceholder')
                    "
                  />
                </sky-glass>
              </label>
              <div class="pages__profile-actions">
                <sky-glass
                  v-if="pages.profile?.exists"
                  class="pages__profile-action"
                  ><button type="button" @click="cancelProfileEdit">
                    {{ phone.t('Apps.localPages.profileCancel') }}
                  </button></sky-glass
                >
                <sky-glass
                  class="pages__profile-action pages__profile-action--save"
                  ><button
                    type="button"
                    :disabled="!canSaveProfile || profilePending"
                    @click="saveProfile"
                  >
                    {{ phone.t('Apps.localPages.profileSave') }}
                  </button></sky-glass
                >
              </div>
            </section>
            <template v-else>
              <sky-glass class="pages-profile-glass">
                <div class="pages__profile">
                  <span
                    ><img
                      v-if="pages.profile.avatar_url"
                      :src="pages.profile.avatar_url"
                      alt=""
                    /><template v-else>{{
                      pages.profile.handle.charAt(0).toUpperCase()
                    }}</template></span
                  >
                  <div>
                    <small>{{ phone.t('Apps.localPages.localCreator') }}</small
                    ><strong>@{{ pages.profile.handle }}</strong
                    ><b
                      >{{ pages.profile.post_count }}
                      {{ phone.t('Apps.localPages.posts') }}</b
                    >
                    <p v-if="pages.profile.bio">{{ pages.profile.bio }}</p>
                  </div>
                  <button
                    class="pages__profile-edit"
                    type="button"
                    :aria-label="phone.t('Apps.localPages.editProfile')"
                    @click="editProfile"
                  >
                    <Pencil :size="15" />
                  </button>
                </div>
              </sky-glass>
              <SkySegmented
                class="pages__segmented"
                :active-index="profileMode === 'own' ? 0 : 1"
                :aria-label="phone.t('Apps.localPages.profile')"
                :item-count="2"
                rounded
                strong
              >
                <SkySegmentedButton
                  :active="profileMode === 'own'"
                  @click="profileMode = 'own'"
                >
                  {{ phone.t('Apps.localPages.myPosts') }}
                </SkySegmentedButton>
                <SkySegmentedButton
                  :active="profileMode === 'saved'"
                  @click="profileMode = 'saved'"
                >
                  {{ phone.t('Apps.localPages.saved') }}
                </SkySegmentedButton>
              </SkySegmented>
            </template>
          </template>
        </template>

        <div v-if="pages.isLoading" class="pages__empty">
          {{ phone.t('Common.loading') }}
        </div>
        <div
          v-else-if="
            tab === 'feed' ||
            (isAuthenticated && pages.profile?.exists && !profileEditing)
          "
          class="pages__feed"
        >
          <sky-glass
            v-for="post in displayedPosts"
            :key="post.id"
            class="pages-post-glass"
          >
            <article class="pages__post">
              <button
                class="pages__post-open"
                type="button"
                @click="openPost(post)"
              >
                <div class="pages__post-head">
                  <span
                    ><img
                      v-if="post.author_avatar"
                      :src="post.author_avatar"
                      alt=""
                    /><template v-else>{{
                      post.author_name.charAt(0).toUpperCase()
                    }}</template></span
                  >
                  <div>
                    <strong>@{{ post.author_name }}</strong
                    ><small
                      ><MapPin :size="10" />
                      {{
                        post.district
                          ? phone.t(`Apps.citymarkt.districts.${post.district}`)
                          : phone.t('Apps.localPages.allLosSantos')
                      }}
                      · {{ relativeDate(post.created_at) }}</small
                    >
                  </div>
                  <i>{{ label('categories', post.category) }}</i>
                </div>
                <div
                  v-if="post.image"
                  class="pages__cover"
                  :style="{ background: post.image }"
                >
                  <b v-if="post.images.length > 1"
                    >1 / {{ post.images.length }}</b
                  >
                </div>
                <h2>{{ post.title }}</h2>
                <p>{{ post.body }}</p>
              </button>
              <div class="pages__post-foot">
                <button
                  type="button"
                  class="pages__reaction"
                  :class="{
                    active: post.is_liked,
                    'is-pulsing': reactionPulse === `${post.id}:like`,
                  }"
                  :disabled="reactionPending"
                  :aria-label="phone.t('Apps.localPages.likes')"
                  @click="reactToPost(post, 'like')"
                >
                  <Heart
                    :size="15"
                    :fill="post.is_liked ? 'currentColor' : 'none'"
                  />
                  {{ post.like_count }}
                </button>
                <span v-if="post.source_type === 'citymarkt'"
                  ><Store :size="14" /> CityMarkt</span
                >
                <button
                  type="button"
                  :aria-label="phone.t('Apps.easyShare.share')"
                  @click="sharePost(post)"
                >
                  <Share2 :size="15" /> {{ phone.t('Apps.easyShare.share') }}
                </button>
                <button
                  type="button"
                  class="pages__reaction"
                  :class="{
                    active: post.is_saved,
                    'is-pulsing': reactionPulse === `${post.id}:save`,
                  }"
                  :disabled="reactionPending"
                  :aria-label="phone.t('Apps.localPages.save')"
                  @click="reactToPost(post, 'save')"
                >
                  <Bookmark
                    :size="15"
                    :fill="post.is_saved ? 'currentColor' : 'none'"
                  />
                  {{ phone.t('Apps.localPages.save') }}
                </button>
              </div>
            </article>
          </sky-glass>
          <div v-if="!displayedPosts.length" class="pages__empty">
            <Compass :size="38" /><strong>{{
              phone.t('Apps.localPages.noPosts')
            }}</strong
            ><span>{{ phone.t('Apps.localPages.noPostsBody') }}</span>
          </div>
        </div>
      </SkyScrollArea>

      <SkyPillNavigation
        v-if="isAuthenticated && pages.profile?.exists"
        class="pages-navigation"
        :label="phone.t('Apps.localPages.name')"
        layout="full"
      >
        <SkySegmented
          class="pages-navigation__segments"
          :active-index="tabIndex"
          :aria-label="phone.t('Apps.localPages.name')"
          :item-count="3"
          navigation
          strong
        >
          <SkySegmentedButton
            :active="tab === 'feed'"
            class="pages-navigation__button"
            @click="selectTab('feed')"
          >
            <Compass :size="19" />
            <small>{{ phone.t('Apps.localPages.discover') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            class="pages-navigation__button"
            @click="selectTab('create')"
          >
            <span class="pages-navigation__create"><Plus :size="19" /></span>
            <small>{{ phone.t('Apps.localPages.create') }}</small>
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="tab === 'profile'"
            class="pages-navigation__button"
            @click="selectTab('profile')"
          >
            <UserRound :size="19" />
            <small>{{ phone.t('Apps.localPages.profile') }}</small>
          </SkySegmentedButton>
        </SkySegmented>
      </SkyPillNavigation>
    </template>

    <section v-else-if="screen === 'detail' && selected" class="pages__detail">
      <header>
        <sky-glass
          component="button"
          type="button"
          class="pages__detail-control"
          @click="screen = 'main'"
        >
          <ArrowLeft :size="20" />
        </sky-glass>
        <strong>{{ phone.t('Apps.localPages.post') }}</strong>
        <sky-glass
          v-if="selected.is_owner"
          component="button"
          type="button"
          class="pages__detail-control danger"
          @click="removePost"
        >
          <Trash2 :size="18" />
        </sky-glass>
        <sky-glass
          v-else
          component="button"
          type="button"
          class="pages__detail-control pages__reaction"
          :class="{
            active: selected.is_saved,
            'is-pulsing': reactionPulse === `${selected.id}:save`,
          }"
          @click="react('save')"
        >
          <Bookmark
            :size="18"
            :fill="selected.is_saved ? 'currentColor' : 'none'"
          />
        </sky-glass>
      </header>
      <SkyScrollArea as="div" class="pages__detail-scroll">
        <div
          v-if="selected.images.length"
          class="pages__gallery"
          :style="{ background: selected.images[galleryIndex]?.gradient }"
        >
          <button v-if="selected.images.length > 1" @click="moveGallery(-1)">
            <ChevronLeft /></button
          ><button v-if="selected.images.length > 1" @click="moveGallery(1)">
            <ChevronRight /></button
          ><span>{{ galleryIndex + 1 }} / {{ selected.images.length }}</span>
        </div>
        <article>
          <div class="pages__author">
            <span
              ><img
                v-if="selected.author_avatar"
                :src="selected.author_avatar"
                alt=""
              /><template v-else>{{
                selected.author_name.charAt(0).toUpperCase()
              }}</template></span
            >
            <div>
              <strong>@{{ selected.author_name }}</strong
              ><small>{{ relativeDate(selected.created_at) }}</small>
            </div>
            <i>{{ label('categories', selected.category) }}</i>
          </div>
          <h1>{{ selected.title }}</h1>
          <p>{{ selected.body }}</p>
          <div class="pages__location">
            <MapPin :size="17" />
            <div>
              <small>{{ phone.t('Apps.localPages.location') }}</small
              ><strong>{{
                selected.district
                  ? phone.t(`Apps.citymarkt.districts.${selected.district}`)
                  : phone.t('Apps.localPages.allLosSantos')
              }}</strong>
            </div>
          </div>
          <button
            v-if="selected.source_type === 'citymarkt'"
            class="pages__market-link"
            @click="openCityMarktListing"
          >
            <Store :size="18" /><span
              ><small>{{ phone.t('Apps.localPages.sharedFrom') }}</small
              ><strong>{{
                phone.t('Apps.localPages.openCityMarkt')
              }}</strong></span
            ><b v-if="selected.citymarkt_price"
              >${{ Number(selected.citymarkt_price).toLocaleString() }}</b
            >
          </button>
        </article>
      </SkyScrollArea>
      <sky-glass class="pages__detail-actions">
        <button
          type="button"
          class="pages__reaction"
          :class="{
            active: selected.is_liked,
            'is-pulsing': reactionPulse === `${selected.id}:like`,
          }"
          @click="react('like')"
        >
          <Heart
            :size="19"
            :fill="selected.is_liked ? 'currentColor' : 'none'"
          />{{ selected.like_count }} {{ phone.t('Apps.localPages.likes') }}
        </button>
        <button type="button" @click="sharePost(selected)">
          <Share2 :size="19" />{{ phone.t('Apps.easyShare.share') }}
        </button>
        <button
          type="button"
          class="pages__reaction"
          :class="{
            active: selected.is_saved,
            'is-pulsing': reactionPulse === `${selected.id}:save`,
          }"
          @click="react('save')"
        >
          <Bookmark
            :size="19"
            :fill="selected.is_saved ? 'currentColor' : 'none'"
          />{{ phone.t('Apps.localPages.save') }}
        </button>
      </sky-glass>
    </section>

    <section
      v-else
      class="pages__compose"
      :class="{ 'pages__compose--citymarkt': cityMarktListing }"
    >
      <sky-navbar
        class="pages-create-navbar"
        center-title
        :title="
          phone.t(
            cityMarktListing
              ? 'Apps.localPages.cityMarktComposeNavTitle'
              : 'Apps.localPages.shareWithCity',
          )
        "
        :subtitle="
          phone.t(
            cityMarktListing
              ? 'Apps.localPages.categories.citymarkt'
              : 'Apps.localPages.newPost',
          )
        "
      >
        <template #left>
          <SkyButton
            clear
            icon-only
            rounded
            small
            class="pages-create-close"
            :aria-label="phone.t('Common.close')"
            @click="closeCompose"
          >
            <X :size="17" />
          </SkyButton>
        </template>
        <template #right>
          <SkyButton
            clear
            rounded
            small
            class="pages-create-publish"
            :disabled="!canPublish"
            @click="publish"
          >
            {{ phone.t('Apps.localPages.publish') }}
          </SkyButton>
        </template>
      </sky-navbar>
      <SkyScrollArea as="div" class="pages__compose-scroll">
        <sky-glass v-if="cityMarktListing" class="pages__citymarkt-source">
          <Store :size="19" />
          <span
            ><strong>{{
              phone.t('Apps.localPages.cityMarktComposeTitle')
            }}</strong
            ><small>{{
              phone.t('Apps.localPages.cityMarktComposeHint')
            }}</small></span
          >
        </sky-glass>
        <label
          >{{ phone.t('Apps.localPages.title') }}
          <span :class="{ valid: draft.title.trim().length >= 5 }"
            >{{ draft.title.trim().length }}/80 ·
            {{
              phone.t('Apps.citymarkt.minimumCharacters', { minimum: '5' })
            }}</span
          ><sky-glass class="pages__field-glass"
            ><input
              v-model="draft.title"
              maxlength="80"
              :placeholder="
                phone.t('Apps.localPages.titlePlaceholder')
              " /></sky-glass
        ></label>
        <label
          >{{ phone.t('Apps.localPages.body') }}
          <span :class="{ valid: draft.body.trim().length >= 10 }"
            >{{ draft.body.trim().length }}/1500 ·
            {{
              phone.t('Apps.citymarkt.minimumCharacters', { minimum: '10' })
            }}</span
          ><sky-glass class="pages__field-glass pages__field-glass--textarea">
            <textarea
              v-model="draft.body"
              maxlength="1500"
              :placeholder="phone.t('Apps.localPages.bodyPlaceholder')"
            /></sky-glass
        ></label>
        <div class="pages__form-row">
          <label
            >{{ phone.t('Apps.localPages.category')
            }}<CityMarktSelect
              :model-value="draft.category"
              :options="composeCategoryOptions"
              @change="
                (value) => (draft.category = value as typeof draft.category)
              " /></label
          ><label
            >{{ phone.t('Apps.localPages.location')
            }}<CityMarktSelect
              :model-value="draft.district"
              :options="districtOptions"
              @change="(value) => (draft.district = value)"
          /></label>
        </div>
        <section class="pages__photos">
          <ImagePlus :size="30" />
          <h2>{{ phone.t('Apps.citymarkt.addPhotos') }}</h2>
          <p>
            {{
              phone.t(
                cityMarktListing
                  ? 'Apps.localPages.cityMarktPhotosHint'
                  : 'Apps.citymarkt.addPhotosBody',
              )
            }}
          </p>
          <div class="pages__photo-actions">
            <sky-glass
              ><button type="button" @click="openMediaApp('photos')">
                <span><Images :size="20" /></span>
                <strong>{{ phone.t('Apps.citymarkt.chooseGallery') }}</strong>
                <small>{{ phone.t('Apps.citymarkt.chooseGalleryBody') }}</small>
              </button></sky-glass
            >
            <sky-glass
              ><button type="button" @click="openMediaApp('camera')">
                <span><Camera :size="20" /></span>
                <strong>{{ phone.t('Apps.citymarkt.takePhotos') }}</strong>
                <small>{{ phone.t('Apps.citymarkt.takePhotosBody') }}</small>
              </button></sky-glass
            >
          </div>
          <div class="pages__selected-heading">
            <strong>{{ phone.t('Apps.citymarkt.selectedPhotos') }}</strong>
            <span>{{ draft.images.length }} / 6</span>
          </div>
          <CityMarktGallery
            class="pages__selection-gallery"
            :images="selectedImages"
            :empty-title="phone.t('Apps.citymarkt.noPhoto')"
            :empty-body="phone.t('Apps.citymarkt.noPhotoOptional')"
            :previous-label="phone.t('Apps.citymarkt.previousPhoto')"
            :next-label="phone.t('Apps.citymarkt.nextPhoto')"
            :photo-label="phone.t('Apps.citymarkt.photo')"
          />
          <div v-if="selectedImages.length" class="pages__selected-strip">
            <button
              v-for="(photo, index) in selectedImages"
              :key="photo.media_id"
              type="button"
              :style="{ background: photo.gradient }"
              :aria-label="
                phone.t('Apps.citymarkt.removePhoto', {
                  number: String(index + 1),
                })
              "
              @click="togglePhoto(photo.media_id)"
            >
              <i>{{ index + 1 }}</i
              ><X :size="12" />
            </button>
          </div>
        </section>
      </SkyScrollArea>
    </section>
    <AccountLogoutDialog
      v-model:opened="logoutDialogOpen"
      app-id="local-pages"
      :app-name="phone.t('Apps.localPages.name')"
      @logged-out="tab = 'profile'"
    />
    <SkyNotification :opened="Boolean(feedback)" :text="feedback" />
  </sky-app-page>
</template>

<style scoped>
.pages {
  --yellow: #ffd63e;
  --ink: #15191d;
  --panel: #20262c;
  --muted: #9ba4aa;
  --sky-app-accent: var(--yellow);
  --sky-app-accent-soft: rgb(255 214 62 / 16%);
  position: absolute;
  inset: 0;
  padding: 47px 0 24px;
  overflow: hidden;
  background: #12171b;
  color: #f7f7f2;
  font-family: var(--sky-font-family);
}
.pages--light {
  --yellow: #8a6500;
  --panel: #f0f0eb;
  --muted: #737a7d;
  background: #fbfbf6;
  color: #171b1e;
}
.pages button,
.pages input,
.pages textarea {
  font: inherit;
  color: inherit;
}
.pages button {
  border: 0;
}
.pages__header {
  height: 65px;
  padding: 6px 14px;
  display: grid;
  grid-template-columns: 36px 1fr 36px;
  align-items: center;
}
.pages__header > button,
.pages__detail > header button {
  width: 34px;
  height: 34px;
  border-radius: 11px;
  display: grid;
  place-items: center;
  background: var(--panel);
}
.pages__header > div {
  text-align: center;
}
.pages__header span,
.pages__compose header small {
  display: block;
  color: var(--yellow);
  font-size: 8px;
  font-weight: 900;
  letter-spacing: 0.11em;
  text-transform: uppercase;
}
.pages__header h1 {
  margin: 0;
  font-size: 22px;
  line-height: 1.05;
}
.pages__content {
  height: calc(100% - 65px - 59px);
  padding: 0 13px 18px;
  overflow-y: auto;
  scrollbar-width: none;
}
.pages__hero {
  height: 105px;
  margin-bottom: 10px;
  padding: 15px;
  border-radius: 17px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: linear-gradient(125deg, #514005, #d99a00);
  color: #fff;
  box-shadow: 0 8px 22px #0003;
}
.pages__hero div {
  max-width: 210px;
}
.pages__hero small,
.pages__hero strong,
.pages__hero span {
  display: block;
}
.pages__hero small {
  font-size: 8px;
  font-weight: 900;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.pages__hero strong {
  margin: 2px 0;
  font-size: 18px;
}
.pages__hero span {
  font-size: 9px;
  line-height: 1.35;
}
.pages__hero > svg {
  color: #fff;
  filter: drop-shadow(0 4px 6px #0005);
}
.pages__search {
  height: 39px;
  margin-bottom: 7px;
  padding: 0 8px 0 10px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  gap: 7px;
  background: var(--panel);
  color: var(--muted);
}
.pages__search input {
  min-width: 0;
  flex: 1;
  border: 0;
  outline: 0;
  background: none;
  font-size: 11px;
}
.pages__search button {
  padding: 5px 8px;
  border-radius: 7px;
  background: var(--yellow);
  color: #17191a;
  font-size: 9px;
  font-weight: 800;
}
.pages__feed {
  padding-top: 10px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.pages__post {
  width: 100%;
  padding: 11px;
  border-radius: 16px;
  text-align: left;
  background: var(--panel);
  box-shadow: 0 5px 18px #0002;
}
.pages__post-head {
  display: flex;
  align-items: center;
  gap: 7px;
}
.pages__post-head > span,
.pages__profile > span,
.pages__author > span {
  width: 32px;
  height: 32px;
  flex: none;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: var(--yellow);
  color: #20231f;
  font-size: 13px;
  font-weight: 900;
}
.pages__post-head > div {
  min-width: 0;
  flex: 1;
}
.pages__post-head strong,
.pages__post-head small {
  display: block;
}
.pages__post-head strong {
  font-size: 11px;
}
.pages__post-head small {
  display: flex;
  align-items: center;
  gap: 2px;
  overflow: hidden;
  color: var(--muted);
  font-size: 8px;
  white-space: nowrap;
}
.pages__post-head i,
.pages__author i {
  padding: 4px 6px;
  border-radius: 7px;
  background: #ffd63e22;
  color: var(--yellow);
  font-size: 7px;
  font-style: normal;
  font-weight: 800;
}
.pages__cover {
  height: 138px;
  margin: 9px 0;
  border-radius: 12px;
  background-size: cover !important;
  position: relative;
}
.pages__cover > b {
  position: absolute;
  right: 7px;
  bottom: 7px;
  padding: 3px 6px;
  border-radius: 6px;
  background: #111b;
  color: white;
  font-size: 8px;
}
.pages__cover--empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 5px;
  background: linear-gradient(145deg, #262d32, #1a2024) !important;
  color: var(--muted);
  font-size: 9px;
}
.pages--light .pages__cover--empty {
  background: #e7e8e2 !important;
}
.pages__post h2 {
  margin: 0 0 3px;
  font-size: 14px;
}
.pages__post p {
  margin: 0;
  display: -webkit-box;
  overflow: hidden;
  color: var(--muted);
  font-size: 10px;
  line-height: 1.4;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}
.pages__post-foot {
  margin-top: 9px;
  padding-top: 8px;
  border-top: 1px solid #ffffff12;
  display: flex;
  align-items: center;
  gap: 13px;
  color: var(--muted);
  font-size: 9px;
}
.pages__post-foot span {
  display: flex;
  align-items: center;
  gap: 4px;
}
.pages__post-foot svg:last-child {
  margin-left: auto;
}
.pages__empty {
  min-height: 230px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  text-align: center;
  color: var(--muted);
}
.pages__empty strong {
  font-size: 15px;
}
.pages__empty span {
  max-width: 220px;
  font-size: 10px;
}
.pages__profile {
  margin: 3px 0 10px;
  padding: 15px;
  border-radius: 17px;
  display: flex;
  align-items: center;
  gap: 10px;
  background: linear-gradient(125deg, #58450b, #262b2f);
}
.pages__profile > span {
  width: 48px;
  height: 48px;
  font-size: 19px;
}
.pages__profile small,
.pages__profile strong,
.pages__profile b {
  display: block;
}
.pages__profile small {
  color: var(--yellow);
  font-size: 8px;
  text-transform: uppercase;
}
.pages__profile strong {
  font-size: 16px;
}
.pages__profile b {
  color: var(--muted);
  font-size: 9px;
}
.pages__segmented {
  --sky-segmented-strong-highlight: #fff;
  width: 100%;
  margin: 3px 0 10px;
  border: 1px solid color-mix(in srgb, currentColor 13%, transparent);
  padding: 4px;
  border-radius: var(--sky-radius-pill);
  background: color-mix(in srgb, var(--panel) 90%, transparent);
}
.pages__segmented button {
  min-height: 34px;
  font-size: 11px;
  font-weight: 750;
}
.pages__tabbar {
  position: absolute;
  right: 0;
  bottom: 22px;
  left: 0;
  height: 59px;
  padding: 5px 35px 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid #ffffff13;
  background: #151a1eea;
  backdrop-filter: blur(15px);
}
.pages--light .pages__tabbar {
  background: #fbfbf6ec;
}
.pages__tabbar button {
  width: 55px;
  padding: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  background: none;
  color: var(--muted);
  font-size: 8px;
}
.pages__tabbar button.active {
  color: var(--yellow);
}
.pages__tabbar .create span {
  width: 44px;
  height: 36px;
  margin-top: -17px;
  border-radius: 13px;
  display: grid;
  place-items: center;
  background: var(--yellow);
  color: #17191a;
  box-shadow: 0 5px 15px #0004;
}
.pages__detail,
.pages__compose {
  position: absolute;
  inset: 0;
  padding-top: 47px;
  background: #12171b;
}
.pages--light .pages__detail,
.pages--light .pages__compose {
  background: #fbfbf6;
}
.pages__detail > header,
.pages__compose > header {
  height: 53px;
  padding: 5px 13px;
  border-bottom: 1px solid #ffffff12;
  display: flex;
  align-items: center;
  gap: 8px;
}
.pages__detail > header strong {
  flex: 1;
  text-align: center;
  font-size: 13px;
}
.pages__detail > header .danger {
  color: #ff6961;
}
.pages__detail-scroll {
  height: calc(100% - 105px);
  padding-bottom: 64px;
  overflow-y: auto;
}
.pages__gallery {
  height: 235px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background-size: cover !important;
  position: relative;
}
.pages__gallery button {
  width: 32px;
  height: 38px;
  margin: 8px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  background: #101820aa;
  color: #fff;
}
.pages__gallery > span {
  position: absolute;
  right: 10px;
  bottom: 9px;
  padding: 4px 7px;
  border-radius: 7px;
  background: #101820bb;
  color: #fff;
  font-size: 8px;
}
.pages__detail article {
  padding: 13px 15px;
}
.pages__author {
  display: flex;
  align-items: center;
  gap: 8px;
}
.pages__author > div {
  flex: 1;
}
.pages__author strong,
.pages__author small {
  display: block;
}
.pages__author strong {
  font-size: 12px;
}
.pages__author small {
  color: var(--muted);
  font-size: 8px;
}
.pages__detail h1 {
  margin: 14px 0 5px;
  font-size: 20px;
}
.pages__detail article > p {
  margin: 0;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.55;
  white-space: pre-wrap;
}
.pages__location,
.pages__market-link {
  margin-top: 14px;
  padding: 10px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  gap: 8px;
  background: var(--panel);
}
.pages__location svg {
  color: var(--yellow);
}
.pages__location small,
.pages__location strong,
.pages__market-link small,
.pages__market-link strong {
  display: block;
}
.pages__location small,
.pages__market-link small {
  color: var(--muted);
  font-size: 8px;
}
.pages__location strong,
.pages__market-link strong {
  font-size: 10px;
}
.pages__market-link {
  width: 100%;
  text-align: left;
}
.pages__market-link > svg {
  color: var(--yellow);
}
.pages__market-link > span {
  flex: 1;
}
.pages__market-link > b {
  color: var(--yellow);
  font-size: 11px;
}
.pages__detail-actions {
  position: absolute;
  right: 12px;
  bottom: 30px;
  left: 12px;
  height: 43px;
  padding: 4px;
  border-radius: 14px;
  display: flex;
  gap: 5px;
  background: var(--panel);
  box-shadow: 0 7px 25px #0005;
}
.pages__detail-actions button {
  flex: 1;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  background: none;
  font-size: 10px;
  font-weight: 700;
}
.pages__detail-actions button.active {
  color: #ff6473;
}
.pages__compose > header > div {
  min-width: 0;
  flex: 1;
}
.pages__compose > header strong {
  display: block;
  font-size: 12px;
}
.pages__compose > header > button {
  padding: 7px;
  border-radius: 10px;
  background: var(--panel);
}
.pages__compose > header > button:last-child {
  display: flex;
  align-items: center;
  gap: 4px;
  background: var(--yellow);
  color: #17191a;
  font-size: 9px;
  font-weight: 800;
}
.pages__compose > header > button:disabled {
  opacity: 0.35;
}
.pages__compose-scroll {
  height: calc(100% - 53px);
  padding: 15px 14px 35px;
  overflow-y: auto;
}
.pages__compose-scroll label {
  display: block;
  margin-bottom: 14px;
  color: var(--muted);
  font-size: 10px;
  font-weight: 700;
}
.pages__compose-scroll label > span {
  float: right;
  color: #ff9c47;
  font-size: 8px;
}
.pages__compose-scroll label > span.valid {
  color: #59d889;
}
.pages__compose input,
.pages__compose textarea {
  width: 100%;
  margin-top: 5px;
  padding: 11px;
  border: 1px solid #ffffff13;
  border-radius: 11px;
  outline: 0;
  background: var(--panel);
  font-size: 12px;
}
.pages__compose textarea {
  height: 116px;
  resize: none;
  line-height: 1.45;
}
.pages__form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 7px;
}
.pages__photo-title {
  margin: 5px 0 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.pages__photo-title strong,
.pages__photo-title small {
  display: block;
}
.pages__photo-title strong,
.pages__gallery-label {
  font-size: 12px;
}
.pages__photo-title small {
  color: var(--muted);
  font-size: 8px;
}
.pages__photo-title button {
  padding: 7px 9px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  gap: 4px;
  background: var(--yellow);
  color: #17191a;
  font-size: 9px;
  font-weight: 800;
}
.pages__selected {
  margin-bottom: 12px;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
}
.pages__selected button,
.pages__picker button {
  aspect-ratio: 1;
  border-radius: 10px;
  background-size: cover !important;
  position: relative;
}
.pages__selected svg {
  position: absolute;
  top: 5px;
  right: 5px;
  padding: 3px;
  box-sizing: content-box;
  border-radius: 50%;
  background: #12171bcc;
  color: white;
}
.pages__gallery-label {
  display: block;
  margin-bottom: 7px;
}
.pages__picker {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
}
.pages__picker button {
  border: 2px solid transparent;
}
.pages__picker button.active {
  border-color: var(--yellow);
}
.pages__picker i {
  width: 19px;
  height: 19px;
  margin: 4px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: var(--yellow);
  color: #17191a;
  font-size: 9px;
  font-style: normal;
  font-weight: 900;
}
.pages__header {
  height: 64px;
  padding: 6px 16px 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.pages__header > div {
  text-align: left;
}
.pages__header .pages__brand {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--yellow);
  font-size: 10px;
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
.pages__header h1 {
  margin: 1px 0 0;
  font-size: 25px;
  line-height: 1;
}
.pages__content {
  height: calc(100% - 64px - 58px);
}
.pages__segmented button {
  min-height: 34px;
  padding: 8px 10px;
  font-size: 12px;
  font-weight: 700;
}
.pages__post-open {
  width: 100%;
  padding: 0;
  text-align: left;
  background: none;
}
.pages__post-foot {
  gap: 6px;
}
.pages__post-foot button {
  min-height: 28px;
  padding: 5px 8px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  gap: 4px;
  background: #ffffff08;
  color: var(--muted);
  font-size: 9px;
  font-weight: 800;
}
.pages__post-foot button:last-child {
  margin-left: auto;
}
.pages__post-foot button:first-child.active {
  background: #ff647318;
  color: #ff6473;
}
.pages__post-foot button:last-child.active {
  background: #ffd63e1c;
  color: var(--yellow);
}
.pages__post-foot button:disabled {
  opacity: 0.55;
}
.pages__reaction svg {
  transform-origin: center;
}
.pages__reaction.is-pulsing svg {
  animation: pages-reaction-pop 480ms cubic-bezier(0.2, 0.9, 0.25, 1.35);
}
.pages__reaction.is-pulsing {
  animation: pages-reaction-glow 480ms ease-out;
}
@keyframes pages-reaction-pop {
  0%,
  100% {
    transform: scale(1);
  }
  38% {
    transform: scale(1.48) rotate(-8deg);
  }
  68% {
    transform: scale(0.9) rotate(3deg);
  }
}
@keyframes pages-reaction-glow {
  0% {
    box-shadow: 0 0 0 0 color-mix(in srgb, currentColor 34%, transparent);
  }
  100% {
    box-shadow: 0 0 0 12px transparent;
  }
}
@media (prefers-reduced-motion: reduce) {
  .pages__reaction.is-pulsing,
  .pages__reaction.is-pulsing svg {
    animation: none;
  }
}
.pages__post-foot button svg:last-child {
  margin-left: 0;
}
.pages--light .pages__post-foot button {
  background: #00000008;
}
.pages__photos {
  margin-top: 5px;
}
.pages__photos > svg {
  color: var(--yellow);
}
.pages__photos > h2 {
  margin: 7px 0 3px;
  font-size: 19px;
}
.pages__photos > p {
  margin: 0 0 11px;
  color: var(--muted);
  font-size: 9px;
  line-height: 1.4;
}
.pages__photo-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.pages__photo-actions > button {
  min-width: 0;
  padding: 11px 9px;
  border: 1px solid #ffffff12;
  border-radius: 14px;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  text-align: left;
  background: var(--panel);
}
.pages__photo-actions > button > span {
  width: 34px;
  height: 34px;
  margin-bottom: 8px;
  border-radius: 11px;
  display: grid;
  place-items: center;
  background: #ffd63e1c;
  color: var(--yellow);
}
.pages__photo-actions strong {
  font-size: 11px;
}
.pages__photo-actions small {
  margin-top: 2px;
  color: var(--muted);
  font-size: 8px;
  line-height: 1.35;
}
.pages__selected-heading {
  margin: 15px 1px 7px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.pages__selected-heading strong {
  font-size: 12px;
}
.pages__selected-heading span {
  padding: 3px 6px;
  border-radius: 7px;
  background: var(--panel);
  color: var(--yellow);
  font-size: 9px;
  font-weight: 900;
}
.pages__selection-gallery {
  height: 142px;
  border-radius: 14px;
}
.pages__selected-strip {
  margin-top: 7px;
  display: flex;
  gap: 6px;
  overflow-x: auto;
  scrollbar-width: none;
}
.pages__selected-strip button {
  position: relative;
  width: 46px;
  height: 46px;
  flex: none;
  border: 1px solid #ffffff1d;
  border-radius: 9px;
  background-position: center !important;
  background-size: cover !important;
}
.pages__selected-strip button i {
  position: absolute;
  left: 3px;
  bottom: 3px;
  width: 15px;
  height: 15px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: var(--yellow);
  color: #17191a;
  font-size: 7px;
  font-style: normal;
  font-weight: 900;
}
.pages__selected-strip button svg {
  position: absolute;
  top: 3px;
  right: 3px;
  padding: 2px;
  box-sizing: content-box;
  border-radius: 50%;
  background: #11120fc7;
  color: #fff;
}
.pages__photo-source {
  position: absolute;
  z-index: 8;
  inset: 47px 0 0;
  padding: 14px 14px 33px;
  background: #12171b;
}
.pages--light .pages__photo-source {
  background: #fbfbf6;
}
.pages__photo-source > header {
  height: 52px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.pages__photo-source > header > div {
  min-width: 0;
  flex: 1;
}
.pages__photo-source > header small,
.pages__photo-source > header strong {
  display: block;
}
.pages__photo-source > header small {
  color: var(--yellow);
  font-size: 8px;
  font-weight: 900;
  text-transform: uppercase;
}
.pages__photo-source > header strong {
  font-size: 18px;
}
.pages__photo-source > header > span {
  padding: 4px 7px;
  border-radius: 8px;
  background: var(--panel);
  color: var(--yellow);
  font-size: 8px;
  font-weight: 900;
}
.pages__photo-source > header > button {
  width: 31px;
  height: 31px;
  padding: 0;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: var(--panel);
}
.pages__photo-picker {
  max-height: calc(100% - 58px);
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 7px;
  overflow-y: auto;
  scrollbar-width: none;
}
.pages__photo-picker button {
  position: relative;
  aspect-ratio: 1;
  border: 2px solid transparent;
  border-radius: 11px;
  background-position: center !important;
  background-size: cover !important;
}
.pages__photo-picker button.active {
  border-color: var(--yellow);
}
.pages__photo-picker i {
  width: 19px;
  height: 19px;
  margin: 5px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: var(--yellow);
  color: #17191a;
  font-size: 9px;
  font-style: normal;
  font-weight: 900;
}
.pages__capture {
  height: calc(100% - 52px);
  display: flex;
  flex-direction: column;
  align-items: center;
}
.pages__viewfinder {
  position: relative;
  width: 100%;
  min-height: 305px;
  overflow: hidden;
  border-radius: 18px;
  background-position: center !important;
  background-size: cover !important;
  box-shadow: inset 0 0 0 1px #ffffff1c;
}
.pages__viewfinder:after {
  content: '';
  position: absolute;
  inset: 0;
  background: linear-gradient(180deg, #0001, #00000038);
}
.pages__viewfinder > i {
  position: absolute;
  z-index: 2;
  width: 25px;
  height: 25px;
  border-color: #fff;
  border-style: solid;
}
.pages__viewfinder .corner-tl {
  top: 18px;
  left: 18px;
  border-width: 2px 0 0 2px;
}
.pages__viewfinder .corner-tr {
  top: 18px;
  right: 18px;
  border-width: 2px 2px 0 0;
}
.pages__viewfinder .corner-bl {
  bottom: 18px;
  left: 18px;
  border-width: 0 0 2px 2px;
}
.pages__viewfinder .corner-br {
  right: 18px;
  bottom: 18px;
  border-width: 0 2px 2px 0;
}
.pages__camera-flash {
  position: absolute;
  z-index: 4;
  inset: 0;
  background: #fff;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.12s;
}
.pages__camera-flash.active {
  opacity: 0.9;
}
.pages__capture p {
  max-width: 230px;
  margin: 9px 0;
  color: var(--muted);
  font-size: 8px;
  text-align: center;
}
.pages__shutter {
  width: 58px;
  height: 58px;
  padding: 0;
  border: 5px solid #f5f5ee;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: var(--yellow);
  color: #17191a;
  box-shadow: 0 0 0 2px #ffffff42;
}
.pages--light .pages__photo-actions > button,
.pages--light .pages__selected-strip button {
  border-color: #00000012;
}
/* Keep community content readable at the physical phone scale. */
.pages__header span,
.pages__compose header small,
.pages__header .pages__brand {
  font-size: 12px;
}
.pages__hero {
  padding: 13px 15px;
  gap: 12px;
}
.pages__hero div {
  min-width: 0;
  max-width: 205px;
}
.pages__hero small {
  font-size: 9.5px;
  line-height: 1.1;
}
.pages__hero strong {
  margin: 4px 0 3px;
  font-size: 16px;
  line-height: 1.12;
}
.pages__hero span {
  font-size: 11px;
  line-height: 1.3;
}
.pages__hero > svg {
  flex: none;
}
.pages__search input {
  font-size: 13px;
}
.pages__search button {
  font-size: 12px;
}
.pages__post-head strong {
  font-size: 13px;
}
.pages__post-head small {
  font-size: 11.5px;
}
.pages__post-head i,
.pages__author i {
  font-size: 10.5px;
}
.pages__cover > b,
.pages__gallery > span {
  font-size: 10.5px;
}
.pages__cover--empty,
.pages__empty span {
  font-size: 12px;
}
.pages__post h2 {
  font-size: 16px;
}
.pages__post p {
  font-size: 13px;
}
.pages__post-foot,
.pages__post-foot button {
  font-size: 11.5px;
}
.pages__profile small,
.pages__profile b {
  font-size: 11.5px;
}
.pages__tabbar button {
  font-size: 10.5px;
}
.pages__author strong {
  font-size: 14px;
}
.pages__author small,
.pages__location small,
.pages__market-link small {
  font-size: 11.5px;
}
.pages__detail article > p {
  font-size: 13px;
}
.pages__location strong,
.pages__market-link strong {
  font-size: 13px;
}
.pages__market-link > b {
  font-size: 14px;
}
.pages__detail-actions button {
  font-size: 12.5px;
}
.pages__compose > header strong {
  font-size: 14px;
}
.pages__compose > header > button:last-child {
  font-size: 12px;
}
.pages__compose-scroll label {
  font-size: 12px;
}
.pages__compose-scroll label > span {
  font-size: 10.5px;
}
.pages__compose input,
.pages__compose textarea {
  font-size: 13px;
}
.pages__photo-title strong,
.pages__gallery-label,
.pages__selected-heading strong {
  font-size: 14px;
}
.pages__photo-title small,
.pages__photos > p,
.pages__photo-actions small,
.pages__capture p {
  font-size: 11.5px;
}
.pages__photo-title button {
  font-size: 12px;
}
.pages__photo-actions strong {
  font-size: 13px;
}
.pages__selected-heading span,
.pages__photo-source > header small,
.pages__photo-source > header > span {
  font-size: 11px;
}
.pages__selected-strip button i,
.pages__photo-picker i {
  font-size: 10px;
}
.pages {
  --color-primary: var(--yellow);
  position: relative;
  height: 100%;
  padding: 0;
  background: #12171b !important;
}
.pages--light {
  background: #fbfbf6 !important;
}
.pages-navbar {
  --sky-safe-area-top: 46px;
  position: absolute;
  z-index: 5;
  top: 0;
  right: 0;
  left: 0;
}
.pages__content {
  position: absolute;
  inset: 0;
  height: auto;
  padding: 108px 13px 112px;
}
.pages__content--gate {
  padding: 68px 18px 34px;
}
.pages__gate-loading {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  color: var(--muted);
  font-size: 12px;
  font-weight: 750;
}
.pages-hero-glass,
.pages-profile-glass,
.pages-segmented-glass,
.pages-post-glass {
  width: 100%;
  border-radius: 17px;
}
.pages-hero-glass {
  margin-bottom: 10px;
  border-color: rgb(255 255 255 / 16%);
  background: linear-gradient(125deg, #514005, #d99a00);
  color: #fff;
  box-shadow: 0 8px 22px rgb(0 0 0 / 22%);
}
.pages-hero-glass .pages__hero small,
.pages-hero-glass .pages__hero strong,
.pages-hero-glass .pages__hero span {
  color: #fff;
}
.pages__hero {
  height: 105px;
  margin: 0;
  background: transparent;
  box-shadow: none;
}
.pages-searchbar {
  margin-bottom: 8px;
}
.pages-profile-glass {
  margin: 3px 0 10px;
}
.pages__profile {
  margin: 0;
  background: transparent;
}
.pages__segmented {
  color: inherit;
}
.pages-post-glass {
  overflow: hidden;
}
.pages__post {
  background: transparent;
  box-shadow: none;
}
.pages-navigation {
  --sky-app-accent: var(--yellow);
}
.pages-navigation__segments {
  width: 100%;
}
.pages-navigation__button {
  min-width: 0;
  gap: 2px;
  padding-inline: 2px;
}
.pages-navigation__button small {
  display: block;
  max-width: 76px;
  overflow: hidden;
  font-size: 9px;
  font-weight: 750;
  line-height: 10px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pages-navigation__create {
  display: grid;
  place-items: center;
}
.pages__navbar-logout {
  --sky-app-accent: #ff6b70;
  width: 34px;
  height: 34px;
  min-height: 34px;
  border: 0;
  padding: 0;
  background: transparent;
  box-shadow: none;
}
.pages-create-navbar {
  --sky-safe-area-top: 112px;
  position: absolute;
  z-index: 5;
  top: 0;
  right: 0;
  left: 0;
  background: transparent;
}
.pages-create-navbar :deep(.sky-navbar__left),
.pages-create-navbar :deep(.sky-navbar__right) {
  padding: 0;
  border: 0;
  background: transparent;
  box-shadow: none;
  backdrop-filter: none;
  -webkit-backdrop-filter: none;
}
.pages-create-close,
.pages-create-publish {
  width: auto;
  min-width: 44px;
  height: 30px;
  min-height: 30px;
  border: 0;
  padding: 0 8px;
  background: transparent;
  box-shadow: none;
  font-size: 10px;
  font-weight: 800;
}
.pages-create-close {
  width: 30px;
  min-width: 30px;
  padding: 0;
  color: inherit;
}
.pages-create-publish {
  --sky-app-accent: var(--yellow);
  color: var(--yellow);
}
.pages-create-publish:disabled {
  opacity: 0.38;
}
.pages__compose-scroll {
  position: absolute;
  top: 170px;
  right: 0;
  bottom: 0;
  left: 0;
  height: auto;
  padding-bottom: 35px;
}
.pages__citymarkt-source {
  margin-bottom: 14px;
  padding: 11px 12px;
  display: flex;
  align-items: center;
  gap: 9px;
  border-radius: 13px;
  color: var(--yellow);
}
.pages__citymarkt-source span {
  min-width: 0;
}
.pages__citymarkt-source strong,
.pages__citymarkt-source small {
  display: block;
}
.pages__citymarkt-source strong {
  font-size: 12px;
}
.pages__citymarkt-source small {
  margin-top: 2px;
  color: var(--muted);
  font-size: 10px;
  line-height: 1.35;
}
.pages__compose--citymarkt .pages__compose-scroll > label input,
.pages__compose--citymarkt .pages__compose-scroll > label textarea {
  pointer-events: none;
}
.pages__compose--citymarkt .pages__form-row {
  grid-template-columns: minmax(0, 1fr);
}
.pages__compose--citymarkt .pages__form-row > label:first-child,
.pages__compose--citymarkt .pages__photo-actions,
.pages__compose--citymarkt .pages__selected-strip {
  display: none;
}
.pages__field-glass {
  min-height: 44px;
  margin-top: 5px;
  border-radius: 9999px;
  overflow: hidden;
}
.pages__field-glass--textarea {
  min-height: 116px;
  border-radius: 18px;
}
.pages__field-glass > input,
.pages__field-glass > textarea {
  width: 100%;
  min-height: 44px;
  margin: 0 !important;
  padding: 11px 14px !important;
  border: 0 !important;
  outline: 0;
  background: transparent !important;
  color: inherit;
  font-size: 13px !important;
}
.pages__field-glass > textarea {
  min-height: 116px;
  resize: none;
  line-height: 1.45;
}
.pages__photo-actions > * {
  min-width: 0;
  border-radius: 14px;
}
.pages__photo-actions > * > button {
  width: 100%;
  min-height: 118px;
  padding: 11px 9px;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  text-align: left;
  background: transparent;
}
.pages__photo-actions > * > button > span {
  width: 34px;
  height: 34px;
  margin-bottom: 8px;
  border-radius: 11px;
  display: grid;
  place-items: center;
  color: var(--yellow);
}
.pages__tab-icon {
  position: relative;
  display: grid;
  place-items: center;
}
.pages__tab-icon--create {
  width: 38px;
  height: 30px;
  margin-top: -4px;
  border-radius: 10px;
  background: var(--yellow);
  color: #17191a;
  box-shadow: 0 4px 12px #00000030;
}
.pages__detail > header .pages__detail-control,
.pages__detail-actions {
  overflow: hidden;
  border-radius: 10px;
  background: var(--color-ios-dark-glass);
  box-shadow: var(--shadow-ios-dark-glass);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}
.pages--light .pages__detail-control,
.pages--light .pages__detail-actions {
  background: var(--color-ios-light-glass);
  box-shadow: var(--shadow-ios-light-glass);
}
.pages__auth {
  padding: 2px 1px 18px;
}
.pages__auth-head {
  padding: 5px 2px 15px;
  display: flex;
  align-items: flex-start;
  gap: 11px;
}
.pages__auth-head > span {
  width: 44px;
  height: 44px;
  flex: none;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: #ffd63e1b;
  color: var(--yellow);
}
.pages__auth-head div {
  min-width: 0;
}
.pages__auth-head small,
.pages__auth-head strong {
  display: block;
}
.pages__auth-head small {
  color: var(--yellow);
  font-size: 9px;
  font-weight: 900;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.pages__auth-head strong {
  margin-top: 2px;
  font-size: 18px;
}
.pages__auth-head p,
.pages__auth-copy p {
  margin: 3px 0 0;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.35;
}
.pages__auth-modes {
  margin-bottom: 14px;
  padding: 4px;
  border-radius: 11px;
  display: flex;
  background: var(--panel);
}
.pages__auth-modes button {
  min-height: 34px;
  flex: 1;
  border-radius: 8px;
  background: transparent;
  font-size: 12px;
  font-weight: 750;
}
.pages__auth-modes button.active {
  background: var(--yellow);
  color: #17191a;
}
.pages__auth-form {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.pages__auth-copy strong {
  font-size: 15px;
}
.pages__auth-form label {
  color: var(--muted);
  font-size: 12px;
  font-weight: 750;
}
.pages__auth-field {
  min-height: 44px;
  margin-top: 6px;
  padding: 0 12px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  gap: 7px;
  color: var(--yellow);
}
.pages__auth-field input {
  min-width: 0;
  flex: 1;
  padding: 11px 0;
  border: 0;
  outline: 0;
  background: transparent;
  color: #f7f7f2;
  font-size: 13px;
}
.pages--light .pages__auth-field input {
  color: #171b1e;
}
.pages__auth-field > span {
  color: var(--muted);
  font-size: 11px;
  font-weight: 600;
}
.pages__auth-field button {
  width: 30px;
  height: 30px;
  margin-right: -7px;
  display: grid;
  place-items: center;
  background: transparent;
  color: var(--muted);
}
.pages__auth-error {
  margin: -2px 2px 0;
  color: #ff6961;
  font-size: 11px;
  line-height: 1.35;
}
.pages__auth-submit {
  border-radius: 11px;
  overflow: hidden;
  color: var(--yellow);
}
.pages__auth-submit button {
  width: 100%;
  min-height: 44px;
  background: transparent;
  font-size: 13px;
  font-weight: 850;
}
.pages__auth-submit button:disabled {
  opacity: 0.45;
}
.pages__profile > div {
  min-width: 0;
  flex: 1;
}
.pages__profile p {
  margin: 7px 0 0;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.35;
}
.pages__profile-edit {
  width: 34px;
  height: 34px;
  flex: none;
  border-radius: 10px;
  display: grid;
  place-items: center;
  background: #ffffff0d;
  color: var(--yellow);
}
.pages--light .pages__profile-edit {
  background: #0000000a;
}
.pages__profile-editor {
  padding: 2px 1px 14px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.pages__profile-editor-head {
  padding: 5px 2px 2px;
  display: flex;
  align-items: center;
  gap: 10px;
}
.pages__profile-editor-head > span {
  width: 42px;
  height: 42px;
  flex: none;
  border-radius: 12px;
  display: grid;
  place-items: center;
  background: #ffd63e1b;
  color: var(--yellow);
}
.pages__profile-editor-head strong,
.pages__profile-editor-head small {
  display: block;
}
.pages__profile-editor-head strong {
  font-size: 17px;
}
.pages__profile-editor-head small {
  margin-top: 2px;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.3;
}
.pages__profile-photo-editor {
  padding: 12px;
  border: 1px solid #ffffff14;
  border-radius: 12px;
  display: flex;
  align-items: center;
  gap: 12px;
  background: #ffffff08;
}
.pages--light .pages__profile-photo-editor {
  border-color: #00000012;
  background: #00000005;
}
.pages__profile-photo-preview {
  width: 70px;
  height: 70px;
  flex: none;
  overflow: hidden;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: #ffd63e1b;
  color: var(--yellow);
}
.pages__profile-photo-preview img,
.pages__profile > span img,
.pages__post-head > span img,
.pages__author > span img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.pages__profile-photo-editor > div {
  min-width: 0;
  flex: 1;
}
.pages__profile-photo-editor strong,
.pages__profile-photo-editor small {
  display: block;
}
.pages__profile-photo-editor strong {
  font-size: 13px;
}
.pages__profile-photo-editor small {
  margin-top: 2px;
  color: var(--muted);
  font-size: 10px;
  line-height: 1.3;
}
.pages__profile-photo-actions {
  margin-top: 8px;
  display: flex;
  gap: 6px;
}
.pages__profile-photo-actions > * {
  min-width: 0;
  flex: 1;
  border-radius: 9px;
  overflow: hidden;
}
.pages__profile-photo-actions button {
  width: 100%;
  min-height: 34px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  background: transparent;
  color: var(--yellow);
  font-size: 10px;
  font-weight: 800;
}
.pages__profile-photo-remove {
  margin-top: 7px;
  padding: 0;
  background: transparent;
  color: #ff6961;
  font-size: 10px;
  font-weight: 700;
}
.pages__profile-editor label {
  display: block;
  color: var(--muted);
  font-size: 12px;
  font-weight: 750;
}
.pages__profile-editor label > span {
  float: right;
  font-size: 10px;
  font-weight: 600;
}
.pages__profile-editor label > small {
  display: block;
  margin: 5px 2px 0;
  font-size: 10px;
  font-weight: 500;
  line-height: 1.3;
}
.pages__profile-field {
  min-height: 44px;
  margin-top: 6px;
  padding: 0 12px;
  border-radius: 11px;
  display: flex;
  align-items: center;
  gap: 7px;
  color: var(--yellow);
}
.pages__profile-field input,
.pages__profile-field textarea {
  min-width: 0;
  width: 100%;
  margin: 0;
  padding: 11px 0;
  border: 0;
  outline: 0;
  background: transparent;
  color: inherit;
  font-size: 13px;
}
.pages__profile-field input,
.pages__profile-field textarea {
  color: #f7f7f2;
}
.pages--light .pages__profile-field input,
.pages--light .pages__profile-field textarea {
  color: #171b1e;
}
.pages__profile-field--readonly {
  color: var(--muted);
}
.pages__profile-field--readonly input {
  color: var(--muted);
}
.pages__profile-field--bio {
  align-items: flex-start;
}
.pages__profile-field textarea {
  min-height: 88px;
  resize: none;
  line-height: 1.4;
}
.pages__profile-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}
.pages__profile-action {
  min-width: 96px;
  border-radius: 11px;
  overflow: hidden;
}
.pages__profile-action button {
  width: 100%;
  min-height: 42px;
  padding: 0 14px;
  background: transparent;
  font-size: 12px;
  font-weight: 800;
}
.pages__profile-action--save {
  color: var(--yellow);
}
.pages__profile-action button:disabled {
  opacity: 0.4;
}
</style>
