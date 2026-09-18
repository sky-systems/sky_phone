<script setup lang="ts">
import {
  SkyAppPage,
  SkyButton,
  SkyCard,
  SkyDialog,
  SkyDialogButton,
  SkyDropdown,
  SkyEmptyState,
  SkyField,
  SkyIcon,
  SkyLink,
  SkyList,
  SkyListItem,
  SkyNavbar,
  SkyPillNavigation,
  SkyScrollArea,
  SkySpinner,
  SkySearchbar,
  SkySegmented,
  SkySegmentedButton,
  SkyNotification,
} from '@/ui'
import {
  BriefcaseBusiness,
  Building2,
  Camera,
  CalendarDays,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  FileText,
  House,
  ImagePlus,
  Images,
  LayoutGrid,
  Megaphone,
  Newspaper,
  Pencil,
  Plus,
  Search,
  Trash2,
  UserRound,
  X,
} from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import { useWeazelNewsStore } from '@/stores/weazel-news'
import type {
  WeazelNewsArticle,
  WeazelNewsArticleDraft,
  WeazelNewsArticleSummary,
  WeazelNewsCategoryId,
  WeazelNewsManageStatus,
} from '@/types/weazel-news'
import { WEAZEL_NEWS_CATEGORY_IDS } from '@/types/weazel-news'

type MainTab = 'home' | 'categories' | 'search' | 'editorial'
type Screen = 'main' | 'detail' | 'composer'
type SelectedImage = { id: number; url: string }
type ComposerContext = {
  article: WeazelNewsArticle | null
  draft: WeazelNewsArticleDraft
  images: SelectedImage[]
  originTab: MainTab
}

const phone = usePhoneStore()
const news = useWeazelNewsStore()
const messageMedia = useMessageMediaStore()
const route = useRoute()
const router = useRouter()

const activeTab = ref<MainTab>('home')
const screen = ref<Screen>('main')
const detailManaged = ref(false)
const selectedCategory = ref<WeazelNewsCategoryId | null>(null)
const searchQuery = ref('')
const submittedSearchQuery = ref('')
const searchSubmitted = ref(false)
const searchPending = ref(false)
const editorialStatus = ref<WeazelNewsManageStatus>('all')
const editingArticle = ref<WeazelNewsArticle | null>(null)
const selectedImages = ref<SelectedImage[]>([])
const detailImageIndex = ref(0)
const categoryDropdownOpened = ref(false)
const categoryDropdownTarget = ref<HTMLElement | null>(null)
const statusDropdownOpened = ref(false)
const statusDropdownTarget = ref<HTMLElement | null>(null)
const deleteTarget = ref<WeazelNewsArticle | null>(null)
const deleteDialogOpened = ref(false)
const toastOpened = ref(false)
const toastText = ref('')
let toastTimer: number | undefined
let searchTimer: number | undefined

function emptyDraft(): WeazelNewsArticleDraft {
  return {
    body: '',
    category: 'news',
    imageMediaIds: [],
    status: 'draft',
    title: '',
  }
}

const draft = ref<WeazelNewsArticleDraft>(emptyDraft())

const categoryIcons = {
  business: Building2,
  events: CalendarDays,
  jobs: BriefcaseBusiness,
  news: Newspaper,
  official: Megaphone,
}

const featuredArticle = computed(() => news.publicItems[0] ?? null)
const secondaryArticles = computed(() => news.publicItems.slice(1))
const selectedArticle = computed(() => news.selected)
const maximumImages = computed(() => news.context?.maximumImages ?? 6)
const activeTabIndex = computed(() =>
  (['home', 'categories', 'search', 'editorial'] as MainTab[]).indexOf(
    activeTab.value,
  ),
)
const categoryDropdownItems = computed(() =>
  WEAZEL_NEWS_CATEGORY_IDS.map((category) => ({
    checked: draft.value.category === category,
    id: category,
    label: categoryLabel(category),
  })),
)
const statusDropdownItems = computed(() => [
  {
    checked: draft.value.status === 'draft',
    id: 'draft',
    label: t('composer.statusDraft'),
  },
  {
    checked: draft.value.status === 'published',
    id: 'published',
    label: t('composer.statusPublished'),
  },
])
const detailImages = computed<SelectedImage[]>(() => {
  const article = selectedArticle.value
  if (!article) return []
  if (article.images?.length) {
    return article.images.map((image) => ({
      id: image.mediaId,
      url: image.url,
    }))
  }
  return article.imageMediaId && article.imageUrl
    ? [{ id: article.imageMediaId, url: article.imageUrl }]
    : []
})
const activeDetailImage = computed(
  () =>
    detailImages.value[detailImageIndex.value] ?? detailImages.value[0] ?? null,
)
const knownErrors = new Set([
  'feature_disabled',
  'invalid_article',
  'invalid_draft',
  'invalid_publish',
  'invalid_request',
  'invalid_image',
  'invalid_attachment',
  'not_authorized',
  'article_not_found',
  'not_found',
  'revision_conflict',
  'rate_limited',
  'request_failed',
])
const activeError = computed(() => {
  if (screen.value !== 'main') return news.detailError
  if (activeTab.value === 'editorial') {
    return news.context ? news.managedError : news.contextError
  }
  if (activeTab.value === 'categories') return news.contextError
  return news.publicError
})
const contextualError = computed(() =>
  phone.t(
    `Apps.weazelNews.errors.${knownErrors.has(activeError.value) ? activeError.value : 'default'}`,
  ),
)
const currentSurfaceLoading = computed(() => {
  if (screen.value !== 'main') return news.detailLoading
  if (activeTab.value === 'editorial') {
    return news.context ? news.managedLoading : news.contextLoading
  }
  if (activeTab.value === 'categories') return news.contextLoading
  if (activeTab.value === 'search') {
    return searchPending.value || news.publicLoading
  }
  return news.publicLoading
})

function t(path: string, replacements: Record<string, string> = {}): string {
  return phone.t(`Apps.weazelNews.${path}`, replacements)
}

function eventValue(event: Event): string {
  return (
    event.target as HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement
  ).value
}

function categoryLabel(category: WeazelNewsCategoryId | null): string {
  return t(`categories.${category ?? 'all'}`)
}

function categoryCount(category: WeazelNewsCategoryId): number {
  return (
    news.context?.categories.find((entry) => entry.id === category)?.count ?? 0
  )
}

