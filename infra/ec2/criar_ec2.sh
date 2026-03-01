# Em breve

#!/usr/bin/env bash
set -euo pipefail

# ====== Carregar env ======
ENV_FILE="${ENV_FILE:-../env/infra.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Não encontrei $ENV_FILE"
  echo "Crie a partir do exemplo: infra/env/infra.env.example"
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

# ====== Defaults / obrigatórios via env ======
AWS_PROFILE="${AWS_PROFILE}"

AWS_REGION="${AWS_REGION:?AWS_REGION não definido no infra.env}"
INSTANCE_TYPE="${INSTANCE_TYPE:?INSTANCE_TYPE não definido no infra.env}"
VOLUME_SIZE="${VOLUME_SIZE:-15}"
AMI_ID="${AMI_ID:?AMI Não definido no infra.env}"  # pode ser vazio

# ====== Perguntar o que você quer ======
read -rp "Nome da instância (tag Name): " TAG_NAME
read -rp "IAM Instance Profile (role p/ SSM) (ex: role-acesso-ssm): " IAM_INSTANCE_PROFILE

if [[ -z "$TAG_NAME" ]]; then
  echo "❌ Nome da instância não pode ser vazio."
  exit 1
fi
if [[ -z "$IAM_INSTANCE_PROFILE" ]]; then
  echo "❌ IAM Instance Profile não pode ser vazio (SSM depende disso)."
  exit 1
fi

# ====== Credenciais ======
echo "== Verificando credenciais (profile: $AWS_PROFILE) =="
aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null
echo "✅ OK"
echo


# ---------- VPCs ----------
echo "== Listando VPCs na região $AWS_REGION =="
# Lista VPCs (JSON) e monta arrays só com VpcId
VPCS_JSON=$(aws ec2 describe-vpcs \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query "Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,Name:Tags[?Key=='Name']|[0].Value,Default:IsDefault}" \
  --output json)

# Arrays com IDs (sem risco)
mapfile -t VPC_IDS < <(jq -r '.[]?.VpcId' <<< "$VPCS_JSON")

