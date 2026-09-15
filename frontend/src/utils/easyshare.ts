import type { Router } from 'vue-router'

import { getPhoneApp } from '@/config/apps'
import type {
  EasyShareDestinationApp,
  EasyShareKind,
  EasySharePayload,
} from '@/types/easyshare'

const chatDestinations: EasyShareDestinationApp[] = [
  'messages',
  'darkchat',
  'flare',
]
const noteCompatibleKinds = new Set<EasyShareKind>([
  'document',
  'link',
  'location',
  'note',
  'text',
])

const schemeRoutes: Record<string, string> = {
  location: '/apps/map',
  media: '/apps/photos',
  phone: '/apps/phone',
}

export function easyShareDestinationAppIds(
  payload: EasySharePayload,
): EasyShareDestinationApp[] {
  const destinations = [...chatDestinations]
  if (payload.appId !== 'notes' && noteCompatibleKinds.has(payload.kind)) {
    destinations.push('notes')
  }
  return destinations
}

export function easyShareRoute(payload: EasySharePayload): {
  path: string
  query: Record<string, string>
} {
  const match = payload.link?.match(
    /^skyphone:\/\/([^/]+)(?:\/([^/]+))?(?:\/(.+))?$/,
  )
  const schemeApp = match?.[1]
  const app = schemeApp ? getPhoneApp(schemeApp) : getPhoneApp(payload.appId)
  const path = (schemeApp && schemeRoutes[schemeApp]) || app?.route || '/'
  const query: Record<string, string> = {
    easyShareId: String(payload.id ?? match?.[3] ?? match?.[2] ?? ''),
    easyShareKind: payload.kind,
    easyShareLink: payload.link ?? '',
  }
  if (
    !payload.meta?.received &&
    ((payload.kind === 'profile' &&
      ['flare', 'crewlink'].includes(payload.appId)) ||
      ['note', 'text', 'document', 'photo', 'video', 'media'].includes(
        payload.kind,
      ))
  ) {
    query.sharedContent = JSON.stringify({
      title: payload.title,
      body: payload.copyText,
      imageUrl: payload.imageUrl,
      kind: payload.kind,
      items:
        payload.kind === 'media'
          ? payload.meta?.items
          : ['photo', 'video'].includes(payload.kind)
            ? [
                {
                  url: payload.meta?.url ?? payload.imageUrl,
                  mediaType: payload.kind,
                },
              ]
            : [],
    })
  }
  if (payload.appId === 'music' && payload.meta?.songs) {
    query.sharedMusic = JSON.stringify({
      title: payload.title,
      songs: payload.meta.songs,
    })
  }
  if (
    payload.kind === 'location' &&
    typeof payload.meta?.x === 'number' &&
    typeof payload.meta?.y === 'number'
  ) {
    query.sharedLocation = JSON.stringify({
      x: payload.meta.x,
      y: payload.meta.y,
      z: payload.meta.z ?? 0,
      label: payload.title,
    })
  }
  if (payload.kind === 'contact') {
    const number = payload.meta?.phoneNumber ?? payload.subtitle
    if (typeof number === 'string' && /^[+\d\s()-]+$/.test(number)) {
      query.sharedContactNumber = number.replace(/[^+\d]/g, '')
    }
  }
  if (schemeApp === 'citymarkt' && match?.[2] === 'listing' && match[3]) {
    try {
      query.listingId = decodeURIComponent(match[3])
    } catch {
      query.listingId = match[3]
    }
  }
  return {
    path,
    query,
  }
}

export function easyShareCrewLinkInviteCode(
  kind: unknown,
  link: unknown,
  id: unknown,
): string | null {
  if (kind !== 'link') return null
  if (typeof link === 'string') {
    const match = link.match(/^skyphone:\/\/crewlink\/invite\/([a-z0-9]{8})$/i)
    if (match) return match[1].toUpperCase()
  }
  if (typeof id === 'string' && /^[a-z0-9]{8}$/i.test(id)) {
    return id.toUpperCase()
  }
  return null
}

export function easyShareDarkChatInviteCode(
  kind: unknown,
  link: unknown,
): string | null {
  if (kind !== 'profile' || typeof link !== 'string') return null
  const match = link.match(
    /^skyphone:\/\/darkchat\/invite\/(DC-[A-Z0-9]{4}-[A-Z0-9]{4})$/i,
  )
  return match ? match[1].toUpperCase() : null
}

export type EasyShareMusicTarget =
  | { id: string; kind: 'playlist' }
  | { id: string; kind: 'track'; source: 'server' | 'youtube' }

export function easyShareMusicTarget(
  kind: unknown,
  link: unknown,
): EasyShareMusicTarget | null {
  if (typeof link !== 'string') return null
  if (kind === 'track') {
    const match = link.match(
      /^skyphone:\/\/music\/(server|youtube)\/([^/?#]+)$/,
    )
    if (match) {
      return {
        id: match[2],
        kind: 'track',
        source: match[1] as 'server' | 'youtube',
      }
    }
  }
  if (kind === 'playlist') {
    const match = link.match(/^skyphone:\/\/music\/playlist\/([^/?#]+)$/)
    if (match) return { id: match[1], kind: 'playlist' }
  }
  return null
}

export async function openEasySharePayload(
  router: Router,
  payload: EasySharePayload,
): Promise<void> {
  const target = easyShareRoute(payload)
  target.query.easyShareLaunch = crypto.randomUUID()
  await router.push(target)
}
