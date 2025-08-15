#URLs de acesso ao API Gateway e API Key (sensível)
output "api_url" {
  value = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}

# API Key (sensível)
output "api_key" {
  value     = aws_api_gateway_api_key.key.value
  sensitive = true
}

output "rest_api_id" { value = aws_api_gateway_rest_api.this.id } # ID do API Gateway

output "stage_name" { value = aws_api_gateway_stage.prod.stage_name } # Nome do stage (prod)
