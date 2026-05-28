import { getTodo } from "@/lib/actionsTodo"
import Formulaire from "./formulaire"

export default async function Page({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const todo = await getTodo(id)

  if (!todo) {
    return <div>Todo not found</div>
  }

  return <Formulaire item={todo} />
}
