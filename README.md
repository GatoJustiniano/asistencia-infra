# asistencia-infra

Plantillas que crean y configuran **un tenant**. Las ejecuta el worker de [plataforma-tenants](../plataforma-tenants), que clona este repositorio en un tag fijo, por ejemplo `infra-v1.0.0`.

| Carpeta | Herramienta | Función |
|---|---|---|
| `terraform/` | Terraform / OpenTofu | Motor principal. El mismo HCL sirve para los dos binarios. |
| `pulumi/` | Pulumi (TypeScript) | Segunda implementación reducida, para comparar. |
| `cloudformation/` | CloudFormation | Segunda implementación reducida con stacks anidados. |
| `cloud-init/` | cloud-init | Configuración del primer arranque de la EC2 del tenant. |
| `packer/` | Packer | AMI base con Node, la app y node_exporter. |
| `ansible/` | Ansible | Configuración posterior de las EC2 que ya existen. |

## Estado actual

`terraform/`, `pulumi/`, `cloudformation/` y `cloud-init/` se copiaron sin cambios del práctico anterior (`infrastructure_as_code`). Lo único que cambia es que `RepoUrl` apunta ahora a `asistencia-app`. Todavía crean **una VPC por despliegue**.

## Pendiente para el proyecto final

1. **Red compartida:** sacar `network` a un stack propio que se crea una sola vez. Cada tenant recibe `vpc_id` y `subnet_id` como entradas, porque AWS permite solo 5 VPC por región.
2. **Módulo `tenant`:** Security Group, volumen EBS de datos cifrado (SQLite) y EC2. Las variables son `tenant_id`, `entorno`, `plan`, `instance_type`, `data_volume_gb` y `ami_id`. Los tags `Tenant`, `Entorno` y `Plan` sirven para que Prometheus descubra la instancia.
3. **Backend S3 del estado:** la clave es `tenants/<tenant_id>/terraform.tfstate`, con lock. Se configura con `-backend-config` desde el worker.
4. **Secretos:** `AdminKey` deja de ser una variable. cloud-init la lee de SSM en `/asistencia/<tenant>/admin-key` usando el rol IAM de la instancia.
5. **Suspender:** un recurso `aws_ec2_instance_state` con `state = var.suspendido ? "stopped" : "running"`. El volumen EBS se conserva.
6. **Pulumi y CloudFormation:** la misma interfaz que el módulo `tenant`, en versión reducida.
7. **Packer y Ansible:** ver el README de cada carpeta.

## Reglas

- Aquí no van secretos ni archivos `.tfvars` con valores reales de los tenants: los genera el worker en cada operación.
- No se suben los archivos de estado (`*.tfstate`) ni `.terraform/`.
