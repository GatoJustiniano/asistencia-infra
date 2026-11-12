# AMI base de los tenants: Amazon Linux 2023 + Node.js + herramientas de compilación
# + node_exporter. No contiene datos ni secretos de ningún tenant: lo propio de cada
# uno (volumen, clave, versión de la app) lo hace cloud-init al arrancar.
#
#   packer init .
#   packer build .

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.3"
    }
  }
}

locals {
  fecha = formatdate("YYYYMMDD-hhmm", timestamp())
}

source "amazon-ebs" "tenant" {
  region          = var.region
  instance_type   = var.instance_type
  ami_name        = "asistencia-tenant-${local.fecha}"
  ami_description = "Base de tenants del Sistema de Asistencia (AL2023, Node.js, node_exporter ${var.node_exporter_version})"

  source_ami_filter {
    owners      = ["amazon"]
    most_recent = true
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
  }

  # Se construye en la red compartida de los tenants (la crea plataforma-tenants/infra/red)
  vpc_filter {
    filters = { "tag:Rol" = "red-tenants" }
  }
  subnet_filter {
    filters   = { "tag:Tipo" = "publica" }
    most_free = true
  }
  associate_public_ip_address = true
  # SG temporal con SSH abierto solo a la IP pública de quien ejecuta Packer
  temporary_security_group_source_public_ip = true
  ssh_username                              = "ec2-user"

  imds_support = "v2.0"
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # Terraform busca la AMI más reciente con Rol = ami-tenant
  tags = {
    Name         = "asistencia-tenant-${local.fecha}"
    Proyecto     = "asistencia"
    Rol          = "ami-tenant"
    Base         = "{{ .SourceAMIName }}"
    NodeExporter = var.node_exporter_version
    CacheApp     = var.app_version
    Herramienta  = "packer"
  }
  snapshot_tags = {
    Proyecto = "asistencia"
    Rol      = "ami-tenant"
  }
  run_tags = {
    Name       = "packer-asistencia-tenant"
    Proyecto   = "asistencia"
    Componente = "packer"
  }
}

build {
  sources = ["source.amazon-ebs.tenant"]

  provisioner "shell" {
    script          = "${path.root}/scripts/base.sh"
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    environment_vars = [
      "NODE_EXPORTER_VERSION=${var.node_exporter_version}",
      "APP_REPO_URL=${var.app_repo_url}",
      "APP_VERSION=${var.app_version}",
    ]
  }

  # Deja constancia de qué se construyó (RF-13: versiones usadas)
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
