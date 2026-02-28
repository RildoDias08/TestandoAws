import { Bell, ClipboardList, LayoutDashboard, LogOut, Search, Settings, UserCircle2 } from "lucide-react";
import { Link, Outlet, useLocation, useNavigate } from "react-router-dom";

import { useAuth } from "../../hooks/useAuth";
import { Button } from "../ui/button";
import { Input } from "../ui/input";

const navigation = [
  { icon: LayoutDashboard, label: "Dashboard", to: "/" },
  { icon: ClipboardList, label: "Operações", to: "/" },
  { icon: Settings, label: "Configurações", to: "/" }
];

export function AppLayout() {
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const { logout, user } = useAuth();

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#e8edf4] via-[#f3f7fb] to-[#e6eef8] p-4 md:p-6">
      <div className="mx-auto grid min-h-[calc(100vh-2rem)] max-w-[1400px] grid-cols-1 gap-4 lg:grid-cols-[260px_1fr] lg:gap-6">
        <aside className="rounded-2xl border border-[#213457] bg-gradient-to-b from-[#102240] to-[#0b1931] p-5 text-[#d8e6fb] shadow-panel">
          <div className="rounded-xl border border-[#365178] bg-white/5 p-4">
            <p className="text-lg font-semibold tracking-tight">Atlas Enterprise</p>
            <p className="mt-1 text-xs uppercase tracking-[0.22em] text-[#98b3d8]">Operations Suite</p>
          </div>

          <nav className="mt-6 space-y-1.5">
            {navigation.map((item) => {
              const active = pathname === item.to;
              return (
                <Link
                  key={item.label}
                  to={item.to}
                  className={`flex items-center gap-2.5 rounded-lg border px-3 py-2.5 text-sm transition ${
                    active
                      ? "border-[#78b3ff] bg-[#1b3f72] text-white"
                      : "border-transparent text-[#d8e6fb] hover:border-[#3f5f8f] hover:bg-white/5"
                  }`}
                >
                  <item.icon className="h-4 w-4" />
                  {item.label}
                </Link>
              );
            })}
          </nav>
        </aside>

        <div className="flex min-h-0 flex-col gap-4 lg:gap-6">
          <header className="flex flex-col gap-4 rounded-2xl border border-border bg-white/85 p-4 shadow-panel backdrop-blur-sm md:flex-row md:items-center md:justify-between">
            <div>
              <h1 className="text-2xl font-semibold tracking-tight text-[#10213d]">Enterprise Dashboard</h1>
              <p className="text-sm text-muted-foreground">Observabilidade e gestão operacional em um único painel.</p>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <div className="relative w-full min-w-[220px] md:w-[280px]">
                <Search className="pointer-events-none absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input placeholder="Buscar no painel" className="pl-8" />
              </div>
              <Button variant="outline" size="sm" className="gap-2">
                <Bell className="h-4 w-4" />
                Alertas
              </Button>
              <div className="flex items-center gap-2 rounded-md border border-input px-3 py-1.5 text-sm">
                <UserCircle2 className="h-4 w-4 text-muted-foreground" />
                <span>{user?.name ?? "Operador"}</span>
              </div>
              <Button
                variant="ghost"
                size="sm"
                className="gap-1.5 text-muted-foreground"
                onClick={() => {
                  logout();
                  navigate("/login");
                }}
              >
                <LogOut className="h-4 w-4" />
                Sair
              </Button>
            </div>
          </header>

          <main className="min-h-0 flex-1">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
}
