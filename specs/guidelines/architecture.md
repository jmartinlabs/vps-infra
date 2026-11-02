# Architecture guidelines

## Fuente de verdad
Las decisiones de arquitectura de la plataforma viven en
[arquitectura](../../docs/arquitectura.md) y el estado real en
[estado-actual](../../docs/estado-actual.md). Este documento solo fija restricciones
comprobables; no introduce stack, topología ni servicios nuevos.

## Restricciones vigentes
- Un VPS compartido; ninguna aplicación es dueña del sistema anfitrión.
- Caddy centraliza la entrada HTTPS y solo enruta servicios autorizados.
- Contenedores rootless con Podman/Quadlet; identidades, redes y datos separados según riesgo.
- Sin puertos de bases de datos ni administración expuestos a Internet.
- Secretos fuera de Git, de las imágenes y de los logs.
- Copia y restauración verificables antes de incorporar datos importantes.
- Cambios reproducibles, mínimos, observables y reversibles.

## Decisiones pendientes (UNDECIDED)
Topología exacta de red rootless, propietarios de procesos, socket de Caddy, publicación
de puertos, monitorización y estrategia de copia externa. No asumir una decisión no
aprobada; documentar alternativas, motivo y aprobación antes de fijarla.

## Verificación
Cada restricción debe mapearse a un comando, revisión o evidencia concreta. La auditoría
del VPS requiere autorización de acceso separada; este repositorio no la concede.
