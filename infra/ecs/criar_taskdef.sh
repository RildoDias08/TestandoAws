#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Seus inputs de infra (região etc.)
source "${SCRIPT_DIR}/../env/infra.env"
# Outputs do prereq (role arn etc.)
source "${SCRIPT_DIR}/.ecs.env"

AWS_REGION="${AWS_REGION:-$(aws configure get region)}"
if [[ -z "${AWS_REGION}" || "${AWS_REGION}" == "None" ]]; then
  echo "[ERRO] AWS_REGION não definida."
  exit 1
fi

: "${EXEC_ROLE_ARN:?EXEC_ROLE_ARN não definido (rode o 02_prereqs primeiro)}"

# Defaults (você pode colocar isso no infra.env depois, se quiser)
read -rp "Nome da task-definition (ex: meuapp-taskdef): " TASK_FAMILY
read -rp "Nome do container (ex: ctn-meuapp): " CONTAINER_NAME

aws ecr describe-repositories \
  --query 'repositories[*].repositoryUri' \
  --output text --profile "${AWS_PROFILE}"

read -rp "Qual URI a ser usada: " IMAGE_URI
read -rp "Tamanho da CPU (ex: 256): " TASK_CPU
read -rp "Nome do ECS Cluster (ex: 512): " TASK_MEMORY


LOG_GROUP="${LOG_GROUP:-/ecs/${TASK_FAMILY}}"
LOG_STREAM_PREFIX="${LOG_STREAM_PREFIX:-ecs}"

echo "==> Região:        $AWS_REGION"
echo "==> Task family:   $TASK_FAMILY"
echo "==> Container:     $CONTAINER_NAME"
echo "==> Image:         $IMAGE_URI"
echo "==> CPU/Mem:       ${TASK_CPU}/${TASK_MEMORY}"
echo "==> Porta:         $APP_PORT"
echo "==> Log group:     $LOG_GROUP"
echo

# 1) Garantir CloudWatch Log Group
if aws logs describe-log-groups \
  --region "$AWS_REGION" \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}'].logGroupName | [0]" \
  --output text | grep -qx "$LOG_GROUP"; then
  echo "[OK] Log group já existe: $LOG_GROUP"
else
  echo "[CREATE] Criando log group: $LOG_GROUP"
  aws logs create-log-group --region "$AWS_REGION" --log-group-name "$LOG_GROUP"
  echo "[OK] Log group criado."
fi
echo

# (Opcional) retenção de logs (ex.: 14 dias). Se não quiser, comente esta linha.
aws logs put-retention-policy --region "$AWS_REGION" --log-group-name "$LOG_GROUP" --retention-in-days 14 >/dev/null 2>&1 || true

# 2) Gerar JSON da task definition
TASKDEF_JSON="/tmp/${TASK_FAMILY}-taskdef.json"

cat > "$TASKDEF_JSON" <<JSON
{
  "family": "${TASK_FAMILY}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "${TASK_CPU}",
  "memory": "${TASK_MEMORY}",
  "executionRoleArn": "${EXEC_ROLE_ARN}",
  "runtimePlatform": {
    "cpuArchitecture": "X86_64",
    "operatingSystemFamily": "LINUX"
  },
  "containerDefinitions": [
    {
      "name": "${CONTAINER_NAME}",
      "image": "${IMAGE_URI}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": ${APP_PORT},
          "protocol": "tcp"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-region": "${AWS_REGION}",
          "awslogs-group": "${LOG_GROUP}",
          "awslogs-stream-prefix": "${LOG_STREAM_PREFIX}"
        }
      }
    }
  ]
}
JSON

echo "[INFO] JSON gerado em: $TASKDEF_JSON"
echo

# 3) Registrar task definition (isso cria uma nova revision)
echo "[REGISTER] Registrando task definition..."
OUT_JSON="$(aws ecs register-task-definition \
  --region "$AWS_REGION" \
  --cli-input-json "file://${TASKDEF_JSON}" \
  --output json)"

TASK_DEF_ARN="$(echo "$OUT_JSON" | jq -r '.taskDefinition.taskDefinitionArn')"
TASK_DEF_REV="$(echo "$OUT_JSON" | jq -r '.taskDefinition.revision')"

echo "[OK] Task registrada:"
echo "     ARN: $TASK_DEF_ARN"
echo "     REV: $TASK_DEF_REV"
echo

# 4) Persistir outputs para próximos passos
# Atualiza/adiciona no .ecs.env (sem duplicar bagunça)
# remove linhas antigas e reescreve no final
tmp_env="/tmp/.ecs.env.$$"
grep -vE '^(TASK_FAMILY|CONTAINER_NAME|IMAGE_URI|TASK_CPU|TASK_MEMORY|LOG_GROUP|TASK_DEF_ARN|TASK_DEF_REV)=' "${SCRIPT_DIR}/.ecs.env" > "$tmp_env" || true

cat >> "$tmp_env" <<OUT
TASK_FAMILY=${TASK_FAMILY}
CONTAINER_NAME=${CONTAINER_NAME}
IMAGE_URI=${IMAGE_URI}
TASK_CPU=${TASK_CPU}
TASK_MEMORY=${TASK_MEMORY}
LOG_GROUP=${LOG_GROUP}
TASK_DEF_ARN=${TASK_DEF_ARN}
TASK_DEF_REV=${TASK_DEF_REV}
OUT

mv "$tmp_env" "${SCRIPT_DIR}/.ecs.env"

echo "==> Atualizado: ${SCRIPT_DIR}/.ecs.env"
