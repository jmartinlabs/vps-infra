---
name: tweak
description: Aplica una modificación pequeña y de bajo riesgo en documentación o recursos locales sin impacto operativo.
---

# Tweak · VPS

## Entradas
Leer `AGENTS.md`; confirmar que el cambio es **Quick** y está autorizado.

## Procedimiento
1. Revisar alcance, rama y archivos existentes, y definir resultado observable.
2. Corregir solo el contenido local acotado; realizar las comprobaciones pertinentes y revisar diff e historial.
3. Publicar una PR cuando corresponda, indicando pruebas y límites. No requiere un documento de especificación nuevo.
4. Si aparece cambio de seguridad, SSH, UFW, DNS, Caddy activo, Podman/Quadlet activo, almacenamiento o acceso remoto, **detenerse y reclasificar**: ninguna de esas operaciones es Quick por ser corta.

## Parada
No acceder al VPS sin permiso específico; no realizar merge, despliegue, cambios destructivos o ampliaciones de alcance por inferencia.
