<script setup lang="ts">
import {
  SkyActionSheet,
  SkyActionButton,
  SkyActionGroup,
  SkyBadge,
  SkyBlock,
  SkyBlockTitle,
  SkyButton,
  SkyCard,
  SkyChip,
  SkyDialog,
  SkyDialogButton,
  SkyEmptyState,
  SkySurface,
  SkyIcon,
  SkyInfiniteLoader,
  SkyLink,
  SkyList,
  SkyListCard,
  SkyField,
  SkyListItem,
  SkyMessage,
  SkyMessagebar,
  SkyMessages,
  SkyMessagesTitle,
  SkySpinner,
  SkyProgress,
  SkyRadio,
  SkySearchbar,
  SkySegmented,
  SkySegmentedButton,
  SkyAppPage,
  SkyNavbar,
  SkyPillNavigation,
  SkyScrollArea,
  SkyScrollRail,
  SkySection,
  SkySheet,
  SkyNotification,
  SkyToggle,
  SkyToolbarPane,
} from '@/ui'
import {
  BadgeCheck,
  BriefcaseBusiness,
  Building2,
  Check,
  CircleAlert,
  ClipboardList,
  Clock3,
  Compass,
  ImagePlus,
  MapPin,
  Megaphone,
  MessageCircle,
  MoreHorizontal,
  Phone,
  PhoneCall,
  Plus,
  RefreshCw,
  Send,
  Share2,
  Settings2,
  Trash2,
  UserRound,
  UsersRound,
  X,
} from 'lucide-vue-next'
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

import { useCallsStore } from '@/stores/calls'
import { useCompaniesStore } from '@/stores/companies'
import { useEasyShareStore } from '@/stores/easyshare'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { useMessagesStore } from '@/stores/messages'
import { usePhoneStore } from '@/stores/phone'
import type {
  Company,
  CompanyAvailability,
  CompanyCoordinates,
  CompanyDirectoryFilters,
  CompanyHours,
  CompanyRequestEvent,
  CompanyRequestList,
  CompanyRequestStatus,
  CompanyRequestSummary,
  CompanyService,
  CompanySummary,
} from '@/types/companies'
import type { PhoneMedia } from '@/types/media'
import { handleEnterAction } from '@/utils/keyboard'
import { nuiCall } from '@/utils/nui'

type CompaniesTab = 'directory' | 'requests' | 'work'
type CompaniesScreen = 'company' | 'manager' | 'request' | 'root'
type RequestOrigin = 'customer' | 'work'

type RequestMediaContext = {
  companyId: string
  description: string
  media: PhoneMedia[]
  serviceId: string
  subject: string
}

type ManagerProfileDraft = {
  acceptsRequests: boolean
  address: string
  description: string
  district: string
  locationLabel: string
}

type ManagerMediaContext = {
  announcement: { body: string; expiresAt: string }
  companyId: string
  coords: CompanyCoordinates | null
  hours: CompanyHours[]
  logoMedia: PhoneMedia | null
  profile: ManagerProfileDraft
  services: CompanyService[]
}

const phone = usePhoneStore()
const calls = useCallsStore()
const messages = useMessagesStore()
const companies = useCompaniesStore()
const easyShare = useEasyShareStore()
const mediaPicker = useMessageMediaStore()
const route = useRoute()
const router = useRouter()

const activeTab = ref<CompaniesTab>('directory')
const activeTabIndex = computed(() => {
  if (activeTab.value === 'requests') return 1
  if (activeTab.value === 'work') return 2
  return 0
})
const screen = ref<CompaniesScreen>('root')
const requestOrigin = ref<RequestOrigin>('customer')
const search = ref('')
const selectedCategory = ref<string | null>(null)
const requestList = ref<CompanyRequestList>('open')
const requestSheetOpened = ref(false)
const requestSheetContent = ref<HTMLElement | null>(null)
const requestServiceId = ref('')
const requestSubject = ref('')
const requestDescription = ref('')
const requestMedia = ref<PhoneMedia[]>([])
const threadDraft = ref('')
const workActionsOpened = ref(false)
const assignmentSheetOpened = ref(false)
const selectedMemberId = ref('')
const serviceLineSheetOpened = ref(false)
const serviceLineTarget = ref('')
const cancelDialogOpened = ref(false)
const conflictDialogOpened = ref(false)
const toastOpened = ref(false)
const toastText = ref('')
const profileDraft = reactive<ManagerProfileDraft>({
  acceptsRequests: false,
  address: '',
  description: '',
  district: '',
  locationLabel: '',
})
const hoursDraft = ref<CompanyHours[]>([])
const servicesDraft = ref<CompanyService[]>([])
const announcementDraft = reactive({ body: '', expiresAt: '' })
const profileCoords = ref<CompanyCoordinates | null>(null)
const selectedLogoMedia = ref<PhoneMedia | null>(null)
const requestThreadBottom = ref<HTMLElement | null>(null)

let searchTimer: ReturnType<typeof setTimeout> | undefined
let toastTimer: ReturnType<typeof setTimeout> | undefined

const directoryFilters = computed<CompanyDirectoryFilters>(() => ({
  acceptsRequests: false,
  availability: null,
  categoryId: selectedCategory.value,
  hasLocation: false,
  search: search.value.trim(),
  sort: 'relevance',
}))
const filtersActive = computed(
  () => Boolean(search.value.trim()) || Boolean(selectedCategory.value),
)
const activeCompany = computed(() => companies.company)
const workCompany = computed(() => companies.workContext?.company ?? null)
const managerLogoUrl = computed(
  () => selectedLogoMedia.value?.url ?? workCompany.value?.logoUrl ?? null,
)
const requestProgress = computed(() => {
  if (!requestServiceId.value) return 0.25
  if (!requestSubject.value.trim() || !requestDescription.value.trim())
    return 0.5
  if (!phone.device?.sim?.registered) return 0.75
  return 1
})
const canSubmitRequest = computed(
  () =>
    Boolean(requestServiceId.value) &&
    requestSubject.value.trim().length >= 3 &&
    requestDescription.value.trim().length >= 10 &&
    Boolean(phone.device?.sim?.registered) &&
    !companies.mutating,
)
const canSendThreadMessage = computed(
  () =>
    Boolean(companies.request?.actions.canReply) &&
    Boolean(threadDraft.value.trim()) &&
    !companies.mutating,
)
const canDialServiceLine = computed(
  () => Boolean(serviceLineTarget.value.trim()) && !companies.mutating,
)
const requestDockVisible = computed(() => {
  const actions = companies.request?.actions
  return Boolean(
    actions && (actions.canCall || actions.canCancel || actions.canReply),
  )
})
const navbarTitle = computed(() => {
  if (screen.value === 'company') return activeCompany.value?.name ?? ''
  if (screen.value === 'request') {
    return companies.request?.subject ?? phone.t('Apps.companies.request')
  }
  if (screen.value === 'manager') {
    return phone.t('Apps.companies.manager.title')
  }
  return phone.t('Apps.companies.name')
})
const availabilityValues: CompanyAvailability[] = [
  'available',
  'busy',
  'closed',
]
const weekdayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const

function eventValue(event: Event): string {
  if (
    !(event.target instanceof HTMLInputElement) &&
    !(event.target instanceof HTMLTextAreaElement) &&
    !(event.target instanceof HTMLSelectElement)
  ) {
    console.error(
      '[companies] Input event did not originate from a form field.',
    )
    return ''
  }
  return event.target.value
}

function messagebarValue(event: Event): string {
  if (!(event.target instanceof HTMLTextAreaElement)) {
    console.error(
      '[companies] Message event did not originate from a textarea.',
    )
    return ''
  }
  return event.target.value
}

function showToast(message: string): void {
  if (toastTimer) clearTimeout(toastTimer)
  toastText.value = message
  toastOpened.value = true
  toastTimer = setTimeout(() => (toastOpened.value = false), 2800)
}

function errorText(code = 'request_failed'): string {
  const phoneErrors = ['airplane_mode', 'busy', 'no_sim', 'voice_unavailable']
  if (phoneErrors.includes(code)) return phone.t(`Apps.phone.errors.${code}`)
  const known = [
    'anonymous_sim',
    'call_unavailable',
    'company_not_found',
    'invalid_media',
    'invalid_expiration',
    'invalid_profile',
    'invalid_request',
    'invalid_service',
    'invalid_status',
    'messaging_unavailable',
    'no_sim',
    'not_authorized',
    'rate_limited',
    'request_not_found',
    'revision_conflict',
    'service_unavailable',
    'too_many_open_requests',
  ]
  const key = known.includes(code) ? code : 'request_failed'
  return phone.t(`Apps.companies.errors.${key}`)
}

function formatDate(value: string): string {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  return new Intl.DateTimeFormat(phone.lang, {
    day: 'numeric',
    hour: '2-digit',
    hourCycle: 'h23',
    minute: '2-digit',
    month: 'short',
  }).format(date)
}

function localDateTimeInput(value: string | null | undefined): string {
  if (!value) return ''
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return ''
  const parts = [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0'),
    String(date.getHours()).padStart(2, '0'),
    String(date.getMinutes()).padStart(2, '0'),
  ]
  return `${parts[0]}-${parts[1]}-${parts[2]}T${parts[3]}:${parts[4]}`
}

function relativeTime(value: string): string {
  const timestamp = new Date(value).getTime()
  if (Number.isNaN(timestamp)) return ''
  const minutes = Math.max(0, Math.floor((Date.now() - timestamp) / 60_000))
  if (minutes < 1) return phone.t('Apps.companies.time.justNow')
  if (minutes < 60) {
    return phone.t('Apps.companies.time.minutesAgo', {
      count: String(minutes),
    })
  }
  const hours = Math.floor(minutes / 60)
  if (hours < 24) {
    return phone.t('Apps.companies.time.hoursAgo', { count: String(hours) })
  }
  return phone.t('Apps.companies.time.daysAgo', {
    count: String(Math.floor(hours / 24)),
  })
}

function companyInitials(company: CompanySummary): string {
  return company.name.trim().charAt(0).toUpperCase()
}

function companySubtitle(company: CompanySummary): string {
  return [
    company.location?.district,
    company.serviceSummary || company.description,
  ]
    .filter(Boolean)
    .join(' · ')
}

function categoryLabel(categoryId: string, fallback: string): string {
  const key = `Apps.companies.categories.${categoryId}`
  const translated = phone.t(key)
  return translated === key ? fallback : translated
}

function statusClass(
  status: CompanyAvailability | CompanyRequestStatus,
): string {
  return `is-${status.replace('_', '-')}`
}

function requestSubtitle(request: CompanyRequestSummary): string {
  const parts = [request.serviceName, relativeTime(request.updatedAt)].filter(
    Boolean,
  )
  return parts.join(' · ')
}

function messageAuthorLabel(value: 'company' | 'customer' | 'you'): string {
  return phone.t(`Apps.companies.messageAuthors.${value}`)
}

function memberName(name: string): string {
  return name.trim() || phone.t('Apps.companies.assignment.unknownMember')
}

function maskedPhoneNumber(value: string): string {
  return value.replace(/.(?=.{4})/g, '•')
}

function eventLabel(event: CompanyRequestEvent): string {
  if (event.type === 'status_changed' && event.status) {
    return phone.t('Apps.companies.timeline.statusChanged', {
      status: phone.t(`Apps.companies.requestStatuses.${event.status}`),
    })
  }
  return phone.t(`Apps.companies.timeline.${event.type}`)
}

function resetDirectoryFilters(): void {
  if (searchTimer) {
    clearTimeout(searchTimer)
    searchTimer = undefined
  }
  search.value = ''
  selectedCategory.value = null
}

