"use client"
import { Button } from "@/components/ui/button"
import { Switch } from "@/components/ui/switch"
import { updateTodo } from "@/lib/actionsTodo"
import { TodoSchema, TodoUpdateSchema } from "@/models/todo.model"
import { IChangeEvent, withTheme } from "@rjsf/core"
import { Theme as shadcnTheme } from "@rjsf/shadcn"
import { RJSFSchema } from "@rjsf/utils"
import validator from "@rjsf/validator-ajv8"
import { useRouter } from "next/navigation"
import { useState } from "react"
import * as z from "zod"
const pathRoot = "/todos"

const Form = withTheme(shadcnTheme)

const widgets = {
  CheckboxWidget: ({ value, onChange, label }: any) => (
    <label className="flex items-center gap-2">
      <span>{label}</span>
      <Switch checked={!!value} onCheckedChange={onChange} />
    </label>
  ),
}

function pick<T, K extends readonly (keyof T)[]>(
  obj: T,
  keys: K
): Pick<T, K[number]> {
  return Object.fromEntries(keys.map((key) => [key, obj[key]])) as Pick<
    T,
    K[number]
  >
}

export default function Page({ item }: { item: z.infer<typeof TodoSchema> }) {
  const itemData = item.id
    ? pick(item, Object.keys(TodoUpdateSchema.shape) as (keyof typeof item)[])
    : {}

  const [data, setData] = useState(itemData || {})
  const [state, setState] = useState<"idle" | "submitting">("idle")
  const [error, setError] = useState<string | null>(null)
  const router = useRouter()

  const jsonSchema = z.toJSONSchema(TodoUpdateSchema) as RJSFSchema
  jsonSchema.$schema = "http://json-schema.org/draft-07/schema#"

  const uiSchema = Object.keys(TodoUpdateSchema.shape).reduce(
    (acc, key) => ({
      ...acc,
      [key]: {
        "ui:options": {
          classNames: "capitalize",
        },
      },
    }),
    {}
  )

  async function handleSubmit({ formData }: IChangeEvent) {
    setState("submitting")

    console.log("Form data:", formData)
    const result = TodoUpdateSchema.safeParse(formData)
    if (!result.success) {
      setError("Validation error: " + result.error.message)
      setState("idle")
      return
    }
    try {
      const { error } = await updateTodo({
        ...formData,
        ...(item.id ? { id: item.id } : {}),
      })

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
        formData={data}
        uiSchema={uiSchema}
        validator={validator}
        onChange={(e) => setData(e.formData)}
        onSubmit={handleSubmit}
        widgets={widgets}
        className="flex flex-col gap-2"
      >
        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={() => router.push(pathRoot)}>
            Cancel
          </Button>
          <Button type="submit" disabled={state === "submitting"}>
            Save
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
