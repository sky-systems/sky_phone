import type { ExternalPhoneAppDefinition } from '@/types/apps'
import type { PhonePlayerIdentity } from '@/types/device'

export function isCustomAppJobAllowed(
  app: ExternalPhoneAppDefinition,
  job: PhonePlayerIdentity['job'],
): boolean {
  const name = job?.name ?? ''
  if (app.store?.disabledJobs?.[name] !== undefined) return false
  const allowed = app.store?.allowedJobs
  return (
    !allowed ||
    !Object.keys(allowed).length ||
    (allowed[name] !== undefined && (job?.grade ?? 0) >= allowed[name]!)
  )
}

export function getCustomAppAccessRequest(
  app: ExternalPhoneAppDefinition,
  imei: string | undefined,
  sessionToken: string | null,
) {
  return {
    appId: app.id,
    ownerResource: app.ownerResource,
    imei,
    sessionToken,
    requirePolicy:
      (app.store?.price ?? 0) > 0 ||
      !!Object.keys(app.store?.allowedJobs ?? {}).length ||
      !!Object.keys(app.store?.disabledJobs ?? {}).length,
  }
}
