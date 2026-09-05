const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000'

type HealthResponse = {
  status: 'ok'
}

export async function getApiHealth(signal?: AbortSignal) {
  const response = await fetch(`${API_BASE_URL}/health/live`, { signal })

  if (!response.ok) {
    throw new Error(`API health check failed: ${response.status}`)
  }

  return (await response.json()) as HealthResponse
}
