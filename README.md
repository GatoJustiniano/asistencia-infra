# asistencia-infra

Plantillas que crean y configuran **un tenant**. Las ejecuta el worker de [plataforma-tenants](../plataforma-tenants), que clona este repositorio en un tag fijo, por ejemplo `infra-v1.0.0`.

| Carpeta | Herramienta | Función |
|---|---|---|
| `terraform/` | Terraform / OpenTofu | Motor principal. El mismo HCL sirve para los dos binarios. |
| `pulumi/` | Pulumi (TypeScript) | Segunda implementación reducida, para comparar. |
| `cloudformation/` | CloudFormation | Segunda implementación reducida: `tenant.yaml`, un stack por tenant. `main.yaml`, `templates/` y `parametros/` son del práctico anterior y no se usan. |
| `cloud-init/` | cloud-init | Configuración del primer arranque de la EC2 del tenant. |
| `packer/` | Packer | AMI base de los tenants: Node.js, node_exporter y caché de dependencias de la app. |
| `ansible/` | Ansible | Configuración posterior de las EC2 que ya existen. |

## Terraform / OpenTofu: un tenant

Requiere que antes se hayan aplicado `plataforma-tenants/infra/bootstrap` (bucket del estado) e `infra/red` (VPC compartida y SG de la plataforma). El tenant encuentra la VPC, las subredes y el SG de la plataforma **por tags**, así que no recibe ids de red.

Qué crea `modules/tenant` por cada tenant:

| Recurso | Para qué |
|---|---|
| Security Group `asistencia-<id>-sg` | Puerto 80 abierto a internet; 22 (Ansible), 9100 (node_exporter) y 9101 (métricas de la app) solo desde el SG de la plataforma. No hay tráfico entre tenants. |
| `random_password` + parámetro SSM `/asistencia/<id>/admin-key` (SecureString) | Clave del panel docente. No está en el código ni en la plantilla. |
| Rol IAM + perfil de instancia | Solo puede leer `/asistencia/<id>/*` (no los secretos de otro tenant), más Session Manager para diagnóstico. Lleva el permissions boundary `asistencia-limite-tenant` (variable `limite_permisos`), que crea `plataforma-tenants/infra/plataforma` y que el worker exige al crear roles. |
| Volumen EBS `asistencia-<id>-datos` (gp3, cifrado) | Base SQLite montada en `/var/lib/asistencia`. Sobrevive a suspender y a recrear la EC2. |
| EC2 `asistencia-<id>-app` (IMDSv2, disco raíz cifrado) | Frontend y backend. Arranca con la AMI de Packer más reciente (tag `Rol=ami-tenant`); cloud-init monta el volumen, lee el secreto de SSM e instala la app. El nombre de la institución (variable `nombre`) llega en base64 y se escribe como `INSTITUCION`, el título de la app; así tildes, comillas o símbolos no rompen el script. |
| `aws_ec2_instance_state` | `suspendido = true` detiene la EC2; `false` la vuelve a arrancar |

Probar a mano (el worker hará lo mismo, generando el `.tfvars.json` desde `catalogo/planes.json`):

```bash
cd terraform
```

```bash
terraform init -reconfigure -backend-config="key=tenants/san-marcos/terraform.tfstate"
```

```bash
terraform apply -var-file=ejemplos/basico.tfvars.json
```

Suspender y reanudar: el mismo `apply` con `-var suspendido=true` o `-var suspendido=false`. Para eliminar: `terraform plan -destroy -var-file=...` (para revisar qué se borrará) y después `terraform destroy -var-file=...`.

Con OpenTofu los comandos son los mismos, cambiando `terraform` por `tofu`.

## Pendiente

1. ~~CloudFormation~~: hecho, en `cloudformation/tenant.yaml`; lo ejecuta `plataforma-tenants/worker/motores/cloudformation.js`. **Pulumi** sigue siendo la versión del práctico anterior; se cubre con la comparación técnica de `plataforma-tenants/docs/arquitectura.md`.
2. **Ansible:** ver `ansible/README.md`.
3. ~~Respaldos~~: hecho. El volumen de datos lleva el tag `Respaldo=<plan>` (lo respalda la política de DLM del plan) y la variable `snapshot_datos` permite restaurarlo (ver `plataforma-tenants/docs/respaldos.md`).

## Reglas

- Aquí no van secretos ni archivos `.tfvars` con valores reales de los tenants: los genera el worker en cada operación.
- No se suben los archivos de estado (`*.tfstate`) ni `.terraform/`.
