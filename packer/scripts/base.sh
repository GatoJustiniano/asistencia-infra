#!/bin/bash
# Provisión de la AMI base de los tenants. Lo ejecuta Packer como root.
set -euxo pipefail

# 1) Paquetes: runtime de la app y lo necesario para compilar sqlite3 si no hay binario
dnf -y update
dnf -y install git nodejs npm gcc-c++ make python3 xfsprogs tar
node --version && npm --version

# 2) node_exporter (métricas de CPU, memoria, disco y estado de servicios para Prometheus)
cd /tmp
NE="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"
BASE="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}"
curl -fsSLO "$BASE/$NE.tar.gz"
curl -fsSLO "$BASE/sha256sums.txt"
grep " $NE.tar.gz\$" sha256sums.txt | sha256sum -c -   # verifica la descarga
tar xzf "$NE.tar.gz"
install -m 0755 "$NE/node_exporter" /usr/local/bin/node_exporter
rm -rf "$NE" "$NE.tar.gz" sha256sums.txt
id node_exporter >/dev/null 2>&1 || useradd --system --no-create-home --shell /sbin/nologin node_exporter

cat > /etc/systemd/system/node_exporter.service <<'UNIT'
[Unit]
Description=Prometheus node_exporter
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
# El puerto 9100 solo está abierto al SG de la plataforma (ver módulo tenant)
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address=:9100 \
  --collector.systemd \
  --collector.systemd.unit-include=(asistencia|node_exporter)\.service \
  --collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys)($|/)
Restart=always
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable node_exporter

# 3) Caché de npm con las dependencias de la app: el primer arranque de cada tenant
#    no tiene que descargarlas ni compilarlas de nuevo
git clone --depth 1 --filter=blob:none --sparse --branch "$APP_VERSION" "$APP_REPO_URL" /tmp/app
git -C /tmp/app sparse-checkout set backend
(cd /tmp/app/backend && npm ci --omit=dev)
APP_COMMIT=$(git -C /tmp/app rev-parse HEAD)
rm -rf /tmp/app

# 4) Datos de la imagen, para auditoría
cat > /etc/asistencia-ami.json <<JSON
{
  "construida": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "node": "$(node --version)",
  "node_exporter": "${NODE_EXPORTER_VERSION}",
  "cache_app": "${APP_VERSION}@${APP_COMMIT}"
}
JSON

# 5) Limpieza: sin llaves SSH de la construcción ni estado de cloud-init
dnf clean all
cloud-init clean --logs
rm -f /home/ec2-user/.ssh/authorized_keys /root/.bash_history
