import { ChevronsLeftRightEllipsis, Filter, Plus } from "lucide-react";
import { useMemo, useState } from "react";

import type { StatusFilter, Task } from "../../types/task";
import { Badge } from "../ui/badge";
import { Button } from "../ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../ui/card";
import { Input } from "../ui/input";
import { Select } from "../ui/select";
import { Skeleton } from "../ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../ui/table";

type TasksTableProps = {
  tasks: Task[];
  isLoading: boolean;
  isError: boolean;
  onCreateClick: () => void;
  onToggleTask: (task: Task) => void;
  onDeleteTask: (task: Task) => void;
  togglePending: boolean;
};

const PAGE_SIZE = 5;

export function TasksTable({ tasks, isLoading, isError, onCreateClick, onToggleTask, onDeleteTask, togglePending }: TasksTableProps) {
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");
  const [page, setPage] = useState(1);

  const filtered = useMemo(() => {
    return tasks.filter((task) => {
      const matchesText = task.title.toLowerCase().includes(search.toLowerCase());
      if (!matchesText) return false;
      if (statusFilter === "open") return !task.done;
      if (statusFilter === "done") return task.done;
      return true;
    });
  }, [search, statusFilter, tasks]);

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const safePage = Math.min(page, pageCount);
  const pagedTasks = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);

  return (
    <Card>
      <CardHeader className="gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <CardTitle>Fluxo Operacional</CardTitle>
          <CardDescription>Tarefas com filtros, paginação e ações rápidas.</CardDescription>
        </div>
        <Button className="gap-2" onClick={onCreateClick}>
          <Plus className="h-4 w-4" />
          Novo item
        </Button>
      </CardHeader>

      <CardContent className="space-y-4">
        <div className="grid grid-cols-1 gap-2 md:grid-cols-[1fr_220px]">
          <div className="relative">
            <Filter className="pointer-events-none absolute left-2.5 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Filtrar por título"
              className="pl-8"
              value={search}
              onChange={(event) => {
                setSearch(event.target.value);
                setPage(1);
              }}
            />
          </div>
          <Select
            value={statusFilter}
            onChange={(event) => {
              setStatusFilter(event.target.value as StatusFilter);
              setPage(1);
            }}
          >
            <option value="all">Todos</option>
            <option value="open">Pendente</option>
            <option value="done">Concluído</option>
          </Select>
        </div>

        {isLoading ? (
          <div className="space-y-2">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : isError ? (
          <div className="rounded-md border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700">
            Erro ao carregar tarefas. Verifique a API e tente novamente.
          </div>
        ) : filtered.length === 0 ? (
          <div className="rounded-md border border-dashed border-border bg-muted/40 p-6 text-center text-sm text-muted-foreground">
            Nenhum item encontrado para os filtros atuais.
          </div>
        ) : (
          <>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Título</TableHead>
                  <TableHead>Prazo</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Ações</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {pagedTasks.map((task) => (
                  <TableRow key={task.id}>
                    <TableCell className="font-medium">{task.title}</TableCell>
                    <TableCell>{task.due_date ? String(task.due_date).slice(0, 10).split("-").reverse().join("/") : "-"}</TableCell>
                    <TableCell>
                      {task.done ? <Badge variant="success">Concluído</Badge> : <Badge variant="warning">Pendente</Badge>}
                    </TableCell>
                    <TableCell>
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          disabled={togglePending}
                          onClick={() => onToggleTask(task)}
                        >
                          Alternar
                        </Button>
                        <Button variant="destructive" size="sm" onClick={() => onDeleteTask(task)}>
                          Excluir
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>

            <div className="flex flex-col gap-3 border-t pt-3 text-sm md:flex-row md:items-center md:justify-between">
              <p className="text-muted-foreground">
                Mostrando {(safePage - 1) * PAGE_SIZE + 1} - {Math.min(safePage * PAGE_SIZE, filtered.length)} de {filtered.length}
              </p>
              <div className="flex items-center gap-2">
                <Button variant="outline" size="sm" onClick={() => setPage((prev) => Math.max(1, prev - 1))} disabled={safePage === 1}>
                  Anterior
                </Button>
                <div className="inline-flex items-center gap-1 rounded-md border px-2 py-1 text-xs text-muted-foreground">
                  <ChevronsLeftRightEllipsis className="h-3.5 w-3.5" />
                  Página {safePage} de {pageCount}
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setPage((prev) => Math.min(pageCount, prev + 1))}
                  disabled={safePage >= pageCount}
                >
                  Próxima
                </Button>
              </div>
            </div>
          </>
        )}
      </CardContent>
    </Card>
  );
}
