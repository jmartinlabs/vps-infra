# Security guidelines

## Límites
No guardar secretos, claves, tokens, credenciales ni datos personales o financieros reales
en el repositorio, PR, logs o chat. Usar fixtures ficticios y valores redactados.

## Acceso y operaciones protegidas
- Sin acceso al VPS, SSH, firewall, DNS, Caddy, Podman/Quadlet, backups o servicios activos
  sin autorización expresa para ese alcance.
- Sin operaciones destructivas, restauración, rollback, despliegue ni cambio de permisos o
  visibilidad sin aprobación específica.
- La autorización de una tarea no se extiende a etapas posteriores ni a otros sistemas.

## Publicación
Publicar rama y PR dentro del alcance autorizado sigue
[la política de publicación](../methodology/approvals.md#branch-and-pr-publication).
La publicación de paquetes o artefactos (package or artifact publication) y el despliegue
requieren aprobación separada. Nunca auto-merge ni force push.
