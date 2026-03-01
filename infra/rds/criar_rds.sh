# ====== Carregar env ======
ENV_FILE="${ENV_FILE:-../env/infra.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Não encontrei $ENV_FILE"
  echo "Crie a partir do exemplo: infra/env/infra.env.example"
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_FILE"


aws rds create-db-instance \
  --region "$AWS_REGION" \
  --db-instance-identifier "$DB_ID" \
  --engine postgres \
  --engine-version "17.6-R2" \
  --db-instance-class "db.t3.micro" \
  --allocated-storage 20 \
  --storage-type gp3 \
  --db-name "$DB_NAME" \
  --master-username "$DB_USER" \
  --master-user-password "$DB_PASS" \
  --vpc-security-group-ids "$DB_SG_ID" \
  --db-subnet-group-name "$SUBNET_ID_A" \
  --backup-retention-period 0 \
  --no-publicly-accessible \
  --deletion-protection
