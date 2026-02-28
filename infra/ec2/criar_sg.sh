#!/usr/bin/env bash
set -euo pipefail

# ===== Defaults =====
AWS_REGION="${AWS_REGION:-}"
VPC_ID="${VPC_ID:-}"

[[ -z "$AWS_REGION" ]] && read -rp "Região AWS (ex: us-east-1): " AWS_REGION
[[ -z "$VPC_ID" ]] && read -rp "VPC ID (ex: vpc-xxxx): " VPC_ID

read -rp "Nome do Security Group: " SG_NAME
read -rp "Descrição do SG: " SG_DESC

echo
echo "== Criando Security Group =="

SG_ID=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "$SG_DESC" \
  --vpc-id "$VPC_ID" \
  --region "$AWS_REGION" \
  --query 'GroupId' \
  --output text)

echo
read -rp "Deseja adicionar regra de entrada? (y/n): " ADD_RULE

if [[ "$ADD_RULE" == "y" ]]; then
  read -rp "Protocolo (tcp/udp): " PROTOCOL
  read -rp "Porta: " PORT
  read -rp "Source-group (ex: sg-ec2): " SG_GP

  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol "$PROTOCOL" \
    --port "$PORT" \
    --source-group "$SG_GP" \
    --region "$AWS_REGION"

  echo "Regra adicionada."
fi

echo
echo "SG Criado: $SG_ID"
