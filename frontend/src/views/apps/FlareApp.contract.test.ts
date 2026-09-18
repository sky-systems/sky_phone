import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(new URL('./FlareApp.vue', import.meta.url), 'utf8')
const clientSource = readFileSync(
  new URL('../../../../sky_phone/source/client/nui_server_bridge.lua', import.meta.url),
  'utf8',
)
const serverSource = readFileSync(
  new URL('../../../../sky_phone/source/server/flare.lua', import.meta.url),
  'utf8',
)
const localeSource = readFileSync(
  new URL('../../../../sky_phone/config/locales/en.lua', import.meta.url),
  'utf8',
)

describe('FlareApp profile editing contract', () => {
  it('shows direct Gallery and Camera actions while creating an account', () => {
    const onboardingStart = source.indexOf(
      '<template v-else-if="!flare.profile">',
    )
    const onboardingEnd = source.indexOf(
      '<template v-else-if="activeMatch">',
      onboardingStart,
    )
    const onboarding = source.slice(onboardingStart, onboardingEnd)

    expect(onboardingStart).toBeGreaterThan(-1)
    expect(onboardingEnd).toBeGreaterThan(onboardingStart)
    expect(onboarding).toContain("openProfileMediaApp('photos')")
    expect(onboarding).toContain("openProfileMediaApp('camera')")
    expect(onboarding).toContain("phone.t('Apps.flare.choosePhotos')")
    expect(onboarding).toContain("phone.t('Apps.flare.takePhoto')")
    expect(onboarding).not.toContain('@click="openPhotoSourcePicker"')
  })

  it('uses the central anchored SkyDropdown for photo sources while editing', () => {
    const triggerClass = source.indexOf('class="flare-photo-add"')
    const triggerStart = source.lastIndexOf('<sky-button', triggerClass)
    const triggerEnd = source.indexOf('</sky-button>', triggerClass)
    const trigger = source.slice(triggerStart, triggerEnd)
    const dropdownStart = source.search(/<SkyDropdown\b/)
    const dropdownEnd = source.indexOf('/>', dropdownStart)
    const dropdown = source.slice(dropdownStart, dropdownEnd)
    const pickerStart = source.indexOf('function openPhotoSourcePicker')
    const pickerEnd = source.indexOf(
      'function openProfileMediaApp',
      pickerStart,
    )
    const picker = source.slice(pickerStart, pickerEnd)
    const mediaAppStart = source.indexOf('function openProfileMediaApp')
    const mediaAppEnd = source.indexOf('function removeDraftPhoto')
    const mediaApp = source.slice(mediaAppStart, mediaAppEnd)

    expect(triggerClass).toBeGreaterThan(-1)
    expect(triggerStart).toBeGreaterThan(-1)
    expect(triggerEnd).toBeGreaterThan(triggerStart)
    expect(source.match(/@click="openPhotoSourcePicker"/g)).toHaveLength(1)
    expect(trigger).toContain('aria-controls="flare-photo-source-menu"')
    expect(trigger).toContain('aria-haspopup="menu"')
    expect(trigger).toContain(':aria-expanded="photoSourceOpened"')
    expect(trigger).not.toContain('aria-haspopup="dialog"')

    expect(dropdownStart).toBeGreaterThan(-1)
    expect(dropdownEnd).toBeGreaterThan(dropdownStart)
    expect(dropdown).toContain('id="flare-photo-source-menu"')
    expect(dropdown).toContain(':items="photoSourceItems"')
    expect(dropdown).toMatch(/:label="phone\.t\('Apps\.flare\.addPhotos'\)"/)
    expect(dropdown).toContain(':opened="photoSourceOpened"')
    expect(dropdown).toContain(':target="photoSourceTarget"')
    expect(dropdown).toContain('@backdropclick="closePhotoSourcePicker"')
    expect(dropdown).toContain('@escape="closePhotoSourcePicker"')
    expect(dropdown).toContain('@positionerror="closePhotoSourcePicker"')
    expect(dropdown).toContain('@select="selectPhotoSource"')

    expect(source).toContain(
      "{ id: 'photos', label: phone.t('Apps.flare.choosePhotos') }",
    )
    expect(source).toContain(
      "{ id: 'camera', label: phone.t('Apps.flare.takePhoto') }",
    )
    expect(pickerStart).toBeGreaterThan(-1)
    expect(pickerEnd).toBeGreaterThan(pickerStart)
    expect(picker).toContain('event.currentTarget instanceof HTMLElement')
    expect(picker).toContain('photoSourceTarget.value = event.currentTarget')
    expect(picker).toContain("if (id !== 'photos' && id !== 'camera') return")
    expect(picker).toContain('openProfileMediaApp(id)')

    expect(source).not.toContain('flare-photo-source-sheet')
    expect(source).not.toMatch(
      /<sky-action-sheet\b[\s\S]*?openProfileMediaApp\(['"](?:photos|camera)['"]\)[\s\S]*?<\/sky-action-sheet>/i,
    )
    expect(mediaAppStart).toBeGreaterThan(-1)
    expect(mediaAppEnd).toBeGreaterThan(mediaAppStart)
    expect(mediaApp).toContain("app: 'camera' | 'photos'")
    expect(mediaApp).toContain("'flare:profile-photos'")
    expect(mediaApp).toContain("app === 'photos' ? remaining : 1")
    expect(mediaApp).toContain('void router.push({')
    expect(mediaApp).toContain("query: { mediaAttachment: 'photo' }")
  })

  it('requires one profile photo before creating or saving a profile', () => {
    const saveStart = source.indexOf('async function saveProfile()')
    const saveEnd = source.indexOf('\n\nfunction selectTab', saveStart)
    const saveProfile = source.slice(saveStart, saveEnd)

    expect(source).toContain(
      'const hasRequiredProfilePhoto = computed(() => draftPhotos.value.length >= 1)',
    )
    expect(saveProfile).toContain('!hasRequiredProfilePhoto.value')
    expect(
      source.match(/:disabled="profileSaving \|\| !hasRequiredProfilePhoto"/g),
    ).toHaveLength(2)
    expect(source).toContain('if (draftPhotos.value.length <= 1) return')
    expect(source).toContain(
      'if (flare.profile && draftPhotos.value.length === 0)',
    )
    expect(
      source.match(
        /<sky-link\s+v-if="draftPhotos\.length > 1"[\s\S]*?class="flare-photo-remove"/g,
      ),
    ).toHaveLength(2)
    expect(source.match(/Apps\.flare\.profilePhotoRequired/g)).toHaveLength(2)
    expect(serverSource).toMatch(
      /#data\.photoMediaIds\s*<\s*1[\s\S]*?#data\.photoMediaIds\s*>\s*6/,
    )
    expect(localeSource).toContain(
      'Add one to six photos from Photos or Camera.',
    )
  })

  it('uses eligible in-game profile photos for Explorer covers', () => {
    const explorerStart = source.indexOf("activeTab === 'explore'")
    const explorerEnd = source.indexOf("activeTab === 'likes'", explorerStart)
    const explorer = source.slice(explorerStart, explorerEnd)

    expect(source).not.toContain('profiles-source.png')
    expect(source).toContain('const exploreTiles = computed(')
    expect(source).toContain('profile.photoUrls.length > 0')
    expect(source).toContain("coverUrl: profile?.photoUrls[0] ?? ''")
    expect(explorer).toContain(
      ':style="tile.coverUrl ? photoStyle(tile.coverUrl) : undefined"',
    )
    expect(explorer).not.toContain('avatarStyle(tile.avatar)')
  })

  it('opens the relationship goal editor from the profile summary card', () => {
    const cardClass = source.indexOf('class="flare-profile-card"')
    const cardStart = source.lastIndexOf('<sky-card', cardClass)
    const cardEnd = source.indexOf('</sky-card>', cardClass)
    const card = source.slice(cardStart, cardEnd)

    expect(cardClass).toBeGreaterThan(-1)
    expect(cardStart).toBeGreaterThan(-1)
    expect(cardEnd).toBeGreaterThan(cardStart)
    expect(card).toContain('component="button"')
    expect(card).toContain('aria-controls="flare-choice-sheet"')
    expect(card).toContain('aria-haspopup="dialog"')
    expect(card).toContain('@click="openProfileGoalEditor"')
    expect(source).toContain('async function openProfileGoalEditor()')
    expect(source).toMatch(
      /openProfileGoalEditor\(\)[\s\S]*?profileEditing\.value = true[\s\S]*?openChoice\('lookingFor', null\)/,
    )
  })

  it('uses the central surfaced SkyNavbar back action for profile screens', () => {
    const mainNavbarStart =
      source.match(/<template v-else>\s*<sky-navbar/)?.index ?? -1
    const mainNavbarEnd = source.indexOf('</sky-navbar>', mainNavbarStart)
    const navbar = source.slice(mainNavbarStart, mainNavbarEnd)

    expect(mainNavbarStart).toBeGreaterThan(-1)
    expect(navbar).toContain(':show-back=')
    expect(navbar).toContain('back-appearance="surface"')
    expect(navbar).toContain(':back-label="phone.t(\'Common.back\')"')
    expect(navbar).toContain('@back="closeProfileScreen"')
    expect(navbar).not.toContain('<template #left>')
  })

  it('shows every own profile photo as a selectable thumbnail', () => {
    expect(source).toContain('class="flare-profile-photo-strip"')
    expect(source).toContain('v-for="(photo, index) in draftPhotos"')
    expect(source).toContain(
      ':aria-pressed="index === normalizedOwnPhotoIndex"',
    )
    expect(source).toContain('@click="selectOwnPhoto(index)"')
    expect(source).toContain(':style="ownPhotoStyle()"')
  })

  it('exposes confirmed sign-out and destructive Flare account deletion', () => {
    expect(source).toContain('<sky-settings-group')
    expect(source).toContain('@activate="signOutDialogOpened = true"')
    expect(source).toContain('@activate="deleteAccountDialogOpened = true"')
    expect(source).toContain(':opened="deleteAccountDialogOpened"')
    expect(source).toContain('role="alertdialog"')
    expect(source).toContain('@escape="closeDeleteAccountDialog"')
    expect(source).toContain('@click="deleteFlareAccount"')
    expect(source).toContain('const account = useAccountStore()')
    expect(source).toContain('const success = await account.logout()')
    expect(source).toContain('appAuth.clear()')
    expect(source).toContain("flare.reset('not_authenticated')")
    expect(localeSource).toContain(
      'This signs the whole phone out of Sky Cloud.',
    )
    expect(localeSource).toContain(
      'Signing out affects every app that uses Sky Cloud on this phone.',
    )
  })

  it('deletes all account-owned Flare data in one server transaction', () => {
    expect(clientSource).toMatch(/flare\s*=\s*\[\[[^\]]*delete-profile/)
    expect(serverSource).toContain(
      'Bridge.Callbacks.Register("sky_phone:flare:delete-profile"',
    )
    expect(serverSource).toContain(
      'SkyPhone.AllowOperation(source, "flare_profile_delete", 3, 60)',
    )
    expect(serverSource).toContain('Bridge.Database.Transaction({')
    expect(serverSource).toContain('DELETE FROM `sky_phone_flare_matches`')
    expect(serverSource).toContain('DELETE FROM `sky_phone_flare_swipes`')
    expect(serverSource).toContain('DELETE FROM `sky_phone_flare_profiles`')
  })
})
