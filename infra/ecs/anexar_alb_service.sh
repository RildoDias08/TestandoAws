#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../env/infra.env"
source "${SCRIPT_DIR}/.ecs.env"

AWS_REGION="${AWS_REGION:-$(aws configure get region)}"
: "${AWS_REGION:?AWS_REGION não definido}"

read -rp "Nome do cluster:" CLUSTER_NAME
read -rp "Nome do Service:" SERVICE_NAME
: "${TASK_DEF_ARN:?TASK_DEF_ARN não definido}"

: "${SG_FARGATE_ID:?SG_FARGATE_ID (SG da task) não definido}"
: "${ALB_SG_ID:?ALB_SG_ID não definido (rode 06)}"
: "${TG_ARN:?TG_ARN não definido (rode 06)}"

: "${CONTAINER_NAME:?CONTAINER_NAME não definido}"
: "${APP_PORT:?APP_PORT não definido}"


echo "==> Região:      $AWS_REGION"
echo "==> Cluster:     $CLUSTER_NAME"
echo "==> Service:     $SERVICE_NAME"
echo "==> TG:          $TG_ARN"
echo "==> Task SG:     $SG_FARGATE_ID"
echo "==> ALB SG:      $ALB_SG_ID"
echo "==> Subnets:     $ALB_SUBNET_IDS"
echo

SUBNETS_CSV="$(echo "$ALB_SUBNET_IDS" | tr ' ,' ',' | sed 's/,,*/,/g')"

# 1) Permitir inbound na task SG somente do SG do ALB na porta do app
echo "[INFO] Garantindo inbound na task SG vindo do ALB SG (TCP ${APP_PORT})..."
aws ec2 authorize-security-group-ingress \
  --region "$AWS_REGION" \
  --group-id "$SG_FARGATE_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=${APP_PORT},ToPort=${APP_PORT},UserIdGroupPairs=[{GroupId=${ALB_SG_ID},Description='From ALB'}]" \
  >/dev/null 2>&1 || true
echo "[OK] Ingress ALB -> Task garantido."
echo

# 2) Atualizar service para usar o target group + tirar IP público
# update-service para trocar network configuration e registrar ALB
echo "[UPDATE] Anexando Target Group no service..."
aws ecs update-service \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --task-definition "$TASK_DEF_ARN" \
  --load-balancers "targetGroupArn=${TG_ARN},containerName=${CONTAINER_NAME},containerPort=${APP_PORT}" \
  --desired-count 2 --force-new-deployment \
  >/dev/null

echo "[WAIT] Aguardando service ficar estável..."
aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" 

echo "[OK] Service atualizado e estável."
echo
echo "Próximo teste: https://${ALB_DNS}"