function queueDirectoryLoad(): void {
  if (searchTimer) clearTimeout(searchTimer)
  searchTimer = setTimeout(
    () => void companies.loadCompanies(directoryFilters.value),
    260,
  )
}

function selectCategory(categoryId: string | null): void {
  selectedCategory.value = categoryId
}

async function selectTab(tab: CompaniesTab): Promise<void> {
  activeTab.value = tab
  screen.value = 'root'
  if (tab === 'directory' && !companies.directory.length) {
    await companies.loadCompanies(directoryFilters.value)
  }
  if (tab === 'requests') await companies.loadMyRequests(requestList.value)
  if (tab === 'work') await companies.loadWorkContext()
}

async function openCompany(companyId: string): Promise<void> {
  companies.company = null
  screen.value = 'company'
  if (!(await companies.loadCompany(companyId))) {
    showToast(errorText(companies.directoryError))
  }
}

async function openRequest(
  requestId: string,
  origin: RequestOrigin,
): Promise<void> {
  requestOrigin.value = origin
  companies.resetRequest()
  screen.value = 'request'
  if (!(await companies.loadRequest(requestId))) {
    showToast(errorText(companies.requestError))
  }
}

function goBack(): void {
  if (screen.value === 'manager') {
    screen.value = 'root'
    activeTab.value = 'work'
    return
  }
  if (screen.value === 'request') {
    companies.resetRequest()
    screen.value = 'root'
    activeTab.value = requestOrigin.value === 'work' ? 'work' : 'requests'
    return
  }
  screen.value = 'root'
  activeTab.value = 'directory'
}

async function callNumber(phoneNumber: string | null): Promise<void> {
  if (!phoneNumber) {
    showToast(phone.t('Apps.companies.actionUnavailable.call'))
    return
  }
  const response = await calls.dial(phoneNumber)
  if (!response.success) {
    showToast(errorText(response.error))
    return
  }
  await router.push('/apps/phone')
}

async function messageCompany(company: CompanySummary): Promise<void> {
  if (!company.canMessage || !company.phoneNumber) {
    showToast(phone.t('Apps.companies.actionUnavailable.message'))
    return
  }
  if (!(await messages.openThread(company.phoneNumber))) {
    showToast(errorText('messaging_unavailable'))
    return
  }
  await router.push('/apps/messages')
}

async function setRoute(company: CompanySummary): Promise<void> {
  if (!company.location) {
    showToast(phone.t('Apps.companies.actionUnavailable.route'))
    return
  }
  const response = await nuiCall('map:setWaypoint', {
    coords: company.location.coords,
  })
  if (!response.success) {
    showToast(errorText(response.error))
    return
  }
  showToast(phone.t('Apps.companies.routeSet'))
}

function shareCompany(company: Company): void {
  easyShare.open({
    appId: 'companies',
    copyText: `${company.name}\n${company.description}`,
    id: company.id,
    imageUrl: company.logoUrl,
    kind: 'profile',
    link: `skyphone://companies/profile/${company.id}`,
    subtitle: company.phoneNumber ?? company.categoryName,
    title: company.name,
  })
}

function openRequestComposer(company: Company): void {
  if (!company.acceptsRequests) {
    showToast(phone.t('Apps.companies.actionUnavailable.request'))
    return
  }
  requestServiceId.value =
    company.services.find(
      (service) => service.active && service.acceptsRequests,
    )?.id ?? ''
  requestSubject.value = ''
  requestDescription.value = ''
  requestMedia.value = []
  requestSheetOpened.value = true
}

function chooseRequestMedia(): void {
  if (!activeCompany.value) return
  mediaPicker.begin(
    'companies:request',
    'photo',
    '/apps/companies?compose=1',
    3,
    {
      companyId: activeCompany.value.id,
      description: requestDescription.value,
      media: requestMedia.value,
      serviceId: requestServiceId.value,
      subject: requestSubject.value,
    } satisfies RequestMediaContext,
  )
  requestSheetOpened.value = false
  void router.push({
    path: '/apps/photos',
    query: { mediaAttachment: 'photo' },
  })
}

function removeRequestMedia(id: number): void {
  requestMedia.value = requestMedia.value.filter((media) => media.id !== id)
}

async function submitRequest(): Promise<void> {
  if (!activeCompany.value || !canSubmitRequest.value) return
  const response = await companies.createRequest({
    companyId: activeCompany.value.id,
    description: requestDescription.value.trim(),
    mediaIds: requestMedia.value.map((media) => String(media.id)),
    serviceId: requestServiceId.value,
    subject: requestSubject.value.trim(),
  })
  if (!response.success || !response.data?.request) {
    if (response.error === 'revision_conflict')
      conflictDialogOpened.value = true
    else showToast(errorText(response.error))
    return
  }
  requestSheetOpened.value = false
  showToast(phone.t('Apps.companies.feedback.requestCreated'))
  activeTab.value = 'requests'
  requestOrigin.value = 'customer'
  screen.value = 'request'
  await companies.loadMyRequests('open')
}

async function sendThreadMessage(): Promise<void> {
  const request = companies.request
  if (!request || !canSendThreadMessage.value) return
  const response = await companies.sendMessage(
    request.id,
    threadDraft.value.trim(),
    request.revision,
  )
  if (!response.success) {
    if (response.error === 'revision_conflict')
      conflictDialogOpened.value = true
    else showToast(errorText(response.error))
    return
  }
  threadDraft.value = ''
}

async function cancelActiveRequest(): Promise<void> {
  const request = companies.request
  if (!request) return
  const response = await companies.cancelRequest(request.id, request.revision)
  cancelDialogOpened.value = false
  if (!response.success) {
    if (response.error === 'revision_conflict')
      conflictDialogOpened.value = true
    else showToast(errorText(response.error))
    return
  }
  showToast(phone.t('Apps.companies.feedback.requestCancelled'))
}

async function claimActiveRequest(): Promise<void> {
  const request = companies.request
  if (!request) return
  const response = await companies.claimRequest(request.id, request.revision)
  workActionsOpened.value = false
  if (!response.success) {
    if (response.error === 'revision_conflict')
      conflictDialogOpened.value = true
    else showToast(errorText(response.error))
    return
  }
  showToast(phone.t('Apps.companies.feedback.requestClaimed'))
}

async function openAssignment(): Promise<void> {
  workActionsOpened.value = false
  selectedMemberId.value = ''
  if (!(await companies.loadMembers())) {
    showToast(errorText(companies.mutationError))
    return
  }
  assignmentSheetOpened.value = true
}

async function assignActiveRequest(): Promise<void> {
  const request = companies.request
  if (!request || !selectedMemberId.value) return
  const response = await companies.assignRequest(
    request.id,
    selectedMemberId.value,
    request.revision,
  )
  if (!response.success) {
    if (response.error === 'revision_conflict')
      conflictDialogOpened.value = true
    else showToast(errorText(response.error))
    return
  }
  assignmentSheetOpened.value = false
  showToast(phone.t('Apps.companies.feedback.requestAssigned'))
}

async function updateActiveRequestStatus(
  status: CompanyRequestStatus,
): Promise<void> {
  const request = companies.request
  if (!request) return
  const response = await companies.updateRequestStatus(
    request.id,
    status,
    request.revision,
  )
  workActionsOpened.value = false
  if (!response.success) {
    if (response.error === 'revision_conflict')
      conflictDialogOpened.value = true
    else showToast(errorText(response.error))
    return
  }
  showToast(phone.t('Apps.companies.feedback.statusUpdated'))
}

async function callRequestParty(): Promise<void> {
  const request = companies.request
  if (!request) return
  if (requestOrigin.value === 'work') {
    const response = await companies.callCustomer(request.id)
    workActionsOpened.value = false
    if (!response.success) {
      showToast(errorText(response.error))
      return
    }
    if (response.data) calls.applyCallState(response.data)
    await router.push('/apps/phone')
    return
  }
  await callNumber(request.phoneNumber)
}

async function setCompanyAvailability(
  availability: CompanyAvailability,
): Promise<void> {
  const company = workCompany.value
  if (!company) return
  const response = await companies.updateAvailability(
    availability,
    company.revision,
  )
  if (!response.success) {
    if (response.error === 'revision_conflict')
      conflictDialogOpened.value = true
    else showToast(errorText(response.error))
    return
  }
  showToast(phone.t('Apps.companies.feedback.availabilityUpdated'))
}

async function toggleCallAvailability(): Promise<void> {
  const context = companies.workContext
  if (!context) return
  const response = await companies.setCallAvailability(!context.callAvailable)
  if (!response.success) {
    showToast(errorText(response.error))
    return
  }
  showToast(
    phone.t(
      `Apps.companies.feedback.${response.data?.context.callAvailable ? 'callsEnabled' : 'callsDisabled'}`,
    ),
  )
}

function openServiceLineDialer(): void {
  if (!companies.workContext?.permissions.canTakeCalls) return
  serviceLineTarget.value = ''
  serviceLineSheetOpened.value = true
}

function closeServiceLineDialer(): void {
  serviceLineSheetOpened.value = false
}

async function dialServiceLine(): Promise<void> {
  if (!canDialServiceLine.value) return
  const response = await companies.dialServiceLine(
    serviceLineTarget.value.trim(),
  )
  if (!response.success || !response.data) {
    showToast(errorText(response.error))
    return
  }
  calls.applyCallState(response.data)
  closeServiceLineDialer()
  await router.push('/apps/phone')
}

function syncManagerDraft(company: Company): void {
  profileDraft.acceptsRequests = company.acceptsRequests
  profileDraft.address = company.location?.address ?? ''
  profileDraft.description = company.description
  profileDraft.district = company.location?.district ?? ''
  profileDraft.locationLabel = company.location?.label ?? ''
  hoursDraft.value = weekdayKeys.map((_, day) => {
    const existing = company.hours.find((hours) => hours.day === day)
    return existing
      ? { ...existing }
      : { closesAt: '18:00', day, isClosed: true, opensAt: '09:00' }
  })
  servicesDraft.value = company.services.map((service) => ({ ...service }))
  announcementDraft.body = company.announcement?.body ?? ''
  announcementDraft.expiresAt = localDateTimeInput(
    company.announcement?.expiresAt,
  )
  profileCoords.value = company.location?.coords
    ? { ...company.location.coords }
    : null
  selectedLogoMedia.value = null
}

function openManager(): void {
  const company = workCompany.value
  if (!company) return
  syncManagerDraft(company)
  screen.value = 'manager'
}

function managerResponseError(error?: string): void {
  if (error === 'revision_conflict') {
    conflictDialogOpened.value = true
    return
  }
  showToast(errorText(error))
}

function chooseManagerMedia(): void {
  const company = workCompany.value
  if (!company) return
  mediaPicker.begin(
    'companies:manager-media',
    'photo',
    '/apps/companies?managerMedia=1',
    1,
    {
      announcement: { ...announcementDraft },
      companyId: company.id,
      coords: profileCoords.value ? { ...profileCoords.value } : null,
      hours: hoursDraft.value.map((hours) => ({ ...hours })),
      logoMedia: selectedLogoMedia.value,
      profile: { ...profileDraft },
      services: servicesDraft.value.map((service) => ({ ...service })),
    } satisfies ManagerMediaContext,
  )
  void router.push({
    path: '/apps/photos',
    query: { mediaAttachment: 'photo' },
  })
}

async function useCurrentLocation(): Promise<void> {
  const response = await nuiCall<{ coords?: CompanyCoordinates }>(
    'map:getPlayerCoords',
  )
  if (!response.success || !response.data?.coords) {
    showToast(errorText(response.error))
    return
  }
  profileCoords.value = { ...response.data.coords }
  showToast(phone.t('Apps.companies.feedback.locationUpdated'))
}

