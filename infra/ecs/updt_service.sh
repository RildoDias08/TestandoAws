#!/usr/bin/env bash
set -euo pipefail


read -rp "Nome do ECS Cluster (ex: rio-cluster): " CLUSTER
read -rp "Nome do ECS Service (ex: rio-service): " SERVICE
read -rp "Task family (ex: rio-backend): " FAMILY
read -rp "Desired count (ex: 2): " DESIRED

LATEST_TD_ARN="$(
  aws ecs list-task-definitions \
    --region "$AWS_REGION" \
    --family-prefix "$FAMILY" \
    --status ACTIVE \
    --sort DESC \
    --max-results 1 \
    --query "taskDefinitionArns[0]" \
    --output text
)"

echo "[INFO] Usando latest taskdef: $LATEST_TD_ARN"

aws ecs update-service \
  --region "$AWS_REGION" \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "$LATEST_TD_ARN" \
  --desired-count "$DESIRED" \
  --force-new-deployment


aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE"

echo "OK: service está estável."
