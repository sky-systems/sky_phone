import { registerPhoneMediaElement } from '@/utils/phoneAudio'
import type { AlarmSoundId } from '@/utils/alarms'
import type { NotificationSoundId } from '@/utils/preferences'

export type PhoneToneId = AlarmSoundId | NotificationSoundId
export type PhoneVibrationKind = 'call' | 'notification'

type ToneVoice = {
  detune?: number
  frequency: number
  gain?: number
  type?: OscillatorType
}

type ToneStep = {
  attackMs?: number
  durationMs: number
  offsetMs: number
  releaseMs?: number
  voices: ToneVoice[]
}

type TonePattern = {
  loopPauseMs: number
  steps: ToneStep[]
}

const TONE_PATTERNS: Record<PhoneToneId, TonePattern> = {
  apex: {
    loopPauseMs: 420,
    steps: [
      {
        offsetMs: 0,
        durationMs: 260,
        voices: [{ frequency: 523 }, { frequency: 1047, gain: 0.16 }],
      },
      {
        offsetMs: 190,
        durationMs: 280,
        voices: [{ frequency: 659 }, { frequency: 1319, gain: 0.14 }],
      },
      {
        offsetMs: 390,
        durationMs: 320,
        voices: [{ frequency: 784 }, { frequency: 1568, gain: 0.12 }],
      },
      {
        offsetMs: 620,
        durationMs: 520,
        releaseMs: 260,
        voices: [{ frequency: 1047 }, { frequency: 1568, gain: 0.18 }],
      },
    ],
  },
  aurora: {
    loopPauseMs: 500,
    steps: [
      {
        offsetMs: 0,
        durationMs: 560,
        attackMs: 80,
        releaseMs: 300,
        voices: [
          { frequency: 440, type: 'triangle' },
          { frequency: 659, gain: 0.32, type: 'sine' },
        ],
      },
      {
        offsetMs: 310,
        durationMs: 620,
        attackMs: 90,
        releaseMs: 340,
        voices: [
          { frequency: 554, type: 'triangle' },
          { frequency: 831, gain: 0.28 },
        ],
      },
      {
        offsetMs: 690,
        durationMs: 700,
        attackMs: 100,
        releaseMs: 400,
        voices: [
          { frequency: 659, type: 'triangle' },
          { frequency: 988, gain: 0.24 },
        ],
      },
    ],
  },
  beacon: {
    loopPauseMs: 460,
    steps: [
      {
        offsetMs: 0,
        durationMs: 240,
        voices: [
          { frequency: 660, type: 'triangle' },
          { frequency: 1320, gain: 0.12 },
        ],
      },
      {
        offsetMs: 250,
        durationMs: 260,
        voices: [
          { frequency: 880, type: 'triangle' },
          { frequency: 1760, gain: 0.1 },
        ],
      },
      {
        offsetMs: 540,
        durationMs: 240,
        voices: [
          { frequency: 660, type: 'triangle' },
          { frequency: 1320, gain: 0.12 },
        ],
      },
      {
        offsetMs: 790,
        durationMs: 340,
        releaseMs: 160,
        voices: [
          { frequency: 880, type: 'triangle' },
          { frequency: 1320, gain: 0.16 },
        ],
      },
    ],
  },
  chime: {
    loopPauseMs: 360,
    steps: [
      {
        offsetMs: 0,
        durationMs: 360,
        releaseMs: 220,
        voices: [{ frequency: 784 }, { frequency: 1568, gain: 0.16 }],
      },
      {
        offsetMs: 250,
        durationMs: 500,
        releaseMs: 320,
        voices: [{ frequency: 1047 }, { frequency: 2093, gain: 0.12 }],
      },
    ],
  },
  chimes: {
    loopPauseMs: 480,
    steps: [
      {
        offsetMs: 0,
        durationMs: 380,
        releaseMs: 240,
        voices: [{ frequency: 523 }, { frequency: 1047, gain: 0.15 }],
      },
      {
        offsetMs: 180,
        durationMs: 420,
        releaseMs: 260,
        voices: [{ frequency: 659 }, { frequency: 1319, gain: 0.14 }],
      },
      {
        offsetMs: 370,
        durationMs: 460,
        releaseMs: 280,
        voices: [{ frequency: 784 }, { frequency: 1568, gain: 0.13 }],
      },
      {
        offsetMs: 580,
        durationMs: 620,
        releaseMs: 380,
        voices: [{ frequency: 1047 }, { frequency: 1568, gain: 0.18 }],
      },
    ],
  },
  circuit: {
    loopPauseMs: 380,
    steps: [
      {
        offsetMs: 0,
        durationMs: 150,
        attackMs: 8,
        releaseMs: 70,
        voices: [
          { frequency: 740, type: 'square', gain: 0.55 },
          { frequency: 1480, type: 'sine', gain: 0.1 },
        ],
      },
      {
        offsetMs: 170,
        durationMs: 150,
        attackMs: 8,
        releaseMs: 70,
        voices: [{ frequency: 932, type: 'square', gain: 0.5 }],
      },
      {
        offsetMs: 350,
        durationMs: 150,
        attackMs: 8,
        releaseMs: 70,
        voices: [{ frequency: 1109, type: 'square', gain: 0.46 }],
      },
      {
        offsetMs: 540,
        durationMs: 300,
        attackMs: 10,
        releaseMs: 170,
        voices: [
          { frequency: 1480, type: 'triangle', gain: 0.58 },
          { frequency: 740, type: 'sine', gain: 0.2 },
        ],
      },
    ],
  },
  constellation: {
    loopPauseMs: 520,
    steps: [
      {
        offsetMs: 0,
        durationMs: 500,
        releaseMs: 340,
        voices: [{ frequency: 988 }, { frequency: 1976, detune: 7, gain: 0.1 }],
      },
      {
        offsetMs: 260,
        durationMs: 540,
        releaseMs: 360,
        voices: [
          { frequency: 784 },
          { frequency: 1568, detune: -6, gain: 0.13 },
        ],
      },
      {
        offsetMs: 540,
        durationMs: 580,
        releaseMs: 380,
        voices: [{ frequency: 1175 }, { frequency: 1760, gain: 0.14 }],
      },
      {
        offsetMs: 820,
        durationMs: 680,
        releaseMs: 440,
        voices: [{ frequency: 1047 }, { frequency: 1568, gain: 0.17 }],
      },
    ],
  },
  daybreak: {
    loopPauseMs: 500,
    steps: [
      {
        offsetMs: 0,
        durationMs: 360,
        voices: [
          { frequency: 392, type: 'triangle' },
          { frequency: 784, gain: 0.14 },
        ],
      },
      {
        offsetMs: 230,
        durationMs: 400,
        voices: [
          { frequency: 494, type: 'triangle' },
          { frequency: 988, gain: 0.13 },
        ],
      },
      {
        offsetMs: 480,
        durationMs: 440,
        voices: [
          { frequency: 587, type: 'triangle' },
          { frequency: 1175, gain: 0.12 },
        ],
      },
      {
        offsetMs: 750,
        durationMs: 600,
        releaseMs: 340,
        voices: [
          { frequency: 784, type: 'triangle' },
          { frequency: 1175, gain: 0.2 },
        ],
      },
    ],
  },
  radar: {
    loopPauseMs: 440,
    steps: [
      {
        offsetMs: 0,
        durationMs: 190,
        attackMs: 12,
        releaseMs: 100,
        voices: [
          { frequency: 880, type: 'triangle' },
          { frequency: 1760, gain: 0.12 },
        ],
      },
      {
        offsetMs: 360,
        durationMs: 190,
        attackMs: 12,
        releaseMs: 100,
        voices: [
          { frequency: 880, type: 'triangle' },
          { frequency: 1760, gain: 0.12 },
        ],
      },
      {
        offsetMs: 720,
        durationMs: 390,
        attackMs: 18,
        releaseMs: 220,
        voices: [
          { frequency: 1175, type: 'triangle' },
          { frequency: 1760, gain: 0.15 },
        ],
      },
    ],
  },
  signal: {
    loopPauseMs: 360,
    steps: [
      {
        offsetMs: 0,
        durationMs: 180,
        voices: [{ frequency: 740, type: 'triangle' }],
      },
      {
        offsetMs: 210,
        durationMs: 220,
        voices: [{ frequency: 988, type: 'triangle' }],
      },
      {
        offsetMs: 470,
        durationMs: 300,
        voices: [
          { frequency: 740, type: 'triangle' },
          { frequency: 1110, gain: 0.12 },
        ],
      },
    ],
  },
  soft: {
    loopPauseMs: 420,
    steps: [
      {
        offsetMs: 0,
        durationMs: 420,
        attackMs: 55,
        releaseMs: 260,
        voices: [
          { frequency: 523, gain: 0.72 },
          { frequency: 784, gain: 0.16 },
        ],
      },
      {
        offsetMs: 300,
        durationMs: 520,
        attackMs: 65,
        releaseMs: 320,
        voices: [
          { frequency: 659, gain: 0.7 },
          { frequency: 988, gain: 0.14 },
        ],
      },
    ],
  },
  uplift: {
    loopPauseMs: 440,
    steps: [
      {
        offsetMs: 0,
        durationMs: 260,
        voices: [
          { frequency: 440, type: 'triangle' },
          { frequency: 660, gain: 0.18 },
        ],
      },
      {
        offsetMs: 170,
        durationMs: 280,
        voices: [
          { frequency: 554, type: 'triangle' },
          { frequency: 831, gain: 0.17 },
        ],
      },
      {
        offsetMs: 350,
        durationMs: 300,
        voices: [
          { frequency: 659, type: 'triangle' },
          { frequency: 988, gain: 0.16 },
        ],
      },
      {
        offsetMs: 550,
        durationMs: 520,
        releaseMs: 300,
        voices: [
          { frequency: 880, type: 'triangle' },
          { frequency: 1320, gain: 0.2 },
        ],
      },
    ],
  },
}