function formatDate(timestamp: number | null | undefined): string {
  if (!timestamp) return ''
  return new Intl.DateTimeFormat(phone.lang, {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(new Date(timestamp))
}

function statusLabel(status: WeazelNewsArticle['status']): string {
  return t(
    status === 'published'
      ? 'composer.statusPublished'
      : 'composer.statusDraft',
  )
}

function showToast(key: string): void {
  if (toastTimer !== undefined) window.clearTimeout(toastTimer)
  toastText.value = t(key)
  toastOpened.value = true
  toastTimer = window.setTimeout(() => {
    toastOpened.value = false
  }, 3000)
}

function errorKey(code: string): string {
  return `errors.${knownErrors.has(code) ? code : 'default'}`
}

async function loadHome(): Promise<void> {
  await news.loadPublic({ category: selectedCategory.value })
}

function cancelQueuedSearch(): void {
  if (searchTimer !== undefined) {
    window.clearTimeout(searchTimer)
    searchTimer = undefined
  }
  searchPending.value = false
}

async function selectTab(tab: MainTab): Promise<void> {
  if (tab !== 'search') cancelQueuedSearch()
  activeTab.value = tab
  screen.value = 'main'
  news.error = ''

  if (tab === 'home') await loadHome()
  if (tab === 'categories') await news.loadContext()
  if (tab === 'search') {
    if (searchSubmitted.value) await submitSearch()
    else await loadLatestSearch()
  }
  if (tab === 'editorial') await loadEditorial()
}

async function loadEditorial(): Promise<void> {
  if (!news.context && !(await news.loadContext())) return
  if (news.context?.canManage) await news.loadManaged(editorialStatus.value)
}

async function selectCategory(
  category: WeazelNewsCategoryId | null,
): Promise<void> {
  selectedCategory.value = category
  activeTab.value = 'home'
  screen.value = 'main'
  await loadHome()
}

async function submitSearch(): Promise<void> {
  if (searchTimer !== undefined) {
    window.clearTimeout(searchTimer)
    searchTimer = undefined
  }
  submittedSearchQuery.value = searchQuery.value.trim()
  if (!submittedSearchQuery.value) {
    await clearSearch()
    return
  }
  searchSubmitted.value = true
  searchPending.value = false
  await news.loadPublic({ search: submittedSearchQuery.value })
}

function queueSearch(event: Event): void {
  searchQuery.value = eventValue(event)
  if (searchTimer !== undefined) window.clearTimeout(searchTimer)
  if (!searchQuery.value.trim()) {
    void clearSearch()
    return
  }
  submittedSearchQuery.value = searchQuery.value.trim()
  searchSubmitted.value = true
  searchPending.value = true
  searchTimer = window.setTimeout(() => {
    searchTimer = undefined
    if (activeTab.value !== 'search') return
    void submitSearch()
  }, 250)
}

async function loadMoreSearch(): Promise<void> {
  await news.loadPublic({
    append: true,
    offset: news.publicItems.length,
    search: submittedSearchQuery.value,
  })
}

async function loadLatestSearch(): Promise<void> {
  await news.loadPublic({ search: '' })
}

async function retrySearch(): Promise<void> {
  if (searchSubmitted.value) await submitSearch()
  else await loadLatestSearch()
}

async function clearSearch(): Promise<void> {
  if (searchTimer !== undefined) {
    window.clearTimeout(searchTimer)
    searchTimer = undefined
  }
  searchQuery.value = ''
  submittedSearchQuery.value = ''
  searchSubmitted.value = false
  searchPending.value = false
  news.publicError = ''
  news.error = ''
  await loadLatestSearch()
}

async function openArticle(
  article: WeazelNewsArticleSummary,
  managed = false,
): Promise<void> {
  if (!(await news.loadArticle(article.id, managed))) {
    showToast(errorKey(news.detailError))
    return
  }
  detailImageIndex.value = 0
  detailManaged.value = managed
  screen.value = 'detail'
}

function closeDetail(): void {
  screen.value = 'main'
  detailImageIndex.value = 0
  news.selected = null
  if (activeTab.value === 'editorial' && news.context?.canManage) {
    void news.loadManaged(editorialStatus.value)
  }
}

function createArticle(): void {
  if (!news.context?.canManage) return
  editingArticle.value = null
  selectedImages.value = []
  closeComposerDropdowns()
  draft.value = emptyDraft()
  screen.value = 'composer'
}

function editArticle(article: WeazelNewsArticle): void {
  if (!news.context?.canManage) return
  editingArticle.value = article
  closeComposerDropdowns()
  selectedImages.value = article.images?.length
    ? article.images.map((image) => ({
        id: image.mediaId,
        url: image.url,
      }))
    : article.imageMediaId && article.imageUrl
      ? [{ id: article.imageMediaId, url: article.imageUrl }]
      : []
  draft.value = {
    body: article.body,
    category: article.category,
    imageMediaIds: selectedImages.value.map((image) => image.id),
    status: article.status,
    title: article.title,
  }
  screen.value = 'composer'
}

function closeComposer(): void {
  closeComposerDropdowns()
  screen.value = editingArticle.value ? 'detail' : 'main'
}

function closeComposerDropdowns(): void {
  categoryDropdownOpened.value = false
  statusDropdownOpened.value = false
}

function toggleCategoryDropdown(event: MouseEvent): void {
  if (!(event.currentTarget instanceof HTMLElement)) return
  categoryDropdownTarget.value = event.currentTarget
  statusDropdownOpened.value = false
  categoryDropdownOpened.value = !categoryDropdownOpened.value
}

function toggleStatusDropdown(event: MouseEvent): void {
  if (!(event.currentTarget instanceof HTMLElement)) return
  statusDropdownTarget.value = event.currentTarget
  categoryDropdownOpened.value = false
  statusDropdownOpened.value = !statusDropdownOpened.value
}

function updateCategory(value: string): void {
  if (WEAZEL_NEWS_CATEGORY_IDS.includes(value as WeazelNewsCategoryId)) {
    draft.value.category = value as WeazelNewsCategoryId
  }
}

function updateStatus(value: string): void {
  if (value === 'draft' || value === 'published') {
    draft.value.status = value
  }
}

function selectCategoryDropdownItem(id: string): void {
  updateCategory(id)
  closeComposerDropdowns()
}

function selectStatusDropdownItem(id: string): void {
  updateStatus(id)
  closeComposerDropdowns()
}

function selectDetailImage(index: number): void {
  if (index < 0 || index >= detailImages.value.length) return
  detailImageIndex.value = index
}

function showPreviousDetailImage(): void {
  const count = detailImages.value.length
  if (count < 2) return
  detailImageIndex.value = (detailImageIndex.value - 1 + count) % count
}

function showNextDetailImage(): void {
  const count = detailImages.value.length
  if (count < 2) return
  detailImageIndex.value = (detailImageIndex.value + 1) % count
}

let detailSwipeStartX: number | null = null

function beginDetailImageSwipe(event: TouchEvent): void {
  detailSwipeStartX = event.changedTouches.item(0)?.clientX ?? null
}

function finishDetailImageSwipe(event: TouchEvent): void {
  const endX = event.changedTouches.item(0)?.clientX
  if (detailSwipeStartX === null || endX === undefined) return
  const distance = endX - detailSwipeStartX
  detailSwipeStartX = null
  if (Math.abs(distance) < 44) return
  if (distance < 0) showNextDetailImage()
  else showPreviousDetailImage()
}

function cancelDetailImageSwipe(): void {
  detailSwipeStartX = null
}

function syncImageMediaIds(): void {
  draft.value.imageMediaIds = selectedImages.value.map((image) => image.id)
}

function openArticleMediaApp(app: 'camera' | 'photos'): void {
  const remaining = maximumImages.value - selectedImages.value.length
  if (remaining < 1) return
  messageMedia.begin(
    'weazel-news:article-images',
    'photo',
    '/apps/weazel-news?compose=1',
    app === 'photos' ? remaining : 1,
    {
      article: editingArticle.value,
      draft: {
        ...draft.value,
        imageMediaIds: [...draft.value.imageMediaIds],
      },
      images: selectedImages.value.map((image) => ({ ...image })),
      originTab: activeTab.value,
    } satisfies ComposerContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

function makePrimaryImage(index: number): void {
  if (index < 1 || index >= selectedImages.value.length) return
  const next = [...selectedImages.value]
  const [image] = next.splice(index, 1)
  if (!image) return
  next.unshift(image)
  selectedImages.value = next
  syncImageMediaIds()
}

function removeImage(index: number): void {
  selectedImages.value = selectedImages.value.filter(
    (_, imageIndex) => imageIndex !== index,
  )
  syncImageMediaIds()
}

async function saveArticle(
  status?: WeazelNewsArticleDraft['status'],
): Promise<void> {
  if (news.mutating) return

  const nextStatus = status ?? draft.value.status
  const title = draft.value.title.trim()
  const body = draft.value.body.trim()
  const titleLength = Array.from(title).length
  const bodyLength = Array.from(body).length

  if (nextStatus === 'draft' && (titleLength < 1 || bodyLength < 1)) {
    showToast('errors.invalid_draft')
    return
  }
  if (nextStatus === 'published' && (titleLength < 1 || bodyLength < 1)) {
    showToast('errors.invalid_publish')
    return
  }

  const payload: WeazelNewsArticleDraft = {
    ...draft.value,
    body,
    imageMediaIds: selectedImages.value.map((image) => image.id),
    status: nextStatus,
    title,
  }
  const wasEditing = editingArticle.value !== null
  const article = editingArticle.value
    ? await news.update(editingArticle.value, payload)
    : await news.create(payload)

  if (!article) {
    showToast(errorKey(news.error))
    return
  }

  editingArticle.value = article
  news.selected = article
  detailImageIndex.value = 0
  detailManaged.value = true
  screen.value = 'detail'
  showToast(wasEditing ? 'feedback.updated' : 'feedback.created')
}

function requestDelete(article: WeazelNewsArticle): void {
  deleteTarget.value = article
  deleteDialogOpened.value = true
}

async function confirmDelete(): Promise<void> {
  const article = deleteTarget.value
  if (!article) return
  deleteDialogOpened.value = false
  if (!(await news.remove(article))) {
    showToast(errorKey(news.error))
    return
  }
  deleteTarget.value = null
  news.selected = null
  screen.value = 'main'
  activeTab.value = 'editorial'
  showToast('feedback.deleted')
  void news.loadManaged(editorialStatus.value)
}

async function changeEditorialStatus(
  status: WeazelNewsManageStatus,
): Promise<void> {
  editorialStatus.value = status
  await news.loadManaged(status)
}

async function loadMoreManaged(): Promise<void> {
  await news.loadManaged(editorialStatus.value, {
    append: true,
    offset: news.managedItems.length,
  })
}

async function initialize(): Promise<void> {
  const selection = messageMedia.consumeMany<ComposerContext>(
    'weazel-news:article-images',
  )
  if (selection?.context) {
    editingArticle.value = selection.context.article
    selectedImages.value = [...selection.context.images]
    draft.value = {
      ...selection.context.draft,
      imageMediaIds: [...selection.context.draft.imageMediaIds],
    }
    activeTab.value = selection.context.originTab
    screen.value = 'composer'
  }
  if (selection?.media.length) {
    const knownIds = new Set(selectedImages.value.map((image) => image.id))
    for (const media of selection.media) {
      if (
        knownIds.has(media.id) ||
        selectedImages.value.length >= maximumImages.value
      ) {
        continue
      }
      knownIds.add(media.id)
      selectedImages.value.push({ id: media.id, url: media.url })
    }
    syncImageMediaIds()
  }

  await news.loadContext()
  await loadHome()
  if (route.query.compose === '1') {
    void router.replace('/apps/weazel-news')
  }
}

onMounted(() => void initialize())

onBeforeUnmount(() => {
  categoryDropdownTarget.value = null
  statusDropdownTarget.value = null
  if (toastTimer !== undefined) window.clearTimeout(toastTimer)
  if (searchTimer !== undefined) window.clearTimeout(searchTimer)
})
</script>

<template>
  <sky-app-page
    component="main"
    class="weazel-app"
    :class="{ 'weazel-app--light': !phone.isDarkMode }"
    :aria-label="t('name')"
  >
    <template v-if="screen === 'main'">
      <sky-navbar class="weazel-navbar" :center-title="true">
        <template #title>
          <span class="weazel-brand" :aria-label="t('brand')">
            <span><Newspaper :size="16" :stroke-width="2.4" /></span>
            <b>{{ t('brand') }}</b>
          </span>
        </template>
      </sky-navbar>

      <sky-scroll-area padded with-tabbar class="weazel-scroll">
        <template v-if="activeTab === 'home'">
          <header class="weazel-section-heading">
            <div>
              <span>{{ t('home.eyebrow') }}</span>
              <h1>{{ categoryLabel(selectedCategory) }}</h1>
            </div>
            <button
              v-if="selectedCategory"
              type="button"
              class="weazel-filter-clear"
              :aria-label="t('categories.all')"
              @click="selectCategory(null)"
            >
              <X :size="15" />
            </button>
          </header>

          <div v-if="currentSurfaceLoading" class="weazel-state">
            <sky-spinner class="text-[#d71920]" />
            <span>{{ t('states.loading') }}</span>
          </div>
          <div v-else-if="activeError" class="weazel-state">
            <Newspaper :size="34" />
            <strong>{{ t('states.errorTitle') }}</strong>
            <span>{{ contextualError }}</span>
            <sky-button rounded small @click="loadHome">{{
              t('retry')
            }}</sky-button>
          </div>
          <div v-else-if="!featuredArticle" class="weazel-state">
            <FileText :size="34" />
            <strong>{{ t('states.emptyTitle') }}</strong>
            <span>{{ t('states.emptyBody') }}</span>
          </div>
          <section v-else :aria-label="t('accessibility.articleList')">
            <sky-card :content-wrap="false" class="weazel-feature-card">
              <button
                type="button"
                :aria-label="
                  t('accessibility.openArticle', {
                    title: featuredArticle.title,
                  })
                "
                @click="openArticle(featuredArticle)"
              >
                <img
                  v-if="featuredArticle.imageUrl"
                  :src="featuredArticle.imageUrl"
                  :alt="t('article.coverAlt', { title: featuredArticle.title })"
                />
                <div v-else class="weazel-feature-placeholder">
                  <span>W</span>
                  <Newspaper :size="34" />
                </div>
                <div class="weazel-feature-copy">
                  <span>{{ categoryLabel(featuredArticle.category) }}</span>
                  <h2>{{ featuredArticle.title }}</h2>
                  <p>{{ featuredArticle.excerpt }}</p>
                  <small>
                    {{
                      t('article.byline', {
                        author: featuredArticle.authorName,
                      })
                    }}
                    · {{ formatDate(featuredArticle.publishedAt) }}
                  </small>
                </div>
              </button>
            </sky-card>

            <div class="weazel-latest-title">
              <span>{{ t('home.latest') }}</span>
              <i></i>
            </div>
            <div class="weazel-card-list">
              <sky-card
                v-for="article in secondaryArticles"
                :key="article.id"
                :content-wrap="false"
                class="weazel-article-card"
              >
                <button
                  type="button"
                  :aria-label="
                    t('accessibility.openArticle', { title: article.title })
                  "
                  @click="openArticle(article)"
                >
                  <div class="weazel-card-copy">
                    <span>{{ categoryLabel(article.category) }}</span>
                    <h2>{{ article.title }}</h2>
                    <p>{{ article.excerpt }}</p>
                    <small>{{ formatDate(article.publishedAt) }}</small>
                  </div>
                  <img
                    v-if="article.imageUrl"
                    :src="article.imageUrl"
                    :alt="t('article.coverAlt', { title: article.title })"
                  />
                  <span v-else class="weazel-card-mark">W</span>
                </button>
              </sky-card>
            </div>
            <sky-button
              v-if="news.publicHasMore"
              class="weazel-load-more"
              tonal
              rounded
              @click="
                news.loadPublic({
                  append: true,
                  category: selectedCategory,
                  offset: news.publicItems.length,
                })
              "
            >
              {{ t('loadMore') }}
            </sky-button>
          </section>
        </template>

        <template v-else-if="activeTab === 'categories'">
          <header class="weazel-section-heading">
            <div>
              <span>{{ t('name') }}</span>
              <h1>{{ t('categories.title') }}</h1>
              <p>{{ t('categories.subtitle') }}</p>
            </div>
          </header>
          <sky-list
            inset
            strong
            class="weazel-category-list"
            :aria-label="t('accessibility.categoryList')"
          >
            <sky-list-item
              v-for="category in WEAZEL_NEWS_CATEGORY_IDS"
              :key="category"
              link
              link-component="button"
              :link-props="{ type: 'button' }"
              :title="categoryLabel(category)"
              :after="String(categoryCount(category))"
              :aria-label="
                t('accessibility.openCategory', {
                  category: categoryLabel(category),
                })
              "
              @click="selectCategory(category)"
            >
              <template #media>
                <span class="weazel-category-icon">
                  <component :is="categoryIcons[category]" :size="19" />
                </span>
              </template>
            </sky-list-item>
          </sky-list>
        </template>

        <template v-else-if="activeTab === 'search'">
          <header class="weazel-section-heading">
            <div>
              <span>{{ t('name') }}</span>
              <h1>{{ t('search.title') }}</h1>
            </div>
          </header>
          <div class="weazel-search-shell">
            <sky-searchbar
              component="form"
              class="weazel-searchbar"
              input-id="weazel-news-search"
              :clear-button="false"
              :value="searchQuery"
              :placeholder="t('search.placeholder')"
              :aria-label="t('accessibility.search')"
              @input="queueSearch"
              @submit.prevent="submitSearch"
            />
            <button
              v-if="searchQuery"
              type="button"
              class="weazel-search-clear"
              :aria-label="t('accessibility.clearSearch')"
              @click="clearSearch"
            >
              <X :size="17" />
            </button>
          </div>
          <label class="weazel-sr-only" for="weazel-news-search">
            {{ t('accessibility.search') }}
          </label>
          <div
            v-if="currentSurfaceLoading"
            class="weazel-state weazel-state--compact"
          >
            <sky-spinner class="text-[#d71920]" />
            <span>{{ t('states.loading') }}</span>
          </div>
          <div
            v-else-if="activeError"
            class="weazel-state weazel-state--compact"
          >
            <Newspaper :size="34" />
            <strong>{{ t('states.errorTitle') }}</strong>
            <span>{{ contextualError }}</span>
            <sky-button rounded small @click="retrySearch">{{
              t('retry')
            }}</sky-button>
          </div>
          <sky-empty-state
            v-else-if="searchSubmitted && !news.publicItems.length"
            compact
            :title="t('search.emptyTitle')"
            :body="t('search.emptyBody')"
          >
            <template #icon><Search :size="34" /></template>
          </sky-empty-state>
          <div
            v-else-if="!news.publicItems.length"
            class="weazel-state weazel-state--compact"
          >
            <FileText :size="34" />
            <strong>{{ t('states.emptyTitle') }}</strong>
            <span>{{ t('states.emptyBody') }}</span>
          </div>
          <div v-else class="weazel-card-list">
            <sky-card
              v-for="article in news.publicItems"
              :key="article.id"
              :content-wrap="false"
              class="weazel-article-card"
            >
              <button type="button" @click="openArticle(article)">
                <div class="weazel-card-copy">
                  <span>{{ categoryLabel(article.category) }}</span>
                  <h2>{{ article.title }}</h2>
                  <p>{{ article.excerpt }}</p>
                  <small>{{ formatDate(article.publishedAt) }}</small>
                </div>
                <img v-if="article.imageUrl" :src="article.imageUrl" alt="" />
                <ChevronRight v-else :size="20" />
              </button>
            </sky-card>
          </div>
          <sky-button
            v-if="news.publicHasMore && !currentSurfaceLoading"
            class="weazel-load-more"
            tonal
            rounded
            @click="loadMoreSearch"
          >
            {{ t('loadMore') }}
          </sky-button>
        </template>

        <template v-else>
          <header class="weazel-section-heading weazel-editorial-heading">
            <div>
              <span>{{ t('name') }}</span>
              <h1>{{ t('editorial.title') }}</h1>
              <p>{{ t('editorial.subtitle') }}</p>
            </div>
          </header>

          <div
            v-if="currentSurfaceLoading && !news.context"
            class="weazel-state"
          >
            <sky-spinner class="text-[#d71920]" />
            <span>{{ t('states.loading') }}</span>
          </div>
          <div v-else-if="activeError && !news.context" class="weazel-state">
            <Newspaper :size="34" />
            <strong>{{ t('states.errorTitle') }}</strong>
            <span>{{ contextualError }}</span>
            <sky-button rounded small @click="loadEditorial">{{
              t('retry')
            }}</sky-button>
          </div>
          <div v-else-if="!news.context?.canManage" class="weazel-state">
            <UserRound :size="36" />
            <strong>{{ t('states.readOnlyTitle') }}</strong>
            <span>{{ t('states.readOnlyBody') }}</span>
          </div>
          <template v-else>
            <sky-card :content-wrap="false" class="weazel-access-card">
              <div class="weazel-access-content">
                <span class="weazel-access-avatar">W</span>
                <div class="weazel-access-identity">
                  <strong>{{ news.context.jobLabel }}</strong>
                  <small>{{
                    t('editorial.jobAccess', {
                      job:
                        news.context.jobGradeLabel ||
                        news.context.jobLabel ||
                        t('name'),
                    })
                  }}</small>
                </div>
                <sky-button
                  rounded
                  small
                  class="weazel-new-article"
                  :aria-label="t('accessibility.newArticle')"
                  @click="createArticle"
                >
                  <Plus :size="17" /> {{ t('editorial.newArticle') }}
                </sky-button>
              </div>
            </sky-card>

            <sky-segmented strong rounded class="weazel-editorial-filter">
              <sky-segmented-button
                v-for="status in [
                  'all',
                  'published',
                  'draft',
                ] as WeazelNewsManageStatus[]"
                :key="status"
                :active="editorialStatus === status"
                @click="changeEditorialStatus(status)"
              >
                {{ t(`editorial.${status === 'draft' ? 'drafts' : status}`) }}
              </sky-segmented-button>
            </sky-segmented>

            <div
              v-if="currentSurfaceLoading"
              class="weazel-state weazel-state--compact"
            >
              <sky-spinner class="text-[#d71920]" />
            </div>
            <div
              v-else-if="activeError"
              class="weazel-state weazel-state--compact"
            >
              <Newspaper :size="34" />
              <strong>{{ t('states.errorTitle') }}</strong>
              <span>{{ contextualError }}</span>
              <sky-button rounded small @click="loadEditorial">{{
                t('retry')
              }}</sky-button>
            </div>
            <div
              v-else-if="!news.managedItems.length"
              class="weazel-state weazel-state--compact"
            >
              <FileText :size="34" />
              <strong>{{ t('states.noManagedTitle') }}</strong>
              <span>{{ t('states.noManagedBody') }}</span>
            </div>
            <sky-list
              v-else
              inset
              strong
              class="weazel-editorial-list"
              :aria-label="t('accessibility.editorialList')"
            >
              <sky-list-item
                v-for="article in news.managedItems"
                :key="article.id"
                link
                link-component="button"
                :link-props="{ type: 'button' }"
                content-class="weazel-editorial-item__content"
                inner-class="weazel-editorial-item__inner"
                title-wrap-class="weazel-editorial-item__title-wrap"
                :title="article.title"
                :subtitle="`${categoryLabel(article.category)} · ${formatDate(article.updatedAt)}`"
                @click="openArticle(article, true)"
              >
                <template #media>
                  <span class="weazel-editorial-thumb">
                    <img
                      v-if="article.imageUrl"
                      :src="article.imageUrl"
                      alt=""
                    />
                    <FileText v-else :size="18" />
                  </span>
                </template>
                <template #after>
                  <span class="weazel-status" :class="`is-${article.status}`">
                    {{ statusLabel(article.status) }}
                  </span>
                </template>
              </sky-list-item>
            </sky-list>
            <sky-button
              v-if="
                news.managedItems.length &&
                news.managedHasMore &&
                !currentSurfaceLoading
              "
              class="weazel-load-more"
              tonal
              rounded
              @click="loadMoreManaged"
            >
              {{ t('loadMore') }}
            </sky-button>
          </template>
        </template>
      </sky-scroll-area>

      <sky-pill-navigation
        layout="full"
        class="weazel-navigation"
        :label="t('navigation')"
      >
        <sky-segmented
          strong
          rounded
          navigation
          :active-index="activeTabIndex"
          :aria-label="t('navigation')"
          :item-count="4"
        >
          <sky-segmented-button
            type="button"
            :active="activeTab === 'home'"
            @click="selectTab('home')"
          >
            <span class="weazel-navigation__item">
              <sky-icon :size="20"><House :size="20" /></sky-icon>
              <span>{{ t('tabs.home') }}</span>
            </span>
          </sky-segmented-button>
          <sky-segmented-button
            type="button"
            :active="activeTab === 'categories'"
            @click="selectTab('categories')"
          >
            <span class="weazel-navigation__item">
              <sky-icon :size="20"><LayoutGrid :size="20" /></sky-icon>
              <span>{{ t('tabs.categories') }}</span>
            </span>
          </sky-segmented-button>
          <sky-segmented-button
            type="button"
            :active="activeTab === 'search'"
            @click="selectTab('search')"
          >
            <span class="weazel-navigation__item">
              <sky-icon :size="20"><Search :size="20" /></sky-icon>
              <span>{{ t('tabs.search') }}</span>
            </span>
          </sky-segmented-button>
          <sky-segmented-button
            type="button"
            :active="activeTab === 'editorial'"
            @click="selectTab('editorial')"
          >
            <span class="weazel-navigation__item">
              <sky-icon :size="20"><UserRound :size="20" /></sky-icon>
              <span>{{ t('tabs.editorial') }}</span>
            </span>
          </sky-segmented-button>
        </sky-segmented>
      </sky-pill-navigation>
    </template>

    <template v-else-if="screen === 'detail' && selectedArticle">
      <sky-navbar
        class="weazel-navbar"
        :title="t('article.readMore')"
        show-back
        back-appearance="surface"
        :back-label="t('back')"
        @back="closeDetail"
      >
        <template v-if="news.context?.canManage && detailManaged" #right>
          <sky-link
            component="button"
            icon-only
            :aria-label="
              t('accessibility.editArticle', { title: selectedArticle.title })
            "
            @click="editArticle(selectedArticle)"
          >
            <Pencil :size="19" />
          </sky-link>
        </template>
      </sky-navbar>
      <sky-scroll-area as="article" class="weazel-detail-scroll">
        <div
          v-if="detailImages.length"
          class="weazel-detail-gallery"
          role="group"
          :aria-label="t('accessibility.articleImages')"
          :tabindex="detailImages.length > 1 ? 0 : undefined"
          @keydown.left.prevent="showPreviousDetailImage"
          @keydown.right.prevent="showNextDetailImage"
          @touchstart.passive="beginDetailImageSwipe"
          @touchend.passive="finishDetailImageSwipe"
          @touchcancel="cancelDetailImageSwipe"
        >
          <img
            v-if="activeDetailImage"
            :key="activeDetailImage.id"
            class="weazel-detail-cover"
            :src="activeDetailImage.url"
            :alt="
              t('article.coverAlt', {
                title: selectedArticle.title,
              })
            "
          />
          <template v-if="detailImages.length > 1">
            <sky-button
              icon-only
              rounded
              glass
              class="weazel-detail-gallery-control is-previous"
              :aria-label="t('accessibility.previousPhoto')"
              @click="showPreviousDetailImage"
            >
              <ChevronLeft :size="22" />
            </sky-button>
            <sky-button
              icon-only
              rounded
              glass
              class="weazel-detail-gallery-control is-next"
              :aria-label="t('accessibility.nextPhoto')"
              @click="showNextDetailImage"
            >
              <ChevronRight :size="22" />
            </sky-button>
            <div
              class="weazel-detail-pagination"
              role="group"
              :aria-label="t('accessibility.articleImages')"
            >
              <button
                v-for="(image, index) in detailImages"
                :key="image.id"
                type="button"
                :class="{ 'is-active': detailImageIndex === index }"
                :aria-current="detailImageIndex === index ? 'true' : undefined"
                :aria-label="
                  t('accessibility.showPhoto', {
                    current: String(index + 1),
                    total: String(detailImages.length),
                  })
                "
                @click="selectDetailImage(index)"
              >
                <span></span>
              </button>
            </div>
          </template>
          <span
            v-if="detailImages.length > 1"
            class="weazel-detail-count"
            aria-hidden="true"
          >
            <Images :size="13" /> {{ detailImageIndex + 1 }} /
            {{ detailImages.length }}
          </span>
        </div>
        <div v-else class="weazel-detail-masthead">
          <span>W</span><Newspaper :size="38" />
        </div>
        <div class="weazel-detail-copy">
          <span class="weazel-kicker">{{
            categoryLabel(selectedArticle.category)
          }}</span>
          <h1>{{ selectedArticle.title }}</h1>
          <div class="weazel-byline">
            <span>{{
              selectedArticle.authorName.charAt(0).toUpperCase()
            }}</span>
            <div>
              <strong>{{
                t('article.byline', { author: selectedArticle.authorName })
              }}</strong>
              <small>{{
                t('article.published', {
                  date: formatDate(
                    selectedArticle.publishedAt || selectedArticle.updatedAt,
                  ),
                })
              }}</small>
            </div>
          </div>
          <p>{{ selectedArticle.body }}</p>
        </div>
        <div
          v-if="news.context?.canManage && detailManaged"
          class="weazel-detail-actions"
        >
          <sky-button
            rounded
            tonal
            class="weazel-danger"
            @click="requestDelete(selectedArticle)"
          >
            <Trash2 :size="18" /> {{ t('editorial.delete') }}
          </sky-button>
        </div>
      </sky-scroll-area>
    </template>

    <template v-else-if="screen === 'composer'">
      <sky-navbar
        class="weazel-navbar"
        :title="t(editingArticle ? 'composer.editTitle' : 'composer.newTitle')"
        show-back
        back-appearance="surface"
        :back-label="t('back')"
        @back="closeComposer"
      />
      <sky-scroll-area padded class="weazel-composer-scroll">
        <section class="weazel-composer-media">
          <header class="weazel-composer-media__header">
            <div>
              <strong>{{ t('composer.photos') }}</strong>
              <span>
                {{
                  t('composer.photoCount', {
                    count: String(selectedImages.length),
                    maximum: String(maximumImages),
                  })
                }}
              </span>
            </div>
          </header>

          <div v-if="selectedImages.length" class="weazel-image-grid">
            <article
              v-for="(image, index) in selectedImages"
              :key="image.id"
              class="weazel-image-preview"
              :class="{ 'is-primary': index === 0 }"
            >
              <img :src="image.url" :alt="t('composer.coverAlt')" />
              <span v-if="index === 0" class="weazel-image-primary">
                {{ t('composer.primaryPhoto') }}
              </span>
              <div class="weazel-image-actions">
                <sky-button
                  v-if="index > 0"
                  rounded
                  small
                  tonal
                  @click="makePrimaryImage(index)"
                >
                  {{ t('composer.makePrimary') }}
                </sky-button>
                <sky-button
                  rounded
                  small
                  clear
                  class="weazel-danger"
                  :aria-label="t('accessibility.removePhoto')"
                  @click="removeImage(index)"
                >
                  <X :size="16" />
                </sky-button>
              </div>
            </article>
          </div>
          <div v-else class="weazel-image-empty">
            <ImagePlus :size="34" />
            <strong>{{ t('composer.addPhotos') }}</strong>
            <span>{{ t('composer.photoSourceHint') }}</span>
          </div>
          <div
            v-if="selectedImages.length < maximumImages"
            class="weazel-photo-source-actions"
            role="group"
            :aria-label="t('composer.addPhotos')"
          >
            <sky-button rounded tonal @click="openArticleMediaApp('photos')">
              <Images :size="19" />
              <span>{{ t('composer.choosePhotos') }}</span>
            </sky-button>
            <sky-button rounded tonal @click="openArticleMediaApp('camera')">
              <Camera :size="19" />
              <span>{{ t('composer.takePhoto') }}</span>
            </sky-button>
          </div>
        </section>

        <sky-list inset strong :dividers="false" class="weazel-composer-list">
          <sky-field
            class="weazel-composer-field"
            maxlength="160"
            :label="t('composer.title')"
            :placeholder="t('composer.titlePlaceholder')"
            :value="draft.title"
            @input="draft.title = eventValue($event)"
          />
          <sky-field
            class="weazel-composer-field"
            type="textarea"
            :rows="8"
            maxlength="12000"
            :label="t('composer.body')"
            :placeholder="t('composer.bodyPlaceholder')"
            :value="draft.body"
            @input="draft.body = eventValue($event)"
          />
          <sky-list-item
            link
            link-component="button"
            :chevron="false"
            :title="t('composer.category')"
            :aria-label="`${t('composer.category')}: ${categoryLabel(draft.category)}`"
            :link-props="{
              id: 'weazel-news-category-trigger',
              'aria-controls': 'weazel-news-category-dropdown',
              'aria-expanded': categoryDropdownOpened,
              'aria-haspopup': 'menu',
              type: 'button',
            }"
            @click="toggleCategoryDropdown"
          >
            <template #after>
              <span class="weazel-composer-select-value">
                {{ categoryLabel(draft.category) }}
                <ChevronDown :size="17" aria-hidden="true" />
              </span>
            </template>
          </sky-list-item>
          <sky-list-item
            v-if="editingArticle"
            link
            link-component="button"
            :chevron="false"
            :title="t('composer.status')"
            :aria-label="
              t('accessibility.status', {
                status: statusLabel(draft.status),
              })
            "
            :link-props="{
              id: 'weazel-news-status-trigger',
              'aria-controls': 'weazel-news-status-dropdown',
              'aria-expanded': statusDropdownOpened,
              'aria-haspopup': 'menu',
              type: 'button',
            }"
            @click="toggleStatusDropdown"
          >
            <template #after>
              <span class="weazel-composer-select-value">
                {{ statusLabel(draft.status) }}
                <ChevronDown :size="17" aria-hidden="true" />
              </span>
            </template>
          </sky-list-item>
        </sky-list>

        <div class="weazel-composer-actions">
          <template v-if="!editingArticle">
            <sky-button
              large
              rounded
              :disabled="news.mutating"
              @click="saveArticle('published')"
            >
              {{ t('composer.publish') }}
            </sky-button>
            <sky-button
              large
              rounded
              tonal
              :disabled="news.mutating"
              @click="saveArticle('draft')"
            >
              {{ t('composer.saveDraft') }}
            </sky-button>
          </template>
          <sky-button
            v-else
            large
            rounded
            :disabled="news.mutating"
            @click="saveArticle()"
          >
            {{ t('composer.saveChanges') }}
          </sky-button>
        </div>
      </sky-scroll-area>
    </template>

    <sky-dropdown
      id="weazel-news-category-dropdown"
      class="weazel-composer-dropdown sky-ui-provider"
      :class="{ 'sky-ui-provider--dark': phone.isDarkMode }"
      :items="categoryDropdownItems"
      :label="t('composer.category')"
      :opened="categoryDropdownOpened"
      placement="auto"
      :target="categoryDropdownTarget"
      @backdropclick="closeComposerDropdowns"
      @escape="closeComposerDropdowns"
      @positionerror="closeComposerDropdowns"
      @select="selectCategoryDropdownItem"
    />
    <sky-dropdown
      id="weazel-news-status-dropdown"
      class="weazel-composer-dropdown sky-ui-provider"
      :class="{ 'sky-ui-provider--dark': phone.isDarkMode }"
      :items="statusDropdownItems"
      :label="t('composer.status')"
      :opened="statusDropdownOpened"
      placement="auto"
      :target="statusDropdownTarget"
      @backdropclick="closeComposerDropdowns"
      @escape="closeComposerDropdowns"
      @positionerror="closeComposerDropdowns"
      @select="selectStatusDropdownItem"
    />

    <sky-dialog
      :opened="deleteDialogOpened"
      @backdropclick="deleteDialogOpened = false"
    >
      <template #title>{{ t('delete.title') }}</template>
      <p>{{ t('delete.body') }}</p>
      <template #buttons>
        <sky-dialog-button @click="deleteDialogOpened = false">
          {{ t('delete.cancel') }}
        </sky-dialog-button>
        <sky-dialog-button strong class="text-red-500" @click="confirmDelete">
          {{ t('delete.confirm') }}
        </sky-dialog-button>
      </template>
    </sky-dialog>

    <sky-notification
      :opened="toastOpened"
      :text="toastText"
      @click="toastOpened = false"
    />
  </sky-app-page>
</template>

<style scoped>
.weazel-app {
  --weazel-bg: #070707;
  --weazel-surface: #151515;
  --weazel-surface-strong: #1d1d1f;
  --weazel-text: #f5f5f5;
  --weazel-muted: #929296;
  --weazel-line: rgb(255 255 255 / 10%);
  position: relative;
  height: 100%;
  overflow: hidden;
  background: var(--weazel-bg) !important;
  color: var(--weazel-text);
}

.weazel-app--light {
  --weazel-bg: #f4f1ec;
  --weazel-surface: #fff;
  --weazel-surface-strong: #ebe7e1;
  --weazel-text: #121212;
  --weazel-muted: #69696e;
  --weazel-line: rgb(0 0 0 / 10%);
}

.weazel-navbar {
  color: var(--weazel-text);
}

.weazel-brand {
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--weazel-text);
  font-family: Georgia, 'Times New Roman', serif;
  font-size: 21px;
  letter-spacing: -0.8px;
}

