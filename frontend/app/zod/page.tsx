"use client"

import Form, { IChangeEvent } from "@rjsf/core"
import { RJSFSchema } from "@rjsf/utils"
import validator from "@rjsf/validator-ajv8"
import * as z from "zod"

// 1️⃣ Définition du schéma Zod
const schema = z.object({
  name: z.string(),
  age: z.number(),
})

// 2️⃣ Conversion vers JSON Schema compatible avec JSONSchema7

export default function Page() {
  const jsonSchema = z.toJSONSchema(schema) as RJSFSchema
  jsonSchema.$schema = "http://json-schema.org/draft-07/schema#"

  function handleSubmit({ formData }: IChangeEvent) {
    const result = schema.safeParse(formData)
    if (!result.success) {
      console.error(result.error)
    } else {
      console.log("✅ data valide:", formData)
    }
  }

  function MySubmitButton() {
    return (
      <button type="submit" className="my-btn">
        🚀 Soumettre
      </button>
    )
  }

  return (
    <div>
      <Form
        schema={jsonSchema}
        formData={{ name: "Alice", age: 30 }}
        validator={validator}
        onSubmit={handleSubmit}
      >
        <MySubmitButton />
      </Form>
    </div>
  )
}
