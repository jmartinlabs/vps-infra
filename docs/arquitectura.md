# Arquitectura de la plataforma compartida

> **Estado:** modelo inicial propuesto, no despliegue confirmado. El inventario factual pendiente está en [estado-actual.md](estado-actual.md).

## Principios

1. Un VPS hospeda aplicaciones independientes; **ninguna aplicación es dueña del sistema anfitrión**.
2. Caddy centraliza el acceso público HTTPS y envía tráfico solo a servicios explícitamente autorizados.
3. Contenedores rootless gestionados por Podman/Quadlet; aislamiento de identidades, procesos, redes, datos y secretos, proporcionado al riesgo.
4. Preferir puertos internos o loopback; no publicar directamente bases de datos ni puertos administrativos en Internet.
5. La configuración compartida se versiona aquí **solo después de auditar la que existe**. No almacenar secretos.
6. Respaldar y ensayar la recuperación antes de incorporar datos importantes; el almacenamiento local no sustituye una copia externa.
7. Favorecer cambios reproducibles, mínimos, observables y reversibles.

## Vista conceptual (no verificada)

```text
Internet (HTTPS)
      |
      v
[Caddy en el VPS: TLS / dominios / rutas]
      |
      +-- [App 1: MyFinanzas] -- datos propios / backup propio
      |
      +-- [App 2: futura web] -- datos propios / backup propio
      |
      +-- [App 3: servicio futuro] -- datos propios / backup propio

Debian 13 / SSH / UFW / Podman rootless / Quadlet
                  |
         Backup externo cifrado (por diseñar)
```

La topología exacta de loopback/red rootless, propietarios de procesos, socket de Caddy y publicación de puertos se determinará **tras auditoría y pruebas**. No asumir que Caddy y un contenedor comparten directamente red o permisos.

## Fronteras de responsabilidad

| Elemento | Repositorio dueño |
| --- | --- |
| Debian, acceso SSH, UFW, Caddy común, certificados, dominios y DNS compartidos | `vps-infra` |
| Convenciones de Podman/Quadlet, monitorización y copia/recuperación de la plataforma | `vps-infra` |
| Imagen, dependencias, código, tests, migraciones y esquema de MyFinanzas | `myfinanzas-app` |
| Configuración funcional y datos persistentes propios de cada aplicación | Repositorio de la aplicación + entorno privado del VPS |
| Contrato entre aplicación y proxy (puerto, healthcheck, rutas, variables no secretas) | Definido conjuntamente, cambios coordinados |
| Desarrollo de futuras webs y servicios | Repositorio independiente por aplicación |

Una tarea transversal debe señalar **qué cambio pertenece a cada repositorio** y la secuencia de integración/despliegue. Evitar duplicar la fuente de verdad.

## Criterios para nuevas aplicaciones

- Repositorio privado/independiente y `AGENTS.md` propio.
- Identidad rootless y datos/volúmenes independientes **cuando proceda**; valorar una cuenta de sistema por aplicación según aislamiento frente a complejidad. No asumir que una cuenta compartida es aislamiento fuerte.
- Puertos no públicos salvo la entrada HTTPS prevista; secretos fuera de Git y de las imágenes.
- Persistencia y rutas auditables, copia/restore verificables, healthcheck y rollback explícito.
- Medir carga y espacio: 2 vCPU/4 GB RAM/40 GB es un presupuesto pequeño, no una garantía de capacidad para múltiples servicios.

## No introducir por ahora

Kubernetes, orquestadores residentes, observabilidad de alto coste, nuevas bases compartidas o despliegue automatizado irreversible. Justificar cualquier excepción con necesidad y costes medibles.
