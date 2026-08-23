import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const cameraView = readFileSync(
  new URL('./CameraApp.vue', import.meta.url),
  'utf8',
)
const appShell = readFileSync(new URL('../../App.vue', import.meta.url), 'utf8')
const appWindow = readFileSync(
  new URL('../PhoneAppWindow.vue', import.meta.url),
  'utf8',
)
const shellStyles = readFileSync(
  new URL('../../assets/main.css', import.meta.url),
  'utf8',
)
const mediaCapture = readFileSync(
  new URL('../../components/PhoneMediaCapture.vue', import.meta.url),
  'utf8',
)
const cameraClient = readFileSync(
  new URL('../../../../sky_phone/source/client/camera.lua', import.meta.url),
  'utf8',
)
const focusClient = readFileSync(
  new URL('../../../../sky_phone/source/client/focus.lua', import.meta.url),
  'utf8',
)
const cameraConfig = readFileSync(
  new URL('../../../../sky_phone/config/config.lua', import.meta.url),
  'utf8',
)
const cameraAnimations = readFileSync(
  new URL(
    '../../../../sky_phone/source/client/animations.lua',
    import.meta.url,
  ),
  'utf8',
)

describe('Camera app controls', () => {
  it('uses shared liquid glass for camera interaction buttons', () => {
    expect(cameraView.match(/variant="glass"/g)).toHaveLength(5)
    expect(cameraView).toMatch(
      /<sky-glass\s+component="button"\s+class="camera-latest"/,
    )
    expect(cameraView).not.toContain('variant="neutral"')
  })

  it('uses the Sky UI moving segment for photo and video modes', () => {
    expect(cameraView).toContain('SkySegmented')
    expect(cameraView).toContain(':active-index="mode === \'photo\' ? 0 : 1"')
    expect(cameraView).not.toContain('SkyPillNavigation')
    expect(cameraView).not.toContain('k-segmented')
    expect(cameraView).not.toContain('k-navbar')
  })

  it('stays dark when the global phone appearance is light', () => {
    const cameraPageTag = cameraView.match(/<sky-app-page\b[^>]*>/s)?.[0]

    expect(cameraPageTag).toBeDefined()
    expect(cameraPageTag).toMatch(/\bdark\b/)
    expect(cameraView).toMatch(
      /\.camera-page\s*\{[^}]*--sky-bg:\s*#000;[^}]*--sky-text:\s*#fff;[^}]*background:\s*var\(--sky-bg\);[^}]*color:\s*var\(--sky-text\);/s,
    )
  })

  it('fills the translucent landscape shell without letterbox gaps', () => {
    const landscapeViewport = cameraView.match(
      /\.camera-page--landscape \.camera-viewport\s*\{([^}]*)\}/s,
    )?.[1]

    expect(cameraView).toMatch(
      /\.camera-page--landscape\s*\{[^}]*--sky-bg:\s*rgba\(0, 0, 0, 0\.42\);/s,
    )
    expect(landscapeViewport).toBeDefined()
    expect(landscapeViewport).toContain('top: 50%')
    expect(landscapeViewport).toContain(
      'width: calc(100% * var(--phone-screen-portrait-ratio))',
    )
    expect(landscapeViewport).toContain(
      'aspect-ratio: var(--phone-screen-portrait-ratio)',
    )
    expect(landscapeViewport).not.toContain('16 / 9')
    expect(cameraView).toMatch(
      /\.camera-page--landscape \.camera-shade\s*\{[^}]*linear-gradient\([^)]*90deg,[^)]*rgba\(0, 0, 0, 0\.42\) 0 18%,[^)]*transparent 18% 75%,[^)]*rgba\(0, 0, 0, 0\.42\) 75% 100%/s,
    )
    expect(appShell).toMatch(
      /'phone-screen--camera-landscape':\s*activeAppId === 'camera' && phone\.cameraLandscape/,
    )
    expect(appWindow).toMatch(
      /'app-window--camera-landscape':\s*app\.id === 'camera' && phone\.cameraLandscape/,
    )
    expect(shellStyles).toMatch(
      /\.phone-screen\s*\{[^}]*--phone-screen-portrait-ratio:\s*2\.30951;/s,
    )
    expect(shellStyles).toMatch(
      /\.phone-screen--camera-landscape\s*\{[^}]*background:\s*transparent;/s,
    )
    expect(shellStyles).toMatch(
      /\.phone-screen--camera-landscape \.springboard\s*\{[^}]*visibility:\s*hidden;/s,
    )
    expect(shellStyles).toMatch(
      /\.app-window--camera-landscape\s*\{[^}]*background:\s*transparent;/s,
    )
  })

  it('renders camera notices as plain text without a glass pill', () => {
    const noticeMarkup = cameraView.slice(
      cameraView.indexOf('<span v-if="noticeText"'),
      cameraView.indexOf('<span v-else-if="pendingCount"'),
    )
    const noticeStyles = cameraView.match(
      /\.camera-notice-text\s*,[\s\S]*?\{([^}]*)\}/,
    )?.[1]

    expect(noticeMarkup).toContain('class="camera-notice-text"')
    expect(noticeMarkup).not.toContain('camera-focus-pill')
    expect(noticeStyles).toBeDefined()
    expect(noticeStyles).toContain('color: #ffd60a')
    expect(noticeStyles).not.toMatch(
      /(?:background|backdrop-filter|border-radius|padding)\s*:/,
    )
  })

  it('uses the current compact lens selector treatment', () => {
    const zoomControl = cameraView.slice(
      cameraView.indexOf('<div class="camera-zoom-control">'),
      cameraView.indexOf('<footer class="camera-controls">'),
    )

    expect(zoomControl).toContain('variant="plain"')
    expect(zoomControl).not.toContain('glass')
    expect(zoomControl).toContain('{{ zoomPresetLabel(zoom) }}')
    expect(cameraView).toContain("return zoom === 0.5 ? '.5' : `${zoom}`")
    expect(cameraView).toMatch(
      /\.camera-zoom-control\s*\{[^}]*bottom:\s*216px;/s,
    )
    expect(cameraView).toMatch(/\.camera-zoom-row\s*\{[^}]*gap:\s*10px;/s)
    expect(cameraView).toMatch(
      /\.camera-zoom-pill\s*\{[^}]*width:\s*36px;[^}]*min-width:\s*36px;[^}]*height:\s*36px;[^}]*min-height:\s*36px;[^}]*padding:\s*0;/s,
    )
    expect(cameraView).toMatch(
      /\.camera-zoom-pill::before\s*\{[^}]*width:\s*var\(--sky-touch-target, 44px\);[^}]*inset-block:\s*-4px;/s,
    )
    expect(cameraView).toMatch(
      /\.camera-zoom-pill\.active\s*\{[^}]*color:\s*#ffd60a;[^}]*background:\s*rgba\(28, 28, 30, 0\.78\);/s,
    )
  })

  it('keeps continuous wheel zoom without an extra slider bar', () => {
    expect(cameraView).not.toContain('camera-zoom-slider')
    expect(cameraView).not.toContain('type="range"')
    expect(cameraView).toContain('@wheel.prevent.stop="zoomWithWheel"')
    expect(cameraView).toContain(
      'Math.min(120, event.deltaY * deltaMultiplier)',
    )
    expect(cameraView).toContain('wheelDelta * 0.00075')
    expect(cameraView).toContain("message.type === 'camera:zoom'")
    expect(cameraClient).toContain('mouse_wheel_zoom_step = 0.08')
    expect(cameraClient).toContain('INPUT_CURSOR_SCROLL_UP')
    expect(cameraClient).toContain('INPUT_CURSOR_SCROLL_DOWN')
    expect(cameraClient).toContain('IsDisabledControlJustPressed(0, 241)')
    expect(cameraClient).toContain('IsDisabledControlJustPressed(0, 242)')
    expect(cameraClient).toContain('type = "camera:zoom"')
    expect(mediaCapture).toContain('nextZoom < 0.5 || nextZoom > 3')
    expect(mediaCapture).not.toContain('[0.5, 1, 2, 3].includes(nextZoom)')
  })

  it('renders the development preview differently at 0.5x and 1x', () => {
    expect(cameraView).toContain('transform: `scale(${selectedZoom})`')
    expect(cameraView).not.toContain('Math.max(1, selectedZoom)')
    expect(cameraView).toMatch(
      /\.camera-dev-view\s*\{[^}]*inset:\s*-50%;[^}]*width:\s*200%;[^}]*height:\s*200%;/s,
    )
  })

  it('locks look controls without changing the global gameplay camera', () => {
    expect(cameraView).toContain("nuiCall('camera:setLocked'")
    expect(cameraView).toContain('cameraLocked.value')
    expect(cameraView).toContain('Apps.camera.lookKey')
    expect(cameraView).not.toContain('Apps.camera.spaceKey')
    expect(cameraClient).toContain('RegisterNUICallback("camera:setLocked"')
    expect(cameraClient).toContain('INPUT_LOOK_LR')
    expect(cameraClient).toContain('INPUT_LOOK_UD')
    expect(cameraClient).toContain('first_person_view_mode = 4')
    expect(cameraClient).toContain(
      'local view_mode = camera_state.front_camera and front_camera_view_mode or first_person_view_mode',
    )
    expect(cameraClient).toContain('SetFollowVehicleCamViewMode(view_mode)')
    expect(cameraClient).toContain('SetFollowPedCamViewMode(view_mode)')
    expect(cameraClient).toMatch(
      /while camera_state\.active do[\s\S]*apply_camera_view\(\)/,
    )
    expect(cameraClient).not.toContain('next_view_apply')
    expect(cameraClient).not.toContain('ultrawide_camera_handle')
    expect(cameraClient).not.toContain('ensure_ultrawide_camera')
  })

  it('uses the configured HoldToLook control and Space in camera modes', () => {
    expect(cameraView).not.toContain("event.code !== 'Space'")
    expect(cameraView).not.toContain("window.addEventListener('keydown'")
    expect(focusClient).toContain(
      'function SkyPhoneFocus.IsHoldToLookPressed()',
    )
    expect(focusClient).toContain(
      'IsDisabledControlPressed(0, hold_to_look_control)',
    )
    expect(cameraClient).toContain('SkyPhoneFocus.IsHoldToLookPressed()')
    expect(cameraClient).toContain(
      'IsDisabledControlPressed(0, camera_passthrough_control)',
    )
    expect(cameraClient).toMatch(
      /if data\.active then\s+watch_camera_controls\(\)/,
    )
    expect(cameraClient).not.toContain('IsDisabledControlJustReleased(0, 22)')
  })

  it('orbits the stable selfie camera while HoldToLook allows movement', () => {
    expect(cameraClient).toContain(
      'if camera_state.locked or camera_state.front_camera then',
    )
    expect(cameraClient).toContain('get_front_camera_transform')
    expect(cameraClient).toContain('local front_camera_view_mode = 0')
    expect(cameraClient).toContain('local front_camera_fov = 32.0')
    expect(cameraClient).toContain('local front_camera_distance = 1.05')
    expect(cameraClient).toContain('local front_camera_horizontal_limit = 75.0')
    expect(cameraClient).toContain('local front_camera_vertical_limit = 35.0')
    expect(cameraClient).toContain('local head_position = GetPedBoneCoords')
    expect(cameraClient).toContain('GetDisabledControlNormal(0, 1)')
    expect(cameraClient).toContain('GetDisabledControlNormal(0, 2)')
    expect(cameraClient).toContain('update_front_camera_orbit()')
    expect(cameraClient).toContain('camera_state.front_camera_yaw')
    expect(cameraClient).toContain('camera_state.front_camera_pitch')
    expect(cameraClient).toContain('front_camera_target_height')
    expect(focusClient).toContain(
      'return { block_game = false, block_look = false, cursor = false, focused = true, game_input = true, keep_input = true }',
    )
    expect(focusClient).toContain(
      'return { block_game = true, block_look = true, cursor = true, focused = true, game_input = false, keep_input = true }',
    )
    expect(focusClient).toContain('gameInput = focus.game_input')
    expect(cameraClient).toContain('SetCamCoord(')
    expect(cameraClient).toContain('PointCamAtCoord(')
    expect(cameraClient).not.toContain('SetCamRot(')
    expect(cameraClient).not.toContain('SetEntityHeading(')
    expect(cameraClient).not.toContain('front_camera_position')
    expect(cameraClient).not.toContain('AttachCamToEntity(')
    expect(cameraClient).not.toContain('PointCamAtEntity(')
  })

  it('uses a looping camera-hold pose instead of the old selfie dance', () => {
    expect(cameraConfig).toContain('Camera = "cellphone@self"')
    expect(cameraConfig).toContain('Camera = "selfie"')
    expect(cameraAnimations).toContain(
      'mode == MODE_CAMERA_REAR or mode == MODE_CAMERA_SELFIE',
    )
    expect(cameraAnimations).toContain(
      'Config.Animations.Dictionaries.Camera, Config.Animations.Clips.Camera',
    )
    expect(cameraConfig).not.toContain('anim@mp_player_intuppertake_selfie')
  })
})
