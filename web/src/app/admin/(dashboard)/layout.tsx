import { AdminNav } from "@/components/AdminNav";

export const metadata = { title: "Admin Dashboard" };

export default function AdminDashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-1">
      <AdminNav />
      <div className="flex-1 overflow-x-auto px-8 py-8">{children}</div>
    </div>
  );
}
