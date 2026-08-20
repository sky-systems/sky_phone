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
      /class="phone-device__frame"[\s\S]*?<PhoneDynamicIsland[\s\S]*?@expanded-change="dynamicIslandExpanded = \$event"[\s\S]*?@live-activity-change="dynamicIslandActivity = \$event"/,
    )
    expect(appSource).toContain('dynamicIslandActivity ||')
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

  it('hides an activity in its owning foreground app but restores it after closing', () => {
    expect(source).toContain(
      'if (!currentActivity || !phone.isOpen) return currentActivity',
    )
    expect(source).toContain("activeAppId.value === 'phone'")
    expect(source).toContain(
      "currentActivity === 'recording' && activeAppId.value === 'memos'",
    )
    expect(source).toContain("activeAppId.value === 'clock'")
    expect(source).toContain(
      "currentActivity === 'music' && activeAppId.value === 'music'",
    )
  })

  it('keeps a non-interactive phone peek visible for background live activities', () => {
    expect(source).toContain("'live-activity-change': [activity:")
    expect(source).toContain("emit('live-activity-change', nextActivity)")
    expect(appSource).toContain(
      "'phone-stage--live-activity':\n          !phone.isOpen && Boolean(dynamicIslandActivity || calls.activeCall)",
    )
    expect(mainCss).toMatch(
      /\.phone-stage--live-activity[\s\S]*?pointer-events:\s*none;[\s\S]*?--phone-live-activity-peek-height/,
    )
    expect(appSource).toContain("? '190px'")
    expect(appSource).toContain("? '155px'")
    expect(appSource).toContain(": '145px'")
    expect(source).toContain(
      "!phone.isOpen ||\n            activity.value === 'incoming-call' ||",
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
    expect(source).not.toContain('phone-dynamic-island__lap')
    expect(source).toContain('phone-dynamic-island__stopwatch-meta')
    expect(source).toContain('{{ stopwatchLapLabel }}')
    expect(source).toContain('{{ stopwatchLapValue }}')
    expect(source).toContain('{{ stopwatchTotalDisplay }}')
  })

  it('matches the reference music player and timer control layouts', () => {
    expect(source).toContain('phone-dynamic-island__music-equalizer')
    expect(source).toContain('phone-dynamic-island__progress-track')
    expect(source).toContain('{{ musicElapsedLabel }}')
    expect(source).toContain('{{ musicRemainingLabel }}')
    expect(source).not.toContain('Airplay')
    expect(source).toContain('<X aria-hidden="true" />')
    expect(source).toMatch(
      /\.phone-dynamic-island--timer\.phone-dynamic-island__copy|\.phone-dynamic-island--timer \.phone-dynamic-island__copy/,
    )
    expect(source).toContain(
      '.phone-dynamic-island--music .phone-dynamic-island__actions--media',
    )
    expect(source).toContain('justify-content: center')
    expect(source).toContain('gap: 34px')
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

  it('collapses expanded activities on taps, swipes, and scrolling outside', () => {
    expect(source).toContain('ref="islandElement"')
    expect(source).toContain(
      "document.addEventListener('pointerdown', onOutsidePointerDown, true)",
    )
    expect(source).toContain(
      "document.addEventListener('scroll', collapseExpanded, true)",
    )
    expect(source).toContain('islandElement.value?.contains(event.target)')
    expect(source).toContain('expanded.value = false')
    expect(source).toContain(
      "document.removeEventListener('pointerdown', onOutsidePointerDown, true)",
    )
    expect(source).toContain(
      "document.removeEventListener('scroll', collapseExpanded, true)",
    )
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
      /\.phone-dynamic-island\[data-expanded='true'\]\s*\{[^}]*width:\s*318px;[^}]*height:\s*74px;/s,
    )
    expect(source).toMatch(
      /\.phone-dynamic-island--incoming-call\[data-expanded='true'\]\s*\{[^}]*height:\s*68px;/s,
    )
    expect(source).toMatch(
      /\.phone-dynamic-island--music\[data-expanded='true'\]\s*\{[^}]*width:\s*316px;[^}]*height:\s*150px;/s,
    )
    expect(source).toMatch(
      /\.phone-dynamic-island--stopwatch\[data-expanded='true'\]\s*\{[^}]*height:\s*70px;/s,
    )
    expect(source).toContain('box-sizing: border-box')
    expect(source).toContain('padding: 8px 16px 8px 10px')
  })
})
