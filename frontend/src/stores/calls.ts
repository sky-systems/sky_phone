import { defineStore } from 'pinia'
import { ref } from 'vue'

import { usePhoneStore } from '@/stores/phone'
import type { PhoneCall, PhoneContact, RecentCall } from '@/types/phone'
import { nuiCall, type NuiResponse } from '@/utils/nui'
import type { RingtoneId } from '@/utils/preferences'
import { playPhoneTone, type PhoneToneId } from '@/utils/tones'

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
    id?: string
    name: string
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
    return nuiCall('calls:answer', { id: activeCall.value.id })
  }

  async function decline(): Promise<boolean> {
    if (!activeCall.value) return false
    return (await nuiCall('calls:decline', { id: activeCall.value.id })).success
  }

  async function hangup(): Promise<boolean> {
    if (!activeCall.value) return false
    return (await nuiCall('calls:hangup', { id: activeCall.value.id })).success
  }

  function applyCallState(call: PhoneCall): void {
    stopRingtone?.()
    stopRingtone = null
    activeCall.value = call
    if (call.direction === 'incoming' && call.state === 'ringing') {
      stopRingtone = playPhoneTone(
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
    contacts,
    decline,
    deleteContact,
    dial,
    hangup,
    loadContacts,
    loadRecents,
    recents,
    saveContact,
  }
})
