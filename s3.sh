function envio_s3(){
	echo "Iniciando envio para o S3..."
	echo ""
	aws s3 sync ./client/dist/ s3://front-rio-aws --profile bia --delete
	echo "Envio finalizado com sucesso!"
}
envio_s3
