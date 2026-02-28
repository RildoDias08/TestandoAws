import type { Task } from "../types/task";

import { getConfig } from "./config";

const { API_URL } = getConfig();

function normalizeApiUrl(url: string): string {
  return (url || "").trim().replace(/\/+$/, "");
}

function hasApiSuffix(url: string): boolean {
  return /\/api$/i.test(url);
}

function getApiBase(): string {
  const normalized = normalizeApiUrl(API_URL);
  if (!normalized) return "/api";
  return hasApiSuffix(normalized) ? normalized : `${normalized}/api`;
}

export function getEffectiveBackendApiUrl(): string {
  try {
    return new URL(getApiBase(), window.location.origin).toString().replace(/\/$/, "");
  } catch {
    return `${window.location.origin}/api`;
  }
}

const apiBase = getApiBase();

const endpoints = {
  health: `${apiBase}/health`,
  dbHealth: `${apiBase}/db-health`,
  info: `${apiBase}/info`,
  tasks: `${apiBase}/tasks`
};

export type HealthResponse = {
  ok: boolean;
  uptimeSec?: number;
  version?: string;
};

export type DbHealthResponse = {
  ok: boolean;
  db?: string;
  error?: string;
};

export type InfoResponse = {
  ok: boolean;
  api: {
    version: string;
    node: string;
    port: number;
  };
};

export async function fetchJson<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
      ...(options?.headers ?? {})
    },
    ...options
  });

  const text = await response.text();
  let data: unknown = null;

  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = null;
    }
  }

  if (!response.ok) {
    const errorPayload = data as { error?: string; message?: string } | null;
    const message = errorPayload?.error || errorPayload?.message || `${response.status}`;
    throw new Error(message);
  }

  return data as T;
}

export const api = {
  health: () => fetchJson<HealthResponse>(endpoints.health),
  dbHealth: () => fetchJson<DbHealthResponse>(endpoints.dbHealth),
  info: () => fetchJson<InfoResponse>(endpoints.info),
  listTasks: () => fetchJson<Task[]>(endpoints.tasks),
  createTask: (payload: { title: string; dueDate?: string }) =>
    fetchJson<Task>(endpoints.tasks, {
      method: "POST",
      body: JSON.stringify(payload)
    }),
  toggleTask: (task: Task) =>
    fetchJson<Task>(`${endpoints.tasks}/${task.id}`, {
      method: "PATCH",
      body: JSON.stringify({ done: !task.done })
    }),
  deleteTask: (taskId: number) =>
    fetchJson<void>(`${endpoints.tasks}/${taskId}`, {
      method: "DELETE"
    })
};
