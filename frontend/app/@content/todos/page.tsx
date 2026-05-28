import { getTodos } from "@/lib/actionsTodo"
import { Todo } from "@/models/todo.model"
import DataTable from "./dataTable"
import Pagination from "./pagination"

type Props = {
  searchParams: { page?: string; pageSize?: string }
}

type TodoResponse = {
  items: Todo[]
  total: number
  page: number
  pageSize: number
}

export default async function Page({ searchParams }: Props) {
  const page = Math.max(1, Number(searchParams.page) || 1)
  const pageSize = Math.max(1, Number(searchParams.pageSize) || 5)
  const query = `?page=${page}&pageSize=${pageSize}`

  const data = (await getTodos({ query })) as TodoResponse
  const items = data.items

  return (
    <>
      <DataTable items={items} />
      <Pagination />
    </>
  )
}
