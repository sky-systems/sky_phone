import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

const source = readFileSync(
  new URL('./PhoneDynamicIsland.vue', import.meta.url),
  'utf8',
)
const appSource = readFileSync(new URL('../App.vue', import.meta.url), 'utf8')
const mainCss = readFileSync(
  new URL('../assets/main.css', import.meta.url),
  'utf8',
)
const recorderSource = readFileSync(
  new URL('./PhoneMemoRecorder.vue', import.meta.url),
  'utf8',
)
const memosSource = readFileSync(
  new URL('../views/apps/MemosApp.vue', import.meta.url),
  'utf8',
)
const clockSource = readFileSync(
  new URL('../views/apps/ClockApp.vue', import.meta.url),
  'utf8',
)

describe('Phone Dynamic Island contract', () => {
  it('renders once at phone shell level instead of forcing calls into Phone', () => {
    expect(appSource).toContain(
      "import PhoneDynamicIsland from '@/components/PhoneDynamicIsland.vue'",
    )
    expect(appSource).toContain(
      "'phone-device--island-expanded': dynamicIslandExpanded",
    )
    expect(appSource).toMatch(
      /class="phone-device__frame"[\s\S]*?<PhoneDynamicIsland[\s\S]*?@expanded-change="dynamicIslandExpanded = \$event"/,
    )
    expect(appSource).toContain(
      'phone.isOpen || notifications.current || calls.activeCall',
    )
    expect(appSource).not.toContain(
      "window.setTimeout(() => void router.push('/apps/phone'), 0)",
    )
  })

  it('prioritizes calls and exposes answer, decline, and hangup controls', () => {
    expect(source.indexOf("return 'incoming-call'")).toBeLessThan(
      source.indexOf("return 'recording'"),
    )
    expect(source).toContain('@click.stop="calls.answer()"')
    expect(source).toContain('@click.stop="endCall"')
    expect(source).toContain('void calls.decline()')
    expect(source).toContain('void calls.hangup()')
    expect(source).toContain('call.answeredAt ?? call.startedAt')
  })

  it('shows an activity only after leaving its owning app', () => {
    expect(source).toContain("activeAppId.value !== 'phone'")
    expect(source).toContain(
      "recordingActive.value && activeAppId.value !== 'memos'",
    )
    expect(source).toContain(
      "timerActive.value && activeAppId.value !== 'clock'",
    )
    expect(source).toContain(
      "stopwatchActive.value && activeAppId.value !== 'clock'",
    )
    expect(source).toContain(
      "music.currentTrack && activeAppId.value !== 'music'",
    )
  })

  it('connects music, recorder, timer, and stopwatch controls to their stores', () => {
    expect(source).toContain('@click.stop="music.previous()"')
    expect(source).toContain('@click.stop="music.toggle()"')
    expect(source).toContain('@click.stop="music.next()"')
    expect(source).toContain("postRecorderCommand('memo:recordStop')")
    expect(source).toContain('clock.pauseTimer(Date.now())')
    expect(source).toContain('clock.pauseStopwatch(Date.now())')
    expect(source).toContain('clock.addLap(Date.now())')
  })

  it('keeps recorder state available across app changes', () => {
    expect(recorderSource).toContain(
      "message.type === 'memo:recordStateRequest'",
    )
    expect(memosSource).toContain(
      "postRecorderCommand('memo:recordStateRequest')",
    )
    expect(memosSource).not.toContain(
      "if (recordingActive.value) postRecorderCommand('memo:recordCancel')",
    )
  })

  it('opens both clock live activities on the correct clock tab', () => {
    expect(source).toContain("'/apps/clock?section=timer'")
    expect(source).toContain("'/apps/clock?section=stopwatch'")
    expect(clockSource).toContain(
      "section === 'timer' || section === 'stopwatch'",
    )
  })

  it('opens activities by tapping the island without a separate expand icon', () => {
    expect(source).toContain('@click.stop="toggleExpanded"')
    expect(source).toContain('@click.stop="openActivity"')
    expect(source).not.toContain('Maximize2')
    expect(source).not.toContain('phone-dynamic-island__open-icon')
  })

  it('animates state changes and moves popup notifications below expanded UI', () => {
    expect(source).toContain('<Transition name="phone-dynamic-island">')
    expect(source).toContain(
      '<Transition name="phone-dynamic-island-content" mode="out-in">',
    )
    expect(source).toContain(".phone-dynamic-island[data-expanded='true']")
    expect(source).toContain("emit('expanded-change', false)")
    expect(mainCss).toContain(
      '.phone-device--island-expanded .phone-notification',
    )
    expect(source).toContain('@media (prefers-reduced-motion: reduce)')
  })

  it('renders below the top edge and above the physical camera frame', () => {
    expect(source).toMatch(
      /\.phone-dynamic-island\s*\{[^}]*z-index:\s*102;[^}]*top:\s*30px;/s,
    )
    expect(mainCss).not.toMatch(/\.phone-dynamic-island\s*\{/)
  })

  it('keeps compact and expanded islands close to the physical camera proportions', () => {
    expect(source).toMatch(
      /\.phone-dynamic-island\s*\{[^}]*width:\s*126px;[^}]*height:\s*38px;/s,
    )
    expect(source).toMatch(
      /\.phone-dynamic-island\[data-expanded='true'\]\s*\{[^}]*width:\s*318px;[^}]*height:\s*82px;/s,
    )
    expect(source).toMatch(
      /\.phone-dynamic-island--incoming-call\[data-expanded='true'\]\s*\{[^}]*height:\s*78px;/s,
    )
    expect(source).toMatch(
      /\.phone-dynamic-island--music\[data-expanded='true'\]\s*\{[^}]*width:\s*326px;[^}]*height:\s*136px;/s,
    )
  })
})
