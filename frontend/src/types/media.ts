export type MediaType = 'photo' | 'video'
export type GalleryFilter = 'all' | MediaType

export type PhoneMedia = {
  createdAt: number
  id: number
  mediaType: MediaType
  url: string
}

export type UploadReady = {
  captureToken: string
  correlationId: string
  mediaType: MediaType
  photo?: {
    Encoding?: 'jpg' | 'png' | 'webp'
    Quality?: number
  }
  presignedUrl: string
  requestId: string
  uploadTimeoutMs?: number
  video?: {
    BitrateKbps?: number
  }
}

export type UploadResult = {
  correlationId: string
  error?: string
  media?: PhoneMedia
  success: boolean
}

export type DeleteResult = {
  correlationId: string
  error?: string
  id?: number
  success: boolean
}
