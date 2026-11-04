# Estado actual e inventario por verificar

**Fecha de referencia documental:** 22-10-2026. **No se ha accedido al VPS** para producir este inventario.

Distinguimos:
- **Informado por el usuario:** antecedente útil, no verificación técnica actual.
- **Verificado en GitHub:** consulta del repositorio, no prueba de despliegue.
- **Pendiente:** debe comprobarse con autorización expresa de acceso de solo lectura.

## Inventario inicial informado

| Área | Información recibida | Estado de verificación remota |
| --- | --- | --- |
| Proveedor | Aruba Cloud | Pendiente |
| Sistema | Debian 13 | Pendiente |
| Recursos | 2 vCPU, 4 GB RAM y 40 GB de almacenamiento | Pendiente |
| Administración | Usuario `mfadmin`; SSH con claves, sin contraseña | Pendiente |
| Firewall | UFW | Pendiente |
| Entrada web | Caddy como proxy inverso y HTTPS | Pendiente |
| Contenedores | Podman rootless y Quadlet | Pendiente |
| Dominio inicial | `myfinanzas.pp.ua` | Pendiente |
| Persistencia | Directorios privados para datos y backups | Pendiente |
| Despliegue | Página estática de prueba; aplicación MyFinanzas no desplegada | Pendiente |

No constan aquí pruebas de que haya reglas de firewall correctas, copias restaurables, TLS válido, políticas de retención o servicios persistentes arrancando al reiniciar.

## MyFinanzas: dependencia externa

Repositorio de aplicación: [jmartinlabs/myfinanzas-app](https://github.com/jmartinlabs/myfinanzas-app).
El remoto se verificó el 2026-11-04; el enlace anterior a `josemartin2000` era histórico.

Consulta GitHub del 22-10-2026, **no estado congelado ni autorización de despliegue**:
- Dev 31 integrado; PR [#31](https://github.com/jmartinlabs/myfinanzas-app/pull/31) integrada.
- Spec Dev 32: PR [#29](https://github.com/jmartinlabs/myfinanzas-app/pull/29) abierta, aprobación documental comunicada; pendiente de integración.
- Implementación Dev 32: PR [#30](https://github.com/jmartinlabs/myfinanzas-app/pull/30) abierta/Draft, checkpoint 23/24 AC; AC-22 y riesgos de concurrencia/durabilidad pendientes. No equivale a estar preparada para producción.
- Adopción metodológica PR [#32](https://github.com/jmartinlabs/myfinanzas-app/pull/32) y política de aislamiento PR [#33](https://github.com/jmartinlabs/myfinanzas-app/pull/33) integradas en la aplicación; **no suponen instalación de `$orchestrate` en `vps-infra`**.

Antes de coordinar una entrega relacionada, **volver a comprobar** estos enlaces y los criterios vigentes en el repositorio de aplicación.

## Auditoría inicial propuesta — solo lectura, no autorizada todavía

Comprobar sin exponer secretos:
- Identidad del anfitrión, versión de SO, fecha de actualización y estado de reinicio pendiente.
- Servicios y sockets activos, puertos escuchando y exposición pública esperada.
- Configuración/estado efectivos de SSH, UFW, Caddy (dominios, TLS y rutas) sin revelar material privado.
- Usuarios, UID/GID, rootless Podman, Quadlet y servicios `systemd --user`; persistencia tras reboot.
- Disco, inodos, particiones, memoria, CPU, logs y riesgos de falta de espacio.
- Inventario de rutas/propietarios para datos, copias locales, rotación y cifrado; sin leer contenidos sensibles.
- Estado de copias externas, restauración, alertas y mantenimiento (puede ser «no implantado»).

Entregable de la auditoría: evidencia redactada, diferencias frente a lo informado, riesgos ordenados por impacto, próximos pasos y solicitudes explícitas de autorización. No hacer correcciones durante la inspección.
