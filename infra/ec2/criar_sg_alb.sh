#!/usr/bin/env bash
set -euo pipefail

# ===== Defaults =====
AWS_REGION="${AWS_REGION:-}"
VPC_ID="${VPC_ID:-}"

[[ -z "$AWS_REGION" ]] && read -rp "Região AWS (ex: us-east-1): " AWS_REGION
[[ -z "$VPC_ID" ]] && read -rp "VPC ID (ex: vpc-xxxx): " VPC_ID

read -rp "Nome do SG: " SG_NAME
read -rp "Descrição do SG: " SG_DESC

echo
echo "== Criando SG do ALB=="


ALB_SG_ID=$(aws ec2 create-security-group \
  --region "$AWS_REGION" \
  --vpc-id "$VPC_ID" \
  --group-name "$SG_NAME" \
  --description "$SG_DESC" \
  --query 'GroupId' --output text)
echo "SG Criado: $ALB_SG_ID"

# Inbound do ALB (HTTP/HTTPS)
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" \
  --group-id "$ALB_SG_ID" --protocol tcp --port 80  --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" \
  --group-id "$ALB_SG_ID" --protocol tcp --port 443 --cidr 0.0.0.0/0
