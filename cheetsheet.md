0) Exports rápidos 
# Pasta do Terraform
cd infra

# Região
export REGION=us-east-1

# Saídas do Terraform (URL e API Key)
export API_URL=$(terraform -chdir=infra output -raw api_url)
export API_KEY=$(terraform -chdir=infra output -raw api_key)

# ID do API Gateway (prefixo da URL)
export API_ID=$(echo "$API_URL" | sed -E 's#https://([^.]+)\..*#\1#')

# Nome do log group de Access Logs 
export APIGW_LOG_GROUP="/aws/apigateway/challenge-api-api/access"

1) Deploy / Infra

# Empacotar Lambda (gera package.zip na raiz)
chmod +x scripts/package.sh
./scripts/package.sh

# Plan e Apply
terraform plan  -var="region=$REGION" -var="package_zip=../package.zip"
terraform apply -auto-approve -var="region=$REGION" -var="package_zip=../package.zip"

# Outputs rápidos
terraform -chdir=infra output -raw api_url
terraform -chdir=infra output -raw api_key

2) Smoke tests

# 200 chamadas concorrentes; agrupa por status
seq 1 200 | xargs -P50 -n1 -I{} sh -c 'curl -s -o /dev/null -w "%{http_code}\n" \
  -H "x-api-key: '"$API_KEY"'" "'$API_URL'/health"' \
| sort | uniq -c

4) Rate limit do WAF (esperar 403)

# Confirmar o limite configurado no WAF (requests por IP/5min)
aws wafv2 get-web-acl-for-resource \
  --resource-arn arn:aws:apigateway:${REGION}::/restapis/${API_ID}/stages/prod \
  --region ${REGION} \
  --query 'WebACL.Rules[?Name==`RateLimitPerIP`].Statement.RateBasedStatement.Limit'

# Disparar 60 requisições simultâneas (deve bloquear a maioria com 403)
for i in $(seq 1 60); do
  curl -s -o /dev/null -w "%{http_code}\n" -H "x-api-key: $API_KEY" "$API_URL/health" &
done; wait

5) Access Logs (CloudWatch)

# Descobrir log groups de access
aws logs describe-log-groups --log-group-name-prefix "/aws/apigateway/" \
  --query 'logGroups[?contains(logGroupName, `access`)].logGroupName' --output text

# Tail ao vivo (10m)
aws logs tail "$APIGW_LOG_GROUP" --since 10m --follow

6) Conferências rápidas de configuração

# Stage do API Gateway (access logs + x-ray)
aws apigateway get-stage --rest-api-id "$API_ID" --stage-name prod --region "$REGION" \
  --query '{xray:xrayTracingEnabled, access:accessLogSettings}'

# Associação do WAF ao stage
aws wafv2 get-web-acl-for-resource \
  --resource-arn arn:aws:apigateway:${REGION}::/restapis/${API_ID}/stages/prod \
  --region ${REGION}

7) Latência/5xx (amostra rápida)
# 10 requisições em série com tempo
time for i in $(seq 1 10); do
  curl -s -o /dev/null -w "%{http_code} %{time_total}\n" -H "x-api-key: $API_KEY" "$API_URL/health"
done


8) Troubleshooting flash
# Últimos erros 4xx/5xx nos Access Logs (CLI simples)
aws logs filter-log-events \
  --log-group-name "$APIGW_LOG_GROUP" \
  --filter-pattern '" 4" || " 5"' --max-items 20

# Checar permissões da Lambda
aws lambda get-policy --function-name challenge-api || true

9) Destroy 

terraform destroy -auto-approve -var="region=$REGION" -var="package_zip=../package.zip"

10) Extras úteis

# Ajustar rate_limit do WAF via Terraform (ex.: 25)
# (edite var rate_limit no módulo ou variável e reaplique)
terraform apply -auto-approve -var="region=$REGION" -var="package_zip=../package.zip"

# Verificar chaves de API existentes
aws apigateway get-api-keys --include-values --region "$REGION" \
  --query 'items[].{name:name,id:id,enabled:enabled}' --output table
