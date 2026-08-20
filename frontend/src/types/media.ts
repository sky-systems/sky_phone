export type MediaType = 'photo' | 'video'
export type GalleryFilter = 'all' | MediaType

export type MediaConfig = {
  customWallpaperUploadEnabled: boolean
  videoBitrateKbps: number
}

export type PhoneMedia = {
  createdAt: number
  favorite: boolean
  id: number
  mediaType: MediaType
  thumbnailUrl?: string
  url: string
}

export type FavoriteResult = {
  favorite: boolean
  id: number
}

export type GalleryCounts = {
  all: number
  favoritePhotos: number
  favorites: number
  favoriteVideos: number
  photos: number
  videos: number
}

export type GallerySortOrder = 'newest' | 'oldest'

export type MediaImportSource = {
  id: string
  label: string
  mediaTypes: MediaType[]
}

export type MediaImportSources = {
  maxSelection: number
  sources: MediaImportSource[]
}

export type ExternalMedia = {
  externalId: string
  filename: string
  imported: boolean
  mediaType: MediaType
  size: number
  sourceId: string
  url: string
}

export type MediaImportPage = {
  hasMore: boolean
  items: ExternalMedia[]
  page: number
  total: number
}

export type MediaImportFailure = {
  error: string
  externalId: string
}

export type MediaImportResult = {
  failed: MediaImportFailure[]
  imported: PhoneMedia[]
}

export type UploadReady = {
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

export type DeleteManyResult = {
  correlationId: string
  deletedIds?: number[]
  error?: string
  success: boolean
}
