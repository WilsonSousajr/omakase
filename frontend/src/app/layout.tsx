import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Providers from "@/components/Providers";
import Sidebar from "@/components/Sidebar";
import TopBar from "@/components/TopBar";
import Toast from "@/components/Toast";
import KeyboardShortcutProvider from "@/components/KeyboardShortcutProvider";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Omakase",
  description: "Productivity app — Plan, Focus, Ship.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${inter.className} flex h-screen bg-zinc-950 text-zinc-100 antialiased`}
      >
        <Providers>
          <KeyboardShortcutProvider>
            <Sidebar />
            <div className="flex flex-1 flex-col overflow-hidden">
              <TopBar />
              <main className="flex-1 overflow-auto">{children}</main>
            </div>
            <Toast />
          </KeyboardShortcutProvider>
        </Providers>
      </body>
    </html>
  );
}