.weazel-brand > span {
  width: 25px;
  height: 25px;
  display: grid;
  place-items: center;
  margin-right: 2px;
  border-radius: 7px;
  background: #d71920;
  color: #fff;
}

.weazel-brand b {
  font-weight: 800;
}

.weazel-sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
}

.weazel-scroll,
.weazel-detail-scroll,
.weazel-composer-scroll {
  scrollbar-width: none;
}

.weazel-detail-scroll {
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-6));
}

.weazel-scroll::-webkit-scrollbar,
.weazel-detail-scroll::-webkit-scrollbar,
.weazel-composer-scroll::-webkit-scrollbar {
  display: none;
}

.weazel-section-heading {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin: 8px 4px 18px;
}

.weazel-section-heading span,
.weazel-kicker,
.weazel-card-copy > span,
.weazel-feature-copy > span {
  color: #d71920;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.25px;
  text-transform: uppercase;
}

.weazel-section-heading h1 {
  margin: 2px 0 0;
  font-family: Georgia, 'Times New Roman', serif;
  font-size: 30px;
  line-height: 1.05;
  letter-spacing: -1.1px;
}

.weazel-section-heading p {
  max-width: 300px;
  margin: 7px 0 0;
  color: var(--weazel-muted);
  font-size: 12px;
  line-height: 1.4;
}

