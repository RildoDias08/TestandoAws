#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../env/infra.env"
source "${SCRIPT_DIR}/.ecs.env"

AWS_REGION="${AWS_REGION:-$(aws configure get region)}"
: "${AWS_REGION:?AWS_REGION não definido}"
: "${VPC_ID:?VPC_ID não definido}"
: "${ALB_SUBNET_IDS:?ALB_SUBNET_IDS não definido no infra.env}"
: "${CERT_ARN:?CERT_ARN não definido no infra.env}"

read -rp "Nome do ALB:" ALB_NAME
read -rp "Nome do Target Group (ex: meuapp-tg): " TG_NAME
read -rp "Nome do SG do ALB (ex: meuapp-sgalb): " ALB_SG_NAME

APP_PORT="${APP_PORT:-3002}"
HEALTH_PATH="${HEALTH_PATH:-/}"
HEALTH_CODES="${HEALTH_CODES:-200-399}"


echo "==> Região:       $AWS_REGION"
echo "==> VPC:          $VPC_ID"
echo "==> ALB:          $ALB_NAME"
echo "==> TG:           $TG_NAME"
echo "==> ALB subnets:  $ALB_SUBNET_IDS"
echo "==> Porta target: $APP_PORT"
echo "==> Health path:  $HEALTH_PATH"
echo

# 1) SG do ALB (80/443 do mundo)
ALB_SG_ID="$(
  aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --filters Name=vpc-id,Values="$VPC_ID" Name=group-name,Values="$ALB_SG_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || true
)"

if [[ -z "${ALB_SG_ID}" || "${ALB_SG_ID}" == "None" ]]; then
  echo "[CREATE] SG do ALB..."
  ALB_SG_ID="$(aws ec2 create-security-group \
    --region "$AWS_REGION" \
    --vpc-id "$VPC_ID" \
    --group-name "$ALB_SG_NAME" \
    --description "SG do ALB do backend (80/443 público)" \
    --query "GroupId" \
    --output text)"
  aws ec2 create-tags --region "$AWS_REGION" --resources "$ALB_SG_ID" \
    --tags Key=Project,Value=rio-aws Key=ManagedBy,Value=awscli >/dev/null
else
  echo "[OK] SG do ALB já existe: $ALB_SG_ID"
fi

# Ingress 80/443
aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$ALB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0,Description='HTTP'}]" \
  >/dev/null 2>&1 || true

aws ec2 authorize-security-group-ingress --region "$AWS_REGION" --group-id "$ALB_SG_ID" \
  --ip-permissions "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description='HTTPS'}]" \
  >/dev/null 2>&1 || true

echo "[OK] Regras do SG do ALB garantidas."
echo

# 2) Target Group (target-type ip para Fargate)
TG_ARN="$(
  aws elbv2 describe-target-groups \
    --region "$AWS_REGION" \
    --names "$TG_NAME" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text 2>/dev/null || true
)"

if [[ -z "${TG_ARN}" || "${TG_ARN}" == "None" ]]; then
  echo "[CREATE] Target Group..."
  TG_ARN="$(aws elbv2 create-target-group \
    --region "$AWS_REGION" \
    --name "$TG_NAME" \
    --protocol HTTP \
    --port "$APP_PORT" \
    --vpc-id "$VPC_ID" \
    --target-type ip \
    --health-check-protocol HTTP \
    --health-check-path "$HEALTH_PATH" \
    --matcher "HttpCode=${HEALTH_CODES}" \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)"
  echo "[OK] TG criado: $TG_ARN"
else
  echo "[OK] TG já existe: $TG_ARN"
fi
echo

# 3) ALB
ALB_ARN="$(
  aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --names "$ALB_NAME" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text 2>/dev/null || true
)"

if [[ -z "${ALB_ARN}" || "${ALB_ARN}" == "None" ]]; then
  echo "[CREATE] ALB..."
  ALB_ARN="$(aws elbv2 create-load-balancer \
    --region "$AWS_REGION" \
    --name "$ALB_NAME" \
    --type application \
    --scheme internet-facing \
    --subnets $(echo "$ALB_SUBNET_IDS") \
    --security-groups "$ALB_SG_ID" \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)"
  echo "[OK] ALB criado: $ALB_ARN"
else
  echo "[OK] ALB já existe: $ALB_ARN"
fi

ALB_DNS="$(aws elbv2 describe-load-balancers \
  --region "$AWS_REGION" \
  --load-balancer-arns "$ALB_ARN" \
  --query "LoadBalancers[0].DNSName" \
  --output text)"

echo "[OK] ALB DNS: $ALB_DNS"
echo

# 4) Listener 80 -> redirect 443
HTTP_LISTENER_ARN="$(
  aws elbv2 describe-listeners \
    --region "$AWS_REGION" \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[?Port==\`80\`].ListenerArn | [0]" \
    --output text 2>/dev/null || true
)"

if [[ -z "${HTTP_LISTENER_ARN}" || "${HTTP_LISTENER_ARN}" == "None" ]]; then
  echo "[CREATE] Listener 80 (redirect para 443)..."
  aws elbv2 create-listener \
    --region "$AWS_REGION" \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=redirect,RedirectConfig="{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}" \
    >/dev/null
  echo "[OK] Listener 80 criado."
else
  echo "[OK] Listener 80 já existe."
fi

# 5) Listener 443 -> forward TG
HTTPS_LISTENER_ARN="$(
  aws elbv2 describe-listeners \
    --region "$AWS_REGION" \
    --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[?Port==\`443\`].ListenerArn | [0]" \
    --output text 2>/dev/null || true
)"

if [[ -z "${HTTPS_LISTENER_ARN}" || "${HTTPS_LISTENER_ARN}" == "None" ]]; then
  echo "[CREATE] Listener 443 (forward para TG)..."
  aws elbv2 create-listener \
    --region "$AWS_REGION" \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTPS \
    --port 443 \
    --certificates CertificateArn="$CERT_ARN" \
    --ssl-policy ELBSecurityPolicy-2016-08 \
    --default-actions Type=forward,TargetGroupArn="$TG_ARN" \
    >/dev/null
  echo "[OK] Listener 443 criado."
else
  echo "[OK] Listener 443 já existe."
fi

# 6) Persistir outputs no .ecs.env
tmp_env="/tmp/.ecs.env.$$"
grep -vE '^(ALB_NAME|ALB_ARN|ALB_DNS|ALB_SG_ID|TG_NAME|TG_ARN)=' "${SCRIPT_DIR}/.ecs.env" > "$tmp_env" || true
cat >> "$tmp_env" <<OUT
ALB_NAME=${ALB_NAME}
ALB_ARN=${ALB_ARN}
ALB_DNS=${ALB_DNS}
ALB_SG_ID=${ALB_SG_ID}
TG_NAME=${TG_NAME}
TG_ARN=${TG_ARN}
OUT
mv "$tmp_env" "${SCRIPT_DIR}/.ecs.env"

echo
echo "==> Outputs salvos em infra/ecs/.ecs.env"
echo "ALB_DNS: $ALB_DNS"
