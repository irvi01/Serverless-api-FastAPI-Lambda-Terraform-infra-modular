#Outputs da função Lambda
#Esses outputs são úteis para referenciar a função Lambda em outros módulos ou recursos

# Nome da função Lambda
output "function_name" {
  description = "Nome da função Lambda"
  value       = aws_lambda_function.this.function_name
}

# ARN da função Lambda
output "invoke_arn" {
  description = "Invoke ARN da Lambda (usado pelo API Gateway)"
  value       = aws_lambda_function.this.invoke_arn
}

# ARN completo da função Lambda
output "lambda_arn" {
  description = "ARN completo da Lambda"
  value       = aws_lambda_function.this.arn
}
