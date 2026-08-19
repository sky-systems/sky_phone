import { defineStore } from 'pinia'
import { ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import type { PhoneCall, PhoneContact, RecentCall } from '@/types/phone'
import { nuiCall, type NuiResponse } from '@/utils/nui'
import type { RingtoneId } from '@/utils/preferences'
import {
  playPhoneTone,
  playPhoneVibration,
  type PhoneToneId,
} from '@/utils/tones'

const RINGTONE_TONES: Record<RingtoneId, PhoneToneId> = {
  horizon: 'aurora',
  pulse: 'signal',
  skyline: 'apex',
}

export const useCallsStore = defineStore('calls', () => {
  const phone = usePhoneStore()
  const activeCall = ref<PhoneCall | null>(null)
  const contacts = ref<PhoneContact[]>([])
  const recents = ref<RecentCall[]>([])
  let stopRingtone: (() => void) | null = null

  async function bootstrap(): Promise<void> {
    await Promise.all([loadContacts(), loadRecents()])
  }

  async function loadContacts(): Promise<void> {
    const response = await nuiCall<PhoneContact[]>('contacts:list')
    if (response.success && response.data) contacts.value = response.data
  }

  async function loadRecents(): Promise<void> {
    const response = await nuiCall<RecentCall[]>('calls:recents')
    if (response.success && response.data) recents.value = response.data
  }

  async function saveContact(contact: {
    avatarMediaId?: number | null
    email?: string
    id?: string
    name: string
    notes?: string
    organization?: string
    phoneNumber: string
  }): Promise<NuiResponse<PhoneContact>> {
    const response = await nuiCall<PhoneContact>('contacts:save', contact)
    if (response.success) await loadContacts()
    return response
  }

  async function deleteContact(id: string): Promise<boolean> {
    const response = await nuiCall('contacts:delete', { id })
    if (response.success) await loadContacts()
    return response.success
  }

  async function dial(phoneNumber: string): Promise<NuiResponse<PhoneCall>> {
    const response = await nuiCall<PhoneCall>('calls:dial', { phoneNumber })
    if (response.success && response.data) applyCallState(response.data)
    return response
  }

  async function answer(): Promise<NuiResponse> {
    if (!activeCall.value) return { success: false, error: 'call_not_found' }
    const response = await nuiCall('calls:answer', { id: activeCall.value.id })
    if (response.success && activeCall.value) {
      activeCall.value = {
        ...activeCall.value,
        answeredAt: activeCall.value.answeredAt ?? Date.now(),
        state: 'connected',
      }
    }
    return response
  }

  async function decline(): Promise<boolean> {
    if (!activeCall.value) return false
    const response = await nuiCall('calls:decline', { id: activeCall.value.id })
    if (response.success) activeCall.value = null
    return response.success
  }

  async function setContactFavorite(
    id: string,
    favorite: boolean,
  ): Promise<NuiResponse<{ favorite: boolean; id: string }>> {
    const response = await nuiCall<{ favorite: boolean; id: string }>(
      'contacts:favorite',
      { favorite, id },
    )
    if (response.success) await loadContacts()
    return response
  }

  async function hangup(): Promise<boolean> {
    if (!activeCall.value) return false
    const response = await nuiCall('calls:hangup', { id: activeCall.value.id })
    if (response.success) {
      activeCall.value = null
      await loadRecents()
    }
    return response.success
  }

  async function setSpeaker(
    enabled: boolean,
  ): Promise<NuiResponse<{ speakerEnabled: boolean }>> {
    const call = activeCall.value
    if (!call || call.state !== 'connected') {
      return { success: false, error: 'call_not_connected' }
    }
    if (!call.speakerSupported) {
      return { success: false, error: 'speaker_unavailable' }
    }

    const response = await nuiCall<{ speakerEnabled: boolean }>(
      'calls:set-speaker',
      { enabled, id: call.id },
    )
    if (response.success && response.data && activeCall.value?.id === call.id) {
      activeCall.value = {
        ...activeCall.value,
        speakerEnabled: response.data.speakerEnabled === true,
      }
    }
    return response
  }

  async function setMuted(
    enabled: boolean,
  ): Promise<NuiResponse<{ muted: boolean }>> {
    const call = activeCall.value
    if (!call || call.state !== 'connected') {
      return { success: false, error: 'call_not_connected' }
    }
    if (!call.muteSupported) {
      return { success: false, error: 'mute_unavailable' }
    }

    const response = await nuiCall<{ muted: boolean }>('calls:set-muted', {
      enabled,
      id: call.id,
    })
    if (response.success && response.data && activeCall.value?.id === call.id) {
      activeCall.value = {
        ...activeCall.value,
        muted: response.data.muted === true,
      }
    }
    return response
  }

  async function blockNumber(phoneNumber: string): Promise<NuiResponse> {
    const response = await nuiCall('calls:block', { phoneNumber })
    if (response.success && activeCall.value?.otherNumber === phoneNumber) {
      activeCall.value = null
      await loadRecents()
    }
    return response
  }

  function applyCallState(call: PhoneCall): void {
    stopRingtone?.()
    stopRingtone = null
    activeCall.value = call
    if (call.direction === 'incoming' && call.state === 'ringing') {
      const alertsMuted =
        phone.preferences.settings.notificationVolume === 0 &&
        phone.preferences.settings.ringtoneVolume === 0
      stopRingtone = alertsMuted
        ? playPhoneVibration('call', true)
        : playPhoneTone(
            RINGTONE_TONES[phone.preferences.settings.ringtone],
            phone.preferences.settings.ringtoneVolume,
            true,
          )
    }
    if (!['ringing', 'connected'].includes(call.state)) {
      window.setTimeout(() => {
        if (activeCall.value?.id === call.id) activeCall.value = null
        void loadRecents()
      }, 1600)
    }
  }

  return {
    activeCall,
    answer,
    applyCallState,
    bootstrap,
    blockNumber,
    contacts,
    decline,
    deleteContact,
    dial,
    hangup,
    loadContacts,
    loadRecents,
    recents,
    saveContact,
    setContactFavorite,
    setMuted,
    setSpeaker,
  }
})