if [[ ${#VPC_IDS[@]} -eq 0 ]]; then
  echo "❌ Nenhuma VPC encontrada."
  exit 1
fi

echo "== VPCs =="
for i in "${!VPC_IDS[@]}"; do
  vpc_id="${VPC_IDS[$i]}"
  cidr=$(jq -r --arg id "$vpc_id" '.[] | select(.VpcId==$id) | .Cidr' <<< "$VPCS_JSON")
  name=$(jq -r --arg id "$vpc_id" '.[] | select(.VpcId==$id) | (.Name // "-")' <<< "$VPCS_JSON")
  def=$(jq -r --arg id "$vpc_id" '.[] | select(.VpcId==$id) | .Default' <<< "$VPCS_JSON")
  printf "[%d] %s | CIDR: %s | Name: %s | Default: %s\n" "$((i+1))" "$vpc_id" "$cidr" "$name" "$def"
done

read -rp "Escolha a VPC (número): " VPC_CHOICE
if ! [[ "$VPC_CHOICE" =~ ^[0-9]+$ ]] || (( VPC_CHOICE < 1 || VPC_CHOICE > ${#VPC_IDS[@]} )); then
  echo "❌ Opção inválida."
  exit 1
fi

VPC_ID="${VPC_IDS[$((VPC_CHOICE-1))]}"
echo "✅ VPC selecionada: $VPC_ID"

# ---------- Subnets ----------
echo "== Listando Subnets da VPC $VPC_ID =="
SUBNETS_JSON=$(aws ec2 describe-subnets \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "Subnets[].{SubnetId:SubnetId,Cidr:CidrBlock,Az:AvailabilityZone,Public:MapPublicIpOnLaunch,Name:Tags[?Key=='Name']|[0].Value}" \
  --output json)

mapfile -t SUBNET_IDS < <(jq -r '.[]?.SubnetId' <<< "$SUBNETS_JSON")

if [[ ${#SUBNET_IDS[@]} -eq 0 ]]; then
  echo "❌ Nenhuma subnet encontrada nessa VPC."
  exit 1
fi

echo "== Subnets =="
for i in "${!SUBNET_IDS[@]}"; do
  sid="${SUBNET_IDS[$i]}"
  cidr=$(jq -r --arg id "$sid" '.[] | select(.SubnetId==$id) | .Cidr' <<< "$SUBNETS_JSON")
  az=$(jq -r --arg id "$sid" '.[] | select(.SubnetId==$id) | .Az' <<< "$SUBNETS_JSON")
  pub=$(jq -r --arg id "$sid" '.[] | select(.SubnetId==$id) | .Public' <<< "$SUBNETS_JSON")
  name=$(jq -r --arg id "$sid" '.[] | select(.SubnetId==$id) | (.Name // "-")' <<< "$SUBNETS_JSON")
  stype="privada?"
  [[ "$pub" == "true" || "$pub" == "True" ]] && stype="publica?"
  printf "[%d] %s | CIDR: %s | AZ: %s | %s | Name: %s\n" "$((i+1))" "$sid" "$cidr" "$az" "$stype" "$name"
done

read -rp "Escolha a Subnet (número): " SUBNET_CHOICE
if ! [[ "$SUBNET_CHOICE" =~ ^[0-9]+$ ]] || (( SUBNET_CHOICE < 1 || SUBNET_CHOICE > ${#SUBNET_IDS[@]} )); then
  echo "❌ Opção inválida."
  exit 1
fi

SUBNET_ID="${SUBNET_IDS[$((SUBNET_CHOICE-1))]}"
echo "✅ Subnet selecionada: $SUBNET_ID"

# ---------- Security Groups ----------
echo "== Listando Security Groups da VPC $VPC_ID =="

SGS_JSON=$(aws ec2 describe-security-groups \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query "SecurityGroups[].{GroupId:GroupId,GroupName:GroupName,Desc:Description}" \
  --output json)

mapfile -t SG_IDS < <(jq -r '.[].GroupId' <<< "$SGS_JSON")

if [[ ${#SG_IDS[@]} -eq 0 ]]; then
  echo "❌ Nenhum SG encontrado nessa VPC."
  exit 1
fi

for i in "${!SG_IDS[@]}"; do
  sg_id="${SG_IDS[$i]}"
  sg_name=$(jq -r --arg id "$sg_id" '.[] | select(.GroupId==$id) | .GroupName' <<< "$SGS_JSON")
  sg_desc=$(jq -r --arg id "$sg_id" '.[] | select(.GroupId==$id) | .Desc' <<< "$SGS_JSON")
  printf "[%d] %s | Name: %s | Desc: %s\n" "$((i+1))" "$sg_id" "$sg_name" "$sg_desc"
done

echo
read -rp "Escolha o Security Group (número): " SG_CHOICE
if ! [[ "$SG_CHOICE" =~ ^[0-9]+$ ]] || (( SG_CHOICE < 1 || SG_CHOICE > ${#SG_IDS[@]} )); then
  echo "❌ Opção inválida."
  exit 1
fi

SECURITY_GROUP_ID="${SG_IDS[$((SG_CHOICE-1))]}"
echo "✅ SG selecionado: $SECURITY_GROUP_ID"
echo

# ---------- AMI ----------
if [[ -z "$AMI_ID" ]]; then
  echo "== AMI_ID vazio no env; buscando Amazon Linux 2023 via SSM =="
  AMI_ID=$(aws ssm get-parameter \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64" \
    --query "Parameter.Value" --output text)
fi
echo "AMI: $AMI_ID"
echo

# ---------- Run instances ----------
echo "== Criando EC2 =="
INSTANCE_ID=$(aws ec2 run-instances \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":$VOLUME_SIZE,\"VolumeType\":\"gp3\"}}]" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG_NAME}]" \
  --iam-instance-profile "Name=$IAM_INSTANCE_PROFILE" \
  --user-data "fileb://user_data_ec2.sh" \
  --query "Instances[0].InstanceId" --output text)

echo "✅ InstanceId: $INSTANCE_ID"

aws ec2 wait instance-running \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

echo
echo "==== RESULTADO ===="
echo "InstanceId: $INSTANCE_ID"
echo "Public IP : $PUBLIC_IP"
echo "VPC       : $VPC_ID"
echo "Subnet    : $SUBNET_ID"
echo "SG        : $SECURITY_GROUP_ID"
echo "Role      : $IAM_INSTANCE_PROFILE"
