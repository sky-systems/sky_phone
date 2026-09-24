import { reactive, ref } from 'vue'
import { defineStore } from 'pinia'

import type { RadioData, RadioMember, RadioSettings } from '@/types/radio'
import { nuiCall } from '@/utils/nui'

const defaults: RadioData = {
  badge: '',
  badgeEnabled: true,
  badgeMaxLength: 8,
  connected: false,
  displayName: '',
  displayNameAllowed: false,
  displayNameEnabled: true,
  displayNameMaxLength: 32,
  frequency: 0,
  frequencyMax: 999.9,
  frequencyMin: 0.1,
  frequencyStep: 0.1,
  history: [],
  members: [],
  provider: null,
  secondaryFrequency: 0,
  secondarySupported: true,
  speakerEnabled: false,
  speakerSupported: false,
  settings: { autoRejoin: false, notifications: false },
  volume: 50,
}

export const useRadioStore = defineStore('radio', () => {
  const data = reactive<RadioData>(structuredClone(defaults))
  const error = ref('')
  const isLoading = ref(false)
  const speakerPending = ref(false)
  const settingRequestIds: Record<keyof RadioSettings, number> = {
    autoRejoin: 0,
    notifications: 0,
  }
  let badgeRequestId = 0
  let displayNameRequestId = 0
  let speakerRequestId = 0
  let volumeRequestId = 0
  let connectionVersion = 0

  function apply(next: Partial<RadioData>): void {
    Object.assign(data, next)
  }

  function forceDisconnect(reason?: string): void {
    connectionVersion += 1
    speakerRequestId += 1
    speakerPending.value = false
    isLoading.value = false
    error.value = reason ?? ''
    apply({
      connected: false,
      frequency: 0,
      secondaryFrequency: 0,
      members: [],
      speakerEnabled: false,
    })
  }

  async function load(): Promise<void> {
    const version = connectionVersion
    isLoading.value = true
    error.value = ''
    const response = await nuiCall<RadioData>('radio:get')
    if (version !== connectionVersion) return
    if (response.success && response.data) apply(response.data)
    else error.value = response.error ?? 'request_failed'
    isLoading.value = false
  }

  async function connect(
    frequency: number,
    secondaryFrequency: number,
  ): Promise<boolean> {
    const version = ++connectionVersion
    isLoading.value = true
    error.value = ''
    const response = await nuiCall<Partial<RadioData>>('radio:connect', {
      frequency,
      secondaryFrequency,
    })
    if (version !== connectionVersion) return false
    if (response.success && response.data) apply(response.data)
    else error.value = response.error ?? 'request_failed'
    isLoading.value = false
    return response.success
  }

  async function disconnect(): Promise<void> {
    const version = ++connectionVersion
    isLoading.value = true
    error.value = ''
    const response = await nuiCall('radio:disconnect')
    if (version !== connectionVersion) return
    if (!response.success) {
      error.value = response.error ?? 'request_failed'
      isLoading.value = false
      return
    }
    apply({
      connected: false,
      frequency: 0,
      members: [],
      secondaryFrequency: 0,
      speakerEnabled: false,
    })
    speakerRequestId += 1
    speakerPending.value = false
    isLoading.value = false
  }

  async function setSpeaker(enabled: boolean): Promise<boolean> {
    if (!data.connected || !data.speakerSupported) {
      error.value = 'speaker_unavailable'
      return false
    }

    const requestId = ++speakerRequestId
    const previous = data.speakerEnabled === true
    data.speakerEnabled = enabled
    error.value = ''
    speakerPending.value = true
    const response = await nuiCall<{ speakerEnabled: boolean }>(
      'radio:set-speaker',
      { enabled },
    )
    if (requestId !== speakerRequestId) return response.success
    speakerPending.value = false
    if (response.success && response.data) {
      data.speakerEnabled = response.data.speakerEnabled === true
    } else {
      data.speakerEnabled = previous
      error.value = response.error ?? 'request_failed'
    }
    return response.success
  }

  async function setVolume(volume: number): Promise<void> {
    const requestId = ++volumeRequestId
    data.volume = volume
    const response = await nuiCall<{ volume: number }>('radio:set-volume', {
      volume,
    })
    if (requestId !== volumeRequestId) return
    if (response.success && response.data) data.volume = response.data.volume
  }

  async function saveSetting(
    key: keyof RadioSettings,
    value: boolean,
  ): Promise<void> {
    const requestId = ++settingRequestIds[key]
    const previous = data.settings[key]
    data.settings[key] = value
    const response = await nuiCall<RadioSettings>('radio:save-settings', {
      key,
      value,
    })
    if (requestId !== settingRequestIds[key]) return
    if (response.success && response.data) {
      data.settings[key] = response.data[key]
    } else {
      data.settings[key] = previous
      error.value = response.error ?? 'request_failed'
    }
  }

  async function saveBadge(badge: string): Promise<boolean> {
    const requestId = ++badgeRequestId
    error.value = ''
    const response = await nuiCall<{ badge: string }>('radio:save-badge', {
      badge,
    })
    if (requestId !== badgeRequestId) return true
    if (response.success && response.data) data.badge = response.data.badge
    else error.value = response.error ?? 'request_failed'
    return response.success
  }

  async function saveDisplayName(displayName: string): Promise<boolean> {
    const requestId = ++displayNameRequestId
    error.value = ''
    const response = await nuiCall<{ displayName: string }>(
      'radio:save-display-name',
      { displayName },
    )
    if (requestId !== displayNameRequestId) return true
    if (response.success && response.data)
      data.displayName = response.data.displayName
    else error.value = response.error ?? 'request_failed'
    return response.success
  }

  function updateMembers(members: RadioMember[]): void {
    data.members = members
  }

  return {
    connect,
    data,
    disconnect,
    forceDisconnect,
    error,
    isLoading,
    load,
    saveBadge,
    saveDisplayName,
    saveSetting,
    setSpeaker,
    setVolume,
    speakerPending,
    updateMembers,
  }
})
