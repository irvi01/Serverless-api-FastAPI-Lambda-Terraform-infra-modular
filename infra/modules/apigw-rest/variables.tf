# inputs necessários para montar a API e integrar com a Lambda
variable "api_name" { type = string }
variable "region" { type = string }
variable "lambda_invoke_arn" { type = string } # de module.lambda_func.invoke_arn, 
# necessário para integração com o API Gateway
variable "lambda_function_name" { type = string } # de module.lambda_func.function_name
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
