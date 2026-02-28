import React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";
import { toast } from "sonner";
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
  Input,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow
} from "../components";
import { endpoints, fetchJson, getEffectiveApiUrl, Task } from "../lib/api";

const taskSchema = z.object({
  title: z.string().min(3, "Mínimo 3 caracteres"),
  dueDate: z.string().optional()
});

type TaskForm = z.infer<typeof taskSchema>;

function useDashboardQueries() {
  const health = useQuery({
    queryKey: ["health"],
    queryFn: () => fetchJson<{ ok: boolean }>(endpoints.health),
    refetchInterval: 15000
  });

  const db = useQuery({
    queryKey: ["db-health"],
    queryFn: () => fetchJson<{ ok: boolean }>(endpoints.dbHealth),
    refetchInterval: 15000
  });

  const info = useQuery({
    queryKey: ["info"],
    queryFn: () => fetchJson<{ api: { version: string } }>(endpoints.info)
  });

  const tasks = useQuery({
    queryKey: ["tasks"],
    queryFn: () => fetchJson<Task[]>(endpoints.tasks)
  });

  return { health, db, info, tasks };
}

function EmptyState({ label }: { label: string }) {
  return (
    <div className="flex h-32 items-center justify-center rounded-lg border border-dashed border-slate-200 text-sm text-slate-500">
      {label}
    </div>
  );
}

