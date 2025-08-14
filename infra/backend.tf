# Configuração do backend para o Terraform
# Aqui usamos o S3 como backend para armazenar o estado do Terraform
terraform {
  backend "s3" {}
}
