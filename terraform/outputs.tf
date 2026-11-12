# El worker lee estos valores con `terraform output -json` y los guarda en la BD de la plataforma.

output "url_app" {
  value = module.tenant.url_app
}

output "public_ip" {
  value = module.tenant.public_ip
}

output "instance_id" {
  value = module.tenant.instance_id
}

output "data_volume_id" {
  value = module.tenant.data_volume_id
}

output "security_group_id" {
  value = module.tenant.security_group_id
}

output "estado_instancia" {
  value = module.tenant.estado_instancia
}

output "ssm_prefijo" {
  value = module.tenant.ssm_prefijo
}