async function saveProfile(): Promise<void> {
  const company = workCompany.value
  if (!company) return
  const response = await companies.updateProfile({
    acceptsRequests: profileDraft.acceptsRequests,
    address: profileDraft.address.trim(),
    ...(profileCoords.value ? { coords: profileCoords.value } : {}),
    description: profileDraft.description.trim(),
    district: profileDraft.district.trim(),
    ...(selectedLogoMedia.value
      ? { logoMediaId: selectedLogoMedia.value.id }
      : {}),
    locationLabel: profileDraft.locationLabel.trim(),
    revision: company.revision,
  })
  if (!response.success || !response.data?.company) {
    managerResponseError(response.error)
    return
  }
  syncManagerDraft(response.data.company)
  showToast(phone.t('Apps.companies.feedback.profileSaved'))
}

function updateHour(
  index: number,
  field: 'closesAt' | 'opensAt',
  event: Event,
): void {
  hoursDraft.value[index][field] = eventValue(event)
}

async function saveHours(): Promise<void> {
  const company = workCompany.value
  if (!company) return
  const response = await companies.updateHours(
    company.revision,
    hoursDraft.value,
  )
  if (!response.success || !response.data?.company) {
    managerResponseError(response.error)
    return
  }
  syncManagerDraft(response.data.company)
  showToast(phone.t('Apps.companies.feedback.hoursSaved'))
}

function addService(): void {
  servicesDraft.value.push({
    acceptsRequests: true,
    active: true,
    description: '',
    id: '',
    priceText: null,
    title: '',
  })
}

function removeService(index: number): void {
  servicesDraft.value.splice(index, 1)
}

function updateService(
  index: number,
  field: 'description' | 'priceText' | 'title',
  event: Event,
): void {
  servicesDraft.value[index][field] = eventValue(event)
}

async function saveServices(): Promise<void> {
  const company = workCompany.value
  if (!company) return
  const response = await companies.updateServices(
    company.revision,
    servicesDraft.value,
  )
  if (!response.success || !response.data?.company) {
    managerResponseError(response.error)
    return
  }
  syncManagerDraft(response.data.company)
  showToast(phone.t('Apps.companies.feedback.servicesSaved'))
}

async function publishAnnouncement(): Promise<void> {
  const company = workCompany.value
  if (!company) return
  let expiresAt: string | null = null
  if (announcementDraft.expiresAt) {
    const expiration = new Date(announcementDraft.expiresAt)
    if (Number.isNaN(expiration.getTime())) {
      showToast(errorText('invalid_expiration'))
      return
    }
    expiresAt = expiration.toISOString()
  }
  const response = await companies.publishAnnouncement({
    body: announcementDraft.body.trim(),
    expiresAt,
    revision: company.revision,
  })
  if (!response.success || !response.data?.company) {
    managerResponseError(response.error)
    return
  }
  syncManagerDraft(response.data.company)
  showToast(phone.t('Apps.companies.feedback.announcementPublished'))
}

async function reloadConflict(): Promise<void> {
  conflictDialogOpened.value = false
  const loaded = await companies.loadWorkContext()
  if (loaded && companies.workContext?.company) {
    syncManagerDraft(companies.workContext.company)
  }
  if (companies.request) await companies.loadRequest(companies.request.id)
}

async function scrollRequestThreadToBottom(animate: boolean): Promise<void> {
  await nextTick()
  await new Promise<void>((resolve) => {
    requestAnimationFrame(() => resolve())
  })
  if (screen.value !== 'request') return
  const reduceMotion = window.matchMedia(
    '(prefers-reduced-motion: reduce)',
  ).matches
  requestThreadBottom.value?.scrollIntoView({
    behavior: animate && !reduceMotion ? 'smooth' : 'auto',
    block: 'end',
  })
}

watch([search, selectedCategory], ([, category], [, previousCategory]) => {
  if (category === previousCategory) {
    queueDirectoryLoad()
    return
  }
  if (searchTimer) {
    clearTimeout(searchTimer)
    searchTimer = undefined
  }
  void companies.loadCompanies(directoryFilters.value)
})
watch(requestList, () => {
  if (activeTab.value === 'requests')
    void companies.loadMyRequests(requestList.value)
})
watch(requestSheetOpened, async (opened) => {
  if (!opened) return
  await nextTick()
  requestSheetContent.value?.scrollTo({ top: 0 })
})
watch(
  [
    () => companies.request?.id ?? '',
    () => companies.request?.messages.length ?? 0,
    () => {
      const messages = companies.request?.messages ?? []
      return messages.length ? messages[messages.length - 1]!.id : ''
    },
  ],
  ([requestId], [previousRequestId]) => {
    if (!requestId || screen.value !== 'request') return
    void scrollRequestThreadToBottom(requestId === previousRequestId)
  },
  { flush: 'post' },
)

watch(
  () => route.query.requestId,
  async (requestId) => {
    if (typeof requestId !== 'string') return
    const origin: RequestOrigin =
      route.query.area === 'work' ? 'work' : 'customer'
    await router.replace('/apps/companies')
    await openRequest(requestId, origin)
  },
)

onMounted(async () => {
  const selection =
    mediaPicker.consumeMany<RequestMediaContext>('companies:request')
  const managerSelection = mediaPicker.consumeMany<ManagerMediaContext>(
    'companies:manager-media',
  )
  const linkedRequestId =
    typeof route.query.requestId === 'string' ? route.query.requestId : null
  const linkedRequestOrigin: RequestOrigin =
    route.query.area === 'work' ? 'work' : 'customer'
  await Promise.all([
    companies.loadCompanies(directoryFilters.value),
    companies.loadMyRequests('open'),
    companies.loadWorkContext(),
    calls.loadContacts(),
  ])
  if (linkedRequestId) {
    await router.replace('/apps/companies')
    await openRequest(linkedRequestId, linkedRequestOrigin)
    return
  }
  if (
    managerSelection?.context &&
    managerSelection.context.companyId === workCompany.value?.id &&
    companies.workContext?.permissions.canManageProfile
  ) {
    const context = managerSelection.context
    openManager()
    Object.assign(profileDraft, context.profile)
    hoursDraft.value = context.hours.map((hours) => ({ ...hours }))
    servicesDraft.value = context.services.map((service) => ({ ...service }))
    announcementDraft.body = context.announcement.body
    announcementDraft.expiresAt = context.announcement.expiresAt
    profileCoords.value = context.coords ? { ...context.coords } : null
    selectedLogoMedia.value = context.logoMedia
    const selectedMedia = managerSelection.media[0]
    if (selectedMedia) {
      selectedLogoMedia.value = selectedMedia
    }
    return
  }
  if (!selection?.context) return
  await openCompany(selection.context.companyId)
  requestServiceId.value = selection.context.serviceId
  requestSubject.value = selection.context.subject
  requestDescription.value = selection.context.description
  requestMedia.value = selection.media.length
    ? selection.media
    : selection.context.media
  requestSheetOpened.value = true
})

onBeforeUnmount(() => {
  if (searchTimer) clearTimeout(searchTimer)
  if (toastTimer) clearTimeout(toastTimer)
})
</script>

