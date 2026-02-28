
**Stack:** Node.js API (`api/`), React Vite client (`client/`), Postgres (local)

## Estrutura

```
.
├─ api/
│  ├─ Dockerfile
│  ├─ .env.example
│  └─ src/
├─ client/
│  ├─ Dockerfile
│  ├─ nginx.conf
│  ├─ docker-entrypoint.sh
│  ├─ .env.example
│  └─ src/
├─ docker-compose.yml
├─ db.env.example
└─ README.md
```

## Rodar local

1. Copie os exemplos de env:

```
cp api/.env.example api/.env
cp client/.env.example client/.env
cp db.env.example db.env
```

2. Suba os containers:

```
docker compose up --build
```

3. Acesso:

- Frontend: `http://localhost:8080`
- Backend: `http://localhost:3002`

## Build das imagens

```
docker build -t meuapp-backend ./api
docker build -t meuapp-frontend ./client
```

## Configuração de env

### Backend (`api/.env`)

- `PORT=3002`
- `DB_HOST=db`
- `DB_PORT=5432`
- `DB_USER=postgres`
- `DB_PASSWORD=postgres`
- `DB_NAME=appdb`
- `DB_SSL=false`
- `APP_VERSION=local`
- `CORS_ORIGIN=http://localhost:8080`

### Frontend (`client/.env`)

- `API_URL=`
  - Use vazio para **same-origin** com proxy do Nginx (`/api` → backend).

### Postgres (`db.env`)

- `POSTGRES_USER=postgres`
- `POSTGRES_PASSWORD=postgres`
- `POSTGRES_DB=appdb`

## Healthcheck e endpoints

- API health: `GET /health`
- Compat: `GET /api/health`
- DB health: `GET /api/db-health`
- Info: `GET /api/info`
- Tasks: `GET /api/tasks`

Exemplos:

```
curl http://localhost:3002/health
curl http://localhost:3002/api/tasks
```

## Runtime config do Frontend

O `client` lê `window.__CONFIG__.API_URL` de `/config.js`, gerado no **start** do container. Nunca usamos `VITE_API_URL` no build.

## Due date em tarefas

As tarefas agora aceitam `dueDate` opcional no `POST /api/tasks` (formato `YYYY-MM-DD`); o backend persiste em `tasks.due_date` (`DATE`) com migração automática via `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...` no boot. No frontend, o formulário de criação inclui campo de data e a lista exibe a coluna "Data" (ou `—` quando vazia).

## AWS (ECS Fargate ou ECS EC2)

### Imagens separadas

- `meuapp-backend` e `meuapp-frontend` com Dockerfiles próprios.

### Exemplo de env vars para Task Definition

**Backend:**
- `PORT=3002`
- `DB_HOST=<rds-endpoint>`
- `DB_PORT=5432`
- `DB_USER=<user>`
- `DB_PASSWORD=<secret>`
- `DB_NAME=<db>`
- `DB_SSL=true`
- `APP_VERSION=<git-sha>`
- `CORS_ORIGIN=https://app.seudominio.com`

**Frontend:**
- `API_URL=` (vazio para same-origin com ALB)

### Security Groups (recomendado)

- **ALB SG**: inbound `80/443` de `0.0.0.0/0`.
- **Frontend SG (ECS)**: inbound `80` **somente** do SG do ALB.
- **Backend SG (ECS)**: inbound `3002` **somente** do SG do ALB.
- **DB SG**: inbound `5432` **somente** do SG do backend.

### ALB routing (path-based)

- `/api/*` → target group **backend** (porta 3002)
- `/` → target group **frontend** (porta 80)

### Observações

- Prefira secrets no AWS Secrets Manager/SSM Parameter Store.
- Logs do Node já estão em JSON (pronto para CloudWatch).
- Healthcheck do backend em `/health`.

## Checklist pré-deploy AWS

- [ ] Atualizar `APP_VERSION` com hash/versão do build
- [ ] Validar `CORS_ORIGIN` apenas com origens confiáveis
- [ ] Confirmar `API_URL` vazio (same-origin) para usar ALB `/api`
- [ ] Configurar SGs conforme recomendado
- [ ] Validar healthchecks no Target Group
- [ ] Confirmar `DB_SSL=true` para RDS
- [ ] Garantir secrets fora do repositório
- [ ] Testar build e push das imagens no CI
