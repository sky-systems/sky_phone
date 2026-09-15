import { createGameView, type GameView } from '@/utils/gameView'
import { nuiCall } from '@/utils/nui'
import type { RealtimeConfig, Role } from './types'

let microphone: MediaStream | undefined
let microphoneRequest: Promise<MediaStream> | undefined
let microphoneUsers = 0
export function setVoiceTalking(value: boolean): void {
  microphone?.getAudioTracks().forEach((track) => {
    track.enabled = value
  })
}
async function acquireMicrophone(): Promise<MediaStream> {
  if (!microphoneRequest) {
    microphoneRequest = navigator.mediaDevices
      .getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: false,
        },
      })
      .then(async (stream) => {
        microphone = stream
        setVoiceTalking(false)
        const state = await nuiCall<{ talking: boolean }>(
          'realtime:microphone',
          { active: true },
        )
        setVoiceTalking(state.data?.talking === true)
        return stream
      })
      .catch((error) => {
        microphoneRequest = undefined
        throw error
      })
  }
  const stream = await microphoneRequest
  microphoneUsers += 1
  return stream
}
function releaseMicrophone(): void {
  microphoneUsers = Math.max(0, microphoneUsers - 1)
  if (microphoneUsers) return
  microphone?.getTracks().forEach((track) => track.stop())
  microphone = undefined
  microphoneRequest = undefined
  void nuiCall('realtime:microphone', { active: false })
}

export class LiveMedia {
  stream = new MediaStream()
  canvas = document.createElement('canvas')
  private view?: GameView
  private animation = 0
  private audio?: AudioContext
  private mixer?: MediaStreamAudioDestinationNode
  private ownGain?: GainNode
  private micAcquired = false
  private disposed = false
  private video = false
  private remote = new Map<
    number,
    {
      source: MediaStreamAudioSourceNode
      gain: GainNode
      audio: HTMLAudioElement
    }
  >()

  async start(role: Role, config: RealtimeConfig): Promise<void> {
    if (role === 'viewer') return
    if (role === 'host' || role === 'nearby') {
      const mic = await acquireMicrophone()
      this.micAcquired = true
      if (this.disposed) {
        releaseMicrophone()
        this.micAcquired = false
        return
      }
      this.audio = new AudioContext()
      await this.audio.resume()
      if (this.disposed) return
      this.mixer = this.audio.createMediaStreamDestination()
      this.ownGain = this.audio.createGain()
      this.audio
        .createMediaStreamSource(mic)
        .connect(this.ownGain)
        .connect(this.mixer)
      this.stream.addTrack(this.mixer.stream.getAudioTracks()[0])
    }
    if (this.disposed || role === 'nearby') return
    this.video = true
    const active = await nuiCall('camera:setActive', {
      active: true,
      front: true,
    })
    if (!active.success) throw new Error(active.error || 'camera_unavailable')
    if (this.disposed) {
      await nuiCall('camera:setActive', { active: false })
      return
    }
    this.view = createGameView(this.canvas, { preserveDrawingBuffer: true })
    this.view.resize(
      Math.round((config.edge * 3) / 4),
      config.edge,
      window.innerWidth,
      window.innerHeight,
    )
    this.view.render()
    let previous = 0
    const render = (now: number) => {
      if (this.disposed) return
      this.animation = requestAnimationFrame(render)
      if (now - previous < 1000 / config.fps) return
      previous = now
      this.view?.render()
    }
    this.animation = requestAnimationFrame(render)
    this.stream.addTrack(
      this.canvas.captureStream(config.fps).getVideoTracks()[0],
    )
  }
  setMuted(muted: boolean): void {
    if (this.ownGain) this.ownGain.gain.value = muted ? 0 : 1
  }
  async flip(front: boolean): Promise<void> {
    const response = await nuiCall('camera:setFacing', { front })
    if (!response.success)
      throw new Error(response.error || 'camera_unavailable')
  }
  mix(id: number, stream: MediaStream, volume: number): void {
    if (!this.audio || !this.mixer || !stream.getAudioTracks().length) return
    this.unmix(id)
    const source = this.audio.createMediaStreamSource(stream)
    const gain = this.audio.createGain()
    gain.gain.value = volume
    source.connect(gain).connect(this.mixer)
    const audio = new Audio()
    audio.srcObject = stream
    audio.volume = 0
    void audio
      .play()
      .catch(() =>
        console.warn('[sky_phone] Nearby stream playback could not start.'),
      )
    this.remote.set(id, { source, gain, audio })
  }
  volume(id: number, value: number): void {
    const remote = this.remote.get(id)
    if (remote) remote.gain.gain.value = value
  }
  unmix(id: number): void {
    const remote = this.remote.get(id)
    if (!remote) return
    remote.source.disconnect()
    remote.gain.disconnect()
    remote.audio.pause()
    remote.audio.srcObject = null
    this.remote.delete(id)
  }
  dispose(): void {
    if (this.disposed) return
    this.disposed = true
    cancelAnimationFrame(this.animation)
    this.stream.getTracks().forEach((track) => track.stop())
    this.remote.forEach((_, id) => this.unmix(id))
    void this.audio?.close()
    this.view?.dispose()
    if (this.micAcquired) releaseMicrophone()
    this.micAcquired = false
    if (this.video) void nuiCall('camera:setActive', { active: false })
  }
}
