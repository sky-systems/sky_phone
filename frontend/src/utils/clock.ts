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
  const totalCentiseconds = Math.floor(milliseconds / 10)
  const minutes = Math.floor(totalCentiseconds / 6000)
  const seconds = Math.floor((totalCentiseconds % 6000) / 100)
  const centiseconds = totalCentiseconds % 100
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}.${String(centiseconds).padStart(2, '0')}`
}

export function formatTimer(milliseconds: number): string {
  const totalSeconds = Math.ceil(milliseconds / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
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
