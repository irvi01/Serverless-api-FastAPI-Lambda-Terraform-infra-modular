# Configuração do backend para o Terraform
# Aqui usamos o S3 como backend para armazenar o estado do Terraform
terraform {
  backend "s3" {
    bucket         = "desafio-tfstate-irvi-1755189166"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "desafio-tf-locks"
    encrypt        = true
  }
}
