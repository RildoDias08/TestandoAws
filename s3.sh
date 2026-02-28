#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

envio_s3 () {
	echo "iniciando envio para o s3..."

	if [ -z "${S3_BUCKET:-}" ]; then
		echo "S3_BUCKET nao definido. Exemplo: S3_BUCKET=meu-bucket-frontend"
		exit 1
	fi

	BUILD_DIR="$ROOT_DIR/client/dist"
	if [ ! -d "$BUILD_DIR" ]; then
		echo "build nao encontrado em $BUILD_DIR. Rode o build primeiro."
		exit 1
	fi

	if [ -n "${AWS_PROFILE:-}" ]; then
		aws s3 sync "$BUILD_DIR/" "s3://${S3_BUCKET}" --delete --profile "$AWS_PROFILE"
	else
		aws s3 sync "$BUILD_DIR/" "s3://${S3_BUCKET}" --delete
	fi

	echo "envio concluido com sucesso"
}

envio_s3
