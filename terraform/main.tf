provider "aws" {
  region              = var.region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = {
      Proyecto    = "asistencia"
      Componente  = "tenant"
      Tenant      = var.tenant_id
      Entorno     = var.entorno
      Plan        = var.plan
      Herramienta = var.motor
    }
  }
}

# ---------- Recursos compartidos (los crea plataforma-tenants/infra/red) ----------

data "aws_vpc" "compartida" {
  tags = { Rol = "red-tenants" }
}

data "aws_subnets" "publicas" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.compartida.id]
  }
  tags = { Tipo = "publica" }
}

data "aws_security_group" "plataforma" {
  vpc_id = data.aws_vpc.compartida.id
  tags   = { Rol = "sg-plataforma" }
}

locals {
  subredes = sort(data.aws_subnets.publicas.ids)
  # Reparte los tenants entre las subredes de forma estable (siempre la misma para el mismo id)
  subnet_id = local.subredes[parseint(substr(md5(var.tenant_id), 0, 4), 16) % length(local.subredes)]
}

module "tenant" {
  source = "./modules/tenant"

  tenant_id      = var.tenant_id
  entorno        = var.entorno
  plan           = var.plan
  region         = var.region
  vpc_id         = data.aws_vpc.compartida.id
  subnet_id      = local.subnet_id
  sg_plataforma  = data.aws_security_group.plataforma.id
  instance_type  = var.instance_type
  root_volume_gb = var.root_volume_gb
  data_volume_gb = var.data_volume_gb
  limites        = var.limites
  suspendido     = var.suspendido
  app_repo_url   = var.app_repo_url
  app_version    = var.app_version
  ami_id         = var.ami_id
  demo_data      = var.demo_data
  cloud_init     = "${path.module}/../cloud-init/cloud-init.yaml"
}
