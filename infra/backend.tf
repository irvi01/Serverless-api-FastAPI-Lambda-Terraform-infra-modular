# Configuração do backend para o Terraform
# Aqui usamos o S3 como backend para armazenar o estado do Terraform
terraform {
  backend "s3" {
    bucket         = "challenge-entrevista"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "desafio-tf-locks"
    encrypt        = true
  }
}
