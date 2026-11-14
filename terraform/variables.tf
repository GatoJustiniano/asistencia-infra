# Los valores de un tenant los genera el worker de la plataforma a partir del
# formulario y de catalogo/planes.json (ver ejemplos/*.tfvars.json).

variable "aws_account_id" {
  description = "Solo se permite desplegar en esta cuenta"
  type        = string
  default     = "207381449073"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "motor" {
  description = "Binario que aplica la plantilla (terraform u opentofu); queda como tag"
  type        = string
  default     = "terraform"
  validation {
    condition     = contains(["terraform", "opentofu"], var.motor)
    error_message = "motor debe ser terraform u opentofu."
  }
}

# ---------- Identidad del tenant ----------

variable "tenant_id" {
  description = "Identificador único (subdominio): minúsculas, números y guiones"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$", var.tenant_id))
    error_message = "tenant_id: de 3 a 30 caracteres, minúsculas, números y guiones, sin guion al inicio ni al final."
  }
}

variable "entorno" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "qa", "prod"], var.entorno)
    error_message = "entorno debe ser dev, qa o prod."
  }
}

variable "plan" {
  type = string
  validation {
    condition     = contains(["basico", "estandar", "avanzado"], var.plan)
    error_message = "plan debe ser basico, estandar o avanzado."
  }
}

# ---------- Recursos del plan (vienen de catalogo/planes.json) ----------

variable "instance_type" {
  type = string
}

variable "root_volume_gb" {
  type    = number
  default = 8
}

variable "data_volume_gb" {
  type = number
}

variable "limites" {
  description = "Límites de uso del plan; se pasan a la app como variables de entorno"
  type = object({
    estudiantes = number
    docentes    = number
    cursos      = number
  })
}

# ---------- Ciclo de vida ----------

variable "suspendido" {
  description = "true detiene la EC2 y conserva el volumen de datos (RF-16, RF-17)"
  type        = bool
  default     = false
}

# ---------- Aplicación ----------

variable "app_repo_url" {
  type    = string
  default = "https://github.com/GatoJustiniano/asistencia-app.git"
}

variable "app_version" {
  description = "Tag o rama de asistencia-app que se instala"
  type        = string
  default     = "main"
}

variable "ami_id" {
  description = "AMI fija; null usa la AMI de Packer más reciente (tag Rol=ami-tenant) o, si no hay, Amazon Linux 2023"
  type        = string
  default     = null
}

variable "nombre" {
  description = "Nombre de la institución: la app lo muestra como título. Vacío = \"Asistencia\"."
  type        = string
  default     = ""
  validation {
    condition     = length(var.nombre) <= 120
    error_message = "El nombre no puede pasar de 120 caracteres."
  }
}

variable "snapshot_datos" {
  description = "Solo para restaurar: snapshot (snap-...) del que se crea el volumen de datos, junto con -replace=module.tenant.aws_ebs_volume.datos"
  type        = string
  default     = null
  validation {
    condition     = var.snapshot_datos == null || can(regex("^snap-[0-9a-f]{8,17}$", var.snapshot_datos))
    error_message = "snapshot_datos debe ser un id de snapshot (snap-...)."
  }
}

variable "limite_permisos" {
  description = "Nombre de la política IAM que se usa como permissions boundary del rol del tenant (la crea plataforma-tenants/infra/plataforma). Vacío = sin límite."
  type        = string
  default     = "asistencia-limite-tenant"
}

variable "demo_data" {
  description = "Carga los datos de ejemplo si la base está vacía"
  type        = bool
  default     = true
}
