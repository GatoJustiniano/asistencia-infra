# Todo lo que pertenece a UN tenant: SG, secreto en SSM, rol IAM, volumen de datos y EC2.
# Ningún recurso se comparte con otro tenant.

locals {
  prefijo     = "asistencia-${var.tenant_id}"
  ssm_prefijo = "/asistencia/${var.tenant_id}"
}

data "aws_caller_identity" "actual" {}

data "aws_subnet" "elegida" {
  id = var.subnet_id
}

# AMI de Packer más reciente (packer/); si todavía no hay ninguna, Amazon Linux 2023
data "aws_ami_ids" "packer" {
  owners = ["self"]
  filter {
    name   = "tag:Rol"
    values = ["ami-tenant"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ---------- Red: Security Group propio ----------

resource "aws_security_group" "tenant" {
  name        = "${local.prefijo}-sg"
  description = "Tenant ${var.tenant_id}: HTTP publico; metricas y SSH solo desde la plataforma"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.prefijo}-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.tenant.id
  description       = "App web"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "desde_plataforma" {
  for_each = {
    ssh           = 22   # Ansible
    node_exporter = 9100 # Prometheus: CPU, memoria, disco
    app_metricas  = 9101 # Prometheus: métricas de la app (peticiones, 5xx, latencia, BD)
  }
  security_group_id            = aws_security_group.tenant.id
  description                  = each.key
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  referenced_security_group_id = var.sg_plataforma
}

resource "aws_vpc_security_group_egress_rule" "todo" {
  security_group_id = aws_security_group.tenant.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------- Secretos: SSM Parameter Store ----------

resource "random_password" "admin_key" {
  length  = 20
  special = false
}

resource "aws_ssm_parameter" "admin_key" {
  name        = "${local.ssm_prefijo}/admin-key"
  description = "Clave del panel docente del tenant ${var.tenant_id}"
  type        = "SecureString"
  value       = random_password.admin_key.result
}

# ---------- IAM: la instancia solo puede leer SUS parámetros ----------

resource "aws_iam_role" "tenant" {
  name = "${local.prefijo}-rol"
  # Techo de permisos: el worker de la plataforma solo puede crear roles con este límite
  permissions_boundary = var.limite_permisos == "" ? null : "arn:aws:iam::${data.aws_caller_identity.actual.account_id}:policy/${var.limite_permisos}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "leer_ssm_propio" {
  name = "leer-ssm-propio"
  role = aws_iam_role.tenant.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParametersByPath"]
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.actual.account_id}:parameter${local.ssm_prefijo}/*"
    }]
  })
}

# Session Manager: acceso de diagnóstico sin abrir SSH a internet
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.tenant.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "tenant" {
  name = "${local.prefijo}-perfil"
  role = aws_iam_role.tenant.name
}

# ---------- Datos: volumen EBS propio (SQLite) ----------

resource "aws_ebs_volume" "datos" {
  availability_zone = data.aws_subnet.elegida.availability_zone
  size              = var.data_volume_gb
  type              = "gp3"
  encrypted         = true
  tags              = { Name = "${local.prefijo}-datos" }
}

# ---------- Cómputo ----------

resource "aws_instance" "app" {
  # aws_ami_ids devuelve las AMIs de la más nueva a la más antigua
  ami                    = coalesce(var.ami_id, try(data.aws_ami_ids.packer.ids[0], null), data.aws_ami.al2023.id)
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.tenant.id]
  iam_instance_profile   = aws_iam_instance_profile.tenant.name

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  root_block_device {
    volume_size = var.root_volume_gb
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile(var.cloud_init, {
    TenantId       = var.tenant_id
    Entorno        = var.entorno
    Plan           = var.plan
    Region         = var.region
    SsmPrefijo     = local.ssm_prefijo
    VolumenDatos   = aws_ebs_volume.datos.id
    AppRepoUrl     = var.app_repo_url
    AppVersion     = var.app_version
    DemoData       = var.demo_data
    MaxEstudiantes = var.limites.estudiantes
    MaxDocentes    = var.limites.docentes
    MaxCursos      = var.limites.cursos
    InstitucionB64 = base64encode(var.nombre)
  })
  # Los datos viven en el EBS, así que recrear la instancia (p. ej. al cambiar
  # app_version) no pierde información.
  user_data_replace_on_change = true

  tags = { Name = "${local.prefijo}-app" }

  lifecycle {
    # Una AMI nueva se usa en los tenants nuevos y cuando la instancia se recrea
    # (p. ej. al cambiar app_version); no reemplaza por sí sola a los que ya existen.
    ignore_changes = [ami]
  }

  # El rol debe poder leer SSM antes de que arranque cloud-init
  depends_on = [aws_iam_role_policy.leer_ssm_propio, aws_ssm_parameter.admin_key]
}

resource "aws_volume_attachment" "datos" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.datos.id
  instance_id = aws_instance.app.id
  # Detiene la instancia antes de desmontar el volumen (evita corromper SQLite)
  stop_instance_before_detaching = true
}

# Suspender / reanudar sin destruir nada
resource "aws_ec2_instance_state" "app" {
  instance_id = aws_instance.app.id
  state       = var.suspendido ? "stopped" : "running"
  depends_on  = [aws_volume_attachment.datos]
}