.weazel-filter-clear {
  width: 28px;
  height: 28px;
  display: grid;
  place-items: center;
  border: 0;
  border-radius: 50%;
  background: var(--weazel-surface-strong);
  color: var(--weazel-text);
}

.weazel-state {
  min-height: 410px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: 10px;
  padding: 28px;
  color: var(--weazel-muted);
  text-align: center;
}

.weazel-state--compact {
  min-height: 260px;
}

.weazel-state strong {
  color: var(--weazel-text);
  font-size: 18px;
}

.weazel-state span {
  max-width: 270px;
  font-size: 12px;
  line-height: 1.45;
}

.weazel-feature-card,
.weazel-article-card,
.weazel-access-card {
  overflow: hidden;
  margin: 0 0 12px !important;
  border: 1px solid var(--weazel-line);
  border-radius: 20px !important;
  background: var(--weazel-surface) !important;
  box-shadow: 0 12px 28px rgb(0 0 0 / 13%);
}

.weazel-feature-card button,
.weazel-article-card button {
  width: 100%;
  border: 0;
  padding: 0;
  background: transparent;
  color: inherit;
  text-align: left;
}

.weazel-feature-card img,
.weazel-feature-placeholder {
  width: 100%;
  height: 178px;
  display: block;
  object-fit: cover;
}

