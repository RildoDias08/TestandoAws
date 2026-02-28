import { getConfig } from "./config";

export type Task = {
  id: number;
  title: string;
  due_date?: string | null;
  done: boolean;
  created_at?: string;
};

const { API_URL } = getConfig();

function normalizeApiUrl(url: string): string {
  return (url || "").trim().replace(/\/+$/, "");
}

function hasApiSuffix(url: string): boolean {
  return /\/api$/i.test(url);
}

export function getApiBase(): string {
  const normalized = normalizeApiUrl(API_URL);
  if (!normalized) return "/api";
  return hasApiSuffix(normalized) ? normalized : `${normalized}/api`;
}

export function getEffectiveApiUrl(): string {
  const apiBase = getApiBase();
  return new URL(apiBase, window.location.origin).toString().replace(/\/$/, "");
}

const apiBase = getApiBase();

export const endpoints = {
  health: `${apiBase}/health`,
  dbHealth: `${apiBase}/db-health`,
  info: `${apiBase}/info`,
  tasks: `${apiBase}/tasks`
};

export async function fetchJson<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
      ...(options?.headers ?? {})
    },
    ...options
  });

  const text = await res.text();
  let json: unknown = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {}

  if (!res.ok) {
    const msg =
      (json as { error?: string; message?: string })?.error ||
      (json as { message?: string })?.message ||
      `${res.status} ${res.statusText}`;
    throw new Error(msg);
  }

  return json as T;
}
