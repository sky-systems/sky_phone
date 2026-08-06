export type NeonDropSound =
  | 'clear'
  | 'drop'
  | 'game-over'
  | 'lock'
  | 'move'
  | 'rotate'
  | 'start'

let context: AudioContext | undefined

function playSequence(sound: NeonDropSound): void {
  context ??= new AudioContext()
  const patterns: Record<
    NeonDropSound,
    Array<[number, number, number, OscillatorType]>
  > = {
    clear: [
      [520, 0, 0.08, 'sine'],
      [700, 0.07, 0.1, 'sine'],
      [930, 0.15, 0.16, 'triangle'],
    ],
    drop: [
      [180, 0, 0.07, 'square'],
      [95, 0.055, 0.11, 'triangle'],
    ],
    'game-over': [
      [260, 0, 0.16, 'sawtooth'],
      [190, 0.14, 0.18, 'sawtooth'],
      [110, 0.3, 0.28, 'triangle'],
    ],
    lock: [[145, 0, 0.07, 'triangle']],
    move: [[340, 0, 0.035, 'square']],
    rotate: [
      [410, 0, 0.045, 'triangle'],
      [530, 0.035, 0.055, 'triangle'],
    ],
    start: [
      [330, 0, 0.08, 'sine'],
      [500, 0.07, 0.1, 'triangle'],
      [760, 0.15, 0.13, 'sine'],
    ],
  }
  const start = context.currentTime
  for (const [frequency, delay, duration, type] of patterns[sound]) {
    const oscillator = context.createOscillator()
    const gain = context.createGain()
    oscillator.type = type
    oscillator.frequency.setValueAtTime(frequency, start + delay)
    gain.gain.setValueAtTime(0.0001, start + delay)
    gain.gain.exponentialRampToValueAtTime(0.12, start + delay + 0.008)
    gain.gain.exponentialRampToValueAtTime(0.0001, start + delay + duration)
    oscillator.connect(gain)
    gain.connect(context.destination)
    oscillator.start(start + delay)
    oscillator.stop(start + delay + duration + 0.02)
  }
}

export function playNeonDropSound(
  sound: NeonDropSound,
  enabled: boolean,
): void {
  if (!enabled) return
  context ??= new AudioContext()
  if (context.state === 'suspended') {
    void context
      .resume()
      .then(() => playSequence(sound))
      .catch((error: unknown) => {
        console.error(`[Neon Drop audio] Failed to resume for ${sound}`, error)
      })
    return
  }
  playSequence(sound)
}