<template>
  <SkyAppPage
    class="companies-app"
    :dark="phone.isDarkMode"
    :label="phone.t('Apps.companies.name')"
  >
    <SkyNavbar
      :title="navbarTitle"
      :show-back="screen !== 'root'"
      :back-label="phone.t('Apps.companies.back')"
      @back="goBack"
    >
      <template
        v-if="
          screen === 'request' && requestOrigin === 'work' && companies.request
        "
        #right
      >
        <SkyLink
          component="button"
          icon-only
          :aria-label="phone.t('Apps.companies.actions')"
          type="button"
          @click="workActionsOpened = true"
        >
          <MoreHorizontal :size="24" />
        </SkyLink>
      </template>
    </SkyNavbar>

    <SkyScrollArea
      v-if="screen === 'root' && activeTab === 'directory'"
      padded
      class="companies-content companies-directory"
      with-tabbar
    >
      <div class="companies-search-wrap">
        <SkySearchbar
          :value="search"
          :clear-label="phone.t('Apps.companies.directory.resetFilters')"
          :placeholder="phone.t('Apps.companies.directory.searchPlaceholder')"
          @input="search = eventValue($event)"
          @clear="search = ''"
        />
      </div>

      <SkyScrollRail
        class="companies-chip-row"
        :label="phone.t('Apps.companies.directory.categories')"
      >
        <SkyChip
          component="button"
          type="button"
          :selected="selectedCategory === null"
          @click="selectCategory(null)"
        >
          {{ phone.t('Apps.companies.directory.allCategories') }}
        </SkyChip>
        <SkyChip
          v-for="category in companies.categories"
          :key="category.id"
          component="button"
          type="button"
          :selected="selectedCategory === category.id"
          @click="selectCategory(category.id)"
        >
          {{ categoryLabel(category.id, category.name) }}
        </SkyChip>
      </SkyScrollRail>

      <SkyEmptyState
        v-if="companies.directoryLoading"
        :title="phone.t('Apps.companies.loading.directory')"
      >
        <template #icon><SkySpinner /></template>
      </SkyEmptyState>
      <SkyEmptyState
        v-else-if="companies.directoryError"
        tone="danger"
        :title="phone.t('Apps.companies.states.directoryError')"
        :body="errorText(companies.directoryError)"
      >
        <template #icon><CircleAlert :size="34" /></template>
        <template #actions>
          <SkyButton rounded @click="companies.loadCompanies(directoryFilters)">
            <RefreshCw :size="16" />
            {{ phone.t('Apps.companies.tryAgain') }}
          </SkyButton>
        </template>
      </SkyEmptyState>
      <SkyEmptyState
        v-else-if="!companies.directory.length"
        :title="
          phone.t(
            filtersActive
              ? 'Apps.companies.states.noResults'
              : 'Apps.companies.states.noCompanies',
          )
        "
        :body="
          phone.t(
            filtersActive
              ? 'Apps.companies.states.noResultsBody'
              : 'Apps.companies.states.noCompaniesBody',
          )
        "
      >
        <template #icon><Building2 :size="36" /></template>
        <template v-if="filtersActive" #actions>
          <SkyButton rounded @click="resetDirectoryFilters">
            {{ phone.t('Apps.companies.directory.resetFilters') }}
          </SkyButton>
        </template>
      </SkyEmptyState>
      <SkySection
        v-else
        :title="phone.t('Apps.companies.directory.allCompanies')"
      >
        <SkyListCard class="company-list">
          <SkyListItem
            v-for="company in companies.directory"
            :key="company.id"
            link
            link-component="button"
            :link-props="{ type: 'button' }"
            :title="company.name"
            :subtitle="companySubtitle(company)"
            @click="openCompany(company.id)"
          >
            <template #media>
              <span class="company-logo">
                <img
                  v-if="company.logoUrl"
                  :src="company.logoUrl"
                  :alt="company.name"
                />
                <span v-else>{{ companyInitials(company) }}</span>
              </span>
            </template>
            <template #after>
              <span class="company-row-after">
                <SkyBadge :class="statusClass(company.availability)">
                  {{
                    phone.t(
                      `Apps.companies.availability.${company.availability}`,
                    )
                  }}
                </SkyBadge>
              </span>
            </template>
          </SkyListItem>
        </SkyListCard>
        <SkyInfiniteLoader
          :has-more="Boolean(companies.directoryNextCursor)"
          :loading="companies.directoryLoadingMore"
          :error="companies.directoryAppendError"
          :load-key="companies.directoryNextCursor"
          :loading-label="phone.t('Apps.companies.loading.directory')"
          :retry-label="phone.t('Apps.companies.tryAgain')"
          @load="companies.loadCompanies(directoryFilters, true)"
          @retry="companies.loadCompanies(directoryFilters, true)"
        />
      </SkySection>
    </SkyScrollArea>

    <SkyScrollArea
      v-else-if="screen === 'root' && activeTab === 'requests'"
      padded
      class="companies-content"
      with-tabbar
    >
      <div class="companies-segment-wrap">
        <SkySegmented
          :active-index="requestList === 'open' ? 0 : 1"
          :aria-label="phone.t('Apps.companies.tabs.requests')"
          :item-count="2"
          compact
          navigation
          rounded
          strong
        >
          <SkySegmentedButton
            :active="requestList === 'open'"
            @click="requestList = 'open'"
          >
            {{ phone.t('Apps.companies.requests.open') }}
          </SkySegmentedButton>
          <SkySegmentedButton
            :active="requestList === 'closed'"
            @click="requestList = 'closed'"
          >
            {{ phone.t('Apps.companies.requests.closed') }}
          </SkySegmentedButton>
        </SkySegmented>
      </div>

      <SkyEmptyState
        v-if="companies.myRequestsLoading"
        :title="phone.t('Apps.companies.loading.requests')"
      >
        <template #icon><SkySpinner /></template>
      </SkyEmptyState>
      <SkyEmptyState
        v-else-if="companies.myRequestsError"
        tone="danger"
        :title="phone.t('Apps.companies.states.requestsError')"
        :body="errorText(companies.myRequestsError)"
      >
        <template #icon><CircleAlert :size="34" /></template>
        <template #actions>
          <SkyButton rounded @click="companies.loadMyRequests(requestList)">
            {{ phone.t('Apps.companies.tryAgain') }}
          </SkyButton>
        </template>
      </SkyEmptyState>
      <SkyEmptyState
        v-else-if="!companies.myRequests.length"
        :title="
          phone.t(
            `Apps.companies.states.no${requestList === 'open' ? 'Open' : 'Closed'}Requests`,
          )
        "
        :body="phone.t('Apps.companies.states.noRequestsBody')"
      >
        <template #icon><ClipboardList :size="36" /></template>
        <template v-if="requestList === 'open'" #actions>
          <SkyButton rounded @click="selectTab('directory')">
            {{ phone.t('Apps.companies.requests.findCompany') }}
          </SkyButton>
        </template>
      </SkyEmptyState>
      <SkyListCard v-else class="company-request-list">
        <SkyListItem
          v-for="item in companies.myRequests"
          :key="item.id"
          link
          link-component="button"
          :link-props="{ type: 'button' }"
          :title="item.subject"
          :subtitle="requestSubtitle(item)"
          :header="item.companyName"
          @click="openRequest(item.id, 'customer')"
        >
          <template #media>
            <span class="company-request-icon"
              ><ClipboardList :size="19"
            /></span>
          </template>
          <template #after>
            <span class="request-row-after">
              <SkyBadge v-if="item.unreadCount" class="is-unread">{{
                item.unreadCount
              }}</SkyBadge>
              <SkyBadge :class="statusClass(item.status)">
                {{ phone.t(`Apps.companies.requestStatuses.${item.status}`) }}
              </SkyBadge>
            </span>
          </template>
        </SkyListItem>
      </SkyListCard>
      <SkyInfiniteLoader
        v-if="
          !companies.myRequestsLoading &&
          !companies.myRequestsError &&
          companies.myRequests.length
        "
        :has-more="Boolean(companies.myRequestsNextCursor)"
        :loading="companies.myRequestsLoadingMore"
        :error="companies.myRequestsAppendError"
        :load-key="companies.myRequestsNextCursor"
        :loading-label="phone.t('Apps.companies.loading.requests')"
        :retry-label="phone.t('Apps.companies.tryAgain')"
        @load="companies.loadMyRequests(requestList, true)"
        @retry="companies.loadMyRequests(requestList, true)"
      />
    </SkyScrollArea>

    <SkyScrollArea
      v-else-if="screen === 'root' && activeTab === 'work'"
      padded
      class="companies-content companies-work"
      with-tabbar
    >
      <SkyEmptyState
        v-if="companies.workContextLoading"
        :title="phone.t('Apps.companies.loading.work')"
      >
        <template #icon><SkySpinner /></template>
      </SkyEmptyState>
      <SkyEmptyState
        v-else-if="companies.workContextError"
        tone="danger"
        :title="phone.t('Apps.companies.states.workError')"
        :body="errorText(companies.workContextError)"
      >
        <template #icon><CircleAlert :size="34" /></template>
        <template #actions>
          <SkyButton rounded @click="selectTab('work')">
            {{ phone.t('Apps.companies.tryAgain') }}
          </SkyButton>
        </template>
      </SkyEmptyState>
      <SkyEmptyState
        v-else-if="!companies.workContext?.authorized"
        :title="phone.t('Apps.companies.work.notAuthorized')"
        :body="phone.t('Apps.companies.work.notAuthorizedBody')"
      >
        <template #icon><BriefcaseBusiness :size="38" /></template>
      </SkyEmptyState>
      <template v-else-if="companies.workContext && workCompany">
        <SkyCard class="work-identity-card">
          <span class="company-logo company-logo--large">
            <img
              v-if="workCompany.logoUrl"
              :src="workCompany.logoUrl"
              :alt="workCompany.name"
            />
            <span v-else>{{ companyInitials(workCompany) }}</span>
          </span>
          <span>
            <small>{{ phone.t('Apps.companies.work.workspace') }}</small>
            <strong>{{ workCompany.name }}</strong>
            <span>{{
              phone.t(`Apps.companies.roles.${companies.workContext.role}`)
            }}</span>
          </span>
          <SkyBadge :class="statusClass(workCompany.availability)">
            {{
              phone.t(`Apps.companies.availability.${workCompany.availability}`)
            }}
          </SkyBadge>
        </SkyCard>

        <section class="work-control-card">
          <SkyBlockTitle>{{
            phone.t('Apps.companies.work.publicAvailability')
          }}</SkyBlockTitle>
          <SkySegmented
            class="availability-segmented"
            :active-index="availabilityValues.indexOf(workCompany.availability)"
            :aria-label="phone.t('Apps.companies.work.publicAvailability')"
            :item-count="availabilityValues.length"
            compact
            navigation
            rounded
            strong
          >
            <SkySegmentedButton
              v-for="availability in availabilityValues"
              :key="availability"
              :active="workCompany.availability === availability"
              :disabled="
                !companies.workContext.permissions.canSetAvailability ||
                companies.mutating
              "
              @click="setCompanyAvailability(availability)"
            >
              {{ phone.t(`Apps.companies.availability.${availability}`) }}
            </SkySegmentedButton>
          </SkySegmented>

          <SkyList inset strong class="work-action-list">
            <SkyListItem
              v-if="companies.workContext.permissions.canTakeCalls"
              :title="phone.t('Apps.companies.work.takeCalls')"
              :subtitle="phone.t('Apps.companies.work.takeCallsBody')"
            >
              <template #media><PhoneCall :size="20" /></template>
              <template #after>
                <SkyToggle
                  :checked="companies.workContext.callAvailable"
                  :disabled="companies.mutating"
                  :aria-label="phone.t('Apps.companies.work.takeCalls')"
                  @change="toggleCallAvailability"
                />
              </template>
            </SkyListItem>
            <SkyListItem
              v-if="companies.workContext.permissions.canTakeCalls"
              link
              link-component="button"
              :link-props="{ type: 'button' }"
              :title="phone.t('Apps.companies.work.dialServiceLine')"
              :subtitle="
                phone.t('Apps.companies.work.dialServiceLineBody', {
                  number:
                    workCompany.phoneNumber ??
                    phone.t('Apps.companies.manager.noPhoneNumber'),
                })
              "
              @click="openServiceLineDialer"
            >
              <template #media><Phone :size="20" /></template>
            </SkyListItem>
            <SkyListItem
              v-if="companies.workContext.role === 'manager'"
              link
              link-component="button"
              :link-props="{ type: 'button' }"
              :title="phone.t('Apps.companies.manager.title')"
              :subtitle="phone.t('Apps.companies.manager.subtitle')"
              @click="openManager"
            >
              <template #media><Settings2 :size="20" /></template>
            </SkyListItem>
          </SkyList>
        </section>

        <SkyBlockTitle>{{
          phone.t('Apps.companies.work.overview')
        }}</SkyBlockTitle>
        <div class="work-metrics">
          <SkySurface :highlight="false" class="work-metric">
            <strong>{{ companies.workContext.metrics.new }}</strong>
            <span>{{ phone.t('Apps.companies.work.metrics.new') }}</span>
          </SkySurface>
          <SkySurface :highlight="false" class="work-metric">
            <strong>{{ companies.workContext.metrics.assigned }}</strong>
            <span>{{ phone.t('Apps.companies.work.metrics.assigned') }}</span>
          </SkySurface>
          <SkySurface :highlight="false" class="work-metric">
            <strong>{{ companies.workContext.metrics.waiting }}</strong>
            <span>{{ phone.t('Apps.companies.work.metrics.waiting') }}</span>
          </SkySurface>
          <SkySurface :highlight="false" class="work-metric">
            <strong>{{ companies.workContext.metrics.completedToday }}</strong>
            <span>{{
              phone.t('Apps.companies.work.metrics.completedToday')
            }}</span>
          </SkySurface>
        </div>
      </template>
    </SkyScrollArea>

    <SkyScrollArea
      v-else-if="screen === 'company'"
      padded
      class="companies-content company-profile"
    >
      <SkyEmptyState
        v-if="companies.directoryLoading && !activeCompany"
        :title="phone.t('Apps.companies.loading.profile')"
      >
        <template #icon><SkySpinner /></template>
      </SkyEmptyState>
      <SkyEmptyState
        v-else-if="companies.directoryError || !activeCompany"
        tone="danger"
        :title="phone.t('Apps.companies.states.profileError')"
        :body="errorText(companies.directoryError)"
      >
        <template #icon><CircleAlert :size="34" /></template>
        <template #actions>
          <SkyButton rounded @click="goBack">
            {{ phone.t('Apps.companies.back') }}
          </SkyButton>
        </template>
      </SkyEmptyState>
      <template v-else>
        <div
          class="company-cover"
          :style="
            activeCompany.coverUrl
              ? { backgroundImage: `url(${activeCompany.coverUrl})` }
              : undefined
          "
        >
          <span class="company-logo company-logo--hero">
            <img
              v-if="activeCompany.logoUrl"
              :src="activeCompany.logoUrl"
              :alt="activeCompany.name"
            />
            <span v-else>{{ companyInitials(activeCompany) }}</span>
          </span>
        </div>
        <SkyBlock class="company-profile-heading">
          <span class="company-profile-heading__eyebrow">
            {{
              categoryLabel(
                activeCompany.categoryId,
                activeCompany.categoryName,
              )
            }}
            <BadgeCheck
              v-if="activeCompany.verified"
              :size="15"
              :aria-label="phone.t('Apps.companies.verified')"
            />
          </span>
          <h1>{{ activeCompany.name }}</h1>
          <SkyBadge :class="statusClass(activeCompany.availability)">
            {{
              phone.t(
                `Apps.companies.availability.${activeCompany.availability}`,
              )
            }}
          </SkyBadge>
          <small>
            {{
              phone.t('Apps.companies.profile.updated', {
                time: relativeTime(activeCompany.availabilityUpdatedAt),
              })
            }}
          </small>
          <p>{{ activeCompany.description }}</p>
        </SkyBlock>

        <SkyCard v-if="activeCompany.announcement" class="company-announcement">
          <Megaphone :size="20" />
          <span>
            <strong>{{
              phone.t('Apps.companies.profile.announcement')
            }}</strong>
            <span>{{ activeCompany.announcement.body }}</span>
          </span>
        </SkyCard>

        <SkyBlockTitle>{{
          phone.t('Apps.companies.profile.location')
        }}</SkyBlockTitle>
        <SkyList inset strong>
          <SkyListItem
            v-if="activeCompany.location"
            :title="activeCompany.location.label"
            :subtitle="`${activeCompany.location.address} · ${activeCompany.location.district}`"
          >
            <template #media><MapPin :size="20" /></template>
          </SkyListItem>
          <SkyListItem
            v-else
            :title="phone.t('Apps.companies.profile.noLocation')"
          >
            <template #media><MapPin :size="20" /></template>
          </SkyListItem>
        </SkyList>

        <SkyBlockTitle>{{
          phone.t('Apps.companies.profile.hours')
        }}</SkyBlockTitle>
        <SkyList inset strong>
          <SkyListItem
            v-for="hours in activeCompany.hours"
            :key="hours.day"
            :title="phone.t(`Apps.companies.days.${weekdayKeys[hours.day]}`)"
            :after="
              hours.isClosed
                ? phone.t('Apps.companies.profile.closed')
                : `${hours.opensAt}–${hours.closesAt}`
            "
          >
            <template #media><Clock3 :size="19" /></template>
          </SkyListItem>
          <SkyListItem
            v-if="!activeCompany.hours.length"
            :title="phone.t('Apps.companies.profile.byAvailability')"
          />
        </SkyList>

        <SkyBlockTitle>{{
          phone.t('Apps.companies.profile.services')
        }}</SkyBlockTitle>
        <SkyList inset strong>
          <SkyListItem
            v-for="service in activeCompany.services.filter(
              (item) => item.active,
            )"
            :key="service.id"
            :title="service.title"
            :subtitle="service.description"
            :after="service.priceText ?? undefined"
          />
          <SkyListItem
            v-if="!activeCompany.services.some((service) => service.active)"
            :title="phone.t('Apps.companies.profile.noServices')"
          />
        </SkyList>

        <SkySurface :highlight="false" class="company-profile-actions">
          <SkyButton
            rounded
            :disabled="!activeCompany.canCall || !activeCompany.phoneNumber"
            @click="callNumber(activeCompany.phoneNumber)"
          >
            <Phone :size="17" />{{ phone.t('Apps.companies.profile.call') }}
          </SkyButton>
          <SkyButton
            rounded
            outline
            :disabled="!activeCompany.canMessage || !activeCompany.phoneNumber"
            @click="messageCompany(activeCompany)"
          >
            <MessageCircle :size="17" />{{
              phone.t('Apps.companies.profile.message')
            }}
          </SkyButton>
          <SkyButton
            rounded
            outline
            :disabled="!activeCompany.location"
            @click="setRoute(activeCompany)"
          >
            <MapPin :size="17" />{{ phone.t('Apps.companies.profile.route') }}
          </SkyButton>
          <SkyButton
            rounded
            :disabled="!activeCompany.acceptsRequests"
            @click="openRequestComposer(activeCompany)"
          >
            <ClipboardList :size="17" />{{
              phone.t('Apps.companies.profile.request')
            }}
          </SkyButton>
          <SkyButton rounded outline @click="shareCompany(activeCompany)">
            <Share2 :size="17" />{{ phone.t('Apps.easyShare.share') }}
          </SkyButton>
        </SkySurface>
      </template>
    </SkyScrollArea>

    <template v-else-if="screen === 'request'">
      <SkyScrollArea padded class="companies-content request-thread">
        <SkyEmptyState
          v-if="companies.requestLoading"
          :title="phone.t('Apps.companies.loading.request')"
        >
          <template #icon><SkySpinner /></template>
        </SkyEmptyState>
        <SkyEmptyState
          v-else-if="companies.requestError || !companies.request"
          tone="danger"
          :title="phone.t('Apps.companies.states.requestError')"
          :body="errorText(companies.requestError)"
        >
          <template #icon><CircleAlert :size="34" /></template>
          <template #actions>
            <SkyButton rounded @click="goBack">
              {{ phone.t('Apps.companies.back') }}
            </SkyButton>
          </template>
        </SkyEmptyState>
        <template v-else>
          <div class="request-thread-content">
            <SkyCard class="request-summary-card">
              <span>
                <small>{{ companies.request.companyName }}</small>
                <strong>{{ companies.request.subject }}</strong>
              </span>
              <SkyBadge :class="statusClass(companies.request.status)">
                {{
                  phone.t(
                    `Apps.companies.requestStatuses.${companies.request.status}`,
                  )
                }}
              </SkyBadge>
              <p>{{ companies.request.description }}</p>
              <span class="request-summary-card__meta">
                {{
                  companies.request.serviceName ??
                  phone.t('Apps.companies.requests.generalService')
                }}
                · {{ formatDate(companies.request.createdAt) }}
              </span>
            </SkyCard>

            <div
              v-if="companies.request.media.length"
              class="request-media-strip"
              :aria-label="phone.t('Apps.companies.requests.attachments')"
            >
              <img
                v-for="media in companies.request.media"
                :key="media.id"
                :src="media.url"
                :alt="phone.t('Apps.companies.requests.attachedPhoto')"
                draggable="false"
                loading="lazy"
                referrerpolicy="no-referrer"
              />
            </div>

            <SkyBlockTitle>{{
              phone.t('Apps.companies.requests.timeline')
            }}</SkyBlockTitle>
            <div class="request-timeline">
              <div v-for="event in companies.request.events" :key="event.id">
                <span><Check :size="12" /></span>
                <p>
                  <strong>{{ eventLabel(event) }}</strong>
                  <small>{{ formatDate(event.createdAt) }}</small>
                </p>
              </div>
            </div>

            <SkyBlockTitle>{{
              phone.t('Apps.companies.requests.conversation')
            }}</SkyBlockTitle>
            <SkyMessages class="company-messages">
              <SkyMessagesTitle v-if="!companies.request.messages.length">
                {{ phone.t('Apps.companies.requests.noMessages') }}
              </SkyMessagesTitle>
              <SkyMessage
                v-for="message in companies.request.messages"
                :key="message.id"
                :type="message.isMine ? 'sent' : 'received'"
                :name="messageAuthorLabel(message.authorLabel)"
                :text="message.body"
                :text-footer="formatDate(message.createdAt)"
              />
            </SkyMessages>
            <span
              ref="requestThreadBottom"
              class="request-thread-bottom"
              aria-hidden="true"
            />
          </div>
        </template>
      </SkyScrollArea>
      <footer
        v-if="requestDockVisible && companies.request"
        class="request-thread-dock"
        :class="{
          'request-thread-dock--actions-only':
            !companies.request.actions.canReply,
        }"
      >
        <div
          v-if="
            companies.request.actions.canCall ||
            companies.request.actions.canCancel
          "
          class="request-thread-actions"
        >
          <SkyButton
            v-if="companies.request.actions.canCall"
            outline
            rounded
            @click="callRequestParty"
          >
            <Phone :size="16" />{{ phone.t('Apps.companies.requests.call') }}
          </SkyButton>
          <SkyButton
            v-if="companies.request.actions.canCancel"
            outline
            rounded
            class="is-danger"
            @click="cancelDialogOpened = true"
          >
            <X :size="16" />{{ phone.t('Apps.companies.requests.cancel') }}
          </SkyButton>
        </div>
        <SkyMessagebar
          v-if="companies.request.actions.canReply"
          class="company-messagebar"
          :disabled="companies.mutating"
          :placeholder="phone.t('Apps.companies.requests.replyPlaceholder')"
          :value="threadDraft"
          @input="threadDraft = messagebarValue($event)"
          @keydown.enter.exact="handleEnterAction($event, sendThreadMessage)"
        >
          <template #right>
            <SkyToolbarPane class="ios:h-10">
              <SkyLink
                component="button"
                icon-only
                :disabled="!canSendThreadMessage"
                :aria-label="phone.t('Apps.companies.requests.sendReply')"
                type="button"
                @click="sendThreadMessage"
              >
                <Send :size="22" />
              </SkyLink>
            </SkyToolbarPane>
          </template>
        </SkyMessagebar>
      </footer>
    </template>

    <SkyScrollArea
      v-else-if="screen === 'manager' && workCompany"
      padded
      class="companies-content manager-screen"
    >
      <SkyCard class="manager-intro">
        <Settings2 :size="24" />
        <span>
          <strong>{{ workCompany.name }}</strong>
          <span>{{
            phone.t('Apps.companies.manager.revision', {
              revision: String(workCompany.revision),
            })
          }}</span>
        </span>
      </SkyCard>

      <SkyBlockTitle>{{
        phone.t('Apps.companies.manager.availability')
      }}</SkyBlockTitle>
      <SkySegmented
        class="availability-segmented"
        :active-index="availabilityValues.indexOf(workCompany.availability)"
        :aria-label="phone.t('Apps.companies.manager.availability')"
        :item-count="availabilityValues.length"
        compact
        navigation
        rounded
        strong
      >
        <SkySegmentedButton
          v-for="availability in availabilityValues"
          :key="availability"
          :active="workCompany.availability === availability"
          :disabled="
            !companies.workContext?.permissions.canSetAvailability ||
            companies.mutating
          "
          @click="setCompanyAvailability(availability)"
        >
          {{ phone.t(`Apps.companies.availability.${availability}`) }}
        </SkySegmentedButton>
      </SkySegmented>

      <template v-if="companies.workContext?.permissions.canManageProfile">
        <SkyBlockTitle>{{
          phone.t('Apps.companies.manager.profile')
        }}</SkyBlockTitle>
        <div class="manager-media-grid">
          <SkyButton
            variant="secondary"
            rounded
            large
            class="manager-media-button"
            @click="chooseManagerMedia()"
          >
            <img
              v-if="managerLogoUrl"
              :src="managerLogoUrl"
              :alt="phone.t('Apps.companies.manager.logoPhoto')"
              loading="lazy"
            />
            <span v-else><ImagePlus :size="22" /></span>
            <small>{{ phone.t('Apps.companies.manager.chooseLogo') }}</small>
          </SkyButton>
        </div>
        <SkyList inset strong class="manager-form-list">
          <SkyField
            type="textarea"
            maxlength="500"
            :label="phone.t('Apps.companies.manager.description')"
            :placeholder="
              phone.t('Apps.companies.manager.descriptionPlaceholder')
            "
            :value="profileDraft.description"
            @input="profileDraft.description = eventValue($event)"
          />
          <SkyField
            type="tel"
            readonly
            :label="phone.t('Apps.companies.manager.phoneNumber')"
            :help="phone.t('Apps.companies.manager.phoneNumberManaged')"
            :value="
              workCompany.phoneNumber ??
              phone.t('Apps.companies.manager.noPhoneNumber')
            "
          />
          <SkyField
            maxlength="80"
            :label="phone.t('Apps.companies.manager.locationLabel')"
            :value="profileDraft.locationLabel"
            @input="profileDraft.locationLabel = eventValue($event)"
          />
          <SkyField
            maxlength="120"
            :label="phone.t('Apps.companies.manager.address')"
            :value="profileDraft.address"
            @input="profileDraft.address = eventValue($event)"
          />
          <SkyField
            maxlength="80"
            :label="phone.t('Apps.companies.manager.district')"
            :value="profileDraft.district"
            @input="profileDraft.district = eventValue($event)"
          />
          <SkyListItem
            :title="phone.t('Apps.companies.manager.acceptRequests')"
            :subtitle="phone.t('Apps.companies.manager.acceptRequestsBody')"
          >
            <template #after>
              <SkyToggle
                :checked="profileDraft.acceptsRequests"
                :aria-label="phone.t('Apps.companies.manager.acceptRequests')"
                @change="
                  profileDraft.acceptsRequests = !profileDraft.acceptsRequests
                "
              />
            </template>
          </SkyListItem>
        </SkyList>
        <SkyButton
          outline
          rounded
          class="manager-location"
          :disabled="companies.mutating"
          @click="useCurrentLocation"
        >
          <Compass :size="16" />{{
            phone.t('Apps.companies.manager.useCurrentLocation')
          }}
        </SkyButton>
        <small v-if="profileCoords" class="manager-location-status">
          {{ phone.t('Apps.companies.manager.locationReady') }}
        </small>
        <SkyButton
          rounded
          class="manager-save"
          :disabled="companies.mutating"
          @click="saveProfile"
        >
          {{ phone.t('Apps.companies.manager.saveProfile') }}
        </SkyButton>
      </template>

      <template v-if="companies.workContext?.permissions.canManageHours">
        <SkyBlockTitle>{{
          phone.t('Apps.companies.manager.hours')
        }}</SkyBlockTitle>
        <SkyCard
          v-for="(hours, index) in hoursDraft"
          :key="hours.day"
          class="manager-hours-card"
          :content-wrap="false"
        >
          <SkyList nested>
            <SkyListItem
              :title="phone.t(`Apps.companies.days.${weekdayKeys[hours.day]}`)"
            >
              <template #after>
                <SkyToggle
                  :checked="!hours.isClosed"
                  :aria-label="phone.t('Apps.companies.manager.dayOpen')"
                  @change="hours.isClosed = !hours.isClosed"
                />
              </template>
            </SkyListItem>
            <template v-if="!hours.isClosed">
              <SkyField
                type="text"
                inputmode="numeric"
                placeholder="HH:MM"
                pattern="([01][0-9]|2[0-3]):[0-5][0-9]"
                :maxlength="5"
                :label="phone.t('Apps.companies.manager.opensAt')"
                :value="hours.opensAt ?? ''"
                @input="updateHour(index, 'opensAt', $event)"
              />
              <SkyField
                type="text"
                inputmode="numeric"
                placeholder="HH:MM"
                pattern="([01][0-9]|2[0-3]):[0-5][0-9]"
                :maxlength="5"
                :label="phone.t('Apps.companies.manager.closesAt')"
                :value="hours.closesAt ?? ''"
                @input="updateHour(index, 'closesAt', $event)"
              />
            </template>
          </SkyList>
        </SkyCard>
        <SkyButton
          rounded
          class="manager-save"
          :disabled="companies.mutating"
          @click="saveHours"
        >
          {{ phone.t('Apps.companies.manager.saveHours') }}
        </SkyButton>
      </template>

      <template v-if="companies.workContext?.permissions.canManageServices">
        <SkyBlockTitle>{{
          phone.t('Apps.companies.manager.services')
        }}</SkyBlockTitle>
        <SkyCard
          v-for="(service, index) in servicesDraft"
          :key="`${service.id}-${index}`"
          class="manager-service-card"
          :content-wrap="false"
        >
          <SkyList nested>
            <SkyField
              maxlength="80"
              :label="phone.t('Apps.companies.manager.serviceTitle')"
              :value="service.title"
              @input="updateService(index, 'title', $event)"
            />
            <SkyField
              maxlength="240"
              :label="phone.t('Apps.companies.manager.serviceDescription')"
              :value="service.description"
              @input="updateService(index, 'description', $event)"
            />
            <SkyField
              maxlength="40"
              :label="phone.t('Apps.companies.manager.priceText')"
              :value="service.priceText ?? ''"
              @input="updateService(index, 'priceText', $event)"
            />
            <SkyListItem
              :title="phone.t('Apps.companies.manager.serviceActive')"
            >
              <template #after>
                <SkyToggle
                  :checked="service.active"
                  :aria-label="phone.t('Apps.companies.manager.serviceActive')"
                  @change="service.active = !service.active"
                />
              </template>
            </SkyListItem>
            <SkyListItem
              :title="phone.t('Apps.companies.manager.serviceRequests')"
            >
              <template #after>
                <SkyToggle
                  :checked="service.acceptsRequests"
                  :aria-label="
                    phone.t('Apps.companies.manager.serviceRequests')
                  "
                  @change="service.acceptsRequests = !service.acceptsRequests"
                />
              </template>
            </SkyListItem>
          </SkyList>
          <SkyButton
            outline
            rounded
            class="manager-remove"
            @click="removeService(index)"
          >
            <Trash2 :size="15" />{{
              phone.t('Apps.companies.manager.removeService')
            }}
          </SkyButton>
        </SkyCard>
        <SkyButton outline rounded class="manager-save" @click="addService">
          <Plus :size="16" />{{ phone.t('Apps.companies.manager.addService') }}
        </SkyButton>
        <SkyButton
          rounded
          class="manager-save"
          :disabled="companies.mutating"
          @click="saveServices"
        >
          {{ phone.t('Apps.companies.manager.saveServices') }}
        </SkyButton>
      </template>

      <template v-if="companies.workContext?.permissions.canManageAnnouncement">
        <SkyBlockTitle>{{
          phone.t('Apps.companies.manager.announcement')
        }}</SkyBlockTitle>
        <SkyList inset strong class="manager-form-list">
          <SkyField
            type="textarea"
            maxlength="280"
            :label="phone.t('Apps.companies.manager.announcementText')"
            :placeholder="
              phone.t('Apps.companies.manager.announcementPlaceholder')
            "
            :value="announcementDraft.body"
            @input="announcementDraft.body = eventValue($event)"
          />
          <SkyField
            type="datetime-local"
            :label="phone.t('Apps.companies.manager.expiresAt')"
            :value="announcementDraft.expiresAt"
            @input="announcementDraft.expiresAt = eventValue($event)"
          />
        </SkyList>
        <SkyButton
          rounded
          class="manager-save"
          :disabled="companies.mutating"
          @click="publishAnnouncement"
        >
          <Megaphone :size="16" />{{
            phone.t('Apps.companies.manager.publish')
          }}
        </SkyButton>
      </template>
    </SkyScrollArea>

    <SkyPillNavigation
      v-if="screen === 'root'"
      class="companies-navigation"
      layout="full"
      :label="phone.t('Apps.companies.navigation')"
    >
      <SkySegmented
        strong
        rounded
        navigation
        :active-index="activeTabIndex"
        :aria-label="phone.t('Apps.companies.navigation')"
        :data-active-tab="activeTab"
        :item-count="3"
      >
        <SkySegmentedButton
          :active="activeTab === 'directory'"
          type="button"
          @click="selectTab('directory')"
        >
          <span class="companies-navigation__item">
            <SkyIcon :size="20"><Compass :size="20" /></SkyIcon>
            <span>{{ phone.t('Apps.companies.tabs.directory') }}</span>
          </span>
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="activeTab === 'requests'"
          type="button"
          @click="selectTab('requests')"
        >
          <span class="companies-navigation__item">
            <span class="companies-tab-icon">
              <SkyIcon :size="20"><ClipboardList :size="20" /></SkyIcon>
              <SkyBadge v-if="companies.customerUnreadCount">{{
                companies.customerUnreadCount
              }}</SkyBadge>
            </span>
            <span>{{ phone.t('Apps.companies.tabs.requests') }}</span>
          </span>
        </SkySegmentedButton>
        <SkySegmentedButton
          :active="activeTab === 'work'"
          type="button"
          @click="selectTab('work')"
        >
          <span class="companies-navigation__item">
            <span class="companies-tab-icon">
              <SkyIcon :size="20"><BriefcaseBusiness :size="20" /></SkyIcon>
              <SkyBadge v-if="companies.workUnreadCount">{{
                companies.workUnreadCount
              }}</SkyBadge>
            </span>
            <span>{{ phone.t('Apps.companies.tabs.work') }}</span>
          </span>
        </SkySegmentedButton>
      </SkySegmented>
    </SkyPillNavigation>

    <div class="companies-sheet">
      <SkySheet
        :opened="requestSheetOpened"
        :aria-label="phone.t('Apps.companies.composer.title')"
        @backdropclick="requestSheetOpened = false"
        @escape="requestSheetOpened = false"
      >
        <section
          v-if="requestSheetOpened && activeCompany"
          ref="requestSheetContent"
          class="companies-sheet__content"
        >
          <header>
            <span><ClipboardList :size="23" /></span>
            <div>
              <small>{{ activeCompany.name }}</small>
              <h2>{{ phone.t('Apps.companies.composer.title') }}</h2>
            </div>
            <SkyLink
              component="button"
              icon-only
              :aria-label="phone.t('Apps.companies.close')"
              type="button"
              @click="requestSheetOpened = false"
            >
              <X :size="19" />
            </SkyLink>
          </header>
          <SkyProgress
            :label="phone.t('Apps.companies.composer.review')"
            :progress="requestProgress"
          />
          <SkyBlockTitle class="composer-service-title">{{
            phone.t('Apps.companies.composer.chooseService')
          }}</SkyBlockTitle>
          <SkyList inset strong class="composer-service-list">
            <SkyListItem
              v-for="service in activeCompany.services.filter(
                (item) => item.active && item.acceptsRequests,
              )"
              :key="service.id"
              label
              :title="service.title"
              :subtitle="service.description"
            >
              <template #media>
                <SkyRadio
                  name="company-request-service"
                  :value="service.id"
                  :checked="requestServiceId === service.id"
                  @change="requestServiceId = service.id"
                />
              </template>
              <template v-if="service.priceText" #after>
                <span class="composer-service-price">{{
                  service.priceText
                }}</span>
              </template>
            </SkyListItem>
          </SkyList>
          <SkyList inset strong class="composer-form-list">
            <SkyField
              outline
              maxlength="100"
              :label="phone.t('Apps.companies.composer.subject')"
              :placeholder="
                phone.t('Apps.companies.composer.subjectPlaceholder')
              "
              :value="requestSubject"
              :input-style="{ height: '38px' }"
              @input="requestSubject = eventValue($event)"
            />
            <SkyField
              outline
              type="textarea"
              maxlength="1200"
              :label="phone.t('Apps.companies.composer.description')"
              :placeholder="
                phone.t('Apps.companies.composer.descriptionPlaceholder')
              "
              :value="requestDescription"
              :input-style="{
                height: '72px',
                lineHeight: '20px',
                paddingBottom: '8px',
                paddingTop: '8px',
                resize: 'none',
              }"
              @input="requestDescription = eventValue($event)"
            />
          </SkyList>
          <SkyCard class="composer-contact-card">
            <Phone :size="18" />
            <span>
              <strong>{{ phone.t('Apps.companies.composer.contact') }}</strong>
              <span v-if="phone.device?.sim?.registered">
                {{
                  phone.t('Apps.companies.composer.registeredSim', {
                    number: maskedPhoneNumber(phone.device.sim.number),
                  })
                }}
              </span>
              <span v-else>{{
                phone.t('Apps.companies.composer.registeredSimRequired')
              }}</span>
            </span>
          </SkyCard>
          <SkyButton
            outline
            rounded
            :disabled="requestMedia.length >= 3"
            @click="chooseRequestMedia"
          >
            <ImagePlus :size="17" />
            {{
              phone.t('Apps.companies.composer.addPhotos', {
                count: String(requestMedia.length),
              })
            }}
          </SkyButton>
          <div v-if="requestMedia.length" class="composer-media-strip">
            <span v-for="media in requestMedia" :key="media.id">
              <img
                :src="media.url"
                :alt="phone.t('Apps.companies.composer.selectedPhoto')"
              />
              <SkyButton
                rounded
                :aria-label="phone.t('Apps.companies.composer.removePhoto')"
                @click="removeRequestMedia(media.id)"
              >
                <X :size="13" />
              </SkyButton>
            </span>
          </div>
          <SkyButton
            large
            rounded
            :disabled="!canSubmitRequest || companies.mutating"
            @click="submitRequest"
          >
            <SkySpinner v-if="companies.mutating" />
            <span v-else>{{ phone.t('Apps.companies.composer.send') }}</span>
          </SkyButton>
        </section>
      </SkySheet>
    </div>

    <SkyActionSheet
      v-if="workActionsOpened"
      :opened="workActionsOpened"
      :label="phone.t('Apps.companies.actions')"
      @backdropclick="workActionsOpened = false"
      @escape="workActionsOpened = false"
    >
      <SkyActionGroup v-if="companies.request">
        <SkyActionButton
          v-if="companies.request.actions.canClaim"
          @click="claimActiveRequest"
        >
          {{ phone.t('Apps.companies.workActions.claim') }}
        </SkyActionButton>
        <SkyActionButton
          v-if="companies.request.actions.canAssign"
          @click="openAssignment"
        >
          {{ phone.t('Apps.companies.workActions.assign') }}
        </SkyActionButton>
        <SkyActionButton
          v-if="companies.request.actions.canCall"
          @click="callRequestParty"
        >
          {{ phone.t('Apps.companies.workActions.callCustomer') }}
        </SkyActionButton>
        <SkyActionButton
          v-for="status in companies.request.actions.allowedStatuses"
          :key="status"
          @click="updateActiveRequestStatus(status)"
        >
          {{
            phone.t('Apps.companies.workActions.setStatus', {
              status: phone.t(`Apps.companies.requestStatuses.${status}`),
            })
          }}
        </SkyActionButton>
      </SkyActionGroup>
      <SkyActionGroup>
        <SkyActionButton bold @click="workActionsOpened = false">
          {{ phone.t('Apps.companies.close') }}
        </SkyActionButton>
      </SkyActionGroup>
    </SkyActionSheet>

    <div class="companies-sheet companies-service-line-sheet">
      <SkySheet
        :opened="serviceLineSheetOpened"
        :aria-label="phone.t('Apps.companies.work.dialServiceLine')"
        @backdropclick="closeServiceLineDialer"
        @escape="closeServiceLineDialer"
      >
        <section
          v-if="serviceLineSheetOpened && workCompany"
          class="companies-sheet__content service-line-sheet__content"
        >
          <header>
            <span><PhoneCall :size="23" /></span>
            <div>
              <small>{{ workCompany.name }}</small>
              <h2>{{ phone.t('Apps.companies.work.dialServiceLine') }}</h2>
            </div>
            <SkyLink
              component="button"
              icon-only
              :aria-label="phone.t('Apps.companies.close')"
              type="button"
              @click="closeServiceLineDialer"
            >
              <X :size="19" />
            </SkyLink>
          </header>
          <p class="service-line-sheet__body">
            {{
              phone.t('Apps.companies.work.dialServiceLineHint', {
                number:
                  workCompany.phoneNumber ??
                  phone.t('Apps.companies.manager.noPhoneNumber'),
              })
            }}
          </p>
          <SkyList inset strong class="service-line-sheet__form">
            <SkyField
              type="tel"
              :label="phone.t('Apps.companies.work.targetNumber')"
              :placeholder="phone.t('Apps.companies.work.targetNumberHint')"
              :value="serviceLineTarget"
              @input="serviceLineTarget = eventValue($event)"
              @keydown.enter.exact="handleEnterAction($event, dialServiceLine)"
            />
          </SkyList>
          <SkyButton
            large
            rounded
            :disabled="!canDialServiceLine"
            @click="dialServiceLine"
          >
            <Phone :size="18" />{{ phone.t('Apps.companies.work.callNow') }}
          </SkyButton>
        </section>
      </SkySheet>
    </div>

    <div class="companies-sheet companies-assignment-sheet">
      <SkySheet
        :opened="assignmentSheetOpened"
        :aria-label="phone.t('Apps.companies.assignment.title')"
        @backdropclick="assignmentSheetOpened = false"
        @escape="assignmentSheetOpened = false"
      >
        <section v-if="assignmentSheetOpened" class="companies-sheet__content">
          <header>
            <span><UsersRound :size="23" /></span>
            <div>
              <h2>{{ phone.t('Apps.companies.assignment.title') }}</h2>
            </div>
            <SkyLink
              component="button"
              icon-only
              :aria-label="phone.t('Apps.companies.close')"
              type="button"
              @click="assignmentSheetOpened = false"
            >
              <X :size="19" />
            </SkyLink>
          </header>
          <SkyEmptyState v-if="companies.membersLoading" compact>
            <template #icon><SkySpinner /></template>
          </SkyEmptyState>
          <SkyListCard v-else>
            <SkyListItem
              v-for="member in companies.members"
              :key="member.id"
              label
              :title="memberName(member.name)"
              :subtitle="`${member.role} · ${phone.t(`Apps.companies.assignment.${member.online ? 'online' : 'offline'}`)}`"
            >
              <template #media
                ><span class="member-avatar"><UserRound :size="18" /></span
              ></template>
              <template #after>
                <SkyRadio
                  name="company-member"
                  :value="member.id"
                  :checked="selectedMemberId === member.id"
                  :disabled="!member.online"
                  @change="selectedMemberId = member.id"
                />
              </template>
            </SkyListItem>
          </SkyListCard>
          <SkyButton
            large
            rounded
            :disabled="!selectedMemberId || companies.mutating"
            @click="assignActiveRequest"
          >
            {{ phone.t('Apps.companies.assignment.confirm') }}
          </SkyButton>
        </section>
      </SkySheet>
    </div>

    <SkyDialog
      :opened="cancelDialogOpened"
      :title="phone.t('Apps.companies.requests.cancelTitle')"
      :content="phone.t('Apps.companies.requests.cancelBody')"
      @backdropclick="cancelDialogOpened = false"
      @escape="cancelDialogOpened = false"
    >
      <template #buttons>
        <SkyDialogButton @click="cancelDialogOpened = false">
          {{ phone.t('Apps.companies.requests.keep') }}
        </SkyDialogButton>
        <SkyDialogButton
          strong
          :disabled="companies.mutating"
          @click="cancelActiveRequest"
        >
          {{ phone.t('Apps.companies.requests.cancelConfirm') }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <SkyDialog
      :opened="conflictDialogOpened"
      :title="phone.t('Apps.companies.conflict.title')"
      :content="phone.t('Apps.companies.conflict.body')"
      @backdropclick="conflictDialogOpened = false"
      @escape="conflictDialogOpened = false"
    >
      <template #buttons>
        <SkyDialogButton @click="conflictDialogOpened = false">
          {{ phone.t('Apps.companies.close') }}
        </SkyDialogButton>
        <SkyDialogButton strong @click="reloadConflict">
          {{ phone.t('Apps.companies.conflict.reload') }}
        </SkyDialogButton>
      </template>
    </SkyDialog>

    <SkyNotification
      :opened="toastOpened"
      :text="toastText"
      @click="toastOpened = false"
    />
  </SkyAppPage>
</template>

<style scoped>
.companies-app {
  --company-blue: var(--sky-app-accent);
  --company-cyan: #38bdf8;
  --company-green: #22c55e;
  --company-orange: #f59e0b;
  --company-red: #ef4444;
  --company-surface: var(--sky-surface);
  --company-surface-muted: var(--sky-surface-muted);
  --company-border: var(--sky-hairline);
  --company-text: var(--sky-text);
  --company-muted: var(--sky-muted);
}

.companies-search-wrap {
  margin: 0 0 8px;
}

.companies-chip-row {
  gap: 6px;
  scroll-snap-type: x proximity;
}

.companies-chip-row :deep(.sky-chip) {
  min-width: auto;
  min-height: 38px;
  flex: none;
  padding: 0 12px;
  font-size: 12px;
  scroll-snap-align: start;
  white-space: nowrap;
}

.companies-chip-row :deep(.sky-chip--selected) {
  color: white;
  background: linear-gradient(135deg, var(--company-blue), var(--company-cyan));
}

.work-identity-card,
.manager-intro,
.request-summary-card,
.composer-contact-card,
.company-announcement {
  margin: 0 0 12px;
  border: 1px solid var(--company-border);
  border-radius: 18px;
  background: var(--company-surface);
  box-shadow: none;
}

.company-list {
  margin: 0 !important;
}

.company-request-list {
  margin: 0 !important;
  display: grid;
  gap: var(--sky-space-2);
  overflow: visible;
  border-radius: 0;
  background: transparent;
}

.company-request-list :deep(.sky-list-item) {
  overflow: hidden;
  border: 1px solid var(--company-border);
  border-radius: var(--sky-radius-card);
  background: var(--company-surface);
}

.company-list :deep(.sky-list-item__row),
.company-request-list :deep(.sky-list-item__row) {
  width: 100%;
  text-align: left;
}

.companies-content :deep(.sky-block-title) {
  margin: 18px 0 8px !important;
  padding: 0 2px !important;
  color: var(--company-muted);
  font-size: 15px;
  line-height: 20px;
}

.company-logo {
  width: 44px;
  height: 44px;
  display: grid;
  flex: none;
  place-items: center;
  overflow: hidden;
  border-radius: 12px;
  color: white;
  background: var(--company-blue);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.42);
  font-size: 13px;
  font-weight: 800;
}

