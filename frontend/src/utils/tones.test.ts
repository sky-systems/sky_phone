import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { ALARM_SOUND_IDS } from './alarms'
import { setPhoneOutputVolume } from './phoneAudio'
import {
  phoneToneDuration,
  playPhoneEffect,
  playPhoneMediaTone,
  playPhoneVibration,
} from './tones'

describe('phone tones', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('defines a playable duration for every alarm sound', () => {
    for (const sound of ALARM_SOUND_IDS) {
      expect(phoneToneDuration(sound)).toBeGreaterThan(0)
      expect(phoneToneDuration(sound)).toBeLessThanOrEqual(1500)
    }
  })

  it('reports media playback only after play has actually started', async () => {
    let resolvePlay: (() => void) | undefined
    const onError = vi.fn()
    const onStarted = vi.fn()
    vi.stubGlobal(
      'Audio',
      class extends EventTarget {
        loop = false
        preload = ''
        volume = 0

        load(): void {}

        pause(): void {}

        play(): Promise<void> {
          return new Promise((resolve) => {
            resolvePlay = resolve
          })
        }

        removeAttribute(): void {}
      },
    )

    const stop = playPhoneMediaTone(
      'data:audio/ogg;base64,T2dnUw==',
      75,
      false,
      {
        onError,
        onStarted,
      },
    )

    expect(onStarted).not.toHaveBeenCalled()
    resolvePlay?.()
    await vi.waitFor(() => expect(onStarted).toHaveBeenCalledOnce())
    expect(onError).not.toHaveBeenCalled()
    stop()
  })

  it.each([false, true])(
    'releases completed one-shot media while preserving looping playback (loop=%s)',
    (loop) => {
      const pause = vi.fn()
      const load = vi.fn()
      const removeAttribute = vi.fn()
      const players: EventTarget[] = []
      vi.stubGlobal(
        'Audio',
        class extends EventTarget {
          loop = false
          preload = ''
          volume = 1
          pause = pause
          load = load
          removeAttribute = removeAttribute

          constructor() {
            super()
            players.push(this)
          }

          async play(): Promise<void> {}
        },
      )

      const stop = playPhoneMediaTone(
        'data:audio/ogg;base64,T2dnUw==',
        100,
        loop,
      )
      players[0]?.dispatchEvent(new Event('ended'))
      expect(pause).toHaveBeenCalledTimes(loop ? 0 : 1)
      stop()
      stop()
      expect(pause).toHaveBeenCalledOnce()
      expect(load).toHaveBeenCalledOnce()
      expect(removeAttribute).toHaveBeenCalledWith('src')
    },
  )
})

class TestAudioParam {
  value = 0
  setValueAtTime = vi.fn((value: number) => {
    this.value = value
  })
  linearRampToValueAtTime = vi.fn()
}

class TestGain {
  gain = new TestAudioParam()
  connect = vi.fn()
  disconnect = vi.fn()
}

class TestOscillator {
  type = 'sine'
  frequency = new TestAudioParam()
  detune = new TestAudioParam()
  connect = vi.fn()
  disconnect = vi.fn()
  start = vi.fn()
  onended: (() => void) | null = null
  private endTimer?: ReturnType<typeof setTimeout>

  constructor(private context: TestAudioContext) {}

  stop = vi.fn((at = this.context.currentTime) => {
    clearTimeout(this.endTimer)
    this.endTimer = setTimeout(
      () => this.onended?.(),
      Math.max(0, (at - this.context.currentTime) * 1000),
    )
  })
}

class TestAudioContext {
  static instances: TestAudioContext[] = []
  static resumeResult: () => Promise<void> = async () => undefined
  private createdAt = Date.now()
  destination = {}
  gains: TestGain[] = []
  oscillators: TestOscillator[] = []
  resume = vi.fn(() => TestAudioContext.resumeResult())
  close = vi.fn(async () => undefined)
  createGain = vi.fn(() => {
    const gain = new TestGain()
    this.gains.push(gain)
    return gain
  })
  createOscillator = vi.fn(() => {
    const oscillator = new TestOscillator(this)
    this.oscillators.push(oscillator)
    return oscillator
  })

  constructor() {
    TestAudioContext.instances.push(this)
  }

  get currentTime(): number {
    return (Date.now() - this.createdAt) / 1000
  }
}

