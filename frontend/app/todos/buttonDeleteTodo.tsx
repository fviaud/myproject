"use client"
import { redirect } from "next/navigation"
import { deleteTodo } from "@/lib/actionsTodo"

const todosRoute = "/todos"

export default function ButtonDeleteTodo({ id }: { id: string }) {
  const handleDelete = async () => {
    await deleteTodo(id)
    redirect(todosRoute)
  }

  return <button onClick={handleDelete}>Delete</button>
}
