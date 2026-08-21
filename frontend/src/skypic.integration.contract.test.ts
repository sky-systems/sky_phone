import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const read = (path: string) =>
  readFileSync(new URL(path, import.meta.url), 'utf8')

const app = read('./App.vue')
const appAuth = read('./stores/app-auth.ts')
const appIcon = read('./components/AppIcon.vue')
const client = read('../../sky_phone/source/client/main.lua')
const easyShare = read('../../sky_phone/source/server/easyshare.lua')
const manifest = read('../../sky_phone/fxmanifest.lua')
const mockServer = read('../testserver/index.cjs')
const phoneServer = read('../../sky_phone/source/server/phone.lua')
const reservedApps = read('../../sky_phone/source/shared/custom_apps.lua')
const server = read('../../sky_phone/source/server/skypic.lua')
const types = read('./types/skypic.ts')

const callbacks = [
  'skypic:bootstrap',
  'skypic:create-profile',
  'skypic:delete-account',
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
  'skypic:spotlight-feed',
  'skypic:publish-spotlight',
  'skypic:view-spotlight',
  'skypic:like-spotlight',
  'skypic:spotlight-comments',
  'skypic:comment-spotlight',
  'skypic:delete-spotlight-comment',
  'skypic:remove-spotlight',
  'skypic:report-spotlight',
  'skypic:thread',
  'skypic:send-message',
  'skypic:mark-thread',
  'skypic:save-message',
  'skypic:delete-message',
] as const

function typeBlock(name: string): string {
  const start = types.indexOf(`export type ${name} = {`)
  const end = types.indexOf(String.fromCharCode(10) + '}', start)
  expect(start).toBeGreaterThanOrEqual(0)
  expect(end).toBeGreaterThan(start)
  return types.slice(start, end)
}

describe('SkyPic cross-runtime integration contract', () => {
  it('bridges every canonical callback through client, server, and browser mock', () => {
    for (const callback of callbacks) {
      expect(client, `missing client callback ${callback}`).toContain(
        `"${callback}"`,
      )
      expect(server, `missing server callback ${callback}`).toContain(
        `"sky_phone:${callback}"`,
      )
      expect(mockServer, `missing browser mock ${callback}`).toContain(
        `endpoint === '${callback}'`,
      )
    }
  })

  it('loads the server after media and reserves the app for built-in sharing', () => {
    const mediaIndex = manifest.indexOf("'source/server/media.lua'")
    const skyPicIndex = manifest.indexOf("'source/server/skypic.lua'")
    expect(mediaIndex).toBeGreaterThanOrEqual(0)
    expect(skyPicIndex).toBeGreaterThan(mediaIndex)
    expect(reservedApps).toContain('skypic = true')
    expect(easyShare).toContain('skypic = true')
  })

  it('routes localized device-aware notifications and refreshes live state', () => {
    expect(client).toContain(
      'RegisterNetEvent("sky_phone:skypic:new", function(data)',
    )
    expect(client).toContain('locale.Nui.Apps.skypic')
    expect(client).toContain(
      'notification_text:gsub("{actor}", tostring(data.actor or ""))',
    )
    expect(client).toContain(
      'SendNUIMessage({ type = "skypic:new", data = data })',
    )
    expect(client).toContain(
      'RegisterNetEvent("sky_phone:skypic:changed", function(data)',
    )
    expect(client).toContain(
      'SendNUIMessage({ type = "skypic:changed", data = data })',
    )
    expect(server).toContain(
      'notify_profile(friendship.peer_id, profile, story_id and "story_reply" or "message", nil)',
    )
    expect(server).toContain('profileId = actor.profile_id')
    expect(phoneServer).toContain('required_app_auth')
    expect(phoneServer).toContain(
      'app_auth.accountEmail ~= device.account_email',
    )
    expect(phoneServer).toContain('has_required_app_session(device)')
    expect(server.match(/}, 'skypic'\)/g)).toHaveLength(3)

    expect(app).toContain("event.data?.type === 'skypic:new'")
    expect(app).toContain("event.data?.type === 'skypic:changed'")
    expect(app).toContain("appId: 'skypic'")
    expect(app).toContain('route: skyPicNotificationRoute(data)')
    expect(app).toContain("query.set('profileId', data.profileId)")
    expect(app).toContain(
      "if (data.kind === 'snap' && data.snapId) query.set('snap', data.snapId)",
    )
    expect(app).toContain(
      'preferences: parsePhonePreferences(data.device.settings ?? null)',
    )
    expect(app).toContain(
      '!data.device || data.device.imei === phone.device?.imei',
    )
    expect(app).toContain('if (phone.isOpen && targetsActiveDevice)')
    expect(app).toContain('void refreshSkyPicState(true)')
    expect(app).toContain('!targetsActiveDevice || signedInOnActiveDevice')
    expect(appIcon).toContain(
      "if (props.app.id === 'skypic') return skypic.unreadCount",
    )
  })

  it('scopes badge state to the active unlocked device and account session', () => {
    expect(appAuth).toContain("'skypic'")
    expect(app).toContain(
      "if (!account.email || !appAuth.isSignedIn('skypic'))",
    )
    expect(app).toContain(
      "() => [phone.device?.imei ?? '', account.email] as const",
    )
    expect(app).toContain(
      'if (imei === previousImei && email === previousEmail) return',
    )
    expect(app).toContain('skypic.resetSession()')
    expect(app).toContain("appAuth.signOut('skypic')")
    expect(app).toContain('unlockedServicesLoaded.value = false')
    expect(app).toContain(
      'if (phone.isOpen && !isLocked.value && !setupRequired.value)',
    )
  })

  it('does not let background refreshes abort auth discovery or account deletion', () => {
    const refreshBlock = app
      .split('async function refreshSkyPicState(refreshThread = false)')[1]
      ?.split('function queueCompaniesChange')[0]
    expect(refreshBlock).toContain(
      'if (!skypic.bootstrapPending) skypic.resetSession()',
    )
    expect(refreshBlock).toContain('if (skypic.accountDeletePending) return')
    expect(app).toContain('!skypic.bootstrapPending')
  })

  it('keeps snap and story secrets out of list payload types', () => {
    const snap = typeBlock('SkyPicSnap')
    const story = typeBlock('SkyPicStory')
    const openedSnap = typeBlock('SkyPicOpenedSnap')
    const viewedStory = typeBlock('SkyPicViewedStory')

    for (const metadata of [snap, story]) {
      expect(metadata).not.toContain('url:')
      expect(metadata).not.toContain('caption:')
      expect(metadata).not.toContain('textOverlay:')
      expect(metadata).not.toContain('overlayColor:')
    }
    for (const opened of [openedSnap, viewedStory]) {
      expect(opened).toContain('url:')
      expect(opened).toContain('caption:')
      expect(opened).toContain('textOverlay:')
      expect(opened).toContain('overlayColor:')
    }
    expect(viewedStory).toContain('canReply:')
    expect(mockServer).toContain('const skyPicSnapContents = new Map(')
    expect(mockServer).toContain('const skyPicStoryContents = new Map(')
    expect(mockServer).toContain('blockedProfiles: skyPicProfiles')
    expect(mockServer).toContain(
      'skyPicIncrementOwnScore(recipients.length * mediaItems.length)',
    )
    expect(mockServer).toContain('.slice(offset, offset + 30)')
    expect(mockServer).toContain(
      "response.json({ success: false, error: 'story_unavailable' })",
    )
  })
})
