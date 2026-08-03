import { defineStore } from 'pinia'

export type PhonePhoto = {
  capturedAt: number
  gradient: string
  id: string
  titleKey: string
}

const samplePhotos: PhonePhoto[] = [
  {
    capturedAt: Date.now() - 86_400_000,
    gradient: 'linear-gradient(145deg, #ff9a62, #5f2c82 58%, #141e30)',
    id: 'sunset-drive',
    titleKey: 'Apps.photos.samples.sunset',
  },
  {
    capturedAt: Date.now() - 172_800_000,
    gradient: 'linear-gradient(160deg, #67d5b5, #26648e 55%, #0b132b)',
    id: 'ocean-air',
    titleKey: 'Apps.photos.samples.ocean',
  },
  {
    capturedAt: Date.now() - 259_200_000,
    gradient: 'linear-gradient(135deg, #fbc2eb, #a6c1ee 48%, #302b63)',
    id: 'city-lights',
    titleKey: 'Apps.photos.samples.city',
  },
  {
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
    capture(): void {
      const gradients = [
        'linear-gradient(145deg, #ff6b6b, #845ec2 52%, #0f2027)',
        'linear-gradient(150deg, #00c9a7, #4d8076 46%, #1f3a5f)',
        'linear-gradient(135deg, #ffc75f, #f96d80 48%, #4b4453)',
      ]
      const captureNumber = this.captures.length
      this.captures.unshift({
        capturedAt: Date.now(),
        gradient: gradients[captureNumber % gradients.length],
        id: `capture-${Date.now()}`,
        titleKey: 'Apps.photos.samples.capture',
      })
    },
    claimApp(id: string): void {
      if (!this.claimedApps.includes(id)) this.claimedApps.push(id)
    },
  },
})
