#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Seus inputs de infra (região etc.)
source "${SCRIPT_DIR}/../env/infra.env"
# Outputs do prereq (role arn etc.)
source "${SCRIPT_DIR}/.ecs.env"

read -rp "Nome do Cluster (ex: meuapp-Cluster): " CLUSTER_NAME
read -rp "Nome do service (ex: meuapp-service): " SERVICE_NAME

echo "[WAIT] Aguardando service ficar estável..."
aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME"

# 1) Pegar uma task RUNNING do service
TASK_ARN="$(aws ecs list-tasks \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --query "taskArns[0]" \
  --output text)"

if [[ -z "${TASK_ARN}" || "${TASK_ARN}" == "None" ]]; then
  echo "[ERRO] Nenhuma task RUNNING encontrada para o service $SERVICE_NAME."
  echo "       Veja: aws ecs describe-services --cluster \"$CLUSTER_NAME\" --services \"$SERVICE_NAME\""
  exit 1
fi

echo "[OK] Task: $TASK_ARN"

# 2) Pegar ENI da task (com retry, porque pode demorar)
ENI_ID=""
for i in {1..12}; do
  ENI_ID="$(aws ecs describe-tasks \
    --region "$AWS_REGION" \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value | [0]" \
    --output text 2>/dev/null || true)"

  if [[ -n "${ENI_ID}" && "${ENI_ID}" != "None" ]]; then
    break
  fi
  echo "[WAIT] ENI ainda não disponível... tentativa $i/12"
  sleep 2
done

if [[ -z "${ENI_ID}" || "${ENI_ID}" == "None" ]]; then
  echo "[ERRO] Não consegui obter o ENI da task."
  exit 1
fi

echo "[OK] ENI: $ENI_ID"

# 3) Pegar Public IP do ENI (com retry)
PUBLIC_IP=""
for i in {1..12}; do
  PUBLIC_IP="$(aws ec2 describe-network-interfaces \
    --region "$AWS_REGION" \
    --network-interface-ids "$ENI_ID" \
    --query "NetworkInterfaces[0].Association.PublicIp" \
    --output text 2>/dev/null || true)"

  if [[ -n "${PUBLIC_IP}" && "${PUBLIC_IP}" != "None" ]]; then
    break
  fi
  echo "[WAIT] Public IP ainda não disponível... tentativa $i/12"
  sleep 2
done

if [[ -z "${PUBLIC_IP}" || "${PUBLIC_IP}" == "None" ]]; then
  echo "[ERRO] Não consegui obter Public IP (subnet pública + assignPublicIp=ENABLED?)."
  exit 1
fi

echo
echo "[OK] Public IP da task: $PUBLIC_IP"
echo "URL base: http://${PUBLIC_IP}:${APP_PORT}"
echo

