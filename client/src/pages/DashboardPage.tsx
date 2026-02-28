import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";

import { CreateTaskDialog } from "../components/dashboard/CreateTaskDialog";
import { DeleteTaskDialog } from "../components/dashboard/DeleteTaskDialog";
import { KpiCards } from "../components/dashboard/KpiCards";
import { TasksTable } from "../components/dashboard/TasksTable";
import { api, getEffectiveBackendApiUrl } from "../services/api";
import type { Task } from "../types/task";

export function DashboardPage() {
  const queryClient = useQueryClient();
  const [createDialogOpen, setCreateDialogOpen] = useState(false);
  const [taskToDelete, setTaskToDelete] = useState<Task | null>(null);

  const health = useQuery({ queryKey: ["health"], queryFn: api.health, refetchInterval: 15_000 });
  const db = useQuery({ queryKey: ["db-health"], queryFn: api.dbHealth, refetchInterval: 15_000 });
  const info = useQuery({ queryKey: ["info"], queryFn: api.info });
  const tasks = useQuery({ queryKey: ["tasks"], queryFn: api.listTasks });

  const createTask = useMutation({
    mutationFn: api.createTask,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["tasks"] });
      setCreateDialogOpen(false);
      toast.success("Item criado com sucesso.");
    },
    onError: (error: Error) => {
      toast.error(`Falha ao criar item: ${error.message}`);
    }
  });

  const toggleTask = useMutation({
    mutationFn: api.toggleTask,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["tasks"] });
      toast.success("Status atualizado.");
    },
    onError: (error: Error) => {
      toast.error(`Falha ao atualizar item: ${error.message}`);
    }
  });

  const deleteTask = useMutation({
    mutationFn: api.deleteTask,
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["tasks"] });
      setTaskToDelete(null);
      toast.success("Item removido.");
    },
    onError: (error: Error) => {
      toast.error(`Falha ao excluir item: ${error.message}`);
    }
  });

  const frontendUrl = window.location.origin;
  const backendApiUrl = getEffectiveBackendApiUrl();

  return (
    <div className="space-y-4 md:space-y-6">
      <KpiCards
        health={health}
        db={db}
        info={info}
        frontendUrl={frontendUrl}
        backendApiUrl={backendApiUrl}
      />

      <TasksTable
        tasks={tasks.data ?? []}
        isLoading={tasks.isLoading}
        isError={tasks.isError}
        onCreateClick={() => setCreateDialogOpen(true)}
        onToggleTask={(task) => toggleTask.mutate(task)}
        onDeleteTask={(task) => setTaskToDelete(task)}
        togglePending={toggleTask.isPending}
      />

      <CreateTaskDialog
        open={createDialogOpen}
        onOpenChange={setCreateDialogOpen}
        onSubmit={(payload) => createTask.mutate(payload)}
        isSubmitting={createTask.isPending}
      />

      <DeleteTaskDialog
        open={Boolean(taskToDelete)}
        onOpenChange={(open) => {
          if (!open) setTaskToDelete(null);
        }}
        taskTitle={taskToDelete?.title}
        onConfirm={() => {
          if (taskToDelete) deleteTask.mutate(taskToDelete.id);
        }}
        isDeleting={deleteTask.isPending}
      />
    </div>
  );
}
