<script setup lang="ts">
import {
  SkyBadge,
  SkyBlockTitle,
  SkyButton,
  SkyCard,
  SkyDialog,
  SkyDialogButton,
  SkyIcon,
  SkyLink,
  SkyList,
  SkyField,
  SkyListItem,
  SkyNavbar,
  SkyAppPage,
  SkySpinner,
  SkySheet,
  SkyTabBar,
  SkyTabButton,
  SkyNotification,
  SkyToggle,
  SkyToolbarPane,
} from '@/ui'
import {
  AlertTriangle,
  Camera,
  Check,
  CircleDot,
  Copy,
  Crown,
  Crosshair,
  Eye,
  EyeOff,
  Flag,
  Info,
  Images,
  LocateFixed,
  LogOut,
  Map as MapIcon,
  MapPinned,
  MapPin,
  Navigation,
  Plus,
  Radio,
  RefreshCw,
  Route,
  Satellite,
  Settings2,
  Share2,
  Shield,
  ShieldCheck,
  Sparkles,
  Trash2,
  UserPlus,
  Users,
  UserRound,
  X,
  Zap,
} from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import {
  defaultCayoStyle,
  defaultMainlandStyle,
  defaultMapCoordinates,
  defaultMapPercentToWorld,
  defaultMapWorldToPercent,
  type MapPoint,
} from '@/features/map/defaultMapGeometry'
import { zoomPanAtPoint } from '@/features/map/mapViewport'
import AccountLogoutDialog from '@/components/account/AccountLogoutDialog.vue'
import AppProfileAuth from '@/components/account/AppProfileAuth.vue'
import { useAccountStore } from '@/stores/account'
import { useAppAuthStore } from '@/stores/app-auth'
import { useCrewLinkStore } from '@/stores/crewlink'
import { useEasyShareStore } from '@/stores/easyshare'
import { useMessageMediaStore } from '@/stores/messageMedia'
import { usePhoneStore } from '@/stores/phone'
import type { PhoneMedia } from '@/types/media'
import type {
  CrewLinkColour,
  CrewLinkMember,
  CrewLinkNearbyPlayer,
  CrewLinkPing,
  CrewLinkPingType,
  CrewLinkRole,
} from '@/types/crewlink'
import { copyText } from '@/utils/clipboard'
import { easyShareCrewLinkInviteCode } from '@/utils/easyshare'
import { consumeEscape, handleEnterAction } from '@/utils/keyboard'
import { nuiCall } from '@/utils/nui'
import { readPhoneViewportGeometry } from '@/utils/phoneViewportGeometry'
import { isTrustedRootMessageSource } from '@/utils/windowMessages'

type CrewLinkTab = 'map' | 'group' | 'pings' | 'profile'
type CrewLinkMapStyle = 'default' | 'satellite' | 'atlas' | 'roads'
type CrewLinkSheet =
  | 'create-group'
  | 'join-group'
  | 'nearby'
  | 'ping'
  | 'edit-group'
  | 'edit-profile'
  | 'member'
  | null
type AuthMediaContext = {
  mode: 'login' | 'register'
  selectedPhoto: PhoneMedia | null
  username: string
}
type ProfileMediaContext = {
  selectedPhoto: PhoneMedia | null
  username: string
}

const phone = usePhoneStore()
const account = useAccountStore()
const appAuth = useAppAuthStore()
const crew = useCrewLinkStore()
const messageMedia = useMessageMediaStore()
const route = useRoute()
const router = useRouter()
const mapStyle = ref<CrewLinkMapStyle>('default')
const mapAspect = ref(
  defaultMapCoordinates.width / defaultMapCoordinates.height,
)
const mapMaxZoom = ref(8)
const cayoMapUrl = `${import.meta.env.BASE_URL}img/maps/cayo-perico.svg`
const mapBounds = {
  minX: -4096,
  maxX: 4096,
  minY: -4096,
  maxY: 4096,
}
const mapOrigin = { x: -336.8, y: -1412.2 }
const mapScale = { x: -2340 / -1548.1, y: 291 / 189.3 }
const mapStyles = [
  { id: 'default' as const, icon: MapPinned },
  { id: 'satellite' as const, icon: Satellite },
  { id: 'atlas' as const, icon: MapIcon },
  { id: 'roads' as const, icon: Route },
]
const activeMapStyle = computed(
  () => mapStyles.find((style) => style.id === mapStyle.value) ?? mapStyles[0],
)
const mapImageUrl = computed(() => {
  const filename =
    mapStyle.value === 'default'
      ? 'gtav-map.svg'
      : mapStyle.value === 'roads'
        ? 'map_roads_4096.webp'
        : mapStyle.value === 'atlas'
          ? 'map_atlas_4096.webp'
          : 'map_satellite_4096.webp'
  return `${import.meta.env.BASE_URL}img/maps/${filename}`
})
const activeTab = ref<CrewLinkTab>('map')
const headerTitle = computed(() =>
  activeTab.value === 'map'
    ? t('name')
    : t(activeTab.value === 'group' ? 'crew' : activeTab.value),
)
const headerSubtitle = computed(() =>
  activeTab.value === 'map' ? t('liveCoordination') : t('name'),
)
const sheet = ref<CrewLinkSheet>(null)
const username = ref('')
const authMode = ref<'login' | 'register'>('login')
const authUsername = ref('')
const authPassword = ref('')
const authProfilePhoto = ref<PhoneMedia | null>(null)
const authPending = ref(false)
const authError = ref('')
const selectedProfilePhoto = ref<PhoneMedia | null>(null)
const profileAvatarRemoved = ref(false)
const groupName = ref('')
const groupColour = ref<CrewLinkColour>('cyan')
const inviteCode = ref('')
const sharedInviteCode = ref(
  easyShareCrewLinkInviteCode(
    route.query.easyShareKind,
    route.query.easyShareLink,
    route.query.easyShareId,
  ),
)
const pingType = ref<CrewLinkPingType>('meeting')
const pingLabel = ref('')
const placingPing = ref(false)
const pingCoords = ref<MapPoint | null>(null)
const nearbyPlayers = ref<CrewLinkNearbyPlayer[]>([])
const selectedMember = ref<CrewLinkMember | null>(null)
const selectedPing = ref<CrewLinkPing | null>(null)
const formError = ref('')
const logoutDialogOpen = ref(false)
const toastText = ref('')
const pendingGroupSetting = ref<'allowMemberPings' | 'overheadAllowed' | null>(
  null,
)
const pendingVisibility = ref<'mapVisible' | 'overheadVisible' | null>(null)
const confirmAction = ref<
  'delete-group' | 'leave-group' | 'remove-member' | 'transfer-owner' | null
>(null)
const zoom = ref(1.45)
const pan = ref<MapPoint>({ x: 0, y: 0 })
const viewportRef = ref<HTMLElement | null>(null)
const canvasRef = ref<HTMLElement | null>(null)
const isPointerDown = ref(false)
const pointerStart = { x: 0, y: 0, panX: 0, panY: 0 }
const pointerLatest = { x: 0, y: 0 }
let liveTimer: number | undefined
let toastTimer: number | undefined
let pointerFrame: number | undefined

const colours: Array<{ id: CrewLinkColour; value: string }> = [
  { id: 'cyan', value: '#27d9ed' },
  { id: 'blue', value: '#2790ff' },
  { id: 'violet', value: '#8b5cf6' },
  { id: 'orange', value: '#ff9f43' },
  { id: 'green', value: '#36d17c' },
  { id: 'rose', value: '#ff5f86' },
]
const roleIcons: Record<CrewLinkRole, typeof Crown> = {
  owner: Crown,
  coordinator: ShieldCheck,
  moderator: Shield,
  member: UserRound,
  guest: Eye,
}
const pingIcons: Record<CrewLinkPingType, typeof MapPin> = {
  meeting: Users,
  danger: AlertTriangle,
  help: Zap,
  target: Crosshair,
  info: Info,
}
const pingColours: Record<CrewLinkPingType, string> = {
  meeting: '#27d9ed',
  danger: '#ff4d67',
  help: '#ffb020',
  target: '#8b5cf6',
  info: '#3198ff',
}
const roleLevels: Record<CrewLinkRole, number> = {
  guest: 1,
  member: 2,
  moderator: 3,
  coordinator: 4,
  owner: 5,
}
const editableRoles: CrewLinkRole[] = [
  'coordinator',
  'moderator',
  'member',
  'guest',
]

const activeGroup = computed(() => crew.activeGroup)
const ownMember = computed(() =>
  activeGroup.value?.members.find((member) => member.id === crew.profile?.id),
)
const onlineMembers = computed(
  () => activeGroup.value?.members.filter((member) => member.online) ?? [],
)
const visibleMapMembers = computed(() =>
  onlineMembers.value.filter((member) => Boolean(member.coords)),
)
const canCoordinate = computed(
  () =>
    roleLevels[activeGroup.value?.role ?? 'guest'] >= roleLevels.coordinator,
)
const canModerate = computed(
  () => roleLevels[activeGroup.value?.role ?? 'guest'] >= roleLevels.moderator,
)
const canPing = computed(
  () => canModerate.value || Boolean(activeGroup.value?.allowMemberPings),
)
const authUsernameValid = computed(() =>
  /^[A-Za-z0-9][A-Za-z0-9._]{1,18}[A-Za-z0-9]$/.test(authUsername.value.trim()),
)
const canvasStyle = computed(() => ({
  aspectRatio: String(mapAspect.value),
  transform: `translate(-50%, -50%) translate(${pan.value.x}px, ${pan.value.y}px) scale(${zoom.value})`,
  width: 'max(128%, 128vh)',
}))
const activeColour = computed(
  () =>
    colours.find((colour) => colour.id === activeGroup.value?.colour)?.value ??
    colours[0].value,
)
const activeCrewStyle = computed(() => ({
  '--crew': activeColour.value,
  '--crew-aura': `${activeColour.value}8c`,
  '--crew-glow': `${activeColour.value}61`,
  '--crew-ring': `${activeColour.value}47`,
}))
function readMapCenterCoords(): MapPoint | null {
  const viewport = viewportRef.value?.getBoundingClientRect()
  const canvas = canvasRef.value?.getBoundingClientRect()
  if (!viewport || !canvas) return null
  return mapPercentToWorld({
    x: Math.min(
      1,
      Math.max(
        0,
        (viewport.left + viewport.width / 2 - canvas.left) / canvas.width,
      ),
    ),
    y: Math.min(
      1,
      Math.max(
        0,
        (viewport.top + viewport.height / 2 - canvas.top) / canvas.height,
      ),
    ),
  })
}

function mapToWorld(coords: MapPoint): MapPoint {
  return {
    x: coords.x / mapScale.x + mapOrigin.x,
    y: coords.y / mapScale.y + mapOrigin.y,
  }
}

function mapWorldToPercent(coords: MapPoint): MapPoint {
  if (mapStyle.value === 'default') return defaultMapWorldToPercent(coords)
  const world = mapToWorld(coords)
  return {
    x: Math.min(
      1,
      Math.max(
        0,
        (world.x - mapBounds.minX) / (mapBounds.maxX - mapBounds.minX),
      ),
    ),
    y: Math.min(
      1,
      Math.max(
        0,
        (mapBounds.maxY - world.y) / (mapBounds.maxY - mapBounds.minY),
      ),
    ),
  }
}

function mapPercentToWorld(point: MapPoint): MapPoint {
  if (mapStyle.value === 'default') return defaultMapPercentToWorld(point)
  const projected = {
    x: mapBounds.minX + point.x * (mapBounds.maxX - mapBounds.minX),
    y: mapBounds.maxY - point.y * (mapBounds.maxY - mapBounds.minY),
  }
  return {
    x: (projected.x - mapOrigin.x) * mapScale.x,
    y: (projected.y - mapOrigin.y) * mapScale.y,
  }
}

function cycleMapStyle(): void {
  const currentIndex = mapStyles.findIndex(
    (style) => style.id === mapStyle.value,
  )
  mapStyle.value = mapStyles[(currentIndex + 1) % mapStyles.length].id
}

async function onMapImageLoad(event: Event): Promise<void> {
  const image = event.target as HTMLImageElement
  const loadedStyle = mapStyle.value
  mapAspect.value =
    loadedStyle === 'default'
      ? defaultMapCoordinates.width / defaultMapCoordinates.height
      : image.naturalWidth / image.naturalHeight

  await nextTick()
  if (!image.isConnected || mapStyle.value !== loadedStyle) return

  mapMaxZoom.value =
    loadedStyle === 'default'
      ? 8
      : Math.max(
          0.85,
          Math.min(
            8,
            image.naturalWidth / Math.max(1, image.offsetWidth),
            image.naturalHeight / Math.max(1, image.offsetHeight),
          ),
        )
  if (zoom.value > mapMaxZoom.value) setZoomAt(mapMaxZoom.value)
}

function t(path: string, replacements: Record<string, string> = {}): string {
  return phone.t(`Apps.crewlink.${path}`, replacements)
}

function errorText(code?: string): string {
  const key = code ?? crew.error ?? 'request_failed'
  const translated = t(`errors.${key}`)
  return translated === `Apps.crewlink.errors.${key}`
    ? t('errors.request_failed')
    : translated
}

function showToast(message: string): void {
  if (toastTimer) window.clearTimeout(toastTimer)
  toastText.value = message
  toastTimer = window.setTimeout(() => {
    toastText.value = ''
  }, 2400)
}

function switchAuthMode(mode: 'login' | 'register'): void {
  authMode.value = mode
  authProfilePhoto.value = null
  authPassword.value = ''
  authUsername.value =
    mode === 'register'
      ? (account.email.split('@')[0] ?? '')
          .replace(/[^a-z0-9._]/gi, '_')
          .slice(0, 20)
      : ''
  authError.value = ''
}