.company-logo img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.company-logo--small {
  width: 36px;
  height: 36px;
  border-radius: 11px;
}

.company-logo--large {
  width: 54px;
  height: 54px;
  border-radius: 17px;
}

.company-row-after,
.request-row-after {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}

.company-list :deep(.sky-list-item__title) {
  white-space: normal;
  overflow-wrap: anywhere;
  text-overflow: clip;
}

.company-row-after small {
  max-width: 82px;
  overflow: hidden;
  color: #94a3b8;
  font-size: 8px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.company-list :deep(.sky-list-item__content),
.company-request-list :deep(.sky-list-item__content) {
  padding-top: 11px;
  padding-bottom: 11px;
}

.company-list :deep(.sky-list-item__title),
.company-request-list :deep(.sky-list-item__title) {
  min-height: 22px;
  align-items: flex-start;
  font-size: 15px;
  line-height: 20px;
}

.company-list :deep(.sky-list-item__subtitle),
.company-request-list :deep(.sky-list-item__subtitle) {
  display: -webkit-box;
  overflow: hidden;
  color: var(--company-muted);
  font-size: 12px;
  line-height: 16px;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

:deep(.sky-badge) {
  min-width: 0;
  border-radius: 999px;
  font-size: 8px;
  line-height: 1.2;
}

:deep(.sky-badge.is-available),
:deep(.sky-badge.is-completed) {
  color: #047857;
  background: #d1fae5;
}

:deep(.sky-badge.is-busy),
:deep(.sky-badge.is-waiting-customer) {
  color: #b45309;
  background: #fef3c7;
}

:deep(.sky-badge.is-closed),
:deep(.sky-badge.is-cancelled) {
  color: #b91c1c;
  background: #fee2e2;
}

:deep(.sky-badge.is-new),
:deep(.sky-badge.is-assigned),
:deep(.sky-badge.is-in-progress),
:deep(.sky-badge.is-unread) {
  color: #1d4ed8;
  background: #dbeafe;
}

.manager-save {
  width: 100%;
  margin: 14px 0 4px;
}

.companies-segment-wrap,
.availability-segmented {
  margin: 0 0 14px;
}

.companies-segment-wrap {
  margin-bottom: 12px;
}

.company-request-icon,
.member-avatar {
  width: 36px;
  height: 36px;
  display: grid;
  place-items: center;
  border-radius: 12px;
  color: var(--company-blue);
  background: rgba(59, 130, 246, 0.13);
}

.work-identity-card :deep(> *),
.manager-intro :deep(> *),
.composer-contact-card :deep(> *),
.company-announcement :deep(> *) {
  display: flex;
  align-items: center;
  gap: 11px;
}

.work-identity-card {
  margin-bottom: 18px;
}

.work-identity-card :deep(> *) {
  min-height: 72px;
  padding: 13px 14px;
}

.work-identity-card :deep(> *) > span:nth-child(2),
.manager-intro :deep(> *) > span,
.composer-contact-card :deep(> *) > span,
.company-announcement :deep(> *) > span {
  min-width: 0;
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}

.work-identity-card small,
.manager-intro span span,
.composer-contact-card span span,
.company-announcement span span {
  color: #64748b;
  font-size: 10px;
}

.work-identity-card strong {
  overflow: hidden;
  font-size: 14px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.work-metrics {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
  margin: 0 0 14px;
}

.work-control-card > :deep(.sky-block-title) {
  margin-top: 0 !important;
}

.work-action-list {
  margin: 0 !important;
}

.work-action-list :deep(.sky-list-item__subtitle) {
  color: var(--company-muted);
  font-size: 12px;
  line-height: 16px;
  text-align: left;
}

.work-metric {
  margin: 0;
  min-height: 72px;
  padding: 12px 14px;
  display: flex;
  flex-direction: column;
  gap: 2px;
  border: 1px solid var(--company-border);
  border-radius: 16px;
  background: var(--company-surface);
}

.work-metrics strong {
  color: var(--company-blue);
  font-size: 22px;
}

.work-metrics span {
  color: var(--company-muted);
  font-size: 11px;
}

.company-cover {
  height: 145px;
  margin: -10px -10px 0;
  display: flex;
  align-items: flex-end;
  padding: 14px;
  background:
    linear-gradient(180deg, transparent, rgba(15, 23, 42, 0.48)),
    linear-gradient(135deg, #1d4ed8, #38bdf8 58%, #67e8f9);
  background-position: center;
  background-size: cover;
}

.company-logo--hero {
  width: 66px;
  height: 66px;
  border: 3px solid rgba(255, 255, 255, 0.88);
  border-radius: 20px;
  font-size: 18px;
}

.company-profile-heading {
  margin-top: 10px;
}

.company-profile-heading__eyebrow {
  display: flex;
  align-items: center;
  gap: 5px;
  color: var(--company-blue);
  font-size: 11px;
  font-weight: 700;
}

.company-profile-heading h1 {
  margin: 3px 0 6px;
  font-size: 24px;
  line-height: 1.1;
}

.company-profile-heading small {
  display: block;
  margin-top: 5px;
  color: #64748b;
  font-size: 9px;
}

.company-profile-heading p {
  margin: 12px 0 0;
  color: #475569;
  font-size: 12px;
  line-height: 1.5;
}

.company-profile {
  padding-bottom: calc(var(--sky-safe-area-bottom) + 24px);
}

.company-profile > :deep(.sky-block-title) {
  margin-top: 18px;
  margin-bottom: 6px;
}

.company-profile > :deep(.sky-list) {
  margin-top: 8px;
  margin-bottom: 10px;
}

.companies-app.sky-app-page--dark .company-profile-heading p,
.companies-app.sky-app-page--dark .work-identity-card small,
.companies-app.sky-app-page--dark .manager-intro span span,
.companies-app.sky-app-page--dark .composer-contact-card span span,
.companies-app.sky-app-page--dark .company-announcement span span,
.companies-app.sky-app-page--dark .work-metrics span {
  color: #94a3b8;
}

.company-announcement {
  color: var(--company-blue);
}

.company-profile-actions {
  position: relative;
  z-index: 4;
  margin: 18px 0 0;
  padding: 8px;
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 7px;
  border: 1px solid rgba(255, 255, 255, 0.45);
  border-radius: 20px;
}

.companies-app.sky-app-page--dark .company-profile-actions {
  border-color: rgba(255, 255, 255, 0.08);
}

.request-thread-content {
  min-height: 100%;
}

.request-summary-card :deep(> *) {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 6px 10px;
}

.request-summary-card :deep(> *) > span:first-child {
  min-width: 0;
  display: flex;
  flex-direction: column;
}

.request-summary-card small,
.request-summary-card__meta {
  color: #64748b;
  font-size: 9px;
}

.request-summary-card p,
.request-summary-card__meta {
  grid-column: 1 / -1;
}

.request-summary-card p {
  margin: 5px 0 0;
  font-size: 12px;
  line-height: 1.45;
}

.request-media-strip {
  margin: 0 2px 14px;
  display: grid;
  grid-auto-columns: minmax(112px, 58%);
  grid-auto-flow: column;
  gap: 8px;
  overflow-x: auto;
  scroll-snap-type: x proximity;
  scrollbar-width: none;
}

.request-media-strip::-webkit-scrollbar {
  display: none;
}

.request-media-strip img {
  width: 100%;
  height: 108px;
  display: block;
  scroll-snap-align: start;
  border-radius: 14px;
  object-fit: cover;
  background: rgba(148, 163, 184, 0.2);
}

.request-timeline {
  margin: 0 12px 16px;
}

.request-timeline > div {
  position: relative;
  display: flex;
  gap: 9px;
  min-height: 40px;
}

.request-timeline > div:not(:last-child)::before {
  position: absolute;
  top: 18px;
  bottom: -3px;
  left: 10px;
  width: 1px;
  content: '';
  background: rgba(59, 130, 246, 0.28);
}

.request-timeline > div > span {
  z-index: 1;
  width: 21px;
  height: 21px;
  display: grid;
  flex: none;
  place-items: center;
  border-radius: 50%;
  color: white;
  background: var(--company-blue);
}

.request-timeline p {
  margin: 1px 0 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
  font-size: 11px;
}

.request-timeline small {
  color: #64748b;
  font-size: 9px;
}

.company-messages {
  min-height: 100px;
}

.request-thread-bottom {
  width: 100%;
  height: 1px;
  display: block;
}

.request-thread-dock {
  position: relative;
  z-index: 4;
  flex: 0 0 auto;
  background: var(--sky-bg);
}

.request-thread-actions {
  margin: var(--sky-space-2)
    calc(var(--sky-page-gutter) + var(--sky-safe-area-right)) var(--sky-space-1)
    calc(var(--sky-page-gutter) + var(--sky-safe-area-left));
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: var(--sky-space-2);
}

.request-thread-actions > :only-child {
  grid-column: 1 / -1;
}

.request-thread-actions .is-danger,
.manager-remove {
  color: var(--company-red);
}

.request-thread-dock--actions-only {
  padding-bottom: calc(var(--sky-safe-area-bottom) + var(--sky-space-2));
}

.company-messagebar {
  position: relative;
  z-index: auto;
  right: auto;
  bottom: auto;
  left: auto;
}

.manager-screen {
  padding-bottom: 35px;
}

.manager-media-grid {
  display: grid;
  grid-template-columns: minmax(0, 86px);
  justify-content: center;
  gap: 9px;
  margin: 0 0 14px;
}

.manager-media-button {
  min-width: 0;
  min-height: 86px;
  overflow: hidden;
  position: relative;
  display: grid;
  place-items: center;
  border: 1px solid rgba(148, 163, 184, 0.3);
  padding: 0;
}

.manager-media-grid img {
  width: 100%;
  height: 86px;
  object-fit: cover;
}

.manager-media-grid small {
  position: absolute;
  right: 6px;
  bottom: 6px;
  left: 6px;
  overflow: hidden;
  border-radius: 8px;
  padding: 4px 6px;
  color: white;
  background: rgba(15, 23, 42, 0.72);
  font-size: 9px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.manager-location {
  width: 100%;
  margin: 0 0 4px;
}

.manager-location-status {
  display: block;
  margin: 0 16px 8px;
  color: #64748b;
  font-size: 10px;
}

.manager-form-list,
.manager-hours-card,
.manager-service-card {
  margin-bottom: 10px;
}

.manager-form-list {
  margin-right: 0 !important;
  margin-left: 0 !important;
}

.manager-hours-card,
.manager-service-card {
  border-radius: 18px;
}

.manager-remove {
  width: calc(100% - 20px);
  margin: 2px 10px 10px;
}

.companies-tab-icon {
  position: relative;
  display: inline-flex;
}

.companies-navigation {
  z-index: 25;
}

.companies-navigation__item {
  min-width: 0;
  max-width: 100%;
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 2px;
  line-height: 1;
}

.companies-navigation__item > span:last-child {
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.companies-tab-icon :deep(.sky-badge) {
  position: absolute;
  top: -5px;
  inset-inline-end: -10px;
  color: white;
  background: var(--company-red);
}

.companies-sheet :deep(.sky-sheet__panel) {
  max-height: 88%;
  border-radius: 24px 24px 0 0;
  overflow: hidden;
}

.companies-sheet__content {
  max-height: 82vh;
  padding: 16px 12px max(22px, env(safe-area-inset-bottom));
  overflow-y: auto;
}

.companies-sheet__content > header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}

.companies-sheet__content > header > span {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 14px;
  color: white;
  background: linear-gradient(145deg, var(--company-blue), var(--company-cyan));
}

.companies-sheet__content > header > div {
  min-width: 0;
  flex: 1;
}

.companies-sheet__content h2 {
  margin: 0;
  font-size: 18px;
}

.companies-sheet__content header small {
  color: #64748b;
  font-size: 9px;
}

.service-line-sheet__body {
  margin: 0 0 var(--sky-space-4);
  color: var(--company-muted);
  font-size: var(--sky-font-body);
  line-height: 1.45;
}

.service-line-sheet__form {
  margin: 0 0 var(--sky-space-4) !important;
}

.service-line-sheet__content > :deep(.sky-button) {
  width: 100%;
}

.composer-service-title {
  margin-top: 18px;
  margin-bottom: 8px;
}

.composer-service-list {
  margin-top: 0;
  margin-right: 8px;
  margin-bottom: 10px;
  margin-left: 8px;
}

.composer-service-list :deep(.sky-list-item__subtitle) {
  overflow: hidden;
  font-size: 11px;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.composer-service-list :deep(.sky-radio__mark) {
  width: 20px;
  height: 20px;
}

.composer-service-price {
  color: #64748b;
  font-size: 11px;
  font-weight: 500;
}

.composer-form-list {
  margin-top: 10px;
  margin-right: 8px;
  margin-bottom: 10px;
  margin-left: 8px;
}

.composer-form-list :deep(.sky-field) {
  margin-top: 8px;
  margin-bottom: 8px;
}

.composer-contact-card {
  margin-top: 12px;
}

.composer-media-strip {
  display: flex;
  gap: 8px;
  margin: 10px 2px;
  overflow-x: auto;
}

.composer-media-strip > span {
  position: relative;
  width: 74px;
  height: 74px;
  flex: none;
}

.composer-media-strip img {
  width: 100%;
  height: 100%;
  border-radius: 13px;
  object-fit: cover;
}

.composer-media-strip :deep(.sky-button) {
  position: absolute;
  top: 3px;
  right: 3px;
  width: 24px;
  min-width: 24px;
  height: 24px;
  padding: 0;
  color: white;
  background: rgba(15, 23, 42, 0.82);
}

@media (max-width: 330px) {
  .company-profile-actions {
    grid-template-columns: 1fr;
  }

  .company-profile {
    padding-bottom: 190px;
  }
}
</style>
