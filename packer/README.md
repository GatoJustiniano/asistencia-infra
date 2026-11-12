# packer

Construye la AMI base `asistencia-base-<versión-app>` sobre Amazon Linux 2023.

Qué debe incluir:
- Node.js y las dependencias de `asistencia-app` en un tag fijo (`npm ci --omit=dev`) en `/opt/asistencia`.
- La unidad systemd `asistencia.service`, instalada pero sin arrancar: la arranca cloud-init cuando el volumen de datos ya está montado.
- `node_exporter` como servicio, para las métricas de CPU, memoria y disco en Grafana.

Archivos previstos: `asistencia.pkr.hcl` y `variables.pkr.hcl`. La AMI se etiqueta con `AppVersion` y el worker usa la más reciente que tenga esa etiqueta.
