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
  settings: { autoRejoin: false, notifications: false },
  volume: 50,
}

export const useRadioStore = defineStore('radio', () => {
  const data = reactive<RadioData>(structuredClone(defaults))
  const error = ref('')
  const isLoading = ref(false)

  function apply(next: Partial<RadioData>): void {
    Object.assign(data, next)
  }

  async function load(): Promise<void> {
    isLoading.value = true
    error.value = ''
    const response = await nuiCall<RadioData>('radio:get')
    if (response.success && response.data) apply(response.data)
    else error.value = response.error ?? 'request_failed'
    isLoading.value = false
  }

  async function connect(
    frequency: number,
    secondaryFrequency: number,
  ): Promise<boolean> {
    isLoading.value = true
    error.value = ''
    const response = await nuiCall<Partial<RadioData>>('radio:connect', {
      frequency,
      secondaryFrequency,
    })
    if (response.success && response.data) apply(response.data)
    else error.value = response.error ?? 'request_failed'
    isLoading.value = false
    return response.success
  }

  async function disconnect(): Promise<void> {
    error.value = ''
    const response = await nuiCall('radio:disconnect')
    if (!response.success) {
      error.value = response.error ?? 'request_failed'
      return
    }
    apply({
      connected: false,
      frequency: 0,
      members: [],
      secondaryFrequency: 0,
    })
  }

  async function setVolume(volume: number): Promise<void> {
    data.volume = volume
    const response = await nuiCall<{ volume: number }>('radio:set-volume', {
      volume,
    })
    if (response.success && response.data) data.volume = response.data.volume
  }

  async function saveSetting(
    key: keyof RadioSettings,
    value: boolean,
  ): Promise<void> {
    const previous = data.settings[key]
    data.settings[key] = value
    const response = await nuiCall<RadioSettings>('radio:save-settings', {
      key,
      value,
    })
    if (response.success && response.data) data.settings = response.data
    else {
      data.settings[key] = previous
      error.value = response.error ?? 'request_failed'
    }
  }

  async function saveBadge(badge: string): Promise<boolean> {
    error.value = ''
    const response = await nuiCall<{ badge: string }>('radio:save-badge', {
      badge,
    })
    if (response.success && response.data) data.badge = response.data.badge
    else error.value = response.error ?? 'request_failed'
    return response.success
  }

  async function saveDisplayName(displayName: string): Promise<boolean> {
    error.value = ''
    const response = await nuiCall<{ displayName: string }>(
      'radio:save-display-name',
      { displayName },
    )
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
    error,
    isLoading,
    load,
    saveBadge,
    saveDisplayName,
    saveSetting,
    setVolume,
    updateMembers,
  }
})
