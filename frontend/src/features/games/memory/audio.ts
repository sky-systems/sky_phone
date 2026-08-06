export type MemorySound = 'flip' | 'match' | 'mismatch' | 'win'

type Tone = {
  duration: number
  frequency: number
  offset: number
  type: OscillatorType
  volume: number
}

const sounds: Record<MemorySound, Tone[]> = {
  flip: [
    { duration: 0.055, frequency: 520, offset: 0, type: 'sine', volume: 0.07 },
  ],
  match: [
    { duration: 0.11, frequency: 660, offset: 0, type: 'sine', volume: 0.09 },
    { duration: 0.16, frequency: 880, offset: 0.09, type: 'sine', volume: 0.1 },
  ],
  mismatch: [
    { duration: 0.1, frequency: 210, offset: 0, type: 'triangle', volume: 0.07 },
    { duration: 0.14, frequency: 150, offset: 0.08, type: 'triangle', volume: 0.065 },
  ],
  win: [
    { duration: 0.16, frequency: 523.25, offset: 0, type: 'sine', volume: 0.085 },
    { duration: 0.16, frequency: 659.25, offset: 0.1, type: 'sine', volume: 0.09 },
    { duration: 0.16, frequency: 783.99, offset: 0.2, type: 'sine', volume: 0.095 },
    { duration: 0.28, frequency: 1046.5, offset: 0.3, type: 'sine', volume: 0.1 },
  ],
}

let audioContext: AudioContext | undefined

export function playMemorySound(sound: MemorySound, enabled: boolean): void {
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
