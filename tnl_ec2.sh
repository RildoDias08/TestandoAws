
aws ssm start-session --target "${ID_INSTANCIA}" \
--document-name AWS-StartPortForwardingSession \
--parameters '{"portNumber":["3002"],"localPortNumber":["3003"]}' --profile "${AWS_PROFILE}"
