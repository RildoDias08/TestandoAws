#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../env/infra.env"
source "${SCRIPT_DIR}/.ecs.env"

AWS_REGION="${AWS_REGION:-$(aws configure get region)}"
if [[ -z "${AWS_REGION}" || "${AWS_REGION}" == "None" ]]; then
  echo "[ERRO] AWS_REGION não definida."
  exit 1
fi

: "${CLUSTER_NAME:?CLUSTER_NAME não definido (.ecs.env)}"
: "${TASK_DEF_ARN:?TASK_DEF_ARN não definido (rode o 03_task_definition)}"
: "${SG_FARGATE_ID:?SG_FARGATE_ID não definido (rode o 02_prereqs)}"
: "${APP_PORT:?APP_PORT não definido}"

read -rp "Nome do Service (ex: meuapp-service): " SERVICE_NAME

read -rp "Desired count (ex: 2): " DESIRED_COUNT

SUBNETS="$SVC_SUBNET_IDS"

echo "==> Região:   $AWS_REGION"
echo "==> Cluster:  $CLUSTER_NAME"
echo "==> Service:  $SERVICE_NAME"
echo "==> TaskDef:  $TASK_DEF_ARN"
echo "==> Subnets:  $SUBNETS"
echo "==> SG:       $SG_FARGATE_ID"
echo "==> Desired:  $DESIRED_COUNT"
echo

# Checar se service existe
STATUS="$(aws ecs describe-services \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --query "services[0].status" \
  --output text 2>/dev/null || true)"

if [[ "$STATUS" == "ACTIVE" ]]; then
  echo "[UPDATE] Service já existe. Atualizando task definition e desired count..."
  aws ecs update-service \
    --region "$AWS_REGION" \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --task-definition "$TASK_DEF_ARN" \
    --desired-count "$DESIRED_COUNT" \
    --force-new-deployment \
    --output json >/dev/null
  echo "[OK] Service atualizado."
else
  echo "[CREATE] Criando service Fargate (sem ALB, com public IP)..."
  aws ecs create-service \
    --region "$AWS_REGION" \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --task-definition "$TASK_DEF_ARN" \
    --launch-type FARGATE \
    --desired-count "$DESIRED_COUNT" \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS}],securityGroups=[${SG_FARGATE_ID}],assignPublicIp=ENABLED}" \
    --tags key=Project,value=rio-aws key=ManagedBy,value=awscli \
    --output json >/dev/null
  echo "[OK] Service criado."
fi

echo
echo "[WAIT] Aguardando service ficar estável..."
aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME"

echo "[OK] Service estável."
echo

# Mostrar tasks do service
echo "==> Tasks do service:"
aws ecs list-tasks \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --output table
