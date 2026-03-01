# ====== Carregar env ======
source ../env/infra.env

aws rds create-db-instance \
  --region "$AWS_REGION" \
  --db-instance-identifier "$DB_ID" \
  --engine postgres \
  --engine-version "17.6" \
  --db-instance-class "db.t3.micro" \
  --allocated-storage 20 \
  --storage-type gp3 \
  --db-name "$DB_NAME" \
  --master-username "$DB_USER" \
  --master-user-password "$DB_PASS" \
  --vpc-security-group-ids "SSG_DB" \
  --db-subnet-group-name "$SUBNET_GROUP" \
  --backup-retention-period 0 \
  --no-publicly-accessible \
  --deletion-protection
