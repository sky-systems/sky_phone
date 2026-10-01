import type { ExternalPhoneAppDefinition } from '@/types/apps'
import type { NuiResponse } from '@/utils/nui'

export type CustomAppLifecycleEvent = 'close' | 'open' | 'ready'
export type CustomAppOrientation = ExternalPhoneAppDefinition['orientation']

type CustomAppLifecycleTask = () => Promise<NuiResponse>

export type CustomAppLifecycleScheduler = {
  enqueue: (task: CustomAppLifecycleTask) => Promise<NuiResponse>
}

type CustomAppLifecycleReporterOptions = {
  onFailure?: (event: CustomAppLifecycleEvent, error: string) => void
  scheduler: CustomAppLifecycleScheduler
  send: (event: CustomAppLifecycleEvent, data?: unknown) => Promise<NuiResponse>
}

export type CustomAppOrientationCoordinator = {
  createSession: (setLandscape: (landscape: boolean) => void) => {
    apply: (orientation: CustomAppOrientation) => void
    release: () => void
  }
}

function stableValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(stableValue)
  if (!value || typeof value !== 'object') return value

  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, item]) => [key, stableValue(item)]),
  )
}

export function getCustomAppFrameKey(app: ExternalPhoneAppDefinition): string {
  return JSON.stringify(
    stableValue({
      bridgeMode: app.bridgeMode,
      bundled: app.bundled,
      capabilities: app.capabilities,
      compatibility: app.compatibility,
      description: app.description,
      id: app.id,
      launchMode: app.launchMode,
      access: {
        price: app.store?.price,
        allowedJobs: app.store?.allowedJobs,
        disabledJobs: app.store?.disabledJobs,
      },
      name: app.name,
      orientation: app.orientation,
      ownerResource: app.ownerResource,
      readyTimeoutMs: app.readyTimeoutMs,
      ui: app.ui,
    }),
  )
}

export function getCustomAppSafeArea(orientation: CustomAppOrientation): {
  bottom: number
  left: number
  right: number
  top: number
} {
  return orientation === 'landscape'
    ? { bottom: 0, left: 44, right: 25, top: 0 }
    : { bottom: 25, left: 0, right: 0, top: 44 }
}

export function createCustomAppOrientationCoordinator(): CustomAppOrientationCoordinator {
  let owner: symbol | null = null

  return {
    createSession(setLandscape) {
      const token = Symbol('custom-app-orientation')

      return {
        apply(orientation): void {
          owner = token
          setLandscape(orientation === 'landscape')
        },
        release(): void {
          if (owner !== token) return
          owner = null
          setLandscape(false)
        },
      }
    },
  }
}

export const customAppOrientationCoordinator =
  createCustomAppOrientationCoordinator()

export function createCustomAppLifecycleScheduler(): CustomAppLifecycleScheduler {
  let tail: Promise<void> = Promise.resolve()

  return {
    enqueue(task): Promise<NuiResponse> {
      const operation = tail.then(task)
      tail = operation.then(
        () => undefined,
        () => undefined,
      )
      return operation
    },
  }
}

export const customAppLifecycleScheduler = createCustomAppLifecycleScheduler()

export function createCustomAppLifecycleReporter(
  options: CustomAppLifecycleReporterOptions,
): {
  isComplete: (event: CustomAppLifecycleEvent) => boolean
  report: (
    event: CustomAppLifecycleEvent,
    data?: unknown,
  ) => Promise<NuiResponse>
} {
  const completed = new Set<CustomAppLifecycleEvent>()
  const pending = new Map<CustomAppLifecycleEvent, Promise<NuiResponse>>()

  function notifyFailure(event: CustomAppLifecycleEvent, error: string): void {
    try {
      options.onFailure?.(event, error)
    } catch (failureHandlerError) {
      console.error(
        '[Custom apps] Lifecycle failure handler threw an error.',
        failureHandlerError,
      )
    }
  }

  function report(
    event: CustomAppLifecycleEvent,
    data?: unknown,
  ): Promise<NuiResponse> {
    if (completed.has(event)) return Promise.resolve({ success: true })

    const existing = pending.get(event)
    if (existing) return existing

    const operation = options.scheduler.enqueue(async () => {
      if (event === 'ready' && !completed.has('open')) {
        return { error: 'open_not_completed', success: false }
      }

      try {
        return await options.send(event, data)
      } catch (error) {
        return {
          error: error instanceof Error ? error.message : 'request_failed',
          success: false,
        }
      }
    })

    const settled = operation.then(
      (response) => {
        if (response.success || response.error === 'hook_failed') {
          completed.add(event)
        }
        if (!response.success)
          notifyFailure(event, response.error ?? 'request_failed')
        if (pending.get(event) === settled) pending.delete(event)
        return response
      },
      (error) => {
        const response = {
          error: error instanceof Error ? error.message : 'request_failed',
          success: false,
        }
        notifyFailure(event, response.error)
        if (pending.get(event) === settled) pending.delete(event)
        return response
      },
    )
    pending.set(event, settled)
    return settled
  }

  return {
    isComplete: (event) => completed.has(event),
    report,
  }
}
