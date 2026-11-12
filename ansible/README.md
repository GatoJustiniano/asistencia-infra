# ansible

Configuración posterior de las EC2 de los tenants que ya existen. El worker de la plataforma la ejecuta después del `apply`, o cuando hay que cambiar algo sin recrear la VM.

Playbooks previstos:
- `post-config.yml`: verifica el montaje del volumen de datos, los permisos y que `asistencia` y `node_exporter` estén activos.
- `actualizar-app.yml`: cambia la app a otro tag de `asistencia-app` y reinicia el servicio.

El inventario lo genera el worker a partir de los outputs del motor (IP y tenant). No se guarda en el repo.
