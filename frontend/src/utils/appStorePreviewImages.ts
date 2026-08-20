import type { BuiltinPhoneAppId } from '@/types/apps'

type PreviewableBuiltinAppId = Exclude<BuiltinPhoneAppId, 'app-store'>

const previewModules = import.meta.glob<string>(
  '../assets/img/app-previews/*.jpg',
  {
    eager: true,
    import: 'default',
    query: '?url',
  },
)

const APP_STORE_PREVIEW_IMAGES = Object.fromEntries(
  Object.entries(previewModules).map(([path, imageUrl]) => {
    const appId = path
      .split('/')
      .at(-1)
      ?.replace(/\.jpg$/, '')
    if (!appId) throw new Error(`Invalid App Store preview path: ${path}`)
    return [appId, imageUrl]
  }),
) as Partial<Record<PreviewableBuiltinAppId, string>>

export function getAppStorePreviewImage(appId: string): string | null {
  return APP_STORE_PREVIEW_IMAGES[appId as PreviewableBuiltinAppId] ?? null
}

export const APP_STORE_PREVIEW_IMAGE_IDS = Object.freeze(
  Object.keys(APP_STORE_PREVIEW_IMAGES) as PreviewableBuiltinAppId[],
)
