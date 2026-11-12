# Al detener y arrancar, AWS asigna una IP pública nueva; aws_instance.app guarda la
# anterior. Por eso se vuelve a leer la instancia después del cambio de estado.
data "aws_instance" "actual" {
  instance_id = aws_instance.app.id
  depends_on  = [aws_ec2_instance_state.app]
}

output "public_ip" {
  description = "Vacío mientras el tenant está suspendido (la IP pública se libera al detener)"
  value       = var.suspendido ? null : data.aws_instance.actual.public_ip
}

output "url_app" {
  value = var.suspendido ? null : "http://${data.aws_instance.actual.public_ip}"
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
