#variavéis para criação da função Lambda

variable "lambda_name" { type = string } # nome da função Lambda
variable "runtime" {
  type    = string
  default = "python3.12" # runtime padrão
}
variable "memory_mb" {
  type    = number
  default = 256 # memória padrão em MB
}
variable "timeout_sec" {
  type    = number
  default = 10 # timeout padrão em segundos
}
variable "zip_file" { type = string } # caminho do package.zip (relativo ao root)
