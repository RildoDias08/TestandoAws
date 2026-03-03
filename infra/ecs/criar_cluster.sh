#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../env/infra.env"

read -rp "Nome do ECS Cluster (ex: rio-cluster): " CLUSTER_NAME

# se cluster existe 
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
