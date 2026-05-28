"use client"
import { deleteTodo } from "@/lib/actionsTodo"
import { redirect } from "next/navigation"

const todosRoute = "/todos"

export default function ButtonDeleteTodo({ id }: { id: string }) {
  const handleDelete = async () => {
    await deleteTodo(id)
    redirect(todosRoute)
  }

  return <button onClick={handleDelete}>Delete</button>
}
