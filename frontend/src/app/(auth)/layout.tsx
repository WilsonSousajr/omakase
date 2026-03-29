export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen w-full items-center justify-center bg-[var(--color-bg)]">
      <div className="w-full max-w-sm px-4">{children}</div>
    </div>
  );
}