describe('synthesized phone effects', () => {
  const stops: Array<() => void> = []

  beforeEach(() => {
    vi.useFakeTimers()
    TestAudioContext.instances = []
    TestAudioContext.resumeResult = async () => undefined
    vi.stubGlobal('window', { AudioContext: TestAudioContext })
    setPhoneOutputVolume(1)
  })

  afterEach(() => {
    for (const stop of stops.splice(0)) stop()
    setPhoneOutputVolume(1)
    vi.useRealTimers()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it('never schedules audio after cancellation while resume is pending', async () => {
    let resume: (() => void) | undefined
    TestAudioContext.resumeResult = () =>
      new Promise((resolve) => {
        resume = resolve
      })
    const stop = playPhoneEffect('calling', 100, true)
    stops.push(stop)
    const context = TestAudioContext.instances[0]!

    stop()
    stop()
    resume?.()
    await Promise.resolve()
    expect(context.createOscillator).not.toHaveBeenCalled()
    expect(context.close).toHaveBeenCalledOnce()
    expect(context.gains[0]!.disconnect).toHaveBeenCalledOnce()
    expect(vi.getTimerCount()).toBe(0)
  })

  it.each(['calling', 'endcall', 'button'] as const)(
    'automatically releases a completed %s one-shot',
    async (effect) => {
      const stop = playPhoneEffect(effect, 80, false)
      stops.push(stop)
      await vi.runAllTimersAsync()
      const context = TestAudioContext.instances[0]!
      expect(context.oscillators.length).toBeGreaterThan(0)
      expect(context.close).toHaveBeenCalledOnce()
      for (const node of [...context.oscillators, ...context.gains])
        expect(node.disconnect).toHaveBeenCalledOnce()
      stop()
      expect(context.close).toHaveBeenCalledOnce()
      expect(vi.getTimerCount()).toBe(0)
    },
  )

  it('keeps the loop gap silent and cancels its pending timer on stop', async () => {
    const stop = playPhoneEffect('calling', 100, true)
    stops.push(stop)
    await vi.advanceTimersByTimeAsync(710)
    const context = TestAudioContext.instances[0]!
    const firstCycleVoices = context.oscillators.length
    expect(firstCycleVoices).toBeGreaterThan(0)
    await vi.advanceTimersByTimeAsync(899)
    expect(context.oscillators).toHaveLength(firstCycleVoices)
    await vi.advanceTimersByTimeAsync(1)
    expect(context.oscillators).toHaveLength(firstCycleVoices * 2)
    await vi.advanceTimersByTimeAsync(710)
    stop()
    await vi.advanceTimersByTimeAsync(10000)
    expect(context.oscillators).toHaveLength(firstCycleVoices * 2)
    expect(context.close).toHaveBeenCalledOnce()
    expect(vi.getTimerCount()).toBe(0)
  })

  it('shares one context between effects and closes it only after the last playback stops', async () => {
    const stopCalling = playPhoneEffect('calling', 100, true)
    const stopButton = playPhoneEffect('button', 55, false)
    stops.push(stopCalling, stopButton)
    await vi.advanceTimersByTimeAsync(70)
    expect(TestAudioContext.instances).toHaveLength(1)
    const context = TestAudioContext.instances[0]!
    expect(context.close).not.toHaveBeenCalled()
    stopCalling()
    expect(context.close).toHaveBeenCalledOnce()
  })

  it('applies live master volume including exact silence and unsubscribes on disposal', async () => {
    setPhoneOutputVolume(0)
    const stop = playPhoneEffect('calling', 50, true)
    stops.push(stop)
    await Promise.resolve()
    const output = TestAudioContext.instances[0]!.gains[0]!.gain
    expect(output.value).toBe(0)
    setPhoneOutputVolume(0.5)
    expect(output.value).toBeCloseTo(0.04)
    setPhoneOutputVolume(0)
    expect(output.value).toBe(0)
    stop()
    const volumeChanges = output.setValueAtTime.mock.calls.length
    setPhoneOutputVolume(1)
    expect(output.setValueAtTime).toHaveBeenCalledTimes(volumeChanges)
  })

  it.each([0, -10, Number.NaN])(
    'does not allocate playback for silent local volume %s',
    (volume) => {
      const stop = playPhoneEffect('button', volume, false)
      stops.push(stop)
      expect(TestAudioContext.instances).toHaveLength(0)
      stop()
    },
  )

  it.each(['call', 'notification'] as const)(
    'synthesizes and disposes the %s buzz without creating a media element',
    async (kind) => {
      const audio = vi.fn()
      vi.stubGlobal('Audio', audio)
      const stop = playPhoneVibration(kind, false)
      stops.push(stop)
      await vi.runAllTimersAsync()
      const context = TestAudioContext.instances[0]!
      expect(audio).not.toHaveBeenCalled()
      expect(context.oscillators.length).toBeGreaterThan(0)
      expect(context.close).toHaveBeenCalledOnce()
    },
  )

  it('cleans up when resume is rejected', async () => {
    const error = new Error('Audio playback denied')
    const log = vi.spyOn(console, 'error').mockImplementation(() => undefined)
    TestAudioContext.resumeResult = async () => {
      throw error
    }
    stops.push(playPhoneEffect('button', 100, false))
    await vi.runAllTimersAsync()
    const context = TestAudioContext.instances[0]!
    expect(log).toHaveBeenCalledWith(
      '[Phone audio] Failed to start phone effect',
      error,
    )
    expect(context.close).toHaveBeenCalledOnce()
    expect(context.gains[0]!.disconnect).toHaveBeenCalledOnce()
    expect(context.oscillators).toHaveLength(0)
  })

  it('disposes partially scheduled audio if voice creation fails', async () => {
    const error = new Error('Voice creation failed')
    const log = vi.spyOn(console, 'error').mockImplementation(() => undefined)
    stops.push(playPhoneEffect('endcall', 100, false))
    const context = TestAudioContext.instances[0]!
    context.createOscillator
      .mockImplementationOnce(() => {
        const oscillator = new TestOscillator(context)
        context.oscillators.push(oscillator)
        return oscillator
      })
      .mockImplementationOnce(() => {
        throw error
      })
    await vi.runAllTimersAsync()
    expect(log).toHaveBeenCalledWith(
      '[Phone audio] Failed to synthesize phone effect',
      error,
    )
    expect(context.close).toHaveBeenCalledOnce()
    expect(context.oscillators[0]!.disconnect).toHaveBeenCalledOnce()
    expect(context.gains[0]!.disconnect).toHaveBeenCalledOnce()
    expect(context.gains[1]!.disconnect).toHaveBeenCalledOnce()
  })
})