function authErrorText(code?: string): string {
  const known = [
    'invalid_credentials',
    'invalid_password',
    'invalid_profile_image',
    'invalid_username',
    'no_ifruit_account',
    'profile_exists',
    'profile_not_found',
    'rate_limited',
    'username_taken',
  ]
  return t(
    `authErrors.${code && known.includes(code) ? code : 'request_failed'}`,
  )
}

async function submitAuthentication(): Promise<void> {
  authError.value = ''
  if (!account.email) {
    authError.value = authErrorText('no_ifruit_account')
    return
  }
  if (authPassword.value.length < 8 || authPassword.value.length > 72) {
    authError.value = authErrorText('invalid_password')
    return
  }
  if (authMode.value === 'register' && !authUsernameValid.value) {
    authError.value = authErrorText('invalid_username')
    return
  }

  const submittedUsername = authUsername.value.trim()
  authPending.value = true
  const response =
    authMode.value === 'login'
      ? await crew.login(authPassword.value)
      : await crew.register(
          submittedUsername,
          authPassword.value,
          authProfilePhoto.value?.id ?? 0,
        )
  authPending.value = false
  if (!response.success || !crew.profile) {
    authError.value = authErrorText(response.error)
    return
  }

  appAuth.signIn('crewlink', account.email)
  username.value = crew.profile?.username ?? submittedUsername
  authUsername.value = ''
  authPassword.value = ''
  authProfilePhoto.value = null
  openSharedInvite()
}

async function handleLoggedOut(): Promise<void> {
  await crew.logout()
  activeTab.value = 'map'
  authPassword.value = ''
}

