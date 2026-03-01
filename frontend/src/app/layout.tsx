import type { Metadata } from "next";
import { Outfit } from "next/font/google";
import "./globals.css";
import Providers from "@/components/Providers";
import Sidebar from "@/components/Sidebar";
import TopBar from "@/components/TopBar";
import Toast from "@/components/Toast";
import ErrorBoundary from "@/components/ErrorBoundary";
import KeyboardShortcutProvider from "@/components/KeyboardShortcutProvider";

const outfit = Outfit({ subsets: ["latin"] });

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
        className={`${outfit.className} flex h-screen bg-[#0a0a0a] text-white antialiased`}
      >
        <Providers>
          <KeyboardShortcutProvider>
            <Sidebar />
            <div className="flex flex-1 flex-col overflow-hidden">
              <TopBar />
              <main className="flex-1 overflow-auto">
                <ErrorBoundary>{children}</ErrorBoundary>
              </main>
            </div>
            <Toast />
          </KeyboardShortcutProvider>
        </Providers>
      </body>
    </html>
  );
}
