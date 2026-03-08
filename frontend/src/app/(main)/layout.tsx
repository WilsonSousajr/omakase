import Sidebar from "@/components/Sidebar";
import TopBar from "@/components/TopBar";
import TaskForm from "@/components/tasks/TaskForm";
import ErrorBoundary from "@/components/ErrorBoundary";
import KeyboardShortcutProvider from "@/components/KeyboardShortcutProvider";

export default function MainLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <KeyboardShortcutProvider>
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <TopBar />
        <main className="flex-1 overflow-auto">
          <ErrorBoundary>{children}</ErrorBoundary>
        </main>
      </div>
      <TaskForm />
    </KeyboardShortcutProvider>
  );
}