function openAuthMedia(app: 'camera' | 'photos'): void {
  messageMedia.begin(
    'crewlink:auth-avatar',
    'photo',
    '/apps/crewlink?auth=register',
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

function shareProfile(): void {
  const profile = crew.profile
  if (!profile) return
  useEasyShareStore().open({
    appId: 'crewlink',
    copyText: `@${profile.username}`,
    id: profile.id,
    kind: 'profile',
    link: `skyphone://crewlink/profile/${profile.id}`,
    subtitle: activeGroup.value?.name,
    title: `@${profile.username}`,
  })
}

function shareGroupInvite(): void {
  const group = activeGroup.value
  if (!group?.inviteCode) return
  useEasyShareStore().open({
    appId: 'crewlink',
    copyText: t('shareInviteBody', {
      code: group.inviteCode,
      group: group.name,
    }),
    id: group.inviteCode,
    kind: 'link',
    link: `skyphone://crewlink/invite/${group.inviteCode}`,
    subtitle: group.inviteCode,
    title: t('shareInviteTitle', { group: group.name }),
  })
}

function openSharedInvite(): void {
  if (!sharedInviteCode.value || !crew.profile) return
  openSheet('join-group')
  inviteCode.value = sharedInviteCode.value
  sharedInviteCode.value = null
}

function updateValue(
  target: 'username' | 'groupName' | 'inviteCode' | 'pingLabel',
  event: Event,
): void {
  const value = (event.target as HTMLInputElement).value
  if (target === 'username') username.value = value
  else if (target === 'groupName') groupName.value = value
  else if (target === 'inviteCode') inviteCode.value = value
  else pingLabel.value = value
  formError.value = ''
}

function colourValue(colour: CrewLinkColour): string {
  return (
    colours.find((candidate) => candidate.id === colour)?.value ??
    colours[0].value
  )
}

function roleLabel(role: CrewLinkRole): string {
  return t(`roles.${role}`)
}

function memberInitials(member: CrewLinkMember): string {
  return member.username.slice(0, 2).toUpperCase()
}

function markerStyle(
  coords: MapPoint,
  offset = '-50%',
): Record<string, string> {
  const point = mapWorldToPercent(coords)
  const canvasWidth = canvasRef.value?.offsetWidth ?? 0
  const canvasHeight = canvasRef.value?.offsetHeight ?? 0
  return {
    left: `calc(50% + ${pan.value.x + (point.x - 0.5) * canvasWidth * zoom.value}px)`,
    top: `calc(50% + ${pan.value.y + (point.y - 0.5) * canvasHeight * zoom.value}px)`,
    transform: `translate(-50%, ${offset})`,
  }
}

function memberStatus(member: CrewLinkMember): string {
  if (!member.online) return t('status.offline')
  if (!member.coords) return t('status.hidden')
  return t('status.live')
}

function expiresIn(timestamp: number): string {
  const seconds = Math.max(0, Math.ceil((timestamp - Date.now()) / 1000))
  if (seconds >= 60)
    return t('expiresMinutes', { count: String(Math.ceil(seconds / 60)) })
  return t('expiresSeconds', { count: String(seconds) })
}

function openSheet(next: CrewLinkSheet): void {
  sheet.value = next
  formError.value = ''
  if (next === 'create-group') {
    groupName.value = ''
    groupColour.value = 'cyan'
  } else if (next === 'join-group') {
    inviteCode.value = ''
  } else if (next === 'ping') {
    pingType.value = 'meeting'
    pingLabel.value = ''
    pingCoords.value = null
  } else if (next === 'edit-group' && activeGroup.value) {
    groupName.value = activeGroup.value.name
    groupColour.value = activeGroup.value.colour
  }
}

function closeSheet(): void {
  if (crew.isLoading) return
  if (sheet.value === 'ping') pingCoords.value = null
  sheet.value = null
  selectedMember.value = null
  selectedProfilePhoto.value = null
  profileAvatarRemoved.value = false
  formError.value = ''
}

function editOwnProfile(): void {
  if (!crew.profile) return
  username.value = crew.profile.username
  selectedProfilePhoto.value = null
  profileAvatarRemoved.value = false
  formError.value = ''
  sheet.value = 'edit-profile'
}

function openProfileMedia(app: 'camera' | 'photos'): void {
  messageMedia.begin(
    'crewlink:profile-avatar',
    'photo',
    '/apps/crewlink?profileEdit=1',
    1,
    {
      selectedPhoto: selectedProfilePhoto.value,
      username: username.value,
    } satisfies ProfileMediaContext,
  )
  void router.push({
    path: `/apps/${app}`,
    query: { mediaAttachment: 'photo' },
  })
}

function removeProfilePhoto(): void {
  selectedProfilePhoto.value = null
  profileAvatarRemoved.value = true
}

async function createGroup(): Promise<void> {
  const response = await crew.createGroup(
    groupName.value.trim(),
    groupColour.value,
  )
  if (!response.success) {
    formError.value = errorText(response.error)
    return
  }
  closeSheet()
  activeTab.value = 'map'
  showToast(t('groupCreated'))
}

async function joinGroup(): Promise<void> {
  const response = await crew.joinCode(inviteCode.value.trim().toUpperCase())
  if (!response.success) {
    formError.value = errorText(response.error)
    return
  }
  closeSheet()
  activeTab.value = 'map'
  showToast(t('joinedGroup'))
}

async function switchGroup(groupId: string): Promise<void> {
  if (groupId === activeGroup.value?.id) return
  const response = await crew.setActive(groupId)
  if (!response.success) showToast(errorText(response.error))
  else {
    await nextTick()
    fitOnlineMembers()
    showToast(t('activeGroupChanged'))
  }
}

async function saveProfile(): Promise<void> {
  if (!crew.profile) return
  const avatarMediaId =
    selectedProfilePhoto.value?.id ??
    (profileAvatarRemoved.value ? 0 : crew.profile.avatarMediaId)
  const response = await crew.updateProfile(
    username.value.trim(),
    crew.profile.mapVisible,
    crew.profile.overheadVisible,
    avatarMediaId,
  )
  if (!response.success) formError.value = errorText(response.error)
  else {
    closeSheet()
    showToast(t('profileSaved'))
  }
}

async function updateVisibility(
  key: 'mapVisible' | 'overheadVisible',
): Promise<void> {
  if (!crew.profile || pendingVisibility.value) return
  const previous = crew.profile[key]
  crew.profile[key] = !previous
  pendingVisibility.value = key
  const response = await crew.updateProfile(
    crew.profile.username,
    crew.profile.mapVisible,
    crew.profile.overheadVisible,
  )
  pendingVisibility.value = null
  if (!response.success) {
    if (crew.profile) crew.profile[key] = previous
    showToast(errorText(response.error))
  }
}

async function saveGroup(): Promise<void> {
  if (!activeGroup.value) return
  const response = await crew.updateGroup(
    activeGroup.value.id,
    groupName.value.trim(),
    groupColour.value,
    activeGroup.value.allowMemberPings,
    activeGroup.value.overheadAllowed,
  )
  if (!response.success) {
    formError.value = errorText(response.error)
    return
  }
  closeSheet()
  showToast(t('groupSaved'))
}

async function toggleGroupSetting(
  key: 'allowMemberPings' | 'overheadAllowed',
): Promise<void> {
  if (!activeGroup.value || pendingGroupSetting.value) return
  const groupId = activeGroup.value.id
  const previous = activeGroup.value[key]
  activeGroup.value[key] = !previous
  pendingGroupSetting.value = key
  const response = await crew.updateGroup(
    groupId,
    activeGroup.value.name,
    activeGroup.value.colour,
    activeGroup.value.allowMemberPings,
    activeGroup.value.overheadAllowed,
  )
  pendingGroupSetting.value = null
  if (!response.success) {
    if (activeGroup.value?.id === groupId) activeGroup.value[key] = previous
    showToast(errorText(response.error))
  }
}

function startPingPlacement(): void {
  sheet.value = null
  formError.value = ''
  pingType.value = 'meeting'
  pingLabel.value = ''
  pingCoords.value = null
  placingPing.value = true
  activeTab.value = 'map'
}

function resumePingPlacement(): void {
  sheet.value = null
  formError.value = ''
  placingPing.value = true
  activeTab.value = 'map'
}

function cancelPingPlacement(): void {
  placingPing.value = false
  pingCoords.value = null
}

function confirmPingPlacement(): void {
  const center = readMapCenterCoords()
  if (!center) {
    showToast(errorText())
    return
  }
  pingCoords.value = { x: center.x, y: center.y }
  placingPing.value = false
  sheet.value = 'ping'
}

function copyInviteCode(): void {
  if (!activeGroup.value?.inviteCode) return
  showToast(
    copyText(activeGroup.value.inviteCode) ? t('codeCopied') : errorText(),
  )
}

async function rotateInviteCode(): Promise<void> {
  if (!activeGroup.value) return
  const response = await crew.rotateCode(activeGroup.value.id)
  if (!response.success) showToast(errorText(response.error))
  else {
    await crew.bootstrap()
    showToast(t('codeRotated'))
  }
}

async function loadNearby(): Promise<void> {
  openSheet('nearby')
  nearbyPlayers.value = []
  const response = await crew.nearby()
  if (!response.success) formError.value = errorText(response.error)
  else nearbyPlayers.value = response.data ?? []
}

async function inviteNearby(player: CrewLinkNearbyPlayer): Promise<void> {
  const response = await crew.inviteNearby(player.source)
  if (!response.success) {
    formError.value = errorText(response.error)
    return
  }
  nearbyPlayers.value = nearbyPlayers.value.filter(
    (candidate) => candidate.source !== player.source,
  )
  showToast(t('inviteSent', { username: player.username }))
}

async function respondInvitation(id: string, accepted: boolean): Promise<void> {
  const response = await crew.respondInvite(id, accepted)
  if (!response.success) showToast(errorText(response.error))
  else {
    if (accepted) {
      closeSheet()
      activeTab.value = 'map'
    }
    showToast(t(accepted ? 'inviteAccepted' : 'inviteDeclined'))
  }
}

function selectMember(member: CrewLinkMember): void {
  if (member.id === crew.profile?.id) return
  selectedMember.value = member
  openSheet('member')
}

async function setMemberRole(role: CrewLinkRole): Promise<void> {
  if (!activeGroup.value || !selectedMember.value) return
  if (selectedMember.value.role === role) return
  const response = await crew.updateMember(
    activeGroup.value.id,
    selectedMember.value.id,
    role,
  )
  if (!response.success) showToast(errorText(response.error))
  else {
    closeSheet()
    showToast(t('roleUpdated'))
  }
}

async function performConfirmedAction(): Promise<void> {
  const action = confirmAction.value
  confirmAction.value = null
  if (!activeGroup.value) return
  let response
  if (action === 'delete-group')
    response = await crew.deleteGroup(activeGroup.value.id)
  else if (action === 'leave-group')
    response = await crew.leave(activeGroup.value.id)
  else if (action === 'remove-member' && selectedMember.value) {
    response = await crew.removeMember(
      activeGroup.value.id,
      selectedMember.value.id,
    )
  } else if (action === 'transfer-owner' && selectedMember.value) {
    response = await crew.transferOwner(
      activeGroup.value.id,
      selectedMember.value.id,
    )
  }
  if (!response?.success) showToast(errorText(response?.error))
  else {
    closeSheet()
    await crew.bootstrap()
    showToast(t(`${action}Done`))
  }
}

function cancelConfirmation(): void {
  confirmAction.value = null
}

async function createPing(): Promise<void> {
  if (!pingCoords.value) {
    formError.value = errorText()
    return
  }
  const response = await crew.createPing(
    pingType.value,
    pingLabel.value.trim(),
    { x: pingCoords.value.x, y: pingCoords.value.y, z: 0 },
  )
  if (!response.success) {
    formError.value = errorText(response.error)
    return
  }
  closeSheet()
  activeTab.value = 'map'
  await crew.refreshLive()
  showToast(t('pingCreated'))
}

async function removePing(ping: CrewLinkPing): Promise<void> {
  const response = await crew.removePing(ping.id)
  if (!response.success) showToast(errorText(response.error))
  else {
    selectedPing.value = null
    await crew.refreshLive()
    showToast(t('pingRemoved'))
  }
}

async function routeTo(coords: {
  x: number
  y: number
  z: number
}): Promise<void> {
  const response = await nuiCall('map:setWaypoint', { coords })
  showToast(t(response.success ? 'routeSet' : 'errors.request_failed'))
}

function routeToSelectedMember(): void {
  if (!selectedMember.value?.coords) return
  void routeTo(selectedMember.value.coords)
  selectedMember.value = null
}

function routeToSelectedPing(): void {
  if (!selectedPing.value) return
  void routeTo(selectedPing.value.coords)
  selectedPing.value = null
}

function centerOn(coords: MapPoint): void {
  const viewport = viewportRef.value?.getBoundingClientRect()
  const canvas = canvasRef.value
  if (!viewport || !canvas) return
  const point = mapWorldToPercent(coords)
  const nextZoom = Math.min(3.8, mapMaxZoom.value)
  zoom.value = nextZoom
  pan.value = {
    x: (0.5 - point.x) * canvas.offsetWidth * nextZoom,
    y: (0.5 - point.y) * canvas.offsetHeight * nextZoom,
  }
}

function fitOnlineMembers(): void {
  const viewport = viewportRef.value
  const canvas = canvasRef.value
  const points = visibleMapMembers.value.map((member) =>
    mapWorldToPercent(member.coords!),
  )
  if (!viewport || !canvas || !points.length) return

  const minX = Math.min(...points.map((point) => point.x))
  const maxX = Math.max(...points.map((point) => point.x))
  const minY = Math.min(...points.map((point) => point.y))
  const maxY = Math.max(...points.map((point) => point.y))
  const horizontalSpan = Math.max(80, (maxX - minX) * canvas.offsetWidth)
  const verticalSpan = Math.max(80, (maxY - minY) * canvas.offsetHeight)
  const nextZoom = Math.max(
    1.25,
    Math.min(
      mapMaxZoom.value,
      (viewport.clientWidth - 90) / horizontalSpan,
      (viewport.clientHeight - 120) / verticalSpan,
    ),
  )
  const center = {
    x: (minX + maxX) / 2,
    y: (minY + maxY) / 2,
  }

  zoom.value = nextZoom
  pan.value = {
    x: (0.5 - center.x) * canvas.offsetWidth * nextZoom,
    y: (0.5 - center.y) * canvas.offsetHeight * nextZoom,
  }
}

function centerOwnLocation(): void {
  const own = ownMember.value?.coords
  if (own) centerOn(own)
  else showToast(t('locationUnavailable'))
}

function setZoomAt(nextZoom: number, clientX?: number, clientY?: number): void {
  const viewport = viewportRef.value
  const currentZoom = zoom.value
  const clampedZoom = Math.max(0.85, Math.min(mapMaxZoom.value, nextZoom))
  if (!viewport || clampedZoom === currentZoom) return

  const bounds =
    readPhoneViewportGeometry(viewport)?.rect(viewport) ??
    viewport.getBoundingClientRect()
  if (!bounds.width || !bounds.height) return
  const focal = {
    x:
      clientX === undefined
        ? viewport.clientWidth / 2
        : ((clientX - bounds.left) * viewport.clientWidth) / bounds.width,
    y:
      clientY === undefined
        ? viewport.clientHeight / 2
        : ((clientY - bounds.top) * viewport.clientHeight) / bounds.height,
  }
  pan.value = zoomPanAtPoint(pan.value, currentZoom, clampedZoom, focal, {
    x: viewport.clientWidth,
    y: viewport.clientHeight,
  })
  zoom.value = clampedZoom
}

function changeZoom(direction: -1 | 1): void {
  setZoomAt(zoom.value * (direction > 0 ? 1.25 : 0.8))
}

function onPointerDown(event: PointerEvent): void {
  if (event.pointerType === 'mouse' && event.button !== 0) return
  isPointerDown.value = true
  pointerStart.x = event.clientX
  pointerStart.y = event.clientY
  pointerStart.panX = pan.value.x
  pointerStart.panY = pan.value.y
  pointerLatest.x = event.clientX
  pointerLatest.y = event.clientY
  ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
}

function onPointerMove(event: PointerEvent): void {
  if (!isPointerDown.value) return
  pointerLatest.x = event.clientX
  pointerLatest.y = event.clientY
  if (pointerFrame) return
  pointerFrame = requestAnimationFrame(() => {
    pointerFrame = undefined
    const viewport = viewportRef.value
    if (!viewport) return
    const bounds =
      readPhoneViewportGeometry(viewport)?.rect(viewport) ??
      viewport.getBoundingClientRect()
    if (!bounds.width || !bounds.height) return
    pan.value = {
      x:
        pointerStart.panX +
        ((pointerLatest.x - pointerStart.x) * viewport.clientWidth) /
          bounds.width,
      y:
        pointerStart.panY +
        ((pointerLatest.y - pointerStart.y) * viewport.clientHeight) /
          bounds.height,
    }
  })
}

function onPointerUp(event: PointerEvent): void {
  isPointerDown.value = false
  const target = event.currentTarget as HTMLElement
  if (target.hasPointerCapture(event.pointerId)) {
    target.releasePointerCapture(event.pointerId)
  }
}

function onWheel(event: WheelEvent): void {
  event.preventDefault()
  const viewportHeight = viewportRef.value?.clientHeight ?? 1
  const pixelDelta =
    event.deltaMode === 1
      ? event.deltaY * 16
      : event.deltaMode === 2
        ? event.deltaY * viewportHeight
        : event.deltaY
  const limitedDelta = Math.max(-120, Math.min(120, pixelDelta))
  setZoomAt(
    zoom.value * Math.exp(-limitedDelta * 0.0018),
    event.clientX,
    event.clientY,
  )
}

function onCrewLinkMessage(event: MessageEvent): void {
  if (!isTrustedRootMessageSource(event.source, window)) return
  if (event.data?.type === 'crewlink:changed') void crew.bootstrap()
}

function onKeydown(event: KeyboardEvent): void {
  if (
    !confirmAction.value &&
    !sheet.value &&
    !selectedMember.value &&
    !selectedPing.value &&
    !placingPing.value
  ) {
    return
  }
  if (!consumeEscape(event)) return

  if (confirmAction.value) {
    cancelConfirmation()
  } else if (sheet.value) {
    closeSheet()
  } else if (selectedMember.value) {
    selectedMember.value = null
  } else if (selectedPing.value) {
    selectedPing.value = null
  } else {
    cancelPingPlacement()
  }
}

onMounted(async () => {
  window.addEventListener('keydown', onKeydown, true)
  const authSelection = messageMedia.consumeMany<AuthMediaContext>(
    'crewlink:auth-avatar',
  )
  const profileSelection = messageMedia.consumeMany<ProfileMediaContext>(
    'crewlink:profile-avatar',
  )
  if (authSelection) {
    authMode.value = authSelection.context?.mode ?? 'register'
    authUsername.value = authSelection.context?.username ?? ''
    authProfilePhoto.value =
      authSelection.media[0] ?? authSelection.context?.selectedPhoto ?? null
  }
  if (appAuth.isSignedIn('crewlink')) {
    await crew.bootstrap()
    if (!crew.authenticated) appAuth.signOut('crewlink')
  }
  username.value = crew.profile?.username ?? ''
  if (profileSelection && crew.profile) {
    username.value = profileSelection.context?.username ?? crew.profile.username
    selectedProfilePhoto.value =
      profileSelection.media[0] ??
      profileSelection.context?.selectedPhoto ??
      null
    profileAvatarRemoved.value = false
    activeTab.value = 'profile'
    sheet.value = 'edit-profile'
  }
  openSharedInvite()
  await nextTick()
  fitOnlineMembers()
  liveTimer = window.setInterval(() => void crew.refreshLive(), 3000)
  window.addEventListener('message', onCrewLinkMessage)
})

onBeforeUnmount(() => {
  if (liveTimer) window.clearInterval(liveTimer)
  if (toastTimer) window.clearTimeout(toastTimer)
  if (pointerFrame) cancelAnimationFrame(pointerFrame)
  window.removeEventListener('keydown', onKeydown, true)
  window.removeEventListener('message', onCrewLinkMessage)
})
</script>

<template>
  <sky-app-page
    class="crewlink"
    :class="{ 'crewlink--dark': phone.isDarkMode }"
  >
    <template v-if="!appAuth.isSignedIn('crewlink')">
      <div class="crewlink-onboarding crewlink-auth">
        <AppProfileAuth
          :mode="authMode"
          v-model:password="authPassword"
          v-model:username="authUsername"
          :avatar-url="authProfilePhoto?.url ?? null"
          :body="t('authBody')"
          :camera-label="t('camera')"
          :email="account.email"
          :email-label="t('ifruitEmail')"
          :error="authError"
          :eyebrow="t('authEyebrow')"
          :gallery-label="t('gallery')"
          :login-label="t('login')"
          :max-username-length="20"
          :min-username-length="3"
          :pending="authPending"
          :password-label="t('password')"
          :password-placeholder="t('passwordPlaceholder')"
          :register-label="t('register')"
          require-password
          :title="t('authTitle')"
          :username-label="t('username')"
          :username-placeholder="t('usernamePlaceholder')"
          variant="centered"
          @camera="openAuthMedia('camera')"
          @gallery="openAuthMedia('photos')"
          @submit="submitAuthentication"
          @update:mode="switchAuthMode"
        />
      </div>
    </template>

    <template v-else-if="crew.isLoading && !crew.profile && !crew.error">
      <div class="crewlink-loading">
        <span class="crewlink-logo"><Radio /></span>
        <sky-spinner />
        <p>{{ t('connecting') }}</p>
      </div>
    </template>

    <template v-else-if="crew.error === 'not_authenticated'">
      <div class="crewlink-onboarding">
        <span class="crewlink-logo"><Users /></span>
        <small>{{ t('privateNetwork') }}</small>
        <h1>{{ t('signInTitle') }}</h1>
        <p>{{ t('signInBody') }}</p>
        <sky-button large rounded @click="appAuth.signOut('crewlink')">
          {{ t('backToLogin') }}
        </sky-button>
      </div>
    </template>

    <template v-else-if="crew.profile">
      <sky-navbar
        v-if="activeGroup"
        class="crewlink-navbar"
        :class="{ 'crewlink-navbar--map': activeTab === 'map' }"
        :subtitle="headerSubtitle"
        :title="headerTitle"
      />

      <main
        class="crewlink-content"
        :class="{
          'crewlink-content--empty': !activeGroup,
          'crewlink-content--placing': placingPing,
        }"
      >
        <section v-if="!activeGroup" class="crewlink-group-gate">
          <button type="button" @click="openSheet('create-group')">
            <span><Plus /></span>
            <strong>{{ t('createGroup') }}</strong>
          </button>
          <button type="button" @click="openSheet('join-group')">
            <span><UserPlus /></span>
            <strong>{{ t('joinGroup') }}</strong>
          </button>
          <sky-button
            large
            rounded
            outline
            class="crewlink-group-gate__logout"
            @click="logoutDialogOpen = true"
          >
            <LogOut />{{ phone.t('Common.signOut') }}
          </sky-button>
        </section>

        <template v-else>
          <section v-show="activeTab === 'map'" class="crewlink-map-tab">
            <div class="crewlink-map-summary">
              <div>
                <span class="crewlink-live-dot"></span>
                <strong>{{ onlineMembers.length }}</strong>
                <small>{{ t('onlineNow') }}</small>
              </div>
              <div class="crewlink-online-faces">
                <span
                  v-for="member in onlineMembers.slice(0, 4)"
                  :key="member.id"
                  :style="{ borderColor: activeColour }"
                  >{{ memberInitials(member) }}</span
                >
                <i v-if="onlineMembers.length > 4"
                  >+{{ onlineMembers.length - 4 }}</i
                >
              </div>
            </div>

            <div
              ref="viewportRef"
              class="crewlink-map"
              @pointerdown="onPointerDown"
              @pointermove="onPointerMove"
              @pointerup="onPointerUp"
              @pointercancel="onPointerUp"
              @wheel="onWheel"
            >
              <div
                ref="canvasRef"
                class="crewlink-map__canvas"
                :style="canvasStyle"
              >
                <img
                  :src="mapImageUrl"
                  alt=""
                  class="crewlink-map__mainland"
                  :class="{
                    'crewlink-map__mainland--default': mapStyle === 'default',
                  }"
                  :style="
                    mapStyle === 'default' ? defaultMainlandStyle : undefined
                  "
                  draggable="false"
                  @load="onMapImageLoad"
                />
                <img
                  v-if="mapStyle === 'default'"
                  :src="cayoMapUrl"
                  alt=""
                  class="crewlink-map__cayo"
                  :style="defaultCayoStyle"
                  draggable="false"
                />
              </div>
              <button
                v-for="member in visibleMapMembers"
                :key="member.id"
                type="button"
                class="crewlink-member-marker"
                :class="{ 'is-self': member.id === crew.profile?.id }"
                :style="{
                  ...markerStyle(member.coords!),
                  ...activeCrewStyle,
                }"
                @pointerdown.stop
                @click.stop="selectedMember = member"
              >
                <span>
                  <img v-if="member.avatarUrl" :src="member.avatarUrl" alt="" />
                  <template v-else>{{ memberInitials(member) }}</template>
                </span>
                <small>{{ member.username }}</small>
              </button>
              <button
                v-for="ping in activeGroup.pings"
                :key="ping.id"
                type="button"
                class="crewlink-ping-marker"
                :style="{
                  ...markerStyle(ping.coords, '-100%'),
                  '--ping': pingColours[ping.type],
                }"
                @pointerdown.stop
                @click.stop="selectedPing = ping"
              >
                <component :is="pingIcons[ping.type]" />
                <small>{{ ping.label }}</small>
              </button>
              <div v-if="placingPing" class="crewlink-map-crosshair">
                <Crosshair />
              </div>
              <div class="crewlink-map-controls">
                <button
                  type="button"
                  :aria-label="t('zoomIn')"
                  @pointerdown.stop
                  @click="changeZoom(1)"
                >
                  +
                </button>
                <button
                  type="button"
                  :aria-label="t('zoomOut')"
                  @pointerdown.stop
                  @click="changeZoom(-1)"
                >
                  −
                </button>
                <button
                  type="button"
                  :aria-label="t('myLocation')"
                  @pointerdown.stop
                  @click="centerOwnLocation"
                >
                  <LocateFixed />
                </button>
                <button
                  type="button"
                  :aria-label="`${t('members')} · ${t('map')}`"
                  @pointerdown.stop
                  @click="fitOnlineMembers"
                >
                  <Users />
                </button>
                <button
                  type="button"
                  :aria-label="`${phone.t('Apps.map.switchStyle')}: ${phone.t(`Apps.map.styles.${mapStyle}`)}`"
                  @pointerdown.stop
                  @click="cycleMapStyle"
                >
                  <component :is="activeMapStyle.icon" />
                </button>
              </div>
              <div v-if="!placingPing" class="crewlink-map-legend">
                <span><i class="is-live"></i>{{ t('status.live') }}</span>
                <span><i class="is-hidden"></i>{{ t('status.hidden') }}</span>
              </div>
            </div>

            <div v-if="placingPing" class="crewlink-ping-placement">
              <div>
                <strong>{{ t('placeOnMap') }}</strong>
                <small>{{ t('placeOnMapBody') }}</small>
              </div>
              <div>
                <sky-button rounded outline @click="cancelPingPlacement">
                  {{ phone.t('Common.cancel') }}
                </sky-button>
                <sky-button rounded @click="confirmPingPlacement">
                  <MapPin />{{ t('addHere') }}
                </sky-button>
              </div>
            </div>

            <div v-else class="crewlink-map-actions">
              <button type="button" @click="activeTab = 'group'">
                <Users /><span
                  ><strong
                    >{{ activeGroup.memberCount }}
                    {{
                      t(activeGroup.memberCount === 1 ? 'member' : 'members')
                    }}</strong
                  ><small>{{ t('openCrew') }}</small></span
                >
              </button>
              <button
                type="button"
                :disabled="!canPing"
                @click="startPingPlacement"
              >
                <MapPin /><span
                  ><strong>{{ t('newPing') }}</strong
                  ><small>{{ t('shareLocation') }}</small></span
                >
              </button>
            </div>
          </section>

          <section
            v-show="activeTab === 'group'"
            class="crewlink-scroll-tab crewlink-group-tab"
          >
            <div class="crewlink-group-hero" :style="activeCrewStyle">
              <div class="crewlink-group-hero__signal"><Radio /></div>
              <small>{{ t('activeCrew') }}</small>
              <h1>{{ activeGroup.name }}</h1>
              <p>
                {{
                  t(
                    activeGroup.memberCount === 1
                      ? 'groupSummarySingle'
                      : 'groupSummary',
                    {
                      online: String(onlineMembers.length),
                      total: String(activeGroup.memberCount),
                    },
                  )
                }}
              </p>
              <div>
                <sky-badge class="crewlink-group-badge">{{
                  roleLabel(activeGroup.role)
                }}</sky-badge>
                <sky-badge class="crewlink-group-badge">{{
                  t('private')
                }}</sky-badge>
              </div>
            </div>

            <div class="crewlink-quick-actions">
              <button v-if="canModerate" type="button" @click="loadNearby">
                <UserPlus /><span>{{ t('nearby') }}</span>
              </button>
              <button
                v-if="activeGroup.inviteCode"
                type="button"
                @click="copyInviteCode"
              >
                <Copy /><span>{{ t('copyCode') }}</span>
              </button>
              <button
                v-if="activeGroup.inviteCode"
                type="button"
                @click="shareGroupInvite"
              >
                <Share2 /><span>{{ t('shareInvite') }}</span>
              </button>
              <button
                v-if="canCoordinate"
                type="button"
                @click="openSheet('edit-group')"
              >
                <Settings2 /><span>{{ t('manage') }}</span>
              </button>
            </div>

            <template v-if="crew.invitations.length">
              <sky-block-title>{{ t('pendingInvitations') }}</sky-block-title>
              <div class="crewlink-invitations crewlink-invitations--inline">
                <sky-card v-for="invite in crew.invitations" :key="invite.id">
                  <div class="crewlink-invite-card">
                    <i :style="{ background: colourValue(invite.colour) }"
                      ><Users
                    /></i>
                    <div>
                      <strong>{{ invite.groupName }}</strong
                      ><span>{{
                        t('invitedBy', { username: invite.inviterUsername })
                      }}</span>
                    </div>
                    <button
                      type="button"
                      @click="respondInvitation(invite.id, false)"
                    >
                      <X />
                    </button>
                    <button
                      type="button"
                      class="is-accept"
                      @click="respondInvitation(invite.id, true)"
                    >
                      <Check />
                    </button>
                  </div>
                </sky-card>
              </div>
            </template>

            <sky-block-title class="crewlink-members-title">{{
              t(activeGroup.memberCount === 1 ? 'member' : 'members')
            }}</sky-block-title>
            <sky-list inset strong class="crewlink-member-list">
              <sky-list-item
                v-for="member in activeGroup.members"
                :key="member.id"
                :link="member.id !== crew.profile?.id && canModerate"
                @click="selectMember(member)"
              >
                <template #title
                  ><span class="crewlink-member-title">{{
                    member.username
                  }}</span></template
                >
                <template #subtitle
                  ><span class="crewlink-member-subtitle"
                    >{{ roleLabel(member.role) }} ·
                    {{ memberStatus(member) }}</span
                  ></template
                >
                <template #media>
                  <span
                    class="crewlink-avatar"
                    :style="{ '--crew': activeColour }"
                  >
                    <img
                      v-if="member.avatarUrl"
                      :src="member.avatarUrl"
                      alt=""
                    />
                    <template v-else>{{ memberInitials(member) }}</template>
                    <i :class="{ 'is-online': member.online }"></i>
                  </span>
                </template>
                <template #after>
                  <component
                    :is="roleIcons[member.role]"
                    :size="17"
                    :class="`role-${member.role}`"
                  />
                </template>
              </sky-list-item>
            </sky-list>
          </section>

          <section
            v-show="activeTab === 'pings'"
            class="crewlink-scroll-tab crewlink-pings-tab"
          >
            <div class="crewlink-section-header">
              <span><MapPin /></span>
              <div>
                <small>{{ t('liveCoordination') }}</small>
                <h1>{{ t('pings') }}</h1>
              </div>
              <button v-if="canPing" type="button" @click="startPingPlacement">
                <Plus />
              </button>
            </div>
            <div v-if="activeGroup.pings.length" class="crewlink-ping-list">
              <sky-card
                v-for="ping in activeGroup.pings"
                :key="ping.id"
                :content-wrap="false"
              >
                <article>
                  <i :style="{ background: pingColours[ping.type] }"
                    ><component :is="pingIcons[ping.type]"
                  /></i>
                  <div>
                    <small
                      >{{ t(`pingTypes.${ping.type}`) }} ·
                      {{ expiresIn(ping.expiresAt) }}</small
                    ><strong>{{ ping.label }}</strong
                    ><span>{{
                      t('sharedBy', { username: ping.creatorUsername })
                    }}</span>
                  </div>
                  <button
                    type="button"
                    :aria-label="t('setRoute')"
                    @click="routeTo(ping.coords)"
                  >
                    <Navigation />
                  </button>
                  <button
                    v-if="
                      ping.creatorProfileId === crew.profile?.id || canModerate
                    "
                    type="button"
                    :aria-label="phone.t('Common.delete')"
                    @click="removePing(ping)"
                  >
                    <Trash2 />
                  </button>
                </article>
              </sky-card>
            </div>
            <div v-else class="crewlink-empty-state">
              <span><CircleDot /></span>
              <h2>{{ t('noPings') }}</h2>
              <p>{{ t('noPingsBody') }}</p>
            </div>
          </section>

          <section
            v-show="activeTab === 'profile'"
            class="crewlink-scroll-tab crewlink-profile-tab"
          >
            <div
              class="crewlink-profile-card"
              :style="{ '--crew': activeColour }"
            >
              <span>
                <img
                  v-if="crew.profile.avatarUrl"
                  :src="crew.profile.avatarUrl"
                  alt=""
                />
                <template v-else>{{
                  crew.profile.username.slice(0, 2).toUpperCase()
                }}</template>
              </span>
              <div>
                <small>{{ t('yourCrewLinkId') }}</small>
                <h1>@{{ crew.profile.username }}</h1>
                <p>
                  {{ activeGroup.name }} · {{ roleLabel(activeGroup.role) }}
                </p>
              </div>
            </div>

            <sky-list inset strong>
              <sky-list-item
                :title="t('editProfile')"
                :subtitle="t('editProfileBody')"
                link
                @click="editOwnProfile"
              >
                <template #media>
                  <span class="crewlink-profile-row-avatar">
                    <img
                      v-if="crew.profile.avatarUrl"
                      :src="crew.profile.avatarUrl"
                      alt=""
                    />
                    <UserRound v-else :size="20" />
                  </span>
                </template>
              </sky-list-item>
              <sky-list-item
                link
                link-component="button"
                :title="phone.t('Apps.easyShare.shareProfile')"
                @click="shareProfile"
              >
                <template #media><Share2 :size="20" /></template>
              </sky-list-item>
            </sky-list>

            <sky-block-title>{{ t('privacyVisibility') }}</sky-block-title>
            <sky-list inset strong>
              <sky-list-item
                :title="t('shareOnMap')"
                :subtitle="t('shareOnMapBody')"
              >
                <template #media><MapIcon :size="20" /></template>
                <template #after
                  ><sky-toggle
                    :checked="crew.profile.mapVisible"
                    :disabled="pendingVisibility !== null"
                    @click.stop.prevent="updateVisibility('mapVisible')"
                /></template>
              </sky-list-item>
              <sky-list-item
                :title="t('overheadLabels')"
                :subtitle="t('overheadLabelsBody')"
              >
                <template #media><Eye :size="20" /></template>
                <template #after
                  ><sky-toggle
                    :checked="crew.profile.overheadVisible"
                    :disabled="pendingVisibility !== null"
                    @click.stop.prevent="updateVisibility('overheadVisible')"
                /></template>
              </sky-list-item>
            </sky-list>

            <sky-block-title>{{ t('yourGroups') }}</sky-block-title>
            <sky-list inset strong>
              <sky-list-item
                v-for="group in crew.groups"
                :key="group.id"
                :title="group.name"
                :subtitle="`${group.memberCount} ${t('members')} · ${roleLabel(group.role)}`"
                link
                @click="switchGroup(group.id)"
              >
                <template #media
                  ><span
                    class="crewlink-group-dot"
                    :style="{ background: colourValue(group.colour) }"
                    ><Users /></span
                ></template>
                <template #after
                  ><Check
                    v-if="group.id === activeGroup.id"
                    :size="18"
                    :style="{ color: colourValue(group.colour) }"
                /></template>
              </sky-list-item>
              <sky-list-item
                :title="t('createAnotherGroup')"
                link
                @click="openSheet('create-group')"
                ><template #media><Plus :size="20" /></template
              ></sky-list-item>
              <sky-list-item
                :title="t('joinWithCode')"
                link
                @click="openSheet('join-group')"
                ><template #media><UserPlus :size="20" /></template
              ></sky-list-item>
            </sky-list>

            <sky-block-title>{{ t('account') }}</sky-block-title>
            <sky-list inset strong>
              <sky-list-item
                :title="t('externalApi')"
                :subtitle="t('externalApiBody')"
                ><template #media><Sparkles :size="20" /></template
              ></sky-list-item>
              <sky-list-item
                :title="phone.t('Common.signOut')"
                class="crewlink-danger-row"
                link
                @click="logoutDialogOpen = true"
              >
                <template #media><LogOut :size="20" /></template>
              </sky-list-item>
              <sky-list-item
                :title="
                  activeGroup.isOwner ? t('deleteGroup') : t('leaveGroup')
                "
                class="crewlink-danger-row"
                link
                @click="
                  confirmAction = activeGroup.isOwner
                    ? 'delete-group'
                    : 'leave-group'
                "
              >
                <template #media><Trash2 :size="20" /></template>
              </sky-list-item>
            </sky-list>
          </section>
        </template>
      </main>

      <sky-tab-bar
        v-if="activeGroup && !placingPing"
        component="nav"
        icons
        labels
        class="bottom-0 left-0 fixed crewlink-tabbar"
        inner-class="crewlink-tabbar__inner"
        :aria-label="t('navigation')"
      >
        <sky-toolbar-pane class="crewlink-tabbar__pane">
          <sky-tab-button
            component="button"
            :active="activeTab === 'map'"
            :link-props="{ type: 'button' }"
            @click="activeTab = 'map'"
            ><template #label>{{ t('map') }}</template
            ><template #icon
              ><sky-icon><MapIcon /></sky-icon></template
          ></sky-tab-button>
          <sky-tab-button
            component="button"
            :active="activeTab === 'group'"
            :link-props="{ type: 'button' }"
            @click="activeTab = 'group'"
            ><template #label>{{ t('crew') }}</template
            ><template #icon
              ><sky-icon><Users /></sky-icon></template
          ></sky-tab-button>
          <sky-tab-button
            component="button"
            :active="activeTab === 'pings'"
            :link-props="{ type: 'button' }"
            @click="activeTab = 'pings'"
          >
            <template #label>{{ t('pings') }}</template>
            <template #icon>
              <sky-icon>
                <span class="crewlink-pings-icon">
                  <MapPin />
                  <sky-badge
                    v-if="activeGroup.pings.length"
                    small
                    class="crewlink-pings-badge"
                    >{{ activeGroup.pings.length }}</sky-badge
                  >
                </span>
              </sky-icon>
            </template>
          </sky-tab-button>
          <sky-tab-button
            component="button"
            :active="activeTab === 'profile'"
            :link-props="{ type: 'button' }"
            @click="activeTab = 'profile'"
            ><template #label>{{ t('profile') }}</template
            ><template #icon
              ><sky-icon><UserRound /></sky-icon></template
          ></sky-tab-button>
        </sky-toolbar-pane>
      </sky-tab-bar>
    </template>

    <sky-sheet :opened="Boolean(sheet)" @backdropclick="closeSheet">
      <section
        v-if="sheet"
        class="crewlink-sheet__panel__content"
        :class="{
          'crewlink-sheet__panel__content--manage': sheet === 'edit-group',
          'crewlink-sheet__panel__content--ping': sheet === 'ping',
        }"
        role="dialog"
        aria-modal="true"
      >
        <sky-link
          component="button"
          class="crewlink-sheet__panel__close"
          :link-props="{ type: 'button' }"
          :aria-label="phone.t('Common.close')"
          @click="closeSheet"
          ><X
        /></sky-link>

        <template v-if="sheet === 'create-group'">
          <span class="crewlink-sheet__panel__icon"><Users /></span>
          <h2>{{ t('createGroup') }}</h2>
          <p>{{ t('createGroupBody') }}</p>
          <sky-list inset strong class="crewlink-form-list"
            ><sky-field
              input-id="crewlink-group-name"
              :label="t('groupName')"
              :placeholder="t('groupNamePlaceholder')"
              :value="groupName"
              maxlength="32"
              outline
              @input="updateValue('groupName', $event)"
          /></sky-list>
          <span class="crewlink-field-label">{{ t('groupColour') }}</span>
          <div class="crewlink-colours" role="radiogroup">
            <button
              v-for="colour in colours"
              :key="colour.id"
              type="button"
              role="radio"
              :aria-checked="groupColour === colour.id"
              :class="{ 'is-active': groupColour === colour.id }"
              :style="{ background: colour.value }"
              @click="groupColour = colour.id"
            >
              <Check />
            </button>
          </div>
          <p v-if="formError" class="crewlink-error">{{ formError }}</p>
          <sky-button
            large
            rounded
            :disabled="crew.isLoading"
            @click="createGroup"
            >{{ t('createCrew') }}</sky-button
          >
        </template>

        <template v-else-if="sheet === 'join-group'">
          <span class="crewlink-sheet__panel__icon"><UserPlus /></span>
          <h2>{{ t('joinWithCode') }}</h2>
          <p>{{ t('joinWithCodeBody') }}</p>
          <sky-list inset strong class="crewlink-form-list"
            ><sky-field
              input-id="crewlink-invite-code"
              :label="t('inviteCode')"
              :placeholder="t('inviteCodePlaceholder')"
              :value="inviteCode"
              maxlength="8"
              outline
              @input="updateValue('inviteCode', $event)"
              @keydown.enter="handleEnterAction($event, joinGroup)"
          /></sky-list>
          <p v-if="formError" class="crewlink-error">{{ formError }}</p>
          <sky-button
            large
            rounded
            :disabled="crew.isLoading"
            @click="joinGroup"
            >{{ t('joinCrew') }}</sky-button
          >
          <template v-if="crew.invitations.length">
            <sky-block-title class="crewlink-join-invitations-title">{{
              t('pendingInvitations')
            }}</sky-block-title>
            <div class="crewlink-invitations crewlink-invitations--join">
              <sky-card v-for="invite in crew.invitations" :key="invite.id">
                <div class="crewlink-invite-card">
                  <i :style="{ background: colourValue(invite.colour) }"
                    ><Users
                  /></i>
                  <div>
                    <strong>{{ invite.groupName }}</strong
                    ><span>{{
                      t('invitedBy', { username: invite.inviterUsername })
                    }}</span>
                  </div>
                  <button
                    type="button"
                    @click="respondInvitation(invite.id, false)"
                  >
                    <X />
                  </button>
                  <button
                    type="button"
                    class="is-accept"
                    @click="respondInvitation(invite.id, true)"
                  >
                    <Check />
                  </button>
                </div>
              </sky-card>
            </div>
          </template>
        </template>

        <template v-else-if="sheet === 'nearby'">
          <span class="crewlink-sheet__panel__icon"><Radio /></span>
          <h2>{{ t('peopleNearby') }}</h2>
          <p>
            {{
              t('peopleNearbyBody', {
                distance: String(crew.limits?.nearbyDistance ?? 5),
              })
            }}
          </p>
          <sky-spinner v-if="crew.isLoading" />
          <sky-list
            v-else-if="nearbyPlayers.length"
            inset
            strong
            class="crewlink-nearby-list"
          >
            <sky-list-item
              v-for="player in nearbyPlayers"
              :key="player.source"
              class="crewlink-nearby-item"
              content-class="crewlink-nearby-item__content"
              media-class="crewlink-nearby-item__media"
              inner-class="crewlink-nearby-item__inner"
              title-wrap-class="crewlink-nearby-item__title"
              :title="player.username"
              :subtitle="t('metersAway', { distance: String(player.distance) })"
            >
              <template #media
                ><span
                  class="crewlink-avatar"
                  :style="{ '--crew': activeColour }"
                  >{{ player.username.slice(0, 2).toUpperCase() }}</span
                ></template
              >
              <template #after
                ><sky-button
                  small
                  rounded
                  class="crewlink-nearby-invite"
                  @click="inviteNearby(player)"
                  >{{ t('invite') }}</sky-button
                ></template
              >
            </sky-list-item>
          </sky-list>
          <div v-else class="crewlink-sheet__panel-empty">
            <EyeOff /><strong>{{ t('nobodyNearby') }}</strong
            ><span>{{ t('nobodyNearbyBody') }}</span>
          </div>
          <p v-if="formError" class="crewlink-error">{{ formError }}</p>
          <sky-button
            large
            rounded
            outline
            class="crewlink-nearby-rescan"
            @click="loadNearby"
            ><RefreshCw />{{ t('scanAgain') }}</sky-button
          >
        </template>

        <template v-else-if="sheet === 'ping'">
          <span class="crewlink-sheet__panel__icon"><MapPin /></span>
          <h2 class="crewlink-ping-title">{{ t('newPing') }}</h2>
          <p class="crewlink-ping-description">{{ t('newPingBody') }}</p>
          <div class="crewlink-ping-types">
            <button
              v-for="(_, type) in pingIcons"
              :key="type"
              type="button"
              :class="{ 'is-active': pingType === type }"
              :style="{
                '--ping': pingColours[type],
                '--ping-glow': `${pingColours[type]}2e`,
              }"
              @click="pingType = type"
            >
              <component :is="pingIcons[type]" /><span>{{
                t(`pingTypes.${type}`)
              }}</span>
            </button>
          </div>
          <sky-list inset strong class="crewlink-form-list crewlink-ping-form"
            ><sky-field
              input-id="crewlink-ping-label"
              input-class="crewlink-ping-label-input"
              :label="t('pingLabel')"
              :placeholder="t('pingLabelPlaceholder')"
              :value="pingLabel"
              maxlength="48"
              outline
              @input="updateValue('pingLabel', $event)"
          /></sky-list>
          <sky-list inset strong class="crewlink-ping-location-list">
            <sky-list-item
              :title="t('placeOnMap')"
              :subtitle="t('positionSelected')"
              link
              @click="resumePingPlacement"
            >
              <template #media><Crosshair :size="22" /></template>
              <template #after><MapPinned :size="19" /></template>
            </sky-list-item>
          </sky-list>
          <p v-if="formError" class="crewlink-error">{{ formError }}</p>
          <sky-button
            large
            rounded
            class="crewlink-share-ping"
            :disabled="crew.isLoading"
            @click="createPing"
            ><Flag />{{ t('sharePing') }}</sky-button
          >
        </template>

        <template v-else-if="sheet === 'edit-group' && activeGroup">
          <span class="crewlink-sheet__panel__icon"><Settings2 /></span>
          <h2>{{ t('manageCrew') }}</h2>
          <p>{{ t('manageCrewBody') }}</p>
          <sky-list inset strong class="crewlink-form-list"
            ><sky-field
              input-id="crewlink-edit-name"
              :label="t('groupName')"
              :value="groupName"
              maxlength="32"
              outline
              @input="updateValue('groupName', $event)"
          /></sky-list>
          <span class="crewlink-field-label">{{ t('groupColour') }}</span>
          <div class="crewlink-colours">
            <button
              v-for="colour in colours"
              :key="colour.id"
              type="button"
              :class="{ 'is-active': groupColour === colour.id }"
              :style="{ background: colour.value }"
              @click="groupColour = colour.id"
            >
              <Check />
            </button>
          </div>
          <sky-list inset strong>
            <sky-list-item
              :title="t('memberPings')"
              :subtitle="t('memberPingsBody')"
              ><template #after
                ><sky-toggle
                  :checked="activeGroup.allowMemberPings"
                  :disabled="pendingGroupSetting !== null"
                  @click.stop.prevent="
                    toggleGroupSetting('allowMemberPings')
                  " /></template
            ></sky-list-item>
            <sky-list-item
              :title="t('allowOverhead')"
              :subtitle="t('allowOverheadBody')"
              ><template #after
                ><sky-toggle
                  :checked="activeGroup.overheadAllowed"
                  :disabled="pendingGroupSetting !== null"
                  @click.stop.prevent="
                    toggleGroupSetting('overheadAllowed')
                  " /></template
            ></sky-list-item>
          </sky-list>
          <sky-card v-if="activeGroup.inviteCode"
            ><div class="crewlink-code-card">
              <small>{{ t('inviteCode') }}</small
              ><strong>{{ activeGroup.inviteCode }}</strong
              ><button type="button" @click="copyInviteCode"><Copy /></button
              ><button type="button" @click="rotateInviteCode">
                <RefreshCw />
              </button></div
          ></sky-card>
          <p v-if="formError" class="crewlink-error">{{ formError }}</p>
          <sky-button large rounded @click="saveGroup">{{
            phone.t('Common.save')
          }}</sky-button>
        </template>

        <template v-else-if="sheet === 'member' && selectedMember">
          <span
            class="crewlink-sheet__panel__avatar"
            :style="{ '--crew': activeColour }"
            >{{ memberInitials(selectedMember) }}</span
          >
          <h2>@{{ selectedMember.username }}</h2>
          <p>
            {{ roleLabel(selectedMember.role) }} ·
            {{ memberStatus(selectedMember) }}
          </p>
          <sky-block-title class="crewlink-role-title">{{
            t('assignRole')
          }}</sky-block-title>
          <sky-list inset strong class="crewlink-role-list">
            <sky-list-item
              v-for="role in editableRoles"
              :key="role"
              class="crewlink-role-item"
              content-class="crewlink-role-item__content"
              media-class="crewlink-role-item__media"
              inner-class="crewlink-role-item__inner"
              title-wrap-class="crewlink-role-item__title"
              :title="roleLabel(role)"
              :subtitle="t(`roleDescriptions.${role}`)"
              :link="role !== selectedMember.role"
              @click="setMemberRole(role)"
            >
              <template #media
                ><component :is="roleIcons[role]" :size="20"
              /></template>
              <template #after
                ><Check v-if="role === selectedMember.role" :size="18"
              /></template>
            </sky-list-item>
          </sky-list>
          <div class="crewlink-member-actions">
            <sky-button
              v-if="activeGroup?.isOwner"
              large
              rounded
              outline
              @click="confirmAction = 'transfer-owner'"
              ><Crown />{{ t('transferOwnership') }}</sky-button
            >
            <sky-button
              large
              rounded
              tonal
              class="crewlink-danger-button"
              @click="confirmAction = 'remove-member'"
              ><Trash2 />{{ t('removeMember') }}</sky-button
            >
          </div>
        </template>

        <template v-else-if="sheet === 'edit-profile' && crew.profile">
          <div class="crewlink-profile-editor__avatar">
            <img
              v-if="selectedProfilePhoto?.url"
              :src="selectedProfilePhoto.url"
              alt=""
            />
            <img
              v-else-if="crew.profile.avatarUrl && !profileAvatarRemoved"
              :src="crew.profile.avatarUrl"
              alt=""
            />
            <UserRound v-else />
          </div>
          <h2>{{ t('editProfile') }}</h2>
          <p>{{ t('editProfileBody') }}</p>
          <div class="crewlink-profile-editor__media-actions">
            <sky-button rounded outline @click="openProfileMedia('photos')">
              <Images :size="16" />{{ t('gallery') }}
            </sky-button>
            <sky-button rounded outline @click="openProfileMedia('camera')">
              <Camera :size="16" />{{ t('camera') }}
            </sky-button>
          </div>
          <sky-button
            v-if="
              selectedProfilePhoto ||
              (crew.profile.avatarUrl && !profileAvatarRemoved)
            "
            rounded
            tonal
            class="crewlink-profile-editor__remove"
            @click="removeProfilePhoto"
          >
            <Trash2 :size="15" />{{ t('removeProfilePhoto') }}
          </sky-button>
          <sky-list inset strong class="crewlink-form-list"
            ><sky-field
              input-id="crewlink-edit-username"
              :label="t('username')"
              :value="username"
              maxlength="20"
              outline
              @input="updateValue('username', $event)"
              @keydown.enter="handleEnterAction($event, saveProfile)"
          /></sky-list>
          <p v-if="formError" class="crewlink-error">{{ formError }}</p>
          <sky-button
            large
            rounded
            :disabled="crew.isLoading"
            @click="saveProfile"
          >
            <sky-spinner v-if="crew.isLoading" />
            <template v-else>{{ phone.t('Common.save') }}</template>
          </sky-button>
        </template>
      </section>
    </sky-sheet>

    <sky-sheet
      :opened="Boolean(selectedMember && !sheet)"
      @backdropclick="selectedMember = null"
    >
      <section
        v-if="selectedMember"
        class="crewlink-sheet__panel__content crewlink-member-preview"
      >
        <sky-link
          component="button"
          class="crewlink-sheet__panel__close"
          :link-props="{ type: 'button' }"
          @click="selectedMember = null"
          ><X
        /></sky-link>
        <span
          class="crewlink-sheet__panel__avatar"
          :style="{ '--crew': activeColour }"
        >
          <img
            v-if="selectedMember.avatarUrl"
            :src="selectedMember.avatarUrl"
            alt=""
          />
          <template v-else>{{ memberInitials(selectedMember) }}</template>
        </span>
        <h2>@{{ selectedMember.username }}</h2>
        <p>
          {{ roleLabel(selectedMember.role) }} ·
          {{ memberStatus(selectedMember) }}
        </p>
        <sky-button
          v-if="selectedMember.coords"
          large
          rounded
          @click="routeToSelectedMember"
          ><Route />{{ t('setRoute') }}</sky-button
        >
      </section>
    </sky-sheet>

    <sky-sheet
      :opened="Boolean(selectedPing)"
      @backdropclick="selectedPing = null"
    >
      <section
        v-if="selectedPing"
        class="crewlink-sheet__panel__content crewlink-member-preview"
      >
        <sky-link
          component="button"
          class="crewlink-sheet__panel__close"
          :link-props="{ type: 'button' }"
          @click="selectedPing = null"
          ><X
        /></sky-link>
        <span
          class="crewlink-sheet__panel__icon"
          :style="{ background: pingColours[selectedPing.type] }"
          ><component :is="pingIcons[selectedPing.type]" /></span
        ><small>{{ t(`pingTypes.${selectedPing.type}`) }}</small>
        <h2>{{ selectedPing.label }}</h2>
        <p>
          {{ t('sharedBy', { username: selectedPing.creatorUsername }) }} ·
          {{ expiresIn(selectedPing.expiresAt) }}
        </p>
        <sky-button large rounded @click="routeToSelectedPing"
          ><Navigation />{{ t('setRoute') }}</sky-button
        >
      </section>
    </sky-sheet>

    <AccountLogoutDialog
      v-model:opened="logoutDialogOpen"
      app-id="crewlink"
      :app-name="t('name')"
      @logged-out="handleLoggedOut"
    />

    <sky-dialog
      :opened="Boolean(confirmAction)"
      @backdropclick="cancelConfirmation"
    >
      <template #title>{{ t(`confirm.${confirmAction}.title`) }}</template>
      <p>{{ t(`confirm.${confirmAction}.body`) }}</p>
      <template #buttons
        ><sky-dialog-button
          class="crewlink-dialog-cancel"
          type="button"
          :aria-label="phone.t('Common.cancel')"
          @click="cancelConfirmation"
          >{{ phone.t('Common.cancel') }}</sky-dialog-button
        ><sky-dialog-button
          strong
          type="button"
          @click="performConfirmedAction"
          >{{ t('confirmAction') }}</sky-dialog-button
        ></template
      >
    </sky-dialog>

    <sky-notification :opened="Boolean(toastText)" :text="toastText" />
  </sky-app-page>
