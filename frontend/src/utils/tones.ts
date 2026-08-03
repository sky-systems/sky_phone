import type { AlarmSoundId } from '@/utils/alarms'
import type { NotificationSoundId } from '@/utils/preferences'

export type PhoneToneId = AlarmSoundId | NotificationSoundId

const TONE_PATTERNS: Record<PhoneToneId, number[]> = {
  beacon: [660, 880, 660, 880],
  chime: [784, 1047],
  chimes: [523, 659, 784, 1047],
  radar: [880, 0, 880, 0, 1175],
  signal: [740, 988, 740],
  soft: [523, 659],
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
  const frequencies = TONE_PATTERNS[tone]
  const volume = Math.max(0, Math.min(1, volumePercent / 100)) * 0.16
  let stopped = false
  let nextPatternTimer: ReturnType<typeof setTimeout> | undefined
  let oscillators: OscillatorNode[] = []

  const schedulePattern = (): void => {
    if (stopped) return
    const startAt = context.currentTime + 0.02
    oscillators = frequencies.flatMap((frequency, index) => {
      if (!frequency) return []
      const oscillator = context.createOscillator()
      const gain = context.createGain()
      const toneStart = startAt + index * 0.24
      oscillator.type = 'sine'
      oscillator.frequency.value = frequency
      gain.gain.setValueAtTime(0, toneStart)
      gain.gain.linearRampToValueAtTime(volume, toneStart + 0.025)
      gain.gain.exponentialRampToValueAtTime(0.001, toneStart + 0.19)
      oscillator.connect(gain).connect(context.destination)
      oscillator.start(toneStart)
      oscillator.stop(toneStart + 0.2)
      return [oscillator]
    })

    if (loop) {
      nextPatternTimer = setTimeout(
        schedulePattern,
        frequencies.length * 240 + 520,
      )
    }
  }

  void context.resume().then(schedulePattern).catch((error: unknown) => {
    console.error('[Phone audio] Failed to start tone', error)
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
