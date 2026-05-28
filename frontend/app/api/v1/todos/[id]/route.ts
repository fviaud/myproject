import { NextRequest, NextResponse } from "next/server"
import { Todo, TodoUpdateSchema } from "@/models/todo.model"
import { deleteTodo, getTodo, updateTodo } from "@/lib/actionsTodo"
import { mutateApi } from "@/lib/api"

const apiUrl = process.env.API_URL || "http://localhost:8080"
const apiVersion = process.env.API_VERSION || "v1"
const apiItems = "todos"
const todosPath = `${apiUrl}/api/${apiVersion}/${apiItems}`
const getTodoPath = (id?: string) => (id ? `${todosPath}/${id}` : todosPath)

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params

  try {
    const todo = (await getTodo(id)) as unknown as Todo
    return NextResponse.json(todo, { status: 200 })
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      {
        status:
          error instanceof Error && error.message === "404 Not Found"
            ? 404
            : 500,
      }
    )
  }
}

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const data = await req.json()
  const parsed = TodoUpdateSchema.safeParse(data)

  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid data" }, { status: 400 })
  }

  try {
    const todo = await mutateApi(getTodoPath(id), "PUT", parsed.data)
    if (todo.error) {
      return NextResponse.json({ error: todo.error.message }, { status: 500 })
    }
    return NextResponse.json(todo, { status: 200 })
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      {
        status:
          error instanceof Error && error.message === "404 Not Found "
            ? 404
            : 500,
      }
    )
  }
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  try {
    await deleteTodo(id)

    return NextResponse.json(
      { message: "Deleted successfully" },
      { status: 200 }
    )
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      {
        status:
          error instanceof Error && error.message === "404 Not Found"
            ? 404
            : 500,
      }
    )
  }
}
