output "public_ip" {
  description = "Vacío mientras el tenant está suspendido (la IP pública se libera al detener)"
  value       = var.suspendido ? null : aws_instance.app.public_ip
}

output "url_app" {
  value = var.suspendido ? null : "http://${aws_instance.app.public_ip}"
}

output "instance_id" {
  value = aws_instance.app.id
}

output "data_volume_id" {
  value = aws_ebs_volume.datos.id
}

output "security_group_id" {
  value = aws_security_group.tenant.id
}

output "estado_instancia" {
  value = aws_ec2_instance_state.app.state
}

output "ssm_prefijo" {
  value = local.ssm_prefijo
}
