# packer

Construye la AMI base de los tenants, `asistencia-tenant-<fecha>`, sobre la Amazon Linux 2023 más reciente.

Qué incluye:
- Node.js, npm, git y las herramientas para compilar `sqlite3` (`gcc-c++`, `make`, `python3`), más `xfsprogs` para el volumen de datos.
- **node_exporter** como servicio systemd en el puerto 9100, con el colector `systemd` limitado a `asistencia.service` y `node_exporter.service`. Prometheus lo usa para CPU, memoria, disco y para saber si la app está corriendo. El SG del tenant solo abre el 9100 al SG de la plataforma.
- La caché de npm con las dependencias de `asistencia-app` (rama `main` por defecto), para que el primer arranque de un tenant no tenga que descargarlas ni compilarlas.
- `/etc/asistencia-ami.json` con la fecha, la versión de Node, la de node_exporter y el commit de la app usado para la caché.

Qué **no** incluye: datos, secretos ni configuración de ningún tenant. El volumen, la clave de SSM y la versión de la app los pone cloud-init al arrancar. La imagen se limpia al final (sin llaves SSH de la construcción ni estado de cloud-init).

## Construir

Requiere la red compartida (`plataforma-tenants/infra/red`): la instancia temporal se lanza en una subred con tag `Tipo=publica`, y Packer abre SSH solo a la IP pública de quien lo ejecuta.

```bash
packer init .
```

```bash
AWS_PROFILE=andres packer build .
```

Tarda unos 6 minutos y deja `manifest.json` (ignorado por git) con el id de la AMI. Variables: `node_exporter_version`, `app_version` (rama o tag para la caché) y `region`, en `variables.pkr.hcl`.

## Cómo la usa Terraform

`modules/tenant` busca la AMI propia más reciente con tag `Rol=ami-tenant` (`data "aws_ami_ids"`). Si no hay ninguna, usa Amazon Linux 2023 y cloud-init instala los paquetes (en ese caso no hay node_exporter). La variable `ami_id` permite fijar una AMI concreta.

Una AMI nueva no reemplaza a las instancias que ya existen (`ignore_changes = [ami]`): la toman los tenants nuevos y los que se recrean, por ejemplo al cambiar `app_version`. El id de la AMI sale en el output `ami_id` y el worker lo guarda entre las versiones de cada operación (RF-13).

Las AMIs viejas se pueden borrar desde la consola (Deregister AMI y luego eliminar su snapshot); cada una cuesta unos 0,4 USD/mes por el snapshot de 8 GB.
