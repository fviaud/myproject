"use client"
import { Button } from "@/components/ui/button"
import { usePathname, useRouter } from "next/navigation"

export default function Menu() {
  const router = useRouter()
  const pathname = usePathname()

  return (
    <nav className="flex flex-row justify-end gap-2">
      <Button
        size="sm"
        variant="outline"
        onClick={() => router.push(`${pathname}/new`)}
      >
        Add
      </Button>
    </nav>
  )
}
