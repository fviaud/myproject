import Link from "next/link"

export default function Page() {
  return (
    <div className="m-4 flex flex-col gap-2">
      <Link href="/todos">Todos</Link>
      <Link href="/products">Products</Link>
      <Link href="/posts">Posts</Link>
    </div>
  )
}