const VIBRATION_SOUND_PATHS: Record<PhoneVibrationKind, string> = {
  call: 'sounds/vibration-call.mp3',
  notification: 'sounds/vibration-notification.mp3',
}

export function phoneToneDuration(tone: PhoneToneId): number {
  return Math.max(
    ...TONE_PATTERNS[tone].steps.map((step) => step.offsetMs + step.durationMs),
  )
}

export function playPhoneTone(
  tone: PhoneToneId,
  volumePercent: number,
  loop: boolean,
): () => void {
  const AudioContextConstructor =
    window.AudioContext ??
    (window as typeof window & { webkitAudioContext?: typeof AudioContext })
      .webkitAudioContext
  if (!AudioContextConstructor) {
    console.error('[Phone audio] Web Audio is unavailable')
    return () => undefined
  }

  const context = new AudioContextConstructor()
  const pattern = TONE_PATTERNS[tone]
  const patternDuration = phoneToneDuration(tone)
  const volume = Math.max(0, Math.min(1, volumePercent / 100)) * 0.16
  let stopped = false
  let nextPatternTimer: ReturnType<typeof setTimeout> | undefined
  let oscillators: OscillatorNode[] = []

  const schedulePattern = (): void => {
    if (stopped) return
    const startAt = context.currentTime + 0.02
    oscillators = pattern.steps.flatMap((step) =>
      step.voices.map((voice) => {
        const oscillator = context.createOscillator()
        const gain = context.createGain()
        const toneStart = startAt + step.offsetMs / 1000
        const toneEnd = toneStart + step.durationMs / 1000
        const attackEnd = toneStart + (step.attackMs ?? 25) / 1000
        const releaseStart = toneEnd - (step.releaseMs ?? 110) / 1000
        const peakVolume = Math.max(0.0001, volume * (voice.gain ?? 1))

        oscillator.type = voice.type ?? 'sine'
        oscillator.frequency.value = voice.frequency
        oscillator.detune.value = voice.detune ?? 0
        gain.gain.setValueAtTime(0.0001, toneStart)
        gain.gain.linearRampToValueAtTime(peakVolume, attackEnd)
        gain.gain.setValueAtTime(peakVolume, releaseStart)
        gain.gain.exponentialRampToValueAtTime(0.0001, toneEnd)
        oscillator.connect(gain).connect(context.destination)
        oscillator.start(toneStart)
        oscillator.stop(toneEnd + 0.01)
        return oscillator
      }),
    )

    if (loop) {
      nextPatternTimer = setTimeout(
        schedulePattern,
        patternDuration + pattern.loopPauseMs,
      )
    }
  }

  void context
    .resume()
    .then(schedulePattern)
    .catch((error: unknown) => {
      if (!stopped) console.error('[Phone audio] Failed to start tone', error)
    })

  return () => {
    stopped = true
    if (nextPatternTimer) clearTimeout(nextPatternTimer)
    for (const oscillator of oscillators) {
      try {
        oscillator.stop()
      } catch {
        // The oscillator already completed its scheduled note.
      }
    }
    void context.close()
  }
}

export function playPhoneVibration(
  kind: PhoneVibrationKind,
  loop: boolean,
): () => void {
  const player = registerPhoneMediaElement(
    new Audio(`${import.meta.env.BASE_URL}${VIBRATION_SOUND_PATHS[kind]}`),
  )
  let stopped = false
  player.loop = loop
  player.preload = 'auto'
  player.volume = 1
  void player.play().catch((error: unknown) => {
    if (!stopped) {
      console.error('[Phone audio] Failed to start vibration sound', error)
    }
  })

  return () => {
    stopped = true
    player.pause()
    player.currentTime = 0
  }
}
