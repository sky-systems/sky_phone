import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const cameraView = readFileSync(
  new URL('./CameraApp.vue', import.meta.url),
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
    expect(cameraView).toContain('Apps.camera.spaceKey')
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

  it('keeps the selfie camera stable while Space still allows movement', () => {
    expect(cameraView).toMatch(
      /event\.code !== 'Space'[\s\S]*cameraLocked\.value/,
    )
    expect(cameraClient).toContain(
      'if camera_state.locked or camera_state.front_camera then',
    )
    expect(cameraClient).toContain('get_front_camera_transform')
    expect(cameraClient).toContain('local front_camera_view_mode = 0')
    expect(cameraClient).toContain('local front_camera_fov = 32.0')
    expect(cameraClient).toContain('local front_camera_distance = 1.05')
    expect(cameraClient).toContain('local head_position = GetPedBoneCoords')
    expect(cameraClient).toContain(
      'local dot = (to_camera.x * forward_vector.x)',
    )
    expect(cameraClient).toContain('front_camera_target_height')
    expect(focusClient).toContain(
      'return { block_game = false, block_look = false, cursor = false, focused = true, game_input = true, keep_input = true }',
    )
    expect(cameraClient).toContain('SetCamCoord(')
    expect(cameraClient).toContain('PointCamAtCoord(')
    expect(cameraClient).not.toContain('SetCamRot(')
    expect(cameraClient).not.toContain('SetEntityHeading(')
    expect(cameraClient).not.toContain('front_camera_position')
    expect(cameraClient).not.toContain('AttachCamToEntity(')
    expect(cameraClient).not.toContain('PointCamAtEntity(')
    expect(cameraView).toContain("window.addEventListener('keyup', onKeyup)")
    expect(cameraView).toContain(
      "nuiCall('camera:setFocus', { focused: true })",
    )
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
