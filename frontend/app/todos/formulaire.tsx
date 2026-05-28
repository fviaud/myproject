"use client"
import type { IChangeEvent } from "@rjsf/core"
import { withTheme } from "@rjsf/core"
import { Theme as shadcnTheme } from "@rjsf/shadcn"
import validator from "@rjsf/validator-ajv8"
import { Button } from "@workspace/ui/components/button"
import { Switch } from "@workspace/ui/components/switch"
import { usePathname, useRouter } from "next/navigation"
import { useState } from "react"

const Form = withTheme(shadcnTheme)

const widgets = {
  CheckboxWidget: ({ value, onChange, label }: any) => (
    <label className="flex items-center gap-2">
      <span>{label}</span>
      <Switch checked={!!value} onCheckedChange={onChange} />
    </label>
  ),
  // InputWidget: ({ value, onChange, label }: any) => (
  //   <div className="flex flex-col">
  //     <label className="mb-1">{label}</label>
  //     <input
  //       type="text"
  //       value={value || ""}
  //       onChange={(e) => onChange(e.target.value)}
  //       className="rounded border border-gray-300 px-3 py-2 focus:border-blue-500 focus:outline-none"
  //     />
  //   </div>
  // ),
}

export default function Formulaire({
  id,
  jsonSchema,
  uiSchema,
  dataSchema,
  action,
}: {
  id?: string
  jsonSchema: Record<string, unknown>
  uiSchema?: Record<string, unknown>
  dataSchema?: Record<string, unknown>
  action: (data: Record<string, unknown>) => Promise<{
    success: boolean
    error: string | null
  }>
}) {
  const [data, setData] = useState(dataSchema || {})
  const [state, setState] = useState<"idle" | "submitting">("idle")
  const [error, setError] = useState<string | null>(null)

  const router = useRouter()
  const pathname = usePathname()
  const pathRoot = pathname.replace(
    /(?:\/new|\/edit(?:\/[^/]+)?|\/[^/]+\/edit)$/,
    ""
  )

  async function handleSubmit({ formData }: IChangeEvent) {
    setState("submitting")
    try {
      const { error } = await action({ ...formData, ...(id ? { id } : {}) })

      if (error) {
        setError(error)
        return
      } else {
        setError(null)
        // Toaster.success(id ? "Todo updated successfully!" : "Todo created successfully!")
        router.push(pathRoot)
      }
    } catch (error) {
      setError(error instanceof Error ? error.message : "Error submitting form")
      return
    } finally {
      setState("idle")
    }
  }

  return (
    <div>
      <Form
        schema={jsonSchema}
        uiSchema={uiSchema}
        formData={data}
        validator={validator}
        onChange={(e) => setData(e.formData)}
        onSubmit={handleSubmit}
        widgets={widgets}
        className="flex flex-col gap-4"
      >
        <div className="flex flex-row gap-4">
          <Button
            variant="outline"
            size="sm"
            onClick={() => router.push(pathRoot)}
          >
            Cancel
          </Button>
          <Button
            variant="outline"
            size="sm"
            type="submit"
            disabled={state === "submitting"}
          >
            {id ? "Update" : "Create"}
          </Button>
        </div>
      </Form>
      <div>
        {error && (
          <div className="mt-4 rounded bg-red-100 p-4 text-red-700">
            <strong className="font-bold">Error:</strong>
            <span className="block">{error}</span>
          </div>
        )}
      </div>
    </div>
  )
}