.weazel-feature-placeholder,
.weazel-detail-masthead {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  overflow: hidden;
  background:
    linear-gradient(135deg, rgb(215 25 32 / 92%), rgb(76 5 8 / 94%)), #d71920;
  color: #fff;
}

.weazel-feature-placeholder::after,
.weazel-detail-masthead::after {
  position: absolute;
  inset: -45%;
  border: 1px solid rgb(255 255 255 / 18%);
  content: '';
  transform: rotate(24deg);
}

.weazel-feature-placeholder span,
.weazel-detail-masthead span {
  font-family: Georgia, serif;
  font-size: 70px;
  font-weight: 900;
  line-height: 1;
}

.weazel-feature-copy {
  padding: 17px 18px 19px;
}

.weazel-feature-copy h2,
.weazel-card-copy h2 {
  margin: 5px 0 7px;
  font-family: Georgia, 'Times New Roman', serif;
  font-size: 22px;
  line-height: 1.08;
  letter-spacing: -0.55px;
}

.weazel-feature-copy p,
.weazel-card-copy p {
  display: -webkit-box;
  overflow: hidden;
  margin: 0 0 10px;
  color: var(--weazel-muted);
  font-size: 12px;
  line-height: 1.45;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 3;
}

.weazel-feature-copy small,
.weazel-card-copy small {
  color: var(--weazel-muted);
  font-size: 10px;
}

