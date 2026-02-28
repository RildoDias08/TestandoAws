import express from "express";
import cors from "cors";
import crypto from "crypto";
import { pool, ensureSchema, waitForDbReady } from "./db.js";

const app = express();
app.use(express.json());
app.set("trust proxy", true);

const port = Number(process.env.PORT || 3002);
const startedAt = Date.now();

const corsOrigins = (process.env.CORS_ORIGIN || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

app.use(
  cors({
    origin(origin, cb) {
      if (!origin) return cb(null, true);
      if (corsOrigins.length === 0) return cb(null, true);
      if (corsOrigins.includes("*") || corsOrigins.includes(origin)) {
        return cb(null, true);
      }
      return cb(new Error("Not allowed by CORS"), false);
    }
  })
);

app.use((req, res, next) => {
  const requestId = req.header("x-request-id") || crypto.randomUUID();
  req.requestId = requestId;
  res.setHeader("x-request-id", requestId);

  const start = Date.now();
  res.on("finish", () => {
    const log = {
      level: "info",
      msg: "request",
      requestId,
      method: req.method,
      path: req.originalUrl,
      status: res.statusCode,
      durationMs: Date.now() - start,
      ip: req.ip,
      userAgent: req.headers["user-agent"] || ""
    };
    console.log(JSON.stringify(log));
  });

  next();
});

/**
 * =========================
 * ROTAS DA API (/api/*)
 * =========================
 */

// Healthcheck da API (use no Target Group do ALB)
app.get("/health", (req, res) => {
  res.json({
    ok: true,
    service: "api",
    uptimeSec: Math.floor((Date.now() - startedAt) / 1000),
    version: process.env.APP_VERSION || "dev"
  });
});

// compat: /api/health
app.get("/api/health", (req, res) => {
  res.json({
    ok: true,
    service: "api",
    uptimeSec: Math.floor((Date.now() - startedAt) / 1000),
    version: process.env.APP_VERSION || "dev"
  });
});

// Health do banco
app.get("/api/db-health", async (req, res) => {
  try {
    const r = await pool.query("SELECT 1 as ok");
    res.json({
      ok: true,
      db: "reachable",
      result: r.rows?.[0]?.ok ?? 1
    });
  } catch (err) {
    res.status(500).json({
      ok: false,
      db: "unreachable",
      error: err?.message || "db error"
    });
  }
});

// Info da aplicação
app.get("/api/info", (req, res) => {
  res.json({
    ok: true,
    api: {
      version: process.env.APP_VERSION || "dev",
      port,
      node: process.version
    },
    database: {
      host: process.env.DB_HOST || null,
      port: Number(process.env.DB_PORT || 5432),
      name: process.env.DB_NAME || null,
      ssl: process.env.DB_SSL || "false"
    }
  });
});

// CRUD de tarefas
app.get("/api/tasks", async (req, res) => {
  const r = await pool.query("SELECT * FROM tasks ORDER BY id DESC");
  res.json(r.rows);
});

app.post("/api/tasks", async (req, res) => {
  const title = (req.body?.title || "").trim();
  if (!title) {
    return res.status(400).json({ error: "title is required" });
  }

  const rawDueDate = req.body?.dueDate;
  let dueDate = null;

  if (rawDueDate !== undefined && rawDueDate !== null && rawDueDate !== "") {
    if (typeof rawDueDate !== "string") {
      return res.status(400).json({ error: "dueDate must be YYYY-MM-DD" });
    }

    const normalized = rawDueDate.trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
      return res.status(400).json({ error: "dueDate must be YYYY-MM-DD" });
    }

    const parsed = new Date(`${normalized}T00:00:00Z`);
    if (Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== normalized) {
      return res.status(400).json({ error: "dueDate must be a valid date" });
    }

    dueDate = normalized;
  }

  const r = await pool.query(
    "INSERT INTO tasks(title, due_date) VALUES($1, $2::date) RETURNING *",
    [title, dueDate]
  );

  res.status(201).json(r.rows[0]);
});

app.patch("/api/tasks/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "invalid id" });
  }

  const done = Boolean(req.body?.done);

  const r = await pool.query(
    "UPDATE tasks SET done=$1 WHERE id=$2 RETURNING *",
    [done, id]
  );

  if (r.rowCount === 0) {
    return res.status(404).json({ error: "not found" });
  }

  res.json(r.rows[0]);
});

app.delete("/api/tasks/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "invalid id" });
  }

  const r = await pool.query("DELETE FROM tasks WHERE id=$1", [id]);

  if (r.rowCount === 0) {
    return res.status(404).json({ error: "not found" });
  }

  res.status(204).send();
});

app.use((err, req, res, next) => {
  const requestId = req.requestId || req.header("x-request-id") || "";
  console.error(
    JSON.stringify({
      level: "error",
      msg: "request_error",
      requestId,
      path: req.originalUrl,
      method: req.method,
      error: err?.message || String(err)
    })
  );
  if (res.headersSent) return next(err);
  const status = err?.message === "Not allowed by CORS" ? 403 : 500;
  res.status(status).json({ error: status === 403 ? "cors_denied" : "internal_error", requestId });
});

/**
 * =========================
 * START SERVER
 * =========================
 */

(async () => {
  try {
    console.log(JSON.stringify({ level: "info", msg: "waiting_for_db" }));
    await waitForDbReady({ retries: 40, delayMs: 1000 });

    console.log(JSON.stringify({ level: "info", msg: "ensuring_db_schema" }));
    await ensureSchema();
    console.log(JSON.stringify({ level: "info", msg: "db_schema_ok" }));
  } catch (e) {
    console.error(
      JSON.stringify({
        level: "error",
        msg: "db_unavailable",
        error: e?.message || String(e)
      })
    );
    // Em ECS, geralmente é melhor sair para o orchestrator reiniciar
    process.exit(1);
  }

  app.listen(port, "0.0.0.0", () => {
    console.log(
      JSON.stringify({ level: "info", msg: "server_listening", port })
    );
  });
})();
