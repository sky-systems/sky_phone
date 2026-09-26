import { blocksCellularRequest } from '@/utils/cellular'

const resourceName = globalThis.window?.GetParentResourceName?.() ?? 'sky_phone'
const requestTimeoutMs = 20_000

export type NuiResponse<T = unknown> = {
  success: boolean
  data?: T
  error?: string
}

export async function nuiCall<T = unknown>(
  endpoint: string,
  data: Record<string, unknown> = {},
): Promise<NuiResponse<T>> {
  if (blocksCellularRequest(endpoint, data))
    return { success: false, error: 'no_signal' }
  const developmentParameters = new URLSearchParams(window.location.search)
  const developmentPort = developmentParameters.get('apiPort')
  const configuredApiBase = developmentParameters.get('apiBase')
  const browserApiBase = configuredApiBase?.startsWith('/')
    ? configuredApiBase.replace(/\/$/, '')
    : null
  const baseUrl =
    browserApiBase ??
    (import.meta.env.DEV
      ? `http://localhost:${developmentPort ?? '3002'}/api`
      : `https://${resourceName}`)
  const requestData =
    browserApiBase || import.meta.env.DEV
      ? {
          ...data,
          _testScenario: developmentParameters.get('testScenario') ?? undefined,
        }
      : data
  const controller = new AbortController()
  const timeoutId = window.setTimeout(
    () => controller.abort(),
    requestTimeoutMs,
  )

  try {
    const response = await fetch(`${baseUrl}/${endpoint}`, {
      body: JSON.stringify(requestData),
      headers: { 'Content-Type': 'application/json' },
      method: 'POST',
      signal: controller.signal,
    })

    if (!response.ok) {
      const error = `${response.status} ${response.statusText}`
      console.error(`[NUI] ${endpoint} failed: ${error}`)
      return { error, success: false }
    }

    const body = await response.text()
    return body ? (JSON.parse(body) as NuiResponse<T>) : { success: true }
  } catch (error) {
    const message = controller.signal.aborted
      ? 'request_timeout'
      : error instanceof Error
        ? error.message
        : 'Unknown error'
    console.error(`[NUI] ${endpoint} failed:`, error)
    return { error: message, success: false }
  } finally {
    window.clearTimeout(timeoutId)
  }
}
