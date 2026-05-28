import { ThemeProvider } from "@/components/theme-provider"
import { Toaster } from "@/components/ui/sonner"
import { cn } from "@/lib/utils"
import { Geist, Geist_Mono } from "next/font/google"
// @ts-ignore
import "./globals.css"

const geist = Geist({ subsets: ["latin"], variable: "--font-sans" })

const fontMono = Geist_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
})

export default function RootLayout({
  sidebar,
  content,
}: Readonly<{
  children: React.ReactNode
  sidebar?: React.ReactNode
  content?: React.ReactNode
}>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={cn(
        "antialiased",
        fontMono.variable,
        "font-sans",
        geist.variable
      )}
    >
      <body>
        <ThemeProvider>
          <div style={{ display: "flex" }}>
            <aside style={{ width: 200 }}>{sidebar}</aside>
            <main style={{ flex: 1 }}>
              {/* {children} */}
              {content}
            </main>
          </div>
          <Toaster />
        </ThemeProvider>
      </body>
    </html>
  )
}
