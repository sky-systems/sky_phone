import blackFrame from '@/assets/img/frames/black.webp'
import blueFrame from '@/assets/img/frames/blue.webp'
import greenFrame from '@/assets/img/frames/green.webp'
import lavenderFrame from '@/assets/img/frames/lavender.webp'
import whiteFrame from '@/assets/img/frames/white.webp'
import type { PhoneFrameId } from '@/utils/preferences'

export const PHONE_FRAME_IMAGES: Record<PhoneFrameId, string> = {
  black: blackFrame,
  blue: blueFrame,
  green: greenFrame,
  lavender: lavenderFrame,
  white: whiteFrame,
}
