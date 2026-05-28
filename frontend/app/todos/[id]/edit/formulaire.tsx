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

export default function Page({ data }: { data: z.infer<typeof TodoSchema> }) {
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
    const result = TodoUpdateSchema.safeParse(formData)
    if (!result.success) {
      setError("Validation error: " + result.error.message)
      setState("idle")
      return
    }
    try {
      const { error } = await updateTodo({ ...formData, id: data.id })

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
        onSubmit={handleSubmit}
        widgets={widgets}
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