.weazel-latest-title {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 22px 4px 12px;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.5px;
  text-transform: uppercase;
}

.weazel-latest-title i {
  height: 1px;
  flex: 1;
  background: var(--weazel-line);
}

.weazel-article-card button {
  min-height: 132px;
  display: flex;
  align-items: stretch;
}

.weazel-card-copy {
  min-width: 0;
  flex: 1;
  padding: 15px;
}

.weazel-card-copy h2 {
  display: -webkit-box;
  overflow: hidden;
  font-size: 17px;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.weazel-card-copy p {
  -webkit-line-clamp: 2;
}

.weazel-article-card img,
.weazel-card-mark {
  width: 115px;
  min-height: 132px;
  flex: 0 0 115px;
  object-fit: cover;
}

.weazel-card-mark {
  display: grid;
  place-items: center;
  background: linear-gradient(145deg, #d71920, #510609);
  color: #fff;
  font-family: Georgia, serif;
  font-size: 48px;
  font-weight: 900;
}

.weazel-load-more {
  width: 100%;
  margin-top: 6px;
}

.weazel-category-list,
.weazel-editorial-list {
  margin-right: 0 !important;
  margin-left: 0 !important;
  overflow: hidden;
  border: 1px solid var(--weazel-line);
  border-radius: 20px !important;
  background: var(--weazel-surface) !important;
}

.weazel-category-icon {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  background: rgb(215 25 32 / 14%);
  color: #d71920;
}

.weazel-search-shell {
  position: relative;
  margin: 0 0 14px;
}

.weazel-search-clear {
  position: absolute;
  z-index: 2;
  top: 50%;
  right: 7px;
  width: var(--sky-touch-target);
  min-width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  min-height: var(--sky-touch-target);
  display: grid;
  place-items: center;
  transform: translateY(-50%);
  border: 0;
  padding: 0;
  background: transparent;
  color: var(--weazel-muted);
}

.weazel-search-clear::before {
  position: absolute;
  width: 30px;
  height: 30px;
  border-radius: var(--sky-radius-pill);
  background: var(--weazel-line);
  content: '';
}

.weazel-search-clear:focus-visible {
  outline: 2px solid var(--sky-app-accent, #007aff);
  outline-offset: -2px;
}

.weazel-search-clear > svg {
  position: relative;
}

.weazel-access-content {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  align-items: center;
  gap: 7px 8px;
  gap: 0.9cqh 1cqh;
  padding: 9px;
  padding: 1.1cqh;
}

.weazel-access-card :deep(.sky-card__content) {
  padding: 0 !important;
}

.weazel-access-identity {
  min-width: 0;
  display: flex;
  flex-direction: column;
  text-align: left;
}

.weazel-access-identity strong {
  overflow: hidden;
  font-size: 14px;
  font-size: 1.73cqh;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.weazel-access-card small {
  overflow: hidden;
  color: var(--weazel-muted);
  font-size: 10px;
  font-size: 1.24cqh;
  line-height: 1.35;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.weazel-access-avatar {
  width: 38px;
  width: 4.7cqh;
  height: 38px;
  height: 4.7cqh;
  display: grid;
  place-items: center;
  border-radius: 9px;
  border-radius: 1.1cqh;
  background: #d71920;
  color: #fff;
  font-family: Georgia, serif;
  font-size: 18px;
  font-size: 2.23cqh;
  font-weight: 900;
}

.weazel-new-article {
  width: 100%;
  min-width: 0;
  height: 34px !important;
  height: 4.2cqh !important;
  min-height: 34px;
  min-height: 4.2cqh;
  grid-column: 1 / -1;
  justify-content: center;
  font-size: 13px;
  font-size: 1.61cqh;
  white-space: nowrap;
}

.weazel-new-article :deep(svg) {
  width: 16px;
  width: 1.98cqh;
  height: 16px;
  height: 1.98cqh;
}

.weazel-editorial-filter {
  margin: 11px 0;
  margin: 1.36cqh 0;
}

.weazel-editorial-thumb {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  overflow: hidden;
  border-radius: 9px;
  background: var(--weazel-surface-strong);
  color: #d71920;
}

.weazel-editorial-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.weazel-editorial-list :deep(.weazel-editorial-item__content) {
  min-height: 68px;
  min-height: 8.42cqh;
}

.weazel-editorial-list :deep(.weazel-editorial-item__inner) {
  min-width: 0;
  padding-top: 8px;
  padding-top: 1cqh;
  padding-bottom: 8px;
  padding-bottom: 1cqh;
  text-align: left;
}

.weazel-editorial-list :deep(.weazel-editorial-item__title-wrap) {
  min-width: 0;
  align-items: center;
  gap: 6px;
  gap: 0.74cqh;
}

.weazel-editorial-list
  :deep(.weazel-editorial-item__title-wrap > div:first-child) {
  min-width: 0;
  display: -webkit-box;
  overflow: hidden;
  flex: 1;
  font-size: 14px;
  font-size: 1.73cqh;
  line-height: 1.25;
  text-align: left;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.weazel-editorial-list :deep(.weazel-editorial-item__inner > div:nth-child(2)) {
  overflow: hidden;
  color: var(--weazel-muted);
  font-size: 10px;
  font-size: 1.24cqh;
  line-height: 1.3;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.weazel-editorial-list
  :deep(.weazel-editorial-item__title-wrap > div:nth-last-child(2)) {
  padding-left: 0;
}

.weazel-editorial-list :deep(.weazel-editorial-item__title-wrap > svg) {
  width: 14px;
  width: 1.73cqh;
  margin-left: 2px;
  margin-left: 0.25cqh;
}

.weazel-status {
  padding: 3px 5px;
  padding: 0.37cqh 0.62cqh;
  border-radius: 999px;
  background: rgb(142 142 147 / 14%);
  color: var(--weazel-muted);
  font-size: 9px;
  font-size: 1.11cqh;
  font-weight: 700;
  text-transform: uppercase;
}

.weazel-status.is-published {
  background: rgb(52 199 89 / 14%);
  color: #34c759;
}

.weazel-navigation__item {
  min-width: 0;
  display: flex;
  align-items: center;
  flex-direction: column;
  justify-content: center;
  gap: 2px;
  font-size: 10px;
  line-height: 1.1;
}

.weazel-navigation__item > span:last-child {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.weazel-detail-gallery {
  position: relative;
  width: 100%;
  height: 240px;
  overflow: hidden;
  touch-action: pan-y;
}

.weazel-detail-gallery:focus-visible,
.weazel-detail-pagination button:focus-visible {
  outline: 2px solid var(--sky-app-accent, #007aff);
  outline-offset: -2px;
}

.weazel-detail-cover {
  width: 100%;
  max-width: none;
  height: 240px;
  display: block;
  object-fit: cover;
}

.weazel-detail-gallery-control {
  position: absolute;
  z-index: 2;
  top: 50%;
  width: var(--sky-touch-target) !important;
  height: var(--sky-touch-target) !important;
  min-width: var(--sky-touch-target) !important;
  min-height: var(--sky-touch-target) !important;
  transform: translateY(-50%);
  color: #fff !important;
}

.weazel-detail-gallery-control.is-previous {
  left: var(--sky-space-2);
}

.weazel-detail-gallery-control.is-next {
  right: var(--sky-space-2);
}

.weazel-detail-pagination {
  position: absolute;
  z-index: 2;
  right: 50%;
  bottom: 0;
  display: flex;
  transform: translateX(50%);
}

.weazel-detail-pagination button {
  width: var(--sky-touch-target);
  min-width: var(--sky-touch-target);
  height: var(--sky-touch-target);
  min-height: var(--sky-touch-target);
  display: grid;
  place-items: center;
  border: 0;
  padding: 0;
  background: transparent;
}

.weazel-detail-pagination span {
  width: 6px;
  height: 6px;
  border-radius: var(--sky-radius-pill);
  background: rgb(255 255 255 / 55%);
  box-shadow: 0 1px 3px rgb(0 0 0 / 45%);
}

.weazel-detail-pagination button.is-active span {
  width: 16px;
  background: #fff;
}

.weazel-detail-masthead {
  width: 100%;
  height: 240px;
}

.weazel-detail-count {
  position: absolute;
  z-index: 2;
  right: var(--sky-page-gutter);
  top: var(--sky-space-3);
  padding: 4px 9px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border-radius: var(--sky-radius-pill);
  background: rgb(0 0 0 / 58%);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  pointer-events: none;
}

.weazel-detail-copy {
  padding: 22px calc(var(--sky-page-gutter) + var(--sky-safe-area-right)) 10px;
  padding-left: calc(var(--sky-page-gutter) + var(--sky-safe-area-left));
}

.weazel-detail-copy h1 {
  margin: 7px 0 16px;
  font-family: Georgia, 'Times New Roman', serif;
  font-size: 31px;
  line-height: 1.08;
  letter-spacing: -1px;
}

.weazel-byline {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 0 17px;
  border-top: 1px solid var(--weazel-line);
  border-bottom: 1px solid var(--weazel-line);
}

.weazel-byline > span {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: #d71920;
  color: #fff;
  font-weight: 800;
}

.weazel-byline > div {
  display: flex;
  flex-direction: column;
}

.weazel-byline small {
  margin-top: 2px;
  color: var(--weazel-muted);
  font-size: 10px;
}

.weazel-detail-copy > p {
  margin: 22px 0;
  font-family: Georgia, 'Times New Roman', serif;
  font-size: 16px;
  line-height: 1.68;
  white-space: pre-wrap;
}

.weazel-detail-actions {
  display: flex;
  gap: 10px;
}

.weazel-detail-actions {
  padding-right: calc(var(--sky-page-gutter) + var(--sky-safe-area-right));
  padding-left: calc(var(--sky-page-gutter) + var(--sky-safe-area-left));
}

.weazel-detail-actions > * {
  width: 100%;
  flex: 1;
}

.weazel-danger {
  color: #ff453a !important;
}

.weazel-composer-actions {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: var(--sky-space-2);
  margin: var(--sky-space-4) 0 0;
}

.weazel-composer-actions > * {
  width: 100%;
}

.weazel-composer-media {
  box-sizing: border-box;
  width: 100%;
  margin-bottom: var(--sky-space-4);
  overflow: hidden;
  border: 1px solid var(--weazel-line);
  border-radius: var(--sky-radius-card);
  background: var(--weazel-surface);
}

.weazel-composer-media__header {
  min-height: var(--sky-touch-target);
  padding: var(--sky-space-2) var(--sky-space-3);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--sky-space-2);
  border-bottom: 1px solid var(--weazel-line);
}

.weazel-composer-media__header > div {
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.weazel-composer-media__header strong {
  color: var(--weazel-text);
  font-size: 14px;
}

.weazel-composer-media__header span {
  color: var(--weazel-muted);
  font-size: 11px;
}

.weazel-image-grid {
  padding: var(--sky-space-2);
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--sky-space-2);
}

.weazel-image-preview {
  position: relative;
  min-width: 0;
  aspect-ratio: 1;
  overflow: hidden;
  border-radius: var(--sky-radius-control);
  background: var(--weazel-surface-strong);
}

.weazel-image-preview.is-primary {
  aspect-ratio: 16 / 9;
  grid-column: 1 / -1;
}

.weazel-image-preview img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
}

.weazel-image-primary {
  position: absolute;
  top: var(--sky-space-2);
  left: var(--sky-space-2);
  padding: 4px 8px;
  border-radius: var(--sky-radius-pill);
  background: rgb(0 0 0 / 64%);
  color: #fff;
  font-size: 10px;
  font-weight: 700;
}

.weazel-image-actions {
  position: absolute;
  right: var(--sky-space-1);
  bottom: var(--sky-space-1);
  left: var(--sky-space-1);
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: var(--sky-space-1);
}

.weazel-image-actions > :first-child:not(:last-child) {
  min-width: 0;
  flex: 1;
}

.weazel-image-actions :deep(.sky-button) {
  min-height: 34px;
  border-color: rgb(255 255 255 / 14%);
  background: rgb(17 17 17 / 78%);
  color: #fff;
  backdrop-filter: blur(12px);
}

.weazel-image-empty {
  width: 100%;
  min-height: 148px;
  padding: var(--sky-space-5);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  gap: var(--sky-space-2);
  border: 0;
  background: transparent;
  color: var(--weazel-muted);
  font: inherit;
}

.weazel-image-empty strong {
  color: var(--weazel-text);
  font-size: 15px;
}

.weazel-image-empty span {
  max-width: 250px;
  font-size: 12px;
  line-height: 1.4;
  text-align: center;
}

.weazel-composer-list {
  margin: 0 0 var(--sky-space-4) !important;
  overflow: hidden;
  background: var(--weazel-surface) !important;
}

.weazel-composer-list :deep(.weazel-composer-field) {
  margin-block: 0 !important;
}

.weazel-composer-list :deep(.sky-field__textarea) {
  min-height: 180px;
  resize: vertical;
}

.weazel-composer-select-value {
  display: inline-flex;
  align-items: center;
  gap: var(--sky-space-1);
  color: var(--weazel-muted);
}

.weazel-photo-source-actions {
  padding: 0 var(--sky-space-3) var(--sky-space-3);
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--sky-space-2);
}

.weazel-photo-source-actions :deep(.sky-button) {
  width: 100%;
  min-height: var(--sky-touch-target);
  height: auto;
  padding: var(--sky-space-2) var(--sky-space-3);
  line-height: 1.2;
  white-space: normal;
}
</style>
