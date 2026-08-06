export type MailSwipeAction = 'delete' | 'read'
export type MailSwipeAxis = 'horizontal' | 'vertical'

export const MAIL_SWIPE_ACTION_WIDTH = 84
export const MAIL_SWIPE_AXIS_LOCK = 8
export const MAIL_SWIPE_TRIGGER = 64

export function resolveMailSwipeAxis(
  deltaX: number,
  deltaY: number,
): MailSwipeAxis | null {
  const horizontalDistance = Math.abs(deltaX)
  const verticalDistance = Math.abs(deltaY)
  if (Math.max(horizontalDistance, verticalDistance) < MAIL_SWIPE_AXIS_LOCK) {
    return null
  }

  return horizontalDistance > verticalDistance * 1.15
    ? 'horizontal'
    : 'vertical'
}

export function clampMailSwipeOffset(
  deltaX: number,
  canRead: boolean,
  canDelete: boolean,
): number {
  if ((deltaX > 0 && !canRead) || (deltaX < 0 && !canDelete)) return 0

  const direction = Math.sign(deltaX)
  const distance = Math.abs(deltaX)
  const resistedDistance =
    distance <= MAIL_SWIPE_ACTION_WIDTH
      ? distance
      : MAIL_SWIPE_ACTION_WIDTH + (distance - MAIL_SWIPE_ACTION_WIDTH) * 0.18

  return direction * Math.min(resistedDistance, MAIL_SWIPE_ACTION_WIDTH + 18)
}

export function resolveMailSwipeAction(
  offset: number,
  canRead: boolean,
  canDelete: boolean,
): MailSwipeAction | null {
  if (canRead && offset >= MAIL_SWIPE_TRIGGER) return 'read'
  if (canDelete && offset <= -MAIL_SWIPE_TRIGGER) return 'delete'
  return null
}