</template>

<style scoped>
.crewlink {
  --cl-bg: #f2f6fa;
  --cl-surface: rgba(255, 255, 255, 0.84);
  --cl-text: #102034;
  --cl-muted: #6e7c8d;
  --cl-map-header-background: var(--cl-bg);
  --sky-safe-area-top: 46px;
  --sky-safe-area-bottom: 25px;
  position: relative;
  height: 100%;
  background: var(--cl-bg);
  color: var(--cl-text);
  overflow: hidden;
}
.crewlink--dark {
  --cl-map-header-background: linear-gradient(90deg, #061823, #0f2837);
  --cl-bg: #071018;
  --cl-surface: rgba(17, 29, 40, 0.88);
  --cl-text: #f3f8fb;
  --cl-muted: #8fa2b3;
}
.crewlink :deep(.page-content) {
  background: transparent;
}
.crewlink-navbar {
  --sky-safe-area-top: 46px;
  --sky-navbar-glass: var(--cl-bg);
  position: absolute;
  z-index: 20;
  top: 0;
  right: 0;
  left: 0;
}
.crewlink-content {
  position: absolute;
  inset: 0;
  overflow: hidden;
}
.crewlink-content--empty {
  inset: var(--sky-safe-area-top) 0 var(--sky-safe-area-bottom);
}
.crewlink-scroll-tab {
  height: 100%;
  overflow-y: auto;
  padding: 108px 11px 112px;
}
.crewlink-loading,
.crewlink-onboarding {
  height: 100%;
  padding: 52px 30px 32px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  gap: 12px;
  background: radial-gradient(
    circle at 50% 32%,
    rgba(39, 217, 237, 0.18),
    transparent 36%
  );
}
.crewlink-auth {
  --auth-accent: var(--sky-app-accent-shade);
  --panel: var(--sky-surface);
  box-sizing: border-box;
  min-height: 100%;
  padding: calc(var(--sky-safe-area-top) + 20px) 18px
    calc(var(--sky-safe-area-bottom) + 20px);
  justify-content: center;
  color: var(--sky-text);
  background:
    radial-gradient(circle at 82% 8%, rgba(39, 217, 237, 0.2), transparent 34%),
    var(--sky-bg);
  overflow-y: auto;
}
.crewlink-auth :deep(.app-profile-auth) {
  width: min(100%, 340px);
  flex: none;
  margin: auto;
}
.crewlink-auth :deep(.app-profile-auth__mode) {
  position: relative;
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 4px;
  min-height: 44px;
  padding: 4px;
  overflow: hidden;
  border: 1px solid rgba(132, 173, 192, 0.18);
  border-radius: var(--sky-radius-pill, 999px);
  background: var(--sky-surface-muted);
  box-shadow: none;
}
.crewlink-auth :deep(.app-profile-auth__mode-button) {
  position: relative;
  z-index: 1;
  min-width: 0;
  min-height: 34px;
  border-radius: var(--sky-radius-pill, 999px) !important;
  color: var(--auth-accent);
  background: transparent;
  box-shadow: none;
  transition:
    color 160ms ease,
    background-color 160ms ease,
    box-shadow 160ms ease,
    transform 100ms ease;
}
.crewlink-auth :deep(.app-profile-auth__mode-button--active) {
  color: #ffffff;
  background: var(--sky-app-accent-shade) !important;
  box-shadow: none;
}
.crewlink-auth :deep(.app-profile-auth__mode-button:active) {
  transform: scale(0.98);
}
@media (prefers-reduced-motion: reduce) {
  .crewlink-auth :deep(.app-profile-auth__mode-button) {
    transition: none;
  }
}
.crewlink-auth :deep(.app-profile-auth__fields) {
  --sky-list-outer-left: 0px;
  --sky-list-outer-right: 0px;
  margin: 0 0 11px;
  padding: 12px;
  border: 1px solid rgba(132, 173, 192, 0.1);
  border-radius: 22px;
  background: var(--sky-surface) !important;
}
.crewlink-auth :deep(.app-profile-auth__fields > .sky-list__items) {
  display: grid;
  gap: 11px;
}
.crewlink-auth :deep(.app-profile-auth__credential-field) {
  min-height: 56px;
  margin: 0;
  padding: 0 14px;
  border: 1px solid rgba(145, 178, 194, 0.52);
  border-radius: 11px;
  color: var(--sky-text);
  background: var(--sky-surface-muted);
  transition:
    border-color 160ms ease,
    background-color 160ms ease,
    box-shadow 160ms ease;
}
.crewlink-auth :deep(.app-profile-auth__credential-field:focus-within) {
  border-color: var(--auth-accent);
  background: var(--sky-surface-muted);
  box-shadow: 0 0 0 2px rgba(32, 189, 224, 0.14);
}
.crewlink-auth :deep(.app-profile-auth__credential-field .sky-field__border) {
  display: none;
}
.crewlink-auth :deep(.app-profile-auth__credential-field .sky-field__media) {
  width: 22px;
  justify-content: center;
  margin-right: 10px;
  padding: 0;
  color: var(--sky-text);
}
.crewlink-auth :deep(.app-profile-auth__credential-field .sky-field__inner) {
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 7px 0;
}
.crewlink-auth :deep(.app-profile-auth__credential-field .sky-field__label) {
  display: block;
  margin: 0;
  color: var(--sky-muted);
  font-size: 10px;
  font-weight: 650;
  line-height: 13px;
  transform: none;
}
.crewlink-auth
  :deep(.app-profile-auth__credential-field .sky-field__label-text) {
  position: static;
  top: auto;
  margin: 0;
  padding: 0;
  background: transparent;
}
.crewlink-auth :deep(.app-profile-auth__credential-field .sky-field__control) {
  margin: 0;
}
.crewlink-auth :deep(.app-profile-auth__credential-field .sky-field__input) {
  height: 24px;
  min-height: 24px;
  color: var(--sky-text);
  font-size: 14px;
  font-weight: 650;
  line-height: 20px;
}
.crewlink-auth
  :deep(.app-profile-auth__credential-field .sky-field__input::placeholder) {
  color: var(--sky-muted);
  opacity: 1;
}
.crewlink-logo {
  width: 78px;
  height: 78px;
  border-radius: 26px;
  display: grid;
  place-items: center;
  color: white;
  background: linear-gradient(145deg, #28dbe9, #1d88ff 58%, #7050ef);
  box-shadow: 0 18px 42px rgba(20, 137, 213, 0.3);
}
.crewlink-logo svg {
  width: 38px;
  height: 38px;
}
.crewlink-onboarding small {
  color: #168cbb;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}
.crewlink-onboarding h1 {
  margin: 0;
  font-size: 27px;
  line-height: 1.05;
}
.crewlink-onboarding p {
  margin: 0 0 10px;
  color: var(--cl-muted);
  font-size: 13px;
  line-height: 1.5;
}
.crewlink-onboarding :deep(.button) {
  width: 100%;
}
.crewlink-navbar--map {
  --sky-text: var(--cl-text);
  --sky-muted: var(--cl-muted);
  background: var(--cl-map-header-background);
}
.crewlink-navbar--map :deep(.sky-navbar__blur),
.crewlink-navbar--map :deep(.sky-navbar__background) {
  display: none;
}
.crewlink-orbits {
  width: 170px;
  height: 170px;
  position: relative;
  margin-bottom: 4px;
}
.crewlink-orbits i {
  position: absolute;
  inset: 8px;
  border: 1px solid rgba(39, 217, 237, 0.22);
  border-radius: 50%;
  animation: cl-pulse 2.8s infinite;
}
.crewlink-orbits i:nth-child(2) {
  inset: 31px;
  animation-delay: 0.3s;
}
.crewlink-orbits i:nth-child(3) {
  inset: 55px;
  animation-delay: 0.6s;
}
.crewlink-orbits span {
  position: absolute;
  inset: 69px;
  border-radius: 18px;
  display: grid;
  place-items: center;
  color: white;
  background: linear-gradient(145deg, #2ce4ed, #257cff);
  box-shadow: 0 10px 35px rgba(31, 162, 228, 0.4);
}
.crewlink-form-list {
  width: 100%;
  margin: 4px 0;
}
.crewlink-privacy {
  display: flex;
  gap: 5px;
  align-items: center;
  color: var(--cl-muted) !important;
  letter-spacing: 0 !important;
  text-transform: none !important;
  font-weight: 500 !important;
}
.crewlink-privacy svg {
  width: 14px;
}
.crewlink-group-gate {
  height: 100%;
  padding: 24px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  align-content: center;
  gap: 12px;
  background: radial-gradient(
    circle at 50% 48%,
    rgba(39, 217, 237, 0.16),
    transparent 48%
  );
}
.crewlink-group-gate button {
  min-width: 0;
  aspect-ratio: 1;
  padding: 16px 8px;
  border: 1px solid rgba(39, 160, 215, 0.14);
  border-radius: 24px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  color: var(--cl-text);
  background: var(--cl-surface);
  box-shadow: 0 14px 32px rgba(11, 43, 65, 0.1);
}
.crewlink-group-gate button span {
  width: 52px;
  height: 52px;
  border-radius: 18px;
  display: grid;
  place-items: center;
  color: white;
  background: linear-gradient(145deg, #2bdde9, #2e7eff);
  box-shadow: 0 10px 24px rgba(30, 150, 220, 0.28);
}
.crewlink-group-gate button:last-child span {
  background: linear-gradient(145deg, #8b5cf6, #387eff);
}
.crewlink-group-gate button svg {
  width: 25px;
  height: 25px;
}
.crewlink-group-gate button strong {
  font-size: 12px;
  line-height: 1.25;
}
.crewlink-group-gate :deep(.crewlink-group-gate__logout) {
  grid-column: 1/-1;
  width: 100%;
  min-height: 46px;
  aspect-ratio: auto;
  border-color: rgba(228, 71, 96, 0.55);
  border-radius: 23px;
  flex-direction: row;
  color: #e44760;
}
.crewlink-logout-button {
  width: 100%;
  color: #e44760;
}
.crewlink-invitations {
  width: 100%;
  margin-top: 18px;
  text-align: left;
}
.crewlink-join-invitations-title {
  margin: 18px 0 8px !important;
  text-align: left;
}
.crewlink-invitations--join {
  display: grid;
  gap: 7px;
  margin: 0;
}
.crewlink-invitations--join :deep(.sky-card) {
  margin: 0;
}
.crewlink-invite-card {
  display: grid;
  grid-template-columns: 38px 1fr 31px 31px;
  gap: 7px;
  align-items: center;
}
.crewlink-invite-card > i {
  width: 38px;
  height: 38px;
  border-radius: 13px;
  display: grid;
  place-items: center;
  color: white;
}
.crewlink-invite-card > i svg {
  width: 19px;
}
.crewlink-invite-card div {
  display: flex;
  flex-direction: column;
}
.crewlink-invite-card div span {
  font-size: 10px;
  color: var(--cl-muted);
}
.crewlink-invite-card button {
  width: 29px;
  height: 29px;
  border: 0;
  border-radius: 10px;
  display: grid;
  place-items: center;
  color: #e94662;
  background: rgba(255, 77, 103, 0.12);
}
.crewlink-invite-card button.is-accept {
  color: #0aa66d;
  background: rgba(46, 204, 126, 0.14);
}
.crewlink-invite-card button svg {
  width: 15px;
}
.crewlink-map-tab {
  height: 100%;
  padding-top: 94px;
  padding-bottom: calc(80px + var(--sky-safe-area-bottom));
  display: flex;
  flex-direction: column;
  background: #09131c;
}
.crewlink-content--placing .crewlink-map-tab {
  padding-bottom: var(--sky-safe-area-bottom);
}
.crewlink-map-summary {
  position: relative;
  z-index: 1001;
  height: 64px;
  padding: 8px 13px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: var(--cl-text);
  background: var(--cl-map-header-background);
}
.crewlink-map-summary::after {
  position: absolute;
  top: 100%;
  right: 0;
  left: 0;
  height: 16px;
  background: var(--cl-map-header-background);
  -webkit-mask-image: linear-gradient(to bottom, #000, transparent);
  mask-image: linear-gradient(to bottom, #000, transparent);
  content: '';
  pointer-events: none;
}
.crewlink-map-summary > div:first-child {
  display: grid;
  grid-template-columns: 10px auto auto;
  align-items: baseline;
  gap: 7px;
}
.crewlink-map-summary strong {
  font-size: 26px;
  line-height: 30px;
}
.crewlink-map-summary small {
  font-size: 14px;
  font-weight: 600;
  line-height: 18px;
  color: var(--cl-muted);
  white-space: nowrap;
}
.crewlink-live-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: #35dc80;
  box-shadow: 0 0 0 4px rgba(53, 220, 128, 0.16);
}
.crewlink-online-faces {
  display: flex;
  align-items: center;
}
.crewlink-online-faces span {
  width: 27px;
  height: 27px;
  margin-left: -6px;
  border: 2px solid;
  border-radius: 50%;
  display: grid;
  place-items: center;
  background: #203347;
  color: white;
  font-size: 8px;
  font-weight: 800;
}
.crewlink-online-faces i {
  font-size: 9px;
  margin-left: 5px;
  color: #9cb0bf;
}
.crewlink-map {
  position: relative;
  flex: 1;
  overflow: hidden;
  touch-action: none;
  background: #d8e0e4;
  cursor: grab;
}
.crewlink-map:active {
  cursor: grabbing;
}
.crewlink-map__canvas {
  position: absolute;
  left: 50%;
  top: 50%;
  transform-origin: center;
}
.crewlink-map__mainland,
.crewlink-map__cayo {
  position: absolute;
  object-fit: fill;
  pointer-events: none;
  user-select: none;
}
.crewlink-map__mainland:not(.crewlink-map__mainland--default) {
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.crewlink-member-marker,
.crewlink-ping-marker {
  position: absolute;
  border: 0;
  background: transparent;
  z-index: 4;
  display: flex;
  flex-direction: column;
  align-items: center;
  transform-origin: center bottom;
  cursor: pointer;
}
.crewlink-member-marker > span {
  width: 31px;
  height: 31px;
  border: 3px solid white;
  border-radius: 50%;
  display: grid;
  place-items: center;
  overflow: hidden;
  color: #10232d;
  background: color-mix(in srgb, var(--crew) 55%, white);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
  font-size: 9px;
  font-weight: 900;
}
.crewlink-member-marker > span img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.crewlink-member-marker.is-self > span {
  box-shadow:
    0 0 0 5px var(--crew-ring),
    0 4px 12px rgba(0, 0, 0, 0.3);
}
.crewlink-member-marker small,
.crewlink-ping-marker small {
  padding: 2px 5px;
  margin-top: 2px;
  border-radius: 6px;
  color: white;
  background: rgba(4, 14, 23, 0.82);
  font-size: 7px;
  font-weight: 700;
  white-space: nowrap;
}
.crewlink-ping-marker > svg {
  width: 28px;
  height: 28px;
  padding: 6px;
  border-radius: 50% 50% 50% 4px;
  transform: rotate(-45deg);
  color: white;
  background: var(--ping);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
}
.crewlink-ping-marker > svg :deep(*) {
  transform: rotate(45deg);
  transform-origin: center;
}
.crewlink-map-controls {
  position: absolute;
  z-index: 8;
  right: 10px;
  top: 10px;
  display: flex;
  flex-direction: column;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.18);
}
.crewlink-map-controls button {
  width: 34px;
  height: 34px;
  border: 0;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
  background: rgba(255, 255, 255, 0.9);
  color: #183044;
  font-size: 19px;
  display: grid;
  place-items: center;
}
.crewlink-map-controls svg {
  width: 16px;
}
.crewlink-map-legend {
  position: absolute;
  left: 10px;
  bottom: 10px;
  padding: 6px 8px;
  border-radius: 10px;
  display: flex;
  gap: 9px;
  background: rgba(8, 20, 30, 0.78);
  backdrop-filter: blur(10px);
  color: white;
  font-size: 8px;
}
.crewlink-map-legend span {
  display: flex;
  align-items: center;
  gap: 4px;
}
.crewlink-map-legend i {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #35dc80;
}
.crewlink-map-legend i.is-hidden {
  background: #8998a4;
}
.crewlink-map-crosshair {
  position: absolute;
  z-index: 7;
  left: 50%;
  top: 50%;
  width: 48px;
  height: 48px;
  border: 2px solid rgba(255, 255, 255, 0.9);
  border-radius: 50%;
  display: grid;
  place-items: center;
  transform: translate(-50%, -50%);
  color: #ff4d67;
  background: rgba(8, 20, 30, 0.28);
  box-shadow:
    0 4px 16px rgba(0, 0, 0, 0.42),
    inset 0 0 0 1px rgba(0, 0, 0, 0.2);
  pointer-events: none;
}
.crewlink-map-crosshair svg {
  width: 28px;
  height: 28px;
  filter: drop-shadow(0 2px 4px rgba(255, 255, 255, 0.72));
}
.crewlink-ping-placement {
  min-height: 112px;
  padding: 10px 12px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 9px;
  color: white;
  background: #0c1822;
}
.crewlink-ping-placement > div:first-child {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}
.crewlink-ping-placement strong {
  font-size: 14px;
  line-height: 18px;
}
.crewlink-ping-placement small {
  color: #a4b4c0;
  font-size: 10px;
  line-height: 13px;
}
.crewlink-ping-placement > div:last-child {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.crewlink-ping-placement :deep(.sky-button) {
  min-height: 44px;
}
.crewlink-ping-placement svg {
  width: 16px;
  height: 16px;
}
.crewlink-map-actions {
  height: 76px;
  padding: 8px 10px;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  background: #0c1822;
}
.crewlink-map-actions button {
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 15px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 11px;
  color: white;
  background: rgba(255, 255, 255, 0.06);
  text-align: left;
}
.crewlink-map-actions button:disabled {
  opacity: 0.4;
}
.crewlink-map-actions svg {
  width: 23px;
  height: 23px;
  flex: none;
  color: #28d9e8;
}
.crewlink-map-actions span {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
}
.crewlink-map-actions strong {
  font-size: 15px;
  line-height: 18px;
  white-space: nowrap;
}
.crewlink-map-actions small {
  font-size: 12px;
  line-height: 15px;
  color: #a4b4c0;
  white-space: nowrap;
}
.crewlink-group-hero {
  padding: 22px;
  border-radius: 25px;
  color: white;
  background:
    radial-gradient(circle at 82% 18%, var(--crew-aura), transparent 35%),
    linear-gradient(145deg, #0b2433, #0b1825);
  box-shadow: 0 15px 35px rgba(6, 20, 31, 0.2);
}
.crewlink-group-tab {
  --sky-card-outer-left: 0px;
  --sky-card-outer-right: 0px;
  --sky-list-outer-left: 0px;
  --sky-list-outer-right: 0px;
  --sky-title-gutter-left: 0px;
  --sky-title-gutter-right: 0px;
}
.crewlink-group-hero__signal {
  width: 48px;
  height: 48px;
  border-radius: 16px;
  display: grid;
  place-items: center;
  background: var(--crew);
  box-shadow: 0 0 28px var(--crew-glow);
}
.crewlink-group-hero__signal svg {
  width: 26px;
}
.crewlink-group-hero > small {
  display: block;
  margin-top: 17px;
  font-size: 12px;
  font-weight: 600;
  line-height: 16px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: #b5c6d0;
}
.crewlink-group-hero h1 {
  margin: 5px 0;
  font-size: 29px;
  line-height: 34px;
}
.crewlink-group-hero p {
  margin: 0 0 14px;
  font-size: 14px;
  line-height: 18px;
  color: #d0dbe1;
}
.crewlink-group-hero > div:last-child {
  display: flex;
  gap: 7px;
}
.crewlink-group-hero :deep(.crewlink-group-badge) {
  min-height: 24px;
  padding: 4px 8px;
  font-size: 13px;
}
.crewlink-quick-actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin: 13px 0 11px;
}
.crewlink-quick-actions button {
  min-height: 64px;
  border: 0;
  border-radius: 15px;
  padding: 11px 5px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 7px;
  color: var(--cl-text);
  background: var(--cl-surface);
  font-size: 12px;
  font-weight: 600;
  line-height: 15px;
  box-shadow: 0 3px 12px rgba(15, 40, 60, 0.06);
}
.crewlink-quick-actions svg {
  width: 22px;
  height: 22px;
  color: #138fc0;
}
.crewlink-invitations--inline {
  margin: 0;
}
.crewlink-members-title {
  height: auto !important;
  min-height: 34px;
  padding-top: 8px !important;
  padding-bottom: 6px !important;
  font-size: 16px !important;
  font-weight: 700 !important;
  color: var(--cl-text) !important;
}
.crewlink-member-list :deep(.sky-list-item) {
  min-height: 70px;
}
.crewlink-member-title {
  font-size: 18px;
  font-weight: 700;
  line-height: 22px;
}
.crewlink-member-subtitle {
  font-size: 14px;
  line-height: 18px;
  color: var(--cl-muted);
}
.crewlink-avatar {
  position: relative;
  width: 43px;
  height: 43px;
  border-radius: 15px;
  display: grid;
  place-items: center;
  color: white;
  background: linear-gradient(145deg, var(--crew), #273e55);
  font-size: 12px;
  font-weight: 900;
}
.crewlink-avatar i {
  position: absolute;
  right: -2px;
  bottom: -2px;
  width: 11px;
  height: 11px;
  border: 2px solid white;
  border-radius: 50%;
  background: #8998a4;
}
.crewlink-avatar i.is-online {
  background: #35d880;
}
.role-owner {
  color: #ffb020;
}
.role-coordinator {
  color: #8b5cf6;
}
.role-moderator {
  color: #2d9cff;
}
.role-member {
  color: #22b77a;
}
.role-guest {
  color: #8998a4;
}
.crewlink-section-header {
  display: flex;
  align-items: center;
  gap: 13px;
  margin: 5px 2px 16px;
}
.crewlink-section-header > span {
  width: 52px;
  height: 52px;
  border-radius: 17px;
  display: grid;
  place-items: center;
  color: white;
  background: linear-gradient(145deg, #27d9ed, #287cff);
}
.crewlink-section-header > span svg {
  width: 26px;
  height: 26px;
}
.crewlink-section-header div {
  flex: 1;
}
.crewlink-section-header small {
  font-size: 13px;
  font-weight: 700;
  line-height: 16px;
  color: #29b8e8;
  text-transform: uppercase;
  letter-spacing: 0.09em;
}
.crewlink-section-header h1 {
  margin: 2px 0 0;
  font-size: 29px;
  line-height: 34px;
}
.crewlink-section-header button {
  width: 42px;
  height: 42px;
  border: 0;
  border-radius: 14px;
  display: grid;
  place-items: center;
  color: white;
  background: #168dc2;
}
.crewlink-section-header button svg {
  width: 22px;
  height: 22px;
}
.crewlink-pings-tab .crewlink-section-header {
  margin-bottom: 12px;
}
.crewlink-ping-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.crewlink-ping-list :deep(.sky-card) {
  margin: 0;
}
.crewlink-ping-list article {
  display: grid;
  grid-template-columns: 47px 1fr 32px 32px;
  gap: 9px;
  align-items: center;
  padding: 11px;
}
.crewlink-ping-list article > i {
  width: 47px;
  height: 47px;
  border-radius: 16px;
  display: grid;
  place-items: center;
  color: white;
}
.crewlink-ping-list article > i svg {
  width: 23px;
}
.crewlink-ping-list article > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.crewlink-ping-list small {
  font-size: 11px;
  line-height: 14px;
  color: var(--cl-muted);
  text-transform: uppercase;
}
.crewlink-ping-list strong {
  font-size: 15px;
  line-height: 19px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.crewlink-ping-list span {
  font-size: 12px;
  line-height: 15px;
  color: var(--cl-muted);
}
.crewlink-ping-list button {
  border: 0;
  background: transparent;
  color: #238fbd;
  display: grid;
  place-items: center;
}
.crewlink-ping-list button:last-child {
  color: #ed5268;
}
.crewlink-ping-list button svg {
  width: 20px;
}
.crewlink-empty-state {
  padding: 68px 22px;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}
.crewlink-empty-state > span {
  width: 70px;
  height: 70px;
  border-radius: 23px;
  display: grid;
  place-items: center;
  color: #168dbd;
  background: rgba(39, 191, 230, 0.12);
}
.crewlink-empty-state > span svg {
  width: 29px;
  height: 29px;
}
.crewlink-empty-state h2 {
  margin: 17px 0 7px;
  font-size: 21px;
  line-height: 26px;
}
.crewlink-empty-state p {
  max-width: 280px;
  margin: 0;
  color: var(--cl-muted);
  font-size: 14px;
  line-height: 20px;
}
.crewlink-profile-card {
  display: flex;
  align-items: center;
  gap: 13px;
  padding: 17px;
  border-radius: 23px;
  color: white;
  background: linear-gradient(145deg, var(--crew), #183a5a);
}
.crewlink-profile-tab {
  --sky-list-outer-left: 0px;
  --sky-list-outer-right: 0px;
  --sky-title-gutter-left: 0px;
  --sky-title-gutter-right: 0px;
}
.crewlink-profile-card > span {
  width: 54px;
  height: 54px;
  border: 3px solid rgba(255, 255, 255, 0.72);
  border-radius: 19px;
  display: grid;
  place-items: center;
  font-size: 15px;
  font-weight: 900;
  background: rgba(8, 25, 40, 0.22);
}
.crewlink-profile-card div {
  min-width: 0;
}
.crewlink-profile-card small {
  font-size: 8px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  opacity: 0.75;
}
.crewlink-profile-card h1 {
  margin: 2px 0;
  font-size: 19px;
}
.crewlink-profile-card p {
  margin: 0;
  font-size: 10px;
  opacity: 0.82;
}
.crewlink-group-dot {
  width: 35px;
  height: 35px;
  border-radius: 13px;
  display: grid;
  place-items: center;
  color: white;
}
.crewlink-group-dot svg {
  width: 18px;
}
.crewlink-danger-row {
  --sky-list-item-title-color: #e44760;
}
.crewlink-danger-button {
  color: #e44760 !important;
}
.crewlink-role-title {
  margin: 16px 0 8px !important;
  padding-inline: 4px !important;
}
.crewlink-role-list {
  margin: 0 !important;
}
.crewlink-role-list :deep(.crewlink-role-item__content) {
  min-height: 68px;
  align-items: center;
}
.crewlink-role-list :deep(.crewlink-role-item__media) {
  width: 28px;
  margin-right: 10px;
  justify-content: center;
  color: #9ca8b3;
}
.crewlink-role-list :deep(.crewlink-role-item__inner) {
  min-width: 0;
  padding-top: 9px;
  padding-bottom: 9px;
  text-align: left;
}
.crewlink-role-list :deep(.crewlink-role-item__title) {
  min-height: 22px;
  font-size: 14px;
  line-height: 18px;
}
.crewlink-role-list :deep(.crewlink-role-item__title + div) {
  max-width: 230px;
  color: var(--cl-muted);
  font-size: 10px;
  line-height: 14px;
  text-align: left;
}
.crewlink-role-list :deep(.crewlink-role-item__title svg) {
  color: #aab5bf;
}
.crewlink-member-actions {
  display: grid;
  gap: 8px;
  margin-top: 12px;
}
.crewlink-member-actions :deep(.sky-button) {
  margin-top: 0;
}
.crewlink-sheet__panel__content {
  position: relative;
  max-height: 82vh;
  overflow-y: auto;
  padding: 26px 18px 24px;
  text-align: center;
  color: var(--cl-text);
  background: var(--cl-bg);
  border-radius: 24px 24px 0 0;
}
.crewlink-sheet__panel__content--manage {
  --sky-card-outer-left: 0px;
  --sky-card-outer-right: 0px;
  --sky-list-outer-left: 0px;
  --sky-list-outer-right: 0px;
}
.crewlink-sheet__panel__content--ping {
  --sky-list-outer-left: 0px;
  --sky-list-outer-right: 0px;
}
.crewlink-sheet__panel__close {
  position: absolute;
  right: 14px;
  top: 12px;
  width: 31px;
  height: 31px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: var(--cl-muted);
  background: rgba(125, 145, 160, 0.15);
}
.crewlink-sheet__panel__close svg {
  width: 17px;
}
.crewlink-sheet__panel__icon,
.crewlink-sheet__panel__avatar {
  width: 56px;
  height: 56px;
  margin: 0 auto 9px;
  border-radius: 20px;
  display: grid;
  place-items: center;
  color: white;
  background: linear-gradient(145deg, #27d9ed, #287cff);
  box-shadow: 0 10px 25px rgba(31, 139, 205, 0.22);
}
.crewlink-sheet__panel__avatar {
  background: linear-gradient(145deg, var(--crew), #29415a);
  font-weight: 900;
}
.crewlink-sheet__panel__icon svg {
  width: 26px;
}
.crewlink-sheet__panel__content h2 {
  margin: 4px 0;
  font-size: 23px;
  line-height: 1.2;
}
.crewlink-sheet__panel__content > p {
  margin: 0 10px 13px;
  color: var(--cl-muted);
  font-size: 13px;
  line-height: 1.45;
}
.crewlink-sheet__panel__content :deep(.button) {
  width: 100%;
  margin-top: 9px;
  font-size: 13px;
}
.crewlink-nearby-list {
  margin: 10px 0 0 !important;
}
.crewlink-nearby-list :deep(.crewlink-nearby-item__content) {
  min-height: 66px;
  align-items: center;
}
.crewlink-nearby-list :deep(.crewlink-nearby-item__media) {
  width: 38px;
  margin-right: 12px;
  justify-content: center;
}
.crewlink-nearby-list :deep(.crewlink-nearby-item__inner) {
  min-width: 0;
  padding-top: 9px;
  padding-bottom: 9px;
  text-align: left;
}
.crewlink-nearby-list :deep(.crewlink-nearby-item__title) {
  min-height: 22px;
  gap: 8px;
  font-size: 14px;
  line-height: 18px;
}
.crewlink-nearby-list :deep(.crewlink-nearby-item__title + div) {
  color: var(--cl-muted);
  font-size: 10px;
  line-height: 14px;
  text-align: left;
}
.crewlink-nearby-list :deep(.crewlink-nearby-invite) {
  width: auto;
  margin-top: 0;
  padding-inline: 13px;
  flex: none;
}
.crewlink-field-label {
  display: block;
  margin: 8px 0;
  text-align: left;
  font-size: 12px;
  font-weight: 700;
  color: var(--cl-muted);
}
.crewlink-colours {
  display: flex;
  justify-content: center;
  gap: 9px;
  margin: 8px 0 14px;
}
.crewlink-colours button {
  width: 35px;
  height: 35px;
  border: 3px solid transparent;
  border-radius: 50%;
  display: grid;
  place-items: center;
  color: white;
}
.crewlink-colours button.is-active {
  border-color: white;
  box-shadow: 0 0 0 2px currentColor;
}
.crewlink-colours svg {
  width: 15px;
  opacity: 0;
}
.crewlink-colours button.is-active svg {
  opacity: 1;
}
.crewlink-error {
  color: #df3e58 !important;
  font-size: 12px !important;
  margin: 8px !important;
}
.crewlink-sheet__panel-empty {
  padding: 25px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 5px;
  color: var(--cl-muted);
}
.crewlink-sheet__panel-empty svg {
  width: 34px;
}
.crewlink-sheet__panel-empty strong {
  color: var(--cl-text);
}
.crewlink-sheet__panel-empty span {
  font-size: 11px;
}
.crewlink-ping-title {
  font-size: 25px !important;
  line-height: 30px !important;
}
.crewlink-sheet__panel__content > .crewlink-ping-description {
  font-size: 14px;
  line-height: 19px;
}
.crewlink-ping-types {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 5px;
  margin: 15px 0;
}
.crewlink-ping-types button {
  min-width: 0;
  border: 1px solid transparent;
  border-radius: 13px;
  padding: 10px 2px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  color: var(--cl-muted);
  background: var(--cl-surface);
  font-size: 12px;
  font-weight: 600;
  line-height: 15px;
}
.crewlink-ping-types button.is-active {
  border-color: var(--ping);
  color: var(--ping);
  box-shadow: 0 3px 12px var(--ping-glow);
}
.crewlink-ping-types svg {
  width: 22px;
  height: 22px;
}
.crewlink-ping-form :deep(.sky-field .text-xs) {
  font-size: 14px !important;
  font-weight: 600;
  line-height: 18px;
}
.crewlink-ping-form :deep(.crewlink-ping-label-input) {
  font-size: 16px !important;
  line-height: 20px;
}
.crewlink-ping-location-list :deep(.sky-list-item) {
  min-height: 70px;
}
.crewlink-ping-location-copy {
  display: flex;
  flex-direction: column;
  gap: 3px;
  text-align: left;
}
.crewlink-ping-location-copy strong {
  font-size: 17px;
  line-height: 21px;
}
.crewlink-ping-location-copy small {
  max-width: 205px;
  color: var(--cl-muted);
  font-size: 14px;
  line-height: 18px;
}
.crewlink-sheet__panel__content :deep(.crewlink-share-ping) {
  font-size: 16px;
}
.crewlink-code-card {
  display: grid;
  grid-template-columns: 1fr auto 30px 30px;
  align-items: center;
  gap: 5px;
  text-align: left;
}
.crewlink-code-card small {
  font-size: 9px;
  color: var(--cl-muted);
}
.crewlink-code-card strong {
  font-family: monospace;
  letter-spacing: 0.12em;
}
.crewlink-code-card button {
  border: 0;
  background: transparent;
  color: #168dbd;
}
.crewlink-code-card svg {
  width: 16px;
}
.crewlink-member-preview {
  padding-top: 34px;
}
.crewlink-tabbar {
  z-index: 20;
}
.crewlink-tabbar::before {
  position: absolute;
  right: 0;
  bottom: 100%;
  left: 0;
  height: 24px;
  background: linear-gradient(transparent, var(--cl-bg));
  content: '';
  pointer-events: none;
}
.crewlink-tabbar :deep(.crewlink-tabbar__inner) {
  width: 100% !important;
  max-width: none !important;
  padding-inline: 4px !important;
}
.crewlink-tabbar :deep(.crewlink-tabbar__pane) {
  width: 100% !important;
  max-width: none !important;
  gap: 2px;
  padding: 0;
}
.crewlink-tabbar :deep(.crewlink-tabbar__pane > .sky-link) {
  min-width: 0 !important;
  max-width: none !important;
  flex: 1 1 25% !important;
  padding-inline: 2px !important;
}
.crewlink-tabbar :deep(.sky-tab-button__label) {
  font-size: 9px;
  line-height: 11px;
}
.crewlink-tabbar :deep(.sky-icon) {
  width: 23px;
  height: 23px;
}
.crewlink-tabbar :deep(.badge) {
  position: absolute;
  top: -3px;
  right: -7px;
  font-size: 7px;
}
.crewlink-pings-icon {
  position: relative;
  width: 23px;
  height: 23px;
  display: grid;
  place-items: center;
}
.crewlink-pings-icon > svg {
  width: 23px;
  height: 23px;
}
.crewlink-tabbar :deep(.crewlink-pings-badge) {
  position: absolute !important;
  z-index: 2;
  top: -6px !important;
  right: -9px !important;
  display: grid;
  min-width: 16px;
  min-height: 16px;
  height: 16px;
  place-items: center;
  padding: 3px 3px 0;
  border: 2px solid #071018;
  border-radius: 999px;
  box-sizing: border-box;
  font-size: 7px;
  line-height: 1;
  text-align: center;
  pointer-events: none;
}
.crewlink-sheet__panel__content :deep(.crewlink-nearby-rescan) {
  margin-top: 16px;
  margin-bottom: 10px;
}
.crewlink :deep(.crewlink-dialog-cancel) {
  color: #f3f8fb !important;
  background: #173247 !important;
}
.crewlink-avatar {
  overflow: hidden;
}
.crewlink-avatar > img,
.crewlink-profile-card > span img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.crewlink-avatar > i {
  z-index: 1;
}
.crewlink-profile-card > span {
  overflow: hidden;
}
.crewlink-profile-row-avatar {
  width: 34px;
  height: 34px;
  border-radius: 12px;
  display: grid;
  place-items: center;
  overflow: hidden;
  color: #168dbd;
  background: rgba(39, 191, 230, 0.12);
}
.crewlink-profile-row-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.crewlink-sheet__panel__avatar {
  overflow: hidden;
}
.crewlink-sheet__panel__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.crewlink-profile-editor__avatar {
  width: 92px;
  height: 92px;
  margin: 4px auto 12px;
  border: 3px solid rgba(39, 217, 237, 0.7);
  border-radius: 30px;
  display: grid;
  place-items: center;
  overflow: hidden;
  color: #20bde0;
  background: var(--cl-surface);
  box-shadow: 0 12px 30px rgba(17, 137, 189, 0.2);
}
.crewlink-profile-editor__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.crewlink-profile-editor__avatar svg {
  width: 36px;
  height: 36px;
}
.crewlink-profile-editor__media-actions {
  width: 100%;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin: 4px 0 8px;
}
.crewlink-profile-editor__media-actions :deep(.sky-button) {
  min-width: 0;
  margin-top: 0;
  gap: 6px;
}
.crewlink-profile-editor__remove {
  width: 100%;
  margin: 0 0 6px !important;
  color: #e44760;
}
@keyframes cl-pulse {
  0%,
  100% {
    opacity: 0.25;
    transform: scale(0.96);
  }
  50% {
    opacity: 0.75;
    transform: scale(1.02);
  }
}
@media (prefers-reduced-motion: reduce) {
  .crewlink-orbits i {
    animation: none;
  }
}
.crewlink:not(.crewlink--dark) .crewlink-tabbar {
  --sky-app-accent: #005bbd;
}
</style>
