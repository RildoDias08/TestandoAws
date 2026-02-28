import { Activity, Database, Package } from "lucide-react";

import { Badge } from "../ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "../ui/card";
import { Skeleton } from "../ui/skeleton";

type KpiCardsProps = {
  health: {
    isLoading: boolean;
    isError: boolean;
    data?: { ok: boolean; uptimeSec?: number; version?: string };
  };
  db: {
    isLoading: boolean;
    isError: boolean;
    data?: { ok: boolean };
  };
  info: {
    isLoading: boolean;
    isError: boolean;
    data?: { api?: { version: string } };
  };
  frontendUrl: string;
  backendApiUrl: string;
};

export function KpiCards({ health, db, info, frontendUrl, backendApiUrl }: KpiCardsProps) {
  return (
    <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
          <CardTitle>API</CardTitle>
          <Activity className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent className="space-y-2">
          {health.isLoading ? (
            <Skeleton className="h-6 w-32" />
          ) : health.isError ? (
            <Badge variant="danger">Offline</Badge>
          ) : (
            <Badge variant="success">Online</Badge>
          )}
          <p className="text-xs text-muted-foreground">Uptime: {health.data?.uptimeSec ?? 0}s</p>
          <div className="space-y-1 rounded-md border border-border bg-muted/40 p-2 text-xs text-muted-foreground">
            <p className="break-all">
              Frontend:{" "}
              <a href={frontendUrl} target="_blank" rel="noreferrer" className="text-primary underline">
                {frontendUrl}
              </a>
            </p>
            <p className="break-all">
              Backend:{" "}
              <a
                href={backendApiUrl}
                target="_blank"
                rel="noreferrer"
                className="text-primary underline"
              >
                {backendApiUrl}
              </a>
            </p>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
          <CardTitle>Database</CardTitle>
          <Database className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          {db.isLoading ? (
            <Skeleton className="h-6 w-28" />
          ) : db.isError ? (
            <Badge variant="danger">Sem conexão</Badge>
          ) : (
            <Badge variant="success">Conectado</Badge>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-3">
          <CardTitle>Versão API</CardTitle>
          <Package className="h-4 w-4 text-muted-foreground" />
        </CardHeader>
        <CardContent>
          {info.isLoading ? (
            <Skeleton className="h-7 w-20" />
          ) : info.isError ? (
            <p className="text-xl font-semibold">local</p>
          ) : (
            <p className="text-xl font-semibold">{info.data?.api?.version ?? "local"}</p>
          )}
        </CardContent>
      </Card>
    </section>
  );
}
