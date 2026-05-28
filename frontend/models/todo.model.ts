import { z } from "zod"

// Schéma de base pour les champs communs
export const BaseSchema = z.object({
  id: z.string(),
  created_at: z.string().datetime().optional(),
  updated_at: z.string().datetime().optional(),
})

export const TodoSchema = BaseSchema.merge(
  z.object({
    title: z.string(),
    completed: z.boolean(),
    number: z.number().optional(),
  })
)

export const TodoCreateSchema = TodoSchema.pick({ title: true })

export const TodoUpdateSchema = TodoSchema.partial().pick({
  title: true,
  completed: true,
  number: true,
})

export type Todo = z.infer<typeof TodoSchema>
