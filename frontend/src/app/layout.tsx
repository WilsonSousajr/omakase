import type { Metadata } from "next";
import { Outfit } from "next/font/google";
import "./globals.css";
import AuthGuard from "@/components/AuthGuard";
import Providers from "@/components/Providers";
import Toast from "@/components/Toast";

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
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${outfit.className} flex h-screen bg-[var(--color-bg)] text-[var(--color-text-primary)] antialiased`}
      >
        <Providers>
          <AuthGuard>
            {children}
          </AuthGuard>
          <Toast />
        </Providers>
      </body>
    </html>
  );
}
