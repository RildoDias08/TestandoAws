#!/usr/bin/env bash
set -euo pipefail

read -rp "Nome do ECS Cluster (ex: rio-cluster): " CLUSTER

read -rp "Nome do ECS Service (ex: rio-service): " SERVICE

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --force-new-deployment --desired-count 2

aws ecs wait services-stable \
  --cluster "$CLUSTER" \
  --services "$SERVICE"

echo "OK: service está estável."
