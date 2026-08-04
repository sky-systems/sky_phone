export function elapsedMilliseconds(
  accumulated: number,
  startedAt: number | null,
  now: number,
): number {
  return Math.max(0, accumulated + (startedAt === null ? 0 : now - startedAt))
}

export function remainingMilliseconds(
  remainingAtStart: number,
  startedAt: number | null,
  now: number,
): number {
  return Math.max(
    0,
    remainingAtStart - (startedAt === null ? 0 : now - startedAt),
  )
}

export function formatStopwatch(milliseconds: number): string {
  const totalMilliseconds = Math.floor(milliseconds)
  const minutes = Math.floor(totalMilliseconds / 60_000)
  const seconds = Math.floor((totalMilliseconds % 60_000) / 1000)
  const millisecondsPart = totalMilliseconds % 1000
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}.${String(millisecondsPart).padStart(3, '0')}`
}

export function formatTimer(milliseconds: number): string {
  const totalSeconds = Math.ceil(milliseconds / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}

export function timerProgressRatio(
  remainingMilliseconds: number,
  durationMilliseconds: number,
): number {
  if (durationMilliseconds <= 0) return 0
  return Math.max(0, Math.min(1, remainingMilliseconds / durationMilliseconds))
}

export function timerPickerValue(milliseconds: number): string {
  const totalSeconds = Math.floor(milliseconds / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  return [hours, minutes, seconds]
    .map((value) => String(value).padStart(2, '0'))
    .join(':')
}

export function timerPickerMilliseconds(value: string): number {
  const [hours = 0, minutes = 0, seconds = 0] = value.split(':').map(Number)
  return (hours * 3600 + minutes * 60 + seconds) * 1000
}
