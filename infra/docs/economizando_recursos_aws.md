#parar RDS quando estiver fora
aws rds stop-db-instance --db-instance-identifier "$DB_ID"

#zerar tasks
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 0

#excluir ALB
ALB_ARN="$(aws elbv2 describe-load-balancers \
  --names "$ALB_NAME" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text)"

echo "$ALB_ARN"

aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
