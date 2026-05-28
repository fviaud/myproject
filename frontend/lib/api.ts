export async function fetchApi<T>(url: string): Promise<T> {
  const response = await fetch(url, {
    method: "GET",
    headers: {
      "Content-Type": "application/json",
    },
    cache: "no-store",
  })

  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}`)
  }

  const data = await response.json()

  return data as T
}

export async function mutateApi(
  url: string,
  method: "POST" | "PUT" | "DELETE",
  body?: unknown
): Promise<{ data?: unknown; error?: Error }> {
  try {
    const response = await fetch(url, {
      method,
      headers: { "Content-Type": "application/json" },
      body: body ? JSON.stringify(body) : undefined,
    })

    if (!response.ok) {
      const data = await response.json().catch(() => ({}))

      return {
        data: null,
        error: new Error(
          data.error || `${response.status} ${response.statusText}`
        ),
      }
    }

    if (response.status === 204) {
      return { data: null, error: undefined }
    }

    const data = await response.json()
    return { data, error: undefined }
  } catch (error) {
    return {
      data: null,
      error: error instanceof Error ? error : new Error("Unknown error"),
    }
  }
}