export default function Dashboard() {
  const { health, db, info, tasks } = useDashboardQueries();
  const queryClient = useQueryClient();
  const [status, setStatus] = React.useState<"all" | "open" | "done">("all");
  const [search, setSearch] = React.useState("");
  const [page, setPage] = React.useState(1);
  const pageSize = 6;
  const frontendUrl = window.location.origin;
  const backendUrl = getEffectiveApiUrl();
  const statusBadge = health.isLoading ? (
    <Skeleton className="h-10 w-24" />
  ) : health.isError ? (
    <Badge variant="danger">Offline</Badge>
  ) : (
    <Badge variant="success">Online</Badge>
  );

  const createTask = useMutation({
    mutationFn: (payload: { title: string; dueDate?: string | null }) =>
      fetchJson<Task>(endpoints.tasks, {
        method: "POST",
        body: JSON.stringify(payload)
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
      toast.success("Tarefa criada");
    },
    onError: (e: Error) => toast.error(e.message)
  });

  const toggleTask = useMutation({
    mutationFn: (task: Task) =>
      fetchJson<Task>(`${endpoints.tasks}/${task.id}`, {
        method: "PATCH",
        body: JSON.stringify({ done: !task.done })
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
      toast.success("Status atualizado");
    },
    onError: (e: Error) => toast.error(e.message)
  });

  const deleteTask = useMutation({
    mutationFn: (taskId: number) =>
      fetchJson(`${endpoints.tasks}/${taskId}`, { method: "DELETE" }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
      toast.success("Tarefa removida");
    },
    onError: (e: Error) => toast.error(e.message)
  });

  const tasksData = tasks.data ?? [];
  const filtered = tasksData.filter((task) => {
    if (status === "open" && task.done) return false;
    if (status === "done" && !task.done) return false;
    if (search && !task.title.toLowerCase().includes(search.toLowerCase())) {
      return false;
    }
    return true;
  });

  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
  const paged = filtered.slice((page - 1) * pageSize, page * pageSize);

  React.useEffect(() => {
    if (page > totalPages) setPage(1);
  }, [page, totalPages]);

  const form = useForm<TaskForm>({
    resolver: zodResolver(taskSchema),
    defaultValues: { title: "", dueDate: "" }
  });

  const onSubmit = (values: TaskForm) => {
    createTask.mutate({
      title: values.title,
      dueDate: values.dueDate?.trim() ? values.dueDate : null
    });
    form.reset();
  };

  return (
    <div className="space-y-6">
      <section className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader>
            <CardTitle>API Status</CardTitle>
            <CardDescription>Disponibilidade atual</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {statusBadge}
              <div className="space-y-1 text-sm">
                <div>
                  Frontend URL:{" "}
                  <a
                    className="text-blue-600 underline"
                    href={frontendUrl}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {frontendUrl}
                  </a>
                </div>
                <div>
                  Backend URL:{" "}
                  <a
                    className="text-blue-600 underline"
                    href={backendUrl}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {backendUrl}
                  </a>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Database</CardTitle>
            <CardDescription>Postgres readiness</CardDescription>
          </CardHeader>
          <CardContent>
            {db.isLoading ? (
              <Skeleton className="h-10 w-24" />
            ) : db.isError ? (
              <Badge variant="danger">Sem conexão</Badge>
            ) : (
              <Badge variant="success">Conectado</Badge>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Versão</CardTitle>
            <CardDescription>Build atual</CardDescription>
          </CardHeader>
          <CardContent>
            {info.isLoading ? (
              <Skeleton className="h-10 w-32" />
            ) : info.isError ? (
              <Badge variant="warning">Indisponível</Badge>
            ) : (
              <div className="text-lg font-semibold">
                {info.data?.api?.version ?? "dev"}
              </div>
            )}
          </CardContent>
        </Card>
      </section>

      <section className="space-y-4">
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div>
            <h2 className="text-xl font-semibold">Fluxo Operacional</h2>
            <p className="text-sm text-slate-500">
              Tarefas e itens pendentes sincronizados com a API
            </p>
          </div>
          <Dialog>
            <DialogTrigger asChild>
              <Button>Novo item</Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Nova tarefa</DialogTitle>
                <DialogDescription>Crie um item para o time.</DialogDescription>
              </DialogHeader>
              <form
                className="mt-4 space-y-4"
                onSubmit={form.handleSubmit(onSubmit)}
              >
                <Input placeholder="Título da tarefa" {...form.register("title")} />
                <Input type="date" {...form.register("dueDate")} />
                {form.formState.errors.title ? (
                  <p className="text-xs text-rose-600">
                    {form.formState.errors.title.message}
                  </p>
                ) : null}
                <div className="flex justify-end">
                  <Button type="submit" disabled={createTask.isPending}>
                    {createTask.isPending ? "Salvando..." : "Criar"}
                  </Button>
                </div>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <Card>
          <CardContent className="pt-6">
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <div className="flex items-center gap-2">
                <Input
                  className="w-64"
                  placeholder="Buscar por título"
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                />
                <select
                  className="h-10 rounded-md border border-slate-200 bg-white px-3 text-sm"
                  value={status}
                  onChange={(e) => setStatus(e.target.value as "all" | "open" | "done")}
                >
                  <option value="all">Todos</option>
                  <option value="open">Em aberto</option>
                  <option value="done">Concluídos</option>
                </select>
              </div>
              <div className="text-sm text-slate-500">
                {filtered.length} itens encontrados
              </div>
            </div>

            {tasks.isLoading ? (
              <div className="mt-6 grid gap-3">
                <Skeleton className="h-10" />
                <Skeleton className="h-10" />
                <Skeleton className="h-10" />
              </div>
            ) : tasks.isError ? (
              <EmptyState label="Erro ao carregar tarefas" />
            ) : filtered.length === 0 ? (
              <EmptyState label="Nenhuma tarefa encontrada" />
            ) : (
              <div className="mt-6 space-y-4">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Tarefa</TableHead>
                      <TableHead>Data</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Ações</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {paged.map((task) => (
                      <TableRow key={task.id}>
                        <TableCell className="font-medium">{task.title}</TableCell>
                        <TableCell>{task.due_date ?? "—"}</TableCell>
                        <TableCell>
                          {task.done ? (
                            <Badge variant="success">Concluída</Badge>
                          ) : (
                            <Badge variant="warning">Pendente</Badge>
                          )}
                        </TableCell>
                        <TableCell>
                          <div className="flex gap-2">
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => toggleTask.mutate(task)}
                            >
                              Alternar
                            </Button>
                            <Button
                              size="sm"
                              variant="destructive"
                              onClick={() => deleteTask.mutate(task.id)}
                            >
                              Excluir
                            </Button>
                          </div>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>

                <div className="flex items-center justify-between text-sm text-slate-500">
                  <span>
                    Página {page} de {totalPages}
                  </span>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={page === 1}
                      onClick={() => setPage((p) => Math.max(1, p - 1))}
                    >
                      Anterior
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={page === totalPages}
                      onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                    >
                      Próxima
                    </Button>
                  </div>
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
