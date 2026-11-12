variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  description = "Solo para construir la imagen; los tenants eligen su tipo según el plan"
  type        = string
  default     = "t3.micro"
}

variable "node_exporter_version" {
  type    = string
  default = "1.9.1"
}

variable "app_repo_url" {
  description = "Repositorio de la app: se usa solo para dejar las dependencias npm en caché"
  type        = string
  default     = "https://github.com/GatoJustiniano/asistencia-app.git"
}

variable "app_version" {
  description = "Rama o tag de la app cuyas dependencias quedan en la caché de npm"
  type        = string
  default     = "main"
}
