import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { z } from "zod";

import { Button } from "../ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "../ui/dialog";
import { Input } from "../ui/input";

const createTaskSchema = z.object({
  title: z.string().trim().min(3, "Título deve ter ao menos 3 caracteres"),
  dueDate: z.string().optional()
});

type CreateTaskDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSubmit: (payload: { title: string; dueDate?: string }) => void;
  isSubmitting: boolean;
};

type CreateTaskForm = z.infer<typeof createTaskSchema>;

export function CreateTaskDialog({ open, onOpenChange, onSubmit, isSubmitting }: CreateTaskDialogProps) {
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors }
  } = useForm<CreateTaskForm>({
    resolver: zodResolver(createTaskSchema),
    defaultValues: {
      title: "",
      dueDate: ""
    }
  });

  const submit = (values: CreateTaskForm) => {
    onSubmit({
      title: values.title.trim(),
      dueDate: values.dueDate || undefined
    });
    reset();
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Novo Item Operacional</DialogTitle>
          <DialogDescription>Crie uma nova tarefa para monitoramento do fluxo.</DialogDescription>
        </DialogHeader>

        <form className="space-y-4" onSubmit={handleSubmit(submit)}>
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="title">
              Título
            </label>
            <Input id="title" placeholder="Ex: Ajustar health check" {...register("title")} />
            {errors.title ? <p className="text-xs text-rose-700">{errors.title.message}</p> : null}
          </div>

          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="dueDate">
              Prazo
            </label>
            <Input id="dueDate" type="date" {...register("dueDate")} />
            {errors.dueDate ? <p className="text-xs text-rose-700">{errors.dueDate.message}</p> : null}
          </div>

          <div className="flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancelar
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Salvando..." : "Salvar item"}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
