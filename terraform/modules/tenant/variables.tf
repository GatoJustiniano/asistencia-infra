variable "tenant_id" { type = string }
variable "entorno" { type = string }
variable "plan" { type = string }
variable "region" { type = string }

variable "vpc_id" { type = string }
variable "subnet_id" { type = string }

variable "sg_plataforma" {
  description = "SG de la EC2 de la plataforma: único origen permitido para métricas y SSH"
  type        = string
}

variable "instance_type" { type = string }
variable "root_volume_gb" { type = number }
variable "data_volume_gb" { type = number }

variable "limites" {
  type = object({
    estudiantes = number
    docentes    = number
    cursos      = number
  })
}

variable "suspendido" { type = bool }

variable "app_repo_url" { type = string }
variable "app_version" { type = string }

variable "ami_id" {
  type    = string
  default = null
}

variable "demo_data" { type = bool }

variable "nombre" {
  description = "Nombre de la institución (título de la app)"
  type        = string
  default     = ""
}

variable "limite_permisos" {
  description = "Nombre de la política de permissions boundary del rol; vacío = sin límite"
  type        = string
  default     = ""
}

variable "cloud_init" {
  description = "Ruta de la plantilla cloud-init"
  type        = string
}
