# Hoja de ruta · VPS compartido

> Roadmap **propuesto** a 22-10-2026. Las fases no son órdenes de ejecución ni autorizaciones implícitas.

## Prioridades

| Prioridad | Entrega | Dependencias | Criterio de salida |
| --- | --- | --- | --- |
| P0 | Auditoría de solo lectura del VPS | Autorización expresa de acceso acotado | Inventario verificado, riesgos y decisiones pendientes; **ningún cambio remoto** |
| P1 | Política de backup externo y recuperación | Inventario de datos, alcance/ubicación, RPO/RTO acordados | Diseño aprobado, retención/cifrado y pruebas de restore aisladas documentadas |
| P2 | Contrato común de despliegue Caddy ↔ Podman/Quadlet | P0, aplicación preparada, dependencias de seguridad | Rutas/red/permisos definidos, pruebas y rollback ensayado sin afectar otros servicios |
| P3 | Operación y mantenimiento básico | P0 y decisiones sobre servicios reales | Salud, alertas, límites de disco, logs, parches y procedimientos operativos verificables |
| P4 | Versionado reproducible de configuración compartida | P0 y contratos aprobados | Cambios mínimos revisados en este repo, sin secretos y reconciliados con el VPS real |

El orden describe **prioridad**, no secuencia estrictamente lineal: P1 puede diseñarse mientras la aplicación termina Dev 32; cambios operativos requieren validar dependencias y autorización.

## Primer despliegue controlado de MyFinanzas (datos ficticios)

Se coordina con el repositorio de aplicación, pero **no forma parte de su desarrollo funcional**:
1. Dev 32 y dependencias resueltas e integradas; confirmar AC-22 y riesgos conocidos.
2. Contrato de red/proxy, HTTPS y recursos verificado para el entorno ficticio.
3. Copias externas, cifrado, retención y prueba de restore aprobados y ensayados.
4. Runbook de despliegue, healthcheck, reversión y recuperación validado sin otros servicios afectados.
5. Aprobación expresa del usuario del despliegue concreto.
6. Verificación posterior e inventario del estado realmente operativo.

Que una CI esté en verde, que una especificación esté aprobada o que exista un fichero Quadlet **no acredita** despliegue/recuperación real.

## Decisiones diferidas

- Creación de usuarios rootless adicionales y política exacta de aislamiento por aplicación.
- Destino externo de backups, coste, retención, RPO/RTO y custodias de claves.
- Registro de servicios, monitorización y alertas mínimas.
- Automatización del despliegue y su alcance. El
  [contrato de despliegue por tags](despliegue-por-tags.md) está documentado, pero **no
  habilitado**; no se introduce automatización sin decisiones, pruebas y autorización.
- Adopción de `$orchestrate` u otro modelo multiagente **si se demuestra ventaja operacional**.

## Próxima propuesta al usuario

Autorizar **por separado** una auditoría de solo lectura: identidad/servicios/red, capacidad, persistencia, Caddy, UFW, Podman/Quadlet y estado de backups. Antes, acordar medio de acceso y límites; evitar capturar secretos. Después revisar hallazgos y proponer cambios mediante PR y autorizaciones específicas.
