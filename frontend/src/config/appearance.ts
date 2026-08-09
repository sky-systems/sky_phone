import blackFrame from '@/assets/img/frames/black.webp'
import blueFrame from '@/assets/img/frames/blue.webp'
import cyanFrame from '@/assets/img/frames/cyan.webp'
import goldFrame from '@/assets/img/frames/gold.webp'
import greenFrame from '@/assets/img/frames/green.webp'
import lavenderFrame from '@/assets/img/frames/lavender.webp'
import limeFrame from '@/assets/img/frames/lime.webp'
import orangeFrame from '@/assets/img/frames/orange.webp'
import pinkFrame from '@/assets/img/frames/pink.webp'
import purpleFrame from '@/assets/img/frames/purple.webp'
import redFrame from '@/assets/img/frames/red.webp'
import rgbFrame from '@/assets/img/frames/rgb.webp'
import tealFrame from '@/assets/img/frames/teal.webp'
import whiteFrame from '@/assets/img/frames/white.webp'
import yellowFrame from '@/assets/img/frames/yellow.webp'
import type { PhoneFrameId } from '@/utils/preferences'

export const PHONE_FRAME_IMAGES: Record<PhoneFrameId, string> = {
  black: blackFrame,
  blue: blueFrame,
  green: greenFrame,
  lavender: lavenderFrame,
  red: redFrame,
  white: whiteFrame,
  orange: orangeFrame,
  yellow: yellowFrame,
  lime: limeFrame,
  teal: tealFrame,
  cyan: cyanFrame,
  purple: purpleFrame,
  pink: pinkFrame,
  gold: goldFrame,
  rgb: rgbFrame,
}

export const PHONE_FRAME_COLORS: Record<PhoneFrameId, string> = {
  black: '#3a3a3c',
  blue: '#7294c2',
  green: '#889b6e',
  lavender: '#aaa1c8',
  red: '#d93f45',
  white: '#f2f2f2',
  orange: '#e68a3f',
  yellow: '#e5d134',
  lime: '#75d13d',
  teal: '#36a992',
  cyan: '#35bfe3',
  purple: '#8251df',
  pink: '#db82b0',
  gold: '#d4aa45',
  rgb: 'conic-gradient(#ff3b30, #ffcc00, #34c759, #00c7be, #007aff, #af52de, #ff2d55, #ff3b30)',
}
