export type NumberMergeSound = 'game-over' | 'merge' | 'move' | 'win'

type Tone = {
  duration: number
  frequency: number
  offset: number
  type: OscillatorType
  volume: number
}

const sounds: Record<NumberMergeSound, Tone[]> = {
  move: [{ duration: 0.05, frequency: 260, offset: 0, type: 'sine', volume: 0.045 }],
  merge: [
    { duration: 0.09, frequency: 390, offset: 0, type: 'sine', volume: 0.065 },
    { duration: 0.12, frequency: 520, offset: 0.055, type: 'sine', volume: 0.075 },
  ],
  win: [
    { duration: 0.16, frequency: 523.25, offset: 0, type: 'sine', volume: 0.08 },
    { duration: 0.16, frequency: 659.25, offset: 0.1, type: 'sine', volume: 0.085 },
    { duration: 0.16, frequency: 783.99, offset: 0.2, type: 'sine', volume: 0.09 },
    { duration: 0.3, frequency: 1046.5, offset: 0.3, type: 'sine', volume: 0.1 },
  ],
  'game-over': [
    { duration: 0.14, frequency: 260, offset: 0, type: 'triangle', volume: 0.065 },
    { duration: 0.18, frequency: 195, offset: 0.12, type: 'triangle', volume: 0.06 },
    { duration: 0.22, frequency: 146, offset: 0.26, type: 'triangle', volume: 0.055 },
  ],
}

let audioContext: AudioContext | undefined

export function playNumberMergeSound(
  sound: NumberMergeSound,
  enabled: boolean,
): void {
  if (!enabled) return

  audioContext ??= new AudioContext()
  if (audioContext.state === 'suspended') void audioContext.resume()

  const now = audioContext.currentTime
  for (const tone of sounds[sound]) {
    const oscillator = audioContext.createOscillator()
    const gain = audioContext.createGain()
    const start = now + tone.offset
    const end = start + tone.duration

    oscillator.type = tone.type
    oscillator.frequency.setValueAtTime(tone.frequency, start)
    gain.gain.setValueAtTime(0.0001, start)
    gain.gain.exponentialRampToValueAtTime(tone.volume, start + 0.012)
    gain.gain.exponentialRampToValueAtTime(0.0001, end)
    oscillator.connect(gain)
    gain.connect(audioContext.destination)
    oscillator.start(start)
    oscillator.stop(end)
  }
}
