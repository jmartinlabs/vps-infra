# Mi VPS · Infraestructura

Fuente de verdad **versionada y revisable** para la infraestructura personal compartida. Este repositorio está separado de las aplicaciones y no constituye, por sí mismo, una configuración desplegada.

## Objetivo y alcance

Administrar y evolucionar el VPS de Aruba Cloud para alojar **MyFinanzas** y futuras aplicaciones o webs independientes, con el menor coste y complejidad razonables.

- **Incluye:** sistema anfitrión, acceso y seguridad, red/firewall/DNS, Caddy y HTTPS, Podman rootless y Quadlet como plataforma, copias externas, restauración, observabilidad y procedimientos operativos.
- **Excluye:** lógica financiera y desarrollo propio de MyFinanzas, y el código interno de cualquier futura aplicación.
- **Límites compartidos:** aquí se definen interfaces de despliegue, dependencias entre servicios, requisitos de seguridad y operación. Cada aplicación conserva sus propios archivos de código, pruebas, esquemas y configuración exclusiva.

## Documentación

| Documento | Para qué sirve |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Reglas para Codex, seguridad, autorizaciones y PR |
| [docs/arquitectura.md](docs/arquitectura.md) | Modelo de plataforma y límites entre aplicaciones |
| [docs/estado-actual.md](docs/estado-actual.md) | Inventario conocido, evidencias y cuestiones no verificadas |
| [docs/roadmap.md](docs/roadmap.md) | Prioridades, dependencias y condiciones de aceptación |
| [docs/operaciones.md](docs/operaciones.md) | Guías de actuación **pendientes de validar**, recuperación y cambios |
| [docs/metodologia-agentes.md](docs/metodologia-agentes.md) | Adopción del harness (skills, roles, modos) y desviaciones locales |
| [CLAUDE.md](CLAUDE.md) | Punto de entrada para Claude Code, siguiendo AGENTS.md |
| [docs/harness.md](docs/harness.md) | Compatibilidad Codex/Claude y límites de validación automatizada |

## Responsabilidades

- **Usuario:** autoriza accesos al VPS, operaciones materiales, integraciones, merges y despliegues.
- **Álex (ChatGPT):** asesor técnico principal; analiza arquitectura, seguridad, prioridades y revisa evidencias.
- **Codex:** ejecuta únicamente encargos autorizados, prepara cambios aislados, pruebas, documentación y pull requests.

## Estado inicial

Según el punto de continuidad del usuario (22-10-2026): VPS Aruba Cloud, Debian 13, 2 vCPU/4 GB RAM/40 GB; usuario `mfadmin`, SSH por claves, UFW, Caddy, Podman rootless y Quadlet, dominio `myfinanzas.pp.ua`. Se informa de una página estática de prueba; **no consta MyFinanzas desplegada**. Estos datos **no han sido verificados mediante acceso al VPS**. Véase el [inventario](docs/estado-actual.md).

## Cómo trabajar

1. Leer `AGENTS.md`, inventario, arquitectura y roadmap; verificar el estado Git y el alcance autorizado.
2. Distinguir **propuesta → desarrollo → pruebas → PR → integración → despliegue**. Ninguna etapa autoriza automáticamente la siguiente.
3. Para tareas con Codex, consultar [metodología adaptada](docs/metodologia-agentes.md) y clasificar Quick / Standard / Full. Trabajar en una rama por cambio, conservar trabajo ajeno, probar y revisar el historial y el diff antes de publicar.
4. Presentar PR; **no hacer merge ni tocar el servidor** sin aprobación aplicable.
5. Si el trabajo afecta a otra aplicación, coordinar interfaces y dependencias sin apropiarse de su desarrollo.

**No guardar** aquí contraseñas, claves privadas, tokens, secretos de configuración, copias de datos ni registros con información sensible.
