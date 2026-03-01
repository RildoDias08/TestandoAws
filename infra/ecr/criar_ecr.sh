source ../env/infra.env

read -rp "Nome do repositório ECR (ex: testandoaws-backend): " ECR_REPO

if [ -z "$ECR_REPO" ]; then
  echo "❌ Nome do repositório não pode ser vazio"
  exit 1
fi

aws ecr create-repository \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE"

echo "${ECR_REPO} criado com sucesso!"
