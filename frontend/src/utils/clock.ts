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
  const minutes = Math.floor(totalSeconds / 60)
  const seconds = totalSeconds % 60
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
}
