# inputs necessários para montar a API e integrar com a Lambda
variable "api_name" { type = string }
variable "region" { type = string }
variable "lambda_invoke_arn" { type = string } # de module.lambda_func.invoke_arn, 
# necessário para integração com o API Gateway
variable "lambda_function_name" { type = string } # de module.lambda_func.function_name

#Bursts e Rate limits do API Gateway
variable "throttle_burst" {
  type    = number
  default = 50
}
variable "throttle_rate" {
  type    = number
  default = 100
}
variable "lambda_arn" {
  type        = string
  description = "ARN da função Lambda"
}
variable "logs_retention_days" {
  description = "Dias de retenção dos access logs do API Gateway"
  type        = number
  default     = 14
}

variable "api_gw_logs_role_name" {
  description = "Nome da role que o API Gateway usa para escrever no CloudWatch"
  type        = string
  default     = "apigw-cloudwatch-logs"
}
