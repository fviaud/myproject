"use client"
export default function Error({ error }: { error: Error }) {
  return (
    <div>
      <p>{error.message}</p>
    </div>
  )
}
