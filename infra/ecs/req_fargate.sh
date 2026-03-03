#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../env/infra.env"

# Região vem do seu ambiente / aws configure
AWS_REGION="${AWS_REGION:-$(aws configure get region)}"
if [[ -z "${AWS_REGION}" || "${AWS_REGION}" == "None" ]]; then
  echo "[ERRO] Região não definida. Exporte AWS_REGION ou configure 'aws configure'."
  exit 1
fi

echo

read -rp "Nome do ECS Cluster (ex: rio-cluster): " CLUSTER_NAME

# 1) Garantir que o cluster existe (idempotente)
if aws ecs describe-clusters \
  --region "$AWS_REGION" \
  --clusters "$CLUSTER_NAME" \
  --query "clusters[0].clusterName" \
  --output text 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "[OK] Cluster já existe: $CLUSTER_NAME"
else
  echo "[CREATE] Criando cluster ECS..."
  aws ecs create-cluster \
    --region "$AWS_REGION" \
    --cluster-name "$CLUSTER_NAME" \
    --settings name=containerInsights,value=enabled \
    --tags key=Project,value=rio-aws key=ManagedBy,value=awscli \
    --output json >/dev/null
  echo "[OK] Cluster criado: $CLUSTER_NAME"
fi
echo

read -rp "Nome do Security Group (ex: rio-fargate-sg): " SG_NAME

# 2) Criar/reutilizar Security Group na VPC informada
SG_ID="$(
  aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$SG_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || true
)"

if [[ -z "${SG_ID}" || "${SG_ID}" == "None" ]]; then
  echo "[CREATE] Criando Security Group..."
  SG_ID="$(aws ec2 create-security-group \
    --region "$AWS_REGION" \
    --vpc-id "$VPC_ID" \
    --group-name "$SG_NAME" \
    --description "SG para ECS Fargate task" \
    --query "GroupId" \
    --output text)"
  echo "[OK] SG criado: $SG_ID"

  aws ec2 create-tags \
    --region "$AWS_REGION" \
    --resources "$SG_ID" \
    --tags Key=Project,Value=rio-aws Key=ManagedBy,Value=awscli >/dev/null
else
  echo "[OK] SG já existe: $SG_ID"
fi
echo

read -rp "Porta do App (ex: 3002): " APP_PORT

# 3) Descobrir seu IP público (pra liberar só ele no SG)
MY_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '\n' || true)"
if [[ -z "${MY_IP}" ]]; then
  echo "[ERRO] Não consegui descobrir seu IP público (curl checkip.amazonaws.com falhou)."
  exit 1
fi
MY_CIDR="${MY_IP}/32"
echo "[OK] Seu IP público: $MY_CIDR"
echo

# 4) Garantir inbound TCP 3002 só do seu IP (idempotente via "|| true")
echo "[INFO] Garantindo inbound TCP ${APP_PORT} de ${MY_CIDR}..."
aws ec2 authorize-security-group-ingress \
  --region "$AWS_REGION" \
  --group-id "$SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=${APP_PORT},ToPort=${APP_PORT},IpRanges=[{CidrIp=${MY_CIDR},Description='Dev access only'}]" \
  >/dev/null 2>&1 || true
echo "[OK] Inbound garantido."
echo

read -rp "Nome da Role (ex: rio-ecsTaskExecutionRole): " EXEC_ROLE_NAME

# 5) Criar/garantir Execution Role
ROLE_ARN="$(
  aws iam get-role \
    --role-name "$EXEC_ROLE_NAME" \
    --query "Role.Arn" \
    --output text 2>/dev/null || true
)"

if [[ -z "${ROLE_ARN}" || "${ROLE_ARN}" == "None" ]]; then
  echo "[CREATE] Criando IAM Role: $EXEC_ROLE_NAME"
  cat > /tmp/ecs-task-exec-trust.json <<'JSON'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ecs-tasks.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
JSON

  ROLE_ARN="$(aws iam create-role \
    --role-name "$EXEC_ROLE_NAME" \
    --assume-role-policy-document file:///tmp/ecs-task-exec-trust.json \
    --query "Role.Arn" \
    --output text)"
  echo "[OK] Role criada: $ROLE_ARN"
else
  echo "[OK] Role já existe: $ROLE_ARN"
fi

echo "[INFO] Garantindo policy AmazonECSTaskExecutionRolePolicy na role..."
aws iam attach-role-policy \
  --role-name "$EXEC_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
  >/dev/null 2>&1 || true
echo "[OK] Policy garantida."

echo

# 7) Exportar outputs para um arquivo (pra próximos scripts)
cat > .ecs.env <<OUT
AWS_REGION=${AWS_REGION}
CLUSTER_NAME=${CLUSTER_NAME}
SG_FARGATE_ID=${SG_ID}
EXEC_ROLE_NAME=${EXEC_ROLE_NAME}
EXEC_ROLE_ARN=${ROLE_ARN}
APP_PORT=${APP_PORT}
MY_CIDR=${MY_CIDR}
OUT

echo "==> Pronto! Variáveis salvas em: .ecs.env"
echo
