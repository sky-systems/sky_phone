const resourceName = window.GetParentResourceName?.() ?? 'sky_phone'

export type NuiResponse<T = unknown> = {
  success: boolean
  data?: T
  error?: string
}

export async function nuiCall<T = unknown>(
  endpoint: string,
  data: Record<string, unknown> = {},
): Promise<NuiResponse<T>> {
  const baseUrl = import.meta.env.DEV
    ? 'http://localhost:3001/api'
    : `https://${resourceName}`

  try {
    const response = await fetch(`${baseUrl}/${endpoint}`, {
      body: JSON.stringify(data),
      headers: { 'Content-Type': 'application/json' },
      method: 'POST',
    })

    if (!response.ok) {
      const error = `${response.status} ${response.statusText}`
      console.error(`[NUI] ${endpoint} failed: ${error}`)
      return { error, success: false }
    }

    const body = await response.text()
    return body ? (JSON.parse(body) as NuiResponse<T>) : { success: true }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    console.error(`[NUI] ${endpoint} failed:`, error)
    return { error: message, success: false }
  }
}
