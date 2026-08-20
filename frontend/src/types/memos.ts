export type MemoDto = {
  id: string
  title: string
  note: string
  url: string
  mimeType: string
  durationMs: number
  waveform: number[]
  pinned: boolean
  revision: number
  createdAt: number
  updatedAt: number
}

export type MemoUpdate = Pick<MemoDto, 'title' | 'note' | 'pinned' | 'revision'>

export type MemoRecorderStateName =
  | 'idle'
  | 'starting'
  | 'recording'
  | 'paused'
  | 'stopping'
  | 'uploading'
  | 'error'

export type MemoRecorderState = {
  state: MemoRecorderStateName
  elapsedMs: number
  levels: number[]
  error?: string
}

export type MemoRecordingMetadata = {
  title: string
  note: string
  pinned: boolean
}

export type MemoUploadReady = {
  requestId: string
  correlationId: string
  presignedUrl: string
  uploadTimeoutMs?: number
}

export type MemoUploadResult = {
  correlationId: string
  success: boolean
  error?: string
  memo?: MemoDto
}

export function isMemoDto(value: unknown): value is MemoDto {
  if (!value || typeof value !== 'object') return false
  const memo = value as Partial<MemoDto>
  return (
    typeof memo.id === 'string' &&
    typeof memo.title === 'string' &&
    typeof memo.note === 'string' &&
    typeof memo.url === 'string' &&
    typeof memo.mimeType === 'string' &&
    typeof memo.durationMs === 'number' &&
    Array.isArray(memo.waveform) &&
    memo.waveform.every((sample) => typeof sample === 'number') &&
    typeof memo.pinned === 'boolean' &&
    typeof memo.revision === 'number' &&
    typeof memo.createdAt === 'number' &&
    typeof memo.updatedAt === 'number'
  )
}
