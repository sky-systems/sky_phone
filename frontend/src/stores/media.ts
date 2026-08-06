import { defineStore } from 'pinia'

import { usePhoneStore } from '@/stores/phone'

export type PhonePhoto = {
  attachmentId: string
  capturedAt: number
  gradient: string
  id: string
  titleKey: string
  url?: string
}

const samplePhotos: PhonePhoto[] = [
  {
    attachmentId: 'sunset-drive',
    capturedAt: Date.now() - 86_400_000,
    gradient: 'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)',
    id: 'sunset-drive',
    titleKey: 'Apps.photos.samples.sunset',
  },
  {
    attachmentId: 'ocean-air',
    capturedAt: Date.now() - 172_800_000,
    gradient: 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
    id: 'ocean-air',
    titleKey: 'Apps.photos.samples.ocean',
  },
  {
    attachmentId: 'city-lights',
    capturedAt: Date.now() - 259_200_000,
    gradient: 'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)',
    id: 'city-lights',
    titleKey: 'Apps.photos.samples.city',
  },
  {
    attachmentId: 'desert-road',
    capturedAt: Date.now() - 345_600_000,
    gradient: 'linear-gradient(150deg, #f6d365, #fda085 45%, #512b58)',
    id: 'desert-road',
    titleKey: 'Apps.photos.samples.desert',
  },
]

export const useMediaStore = defineStore('media', {
  state: () => ({
    cameraFacing: 'rear' as 'front' | 'rear',
    cameraMode: 'photo' as 'photo' | 'portrait' | 'video',
    cameraZoom: 1,
    captures: [] as PhonePhoto[],
    claimedApps: [] as string[],
  }),
  getters: {
    photos: (state): PhonePhoto[] => [...state.captures, ...samplePhotos],
  },
  actions: {
    claimApp(id: string): void {
      if (!this.claimedApps.includes(id)) {
        this.claimedApps.push(id)
        this.persist()
      }
    },
    hydrate(payload: unknown): void {
      const data = payload as Partial<{
        captures: PhonePhoto[]
        claimedApps: string[]
      }> | null
      this.captures = Array.isArray(data?.captures)
        ? data.captures.filter(
            (photo) =>
              typeof photo.id === 'string' &&
              typeof photo.url === 'string' &&
              photo.url.startsWith('https://'),
          )
        : []
      this.claimedApps = Array.isArray(data?.claimedApps)
        ? data.claimedApps.filter((id): id is string => typeof id === 'string')
        : []
    },
    persist(): void {
      usePhoneStore().saveDeviceNamespace('media', {
        captures: this.captures,
        claimedApps: this.claimedApps,
      })
    },
  },
})
