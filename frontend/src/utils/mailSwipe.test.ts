import { describe, expect, it } from 'vitest'

import {
  clampMailSwipeOffset,
  MAIL_SWIPE_ACTION_WIDTH,
  resolveMailSwipeAction,
  resolveMailSwipeAxis,
} from '@/utils/mailSwipe'

describe('mail swipe gestures', () => {
  it('waits for a clear horizontal or vertical direction', () => {
    expect(resolveMailSwipeAxis(5, 2)).toBeNull()
    expect(resolveMailSwipeAxis(24, 5)).toBe('horizontal')
    expect(resolveMailSwipeAxis(10, 18)).toBe('vertical')
  })

  it('limits horizontal movement and blocks unavailable directions', () => {
    expect(clampMailSwipeOffset(70, true, true)).toBe(70)
    expect(clampMailSwipeOffset(70, false, true)).toBe(0)
    expect(clampMailSwipeOffset(-70, true, false)).toBe(0)
    expect(clampMailSwipeOffset(-240, true, true)).toBeGreaterThan(
      -MAIL_SWIPE_ACTION_WIDTH - 19,
    )
  })

  it('only commits an action after crossing its threshold', () => {
    expect(resolveMailSwipeAction(63, true, true)).toBeNull()
    expect(resolveMailSwipeAction(64, true, true)).toBe('read')
    expect(resolveMailSwipeAction(-64, true, true)).toBe('delete')
    expect(resolveMailSwipeAction(80, false, true)).toBeNull()
  })
})
