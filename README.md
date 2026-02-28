# TestandoAws

Aplicação full stack para gestão de tarefas operacionais com:
- API Node.js + Express + PostgreSQL
- Frontend React + Vite + TypeScript
- Execução local via Docker Compose
- Estrutura de scripts para AWS/EC2 e publicação em S3

## Arquitetura

- `api/`: backend REST (Express + `pg`)
- `client/`: frontend React (Vite, Tailwind, React Query, React Hook Form)
- `docker-compose.yml`: orquestra `db`, `backend` e `frontend`
- `infra/`: scripts auxiliares para AWS (alguns ainda em construção)
- `scripts/`: automações locais (ex.: sync para S3)

## Funcionalidades atuais

- Login mock no frontend (persistido em `localStorage`)
- Rotas protegidas (`/login` e dashboard)
- Dashboard com:
  - health da API
  - health do banco
  - informações de runtime
  - CRUD de tarefas
  - filtro, paginação e status
- Campo opcional de prazo (`dueDate`) ao criar tarefa

## Estrutura do projeto

```text
.
├── api/
│   ├── src/
│   │   ├── server.js
│   │   └── db.js
│   ├── .env.example
│   └── Dockerfile
├── client/
│   ├── src/
│   ├── public/config.js
│   ├── .env.example
│   ├── nginx.conf
│   ├── docker-entrypoint.sh
│   └── Dockerfile
├── infra/
│   ├── ec2/
│   ├── env/
│   └── docs/
├── scripts/
│   ├── s3.sh
│   └── build_react.sh
├── db.env.example
└── docker-compose.yml
```

## Subir local com Docker

1. Copie os arquivos de ambiente:

```bash
cp api/.env.example api/.env
cp client/.env.example client/.env
cp db.env.example db.env
```

2. Suba os serviços:

```bash
docker compose up --build
```

3. Acesse:

- Frontend: `http://localhost:8080`
- Backend (direto): `http://localhost:3002`

## Rodar em modo desenvolvimento (sem Docker)

Pré-requisitos:
- Node.js 22+
- PostgreSQL ativo

Backend:

```bash
cd api
npm install
npm start
```

Frontend:

```bash
cd client
npm install
npm run dev
```

## Variáveis de ambiente

### Backend (`api/.env`)

```env
PORT=3002
DB_HOST=db
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=appdb
DB_SSL=false
APP_VERSION=local
CORS_ORIGIN=http://localhost:8080
```

### Frontend (`client/.env`)

```env
API_URL=
```

Com `API_URL` vazio, o frontend usa `/api` (same-origin).

### Banco (`db.env`)

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=appdb
```

## Endpoints da API

- `GET /health`
- `GET /api/health`
- `GET /api/db-health`
- `GET /api/info`
- `GET /api/tasks`
- `POST /api/tasks`
- `PATCH /api/tasks/:id`
- `DELETE /api/tasks/:id`

Exemplos:

```bash
curl http://localhost:3002/health
curl http://localhost:3002/api/tasks
```

Payload de criação:

```json
{
  "title": "Ajustar health check",
  "dueDate": "2026-03-10"
}
```

## Build de imagens

```bash
docker build -t meuapp-backend ./api
docker build -t meuapp-frontend ./client
```

## Frontend runtime config

No container Nginx, o arquivo `/config.js` é gerado no startup por `client/docker-entrypoint.sh` usando `API_URL`.

## Infra e scripts auxiliares

### `scripts/s3.sh`

Sincroniza `client/dist` para um bucket S3:

```bash
S3_BUCKET=meu-bucket ./scripts/s3.sh
# opcional: AWS_PROFILE=meu-perfil
```

### `infra/ec2/`

- `criar_sg.sh`: cria Security Group com opção de regra de entrada
- `criar_sg_alb.sh`: cria SG para ALB e libera 80/443
- `criar_ec2.sh`, `user_data_amzlinux.sh`, `user_data_app.sh`: ainda em construção

Arquivo base de variáveis: `infra/env/infra.env.exemplo`.

## Observações

- `client/dist/` e `client/node_modules/` aparecem no workspace atual; não devem ser versionados.
- `infra/docs/infra.md` ainda está como placeholder.
