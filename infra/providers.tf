terraform {
  required_version = ">= 1.6.0" # trava versão mínima do Terraform
  required_providers {
    aws = {
      source  = "hashicorp/aws" # provider oficial
      version = "~> 5.60"       # faixa compatível, evita quebrar com major
    }
  }
}

provider "aws" {
  region = var.region # vem de variables.tf
}
