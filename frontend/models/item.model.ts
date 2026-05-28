import { z } from "zod"

export const ItemSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string(),
  price: z.number(),
  stock: z.number(),
  created_at: z.string().datetime().optional(),
  updated_at: z.string().datetime().optional(),
})

export type Item = z.infer<typeof ItemSchema>
