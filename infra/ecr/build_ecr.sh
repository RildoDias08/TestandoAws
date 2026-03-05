#!/usr/bin/env bash
set -euo pipefail

source ../env/infra.env

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

read -rp "Nome do repo (ex: bia): " REPO
read -rp "Nome da iamgem (ex: bia): " NAME_IMG


echo "🔐 Login no ECR..."
aws ecr get-login-password --region "$AWS_REGION" \
| docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "🏗️ Build..."
docker build -t "$NAME_IMG" .

echo "🏷️ Tag..."
docker tag "$REPO:latest" "$ECR_REGISTRY/$REPO:latest"

echo "🚀 Push..."
docker push "$ECR_REGISTRY/$REPO:latest"

echo "✅ Imagem enviada!"
