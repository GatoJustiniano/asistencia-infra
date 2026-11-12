terraform {
  # 1.10+ por el lock nativo de S3 (use_lockfile). Sirve igual para OpenTofu 1.10+.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Configuración parcial: cada tenant pasa su propia clave al hacer init:
  #   terraform init -reconfigure -backend-config="key=tenants/<tenant_id>/terraform.tfstate"
  backend "s3" {
    bucket       = "asistencia-iac-estado-207381449073"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
