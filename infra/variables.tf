# infra/variables.tf

#Região da AWS
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

#nome da função Lambda
variable "lambda_name" {
  description = "Nome da função Lambda"
  type        = string
  default     = "challenge-api"
}

#caminho do arquivo ZIP do código da Lambda
variable "package_zip" {
  description = "Caminho do package.zip gerado pelo script"
  type        = string
  default     = "../package.zip" # relativo à pasta infra
}

#quantidade de memória alocada para a Lambda
variable "memory_mb" {
  description = "Memória da Lambda (MB)"
  type        = number
  default     = 256
}

#tempo limite da função Lambda
variable "timeout_sec" {
  description = "Timeout da Lambda (segundos)"
  type        = number
  default     = 10
}
