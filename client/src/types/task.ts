export type Task = {
  id: number;
  title: string;
  due_date?: string | null;
  done: boolean;
  created_at?: string;
};

export type StatusFilter = "all" | "open" | "done";
